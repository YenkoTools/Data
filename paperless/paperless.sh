#!/bin/bash

CONTAINER_NAME="paperless"
IMAGE="ghcr.io/paperless-ngx/paperless-ngx:latest"
PORT_WEB=8000
BIND_ADDRESS="127.0.0.1"   # set to 0.0.0.0 to allow access from other machines
PAPERLESS_URL=""           # e.g. http://myhost:8000; set when not browsing via localhost
OCR_LANGUAGE="eng"
DATA_PATH="$HOME/.local/share/paperless-data"
SECRET_KEY_FILE="$HOME/.config/paperless/secret_key"
NETWORK_NAME="paperless-network"

# PostgreSQL database container (dedicated to Paperless, not published to the host)
DB_CONTAINER_NAME="paperless-db"
DB_IMAGE="postgres:18"   # pinned: major version upgrades require a data migration
DB_NAME="paperless"
DB_USER="paperless"
DB_PASSWORD="paperless"
DB_DATA_PATH="$HOME/.local/share/paperless-db-data"

# Valkey message broker for Paperless background tasks (not published to the host)
BROKER_CONTAINER_NAME="paperless-broker"
BROKER_IMAGE="docker.io/valkey/valkey:9-alpine"
BROKER_DATA_PATH="$HOME/.local/share/paperless-broker-data"

ensure_secret_key() {
    # Generated once and kept outside the repository; changing it ends all sessions
    [ -s "$SECRET_KEY_FILE" ] && return 0

    mkdir -p "$(dirname "$SECRET_KEY_FILE")"
    (umask 077 && head -c 48 /dev/urandom | base64 | tr -d '\n' > "$SECRET_KEY_FILE")
}

start_broker() {
    echo "Starting Paperless broker container..."

    docker rm -f $BROKER_CONTAINER_NAME 2>/dev/null || true

    mkdir -p "$BROKER_DATA_PATH"

    docker run -d \
        --name $BROKER_CONTAINER_NAME \
        --network $NETWORK_NAME \
        --restart=unless-stopped \
        -v "$BROKER_DATA_PATH:/data" \
        --health-cmd "valkey-cli ping | grep -q PONG" \
        --health-interval 30s \
        --health-timeout 5s \
        --health-retries 3 \
        --health-start-period 10s \
        "$BROKER_IMAGE"
}

start_database() {
    echo "Starting Paperless PostgreSQL container..."

    docker rm -f $DB_CONTAINER_NAME 2>/dev/null || true

    mkdir -p "$DB_DATA_PATH"

    # PostgreSQL 18 images keep the cluster below /var/lib/postgresql
    docker run -d \
        --name $DB_CONTAINER_NAME \
        --network $NETWORK_NAME \
        --restart=unless-stopped \
        -e "POSTGRES_USER=$DB_USER" \
        -e "POSTGRES_PASSWORD=$DB_PASSWORD" \
        -e "POSTGRES_DB=$DB_NAME" \
        -v "$DB_DATA_PATH:/var/lib/postgresql" \
        --health-cmd "pg_isready -U $DB_USER -d $DB_NAME || exit 1" \
        --health-interval 30s \
        --health-timeout 5s \
        --health-retries 3 \
        --health-start-period 30s \
        "$DB_IMAGE" || return 1

    # Probe over TCP: the temporary server used during first-run setup is socket only
    echo "Waiting for PostgreSQL to accept connections..."
    for i in $(seq 1 30); do
        if docker exec $DB_CONTAINER_NAME pg_isready -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
            echo "PostgreSQL is ready."
            return 0
        fi
        sleep 2
    done

    echo "Error: PostgreSQL did not become ready in time"
    return 1
}

start_container() {
    # Ensure network exists
    if ! docker network inspect $NETWORK_NAME >/dev/null 2>&1; then
        docker network create $NETWORK_NAME
    fi

    # Remove existing container if present
    docker rm -f $CONTAINER_NAME 2>/dev/null || true

    start_broker || return 1
    start_database || return 1

    echo "Starting Paperless container..."

    ensure_secret_key || return 1

    # Create data directories if they don't exist
    mkdir -p "$DATA_PATH/data" "$DATA_PATH/media" "$DATA_PATH/consume" "$DATA_PATH/export"

    local url_args=()
    [ -n "$PAPERLESS_URL" ] && url_args=(-e "PAPERLESS_URL=$PAPERLESS_URL")

    # USERMAP_* makes files in the mounted directories belong to the service user.
    # The key is passed by name so its value stays out of the process list
    PAPERLESS_SECRET_KEY="$(cat "$SECRET_KEY_FILE")" docker run -d \
        --name $CONTAINER_NAME \
        --network $NETWORK_NAME \
        -p ${BIND_ADDRESS}:${PORT_WEB}:8000 \
        --restart=unless-stopped \
        -v "$DATA_PATH/data:/usr/src/paperless/data" \
        -v "$DATA_PATH/media:/usr/src/paperless/media" \
        -v "$DATA_PATH/consume:/usr/src/paperless/consume" \
        -v "$DATA_PATH/export:/usr/src/paperless/export" \
        -e USERMAP_UID=$(id -u) \
        -e USERMAP_GID=$(id -g) \
        -e PAPERLESS_SECRET_KEY \
        -e PAPERLESS_REDIS=redis://${BROKER_CONTAINER_NAME}:6379 \
        -e PAPERLESS_DBENGINE=postgresql \
        -e PAPERLESS_DBHOST=$DB_CONTAINER_NAME \
        -e PAPERLESS_DBNAME=$DB_NAME \
        -e PAPERLESS_DBUSER=$DB_USER \
        -e "PAPERLESS_DBPASS=$DB_PASSWORD" \
        -e "PAPERLESS_TIME_ZONE=$(cat /etc/timezone 2>/dev/null || echo UTC)" \
        -e "PAPERLESS_OCR_LANGUAGE=$OCR_LANGUAGE" \
        "${url_args[@]}" \
        --health-cmd "curl -fsS -L --max-time 2 http://localhost:8000 || exit 1" \
        --health-interval 30s \
        --health-timeout 10s \
        --health-retries 5 \
        --health-start-period 120s \
        "$IMAGE" || return 1

    echo "Paperless container started successfully."
}

stop_container() {
    for container in $CONTAINER_NAME $DB_CONTAINER_NAME $BROKER_CONTAINER_NAME; do
        echo "Stopping $container..."
        docker stop "$container" 2>/dev/null || echo "$container is not running."
        docker rm "$container" 2>/dev/null || echo "$container already removed."
    done
}

status_container() {
    docker ps -a --filter "name=$CONTAINER_NAME"
}

check_health() {
    echo "Checking Paperless container health..."

    for container in $BROKER_CONTAINER_NAME $DB_CONTAINER_NAME $CONTAINER_NAME; do
        if ! docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
            echo "Container $container is not running"
            return 1
        fi
    done

    if ! docker exec "$BROKER_CONTAINER_NAME" valkey-cli ping >/dev/null 2>&1; then
        echo "Broker is not responding"
        return 1
    fi

    if ! docker exec "$DB_CONTAINER_NAME" pg_isready -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
        echo "PostgreSQL is not responding"
        return 1
    fi

    if ! curl -sf -L --max-time 5 "http://127.0.0.1:${PORT_WEB}" >/dev/null 2>&1; then
        echo "Paperless web UI is not responding (it can take a few minutes on first start)"
        return 1
    fi

    echo "Paperless is healthy and accessible at http://localhost:${PORT_WEB}"
    return 0
}

case "$1" in
    start) start_container ;;
    stop) stop_container ;;
    status) status_container ;;
    health) check_health ;;
    *) echo "Usage: $0 {start|stop|status|health}" ;;
esac
