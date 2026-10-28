#!/bin/bash

CONTAINER_NAME="gitea"
IMAGE="docker.gitea.com/gitea:latest"
PORT_WEB=3001
PORT_SSH=2222
DATA_PATH="$HOME/.local/share/gitea-data"
NETWORK_NAME="gitea-network"

# PostgreSQL database container (dedicated to Gitea, not published to the host)
DB_CONTAINER_NAME="gitea-db"
DB_IMAGE="postgres:17"   # pinned: major version upgrades require a data migration
DB_NAME="gitea"
DB_USER="gitea"
DB_PASSWORD="P@ssword92"
DB_DATA_PATH="$HOME/.local/share/gitea-db-data"

# Gitea Actions runner (act_runner); registers itself on first start after setup
RUNNER_CONTAINER_NAME="gitea-runner"
RUNNER_IMAGE="docker.gitea.com/act_runner:latest"
RUNNER_NAME="$(hostname)-runner"
RUNNER_DATA_PATH="$HOME/.local/share/gitea-runner-data"
DOCKER_SOCKET="/var/run/docker.sock"

start_database() {
    echo "Starting Gitea PostgreSQL container..."

    # Remove existing container if present
    docker rm -f $DB_CONTAINER_NAME 2>/dev/null || true

    # Create data directory if it doesn't exist
    mkdir -p "$DB_DATA_PATH"

    docker run -d \
        --name $DB_CONTAINER_NAME \
        --network $NETWORK_NAME \
        --restart=unless-stopped \
        -e "POSTGRES_USER=$DB_USER" \
        -e "POSTGRES_PASSWORD=$DB_PASSWORD" \
        -e "POSTGRES_DB=$DB_NAME" \
        -v "$DB_DATA_PATH:/var/lib/postgresql/data" \
        --health-cmd "pg_isready -U $DB_USER -d $DB_NAME || exit 1" \
        --health-interval 30s \
        --health-timeout 5s \
        --health-retries 3 \
        --health-start-period 30s \
        "$DB_IMAGE"

    # Wait for PostgreSQL to accept connections before starting Gitea
    echo "Waiting for PostgreSQL to accept connections..."
    for i in $(seq 1 30); do
        if docker exec $DB_CONTAINER_NAME pg_isready -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
            echo "PostgreSQL is ready."
            return 0
        fi
        sleep 2
    done

    echo "Error: PostgreSQL did not become ready in time"
    return 1
}

start_container() {
    echo "Starting Gitea container..."

    # Ensure network exists
    if ! docker network inspect $NETWORK_NAME >/dev/null 2>&1; then
        docker network create $NETWORK_NAME
    fi

    # Remove existing container if present
    docker rm -f $CONTAINER_NAME 2>/dev/null || true

    start_database || exit 1

    # Create data directory if it doesn't exist
    mkdir -p "$DATA_PATH"

    docker run -d \
        --name $CONTAINER_NAME \
        --network $NETWORK_NAME \
        -p ${PORT_WEB}:3000 \
        -p ${PORT_SSH}:22 \
        --restart=unless-stopped \
        -v "$DATA_PATH:/data" \
        -v /etc/timezone:/etc/timezone:ro \
        -v /etc/localtime:/etc/localtime:ro \
        -e USER_UID=$(id -u) \
        -e USER_GID=$(id -g) \
        -e GITEA__server__SSH_PORT=${PORT_SSH} \
        -e GITEA__server__SSH_LISTEN_PORT=22 \
        -e GITEA__database__DB_TYPE=postgres \
        -e GITEA__database__HOST=${DB_CONTAINER_NAME}:5432 \
        -e GITEA__database__NAME=$DB_NAME \
        -e GITEA__database__USER=$DB_USER \
        -e "GITEA__database__PASSWD=$DB_PASSWORD" \
        -e GITEA__actions__ENABLED=true \
        --health-cmd "curl -sf http://localhost:3000 || exit 1" \
        --health-interval 30s \
        --health-timeout 5s \
        --health-retries 3 \
        --health-start-period 30s \
        "$IMAGE"

    echo "Gitea container started successfully."

    start_runner
}

write_runner_config() {
    # Only written once so local edits to config.yaml are preserved
    [ -f "$RUNNER_DATA_PATH/config.yaml" ] && return 0

    cat > "$RUNNER_DATA_PATH/config.yaml" <<'YAML'
log:
  level: info

runner:
  file: /data/.runner
  capacity: 2
  timeout: 3h
  labels:
    - "ubuntu-latest:docker://docker.gitea.com/runner-images:ubuntu-latest"
    - "ubuntu-24.04:docker://docker.gitea.com/runner-images:ubuntu-24.04"
    - "ubuntu-22.04:docker://docker.gitea.com/runner-images:ubuntu-22.04"

cache:
  enabled: true
  dir: /data/cache

container:
  # Job containers use the host network so actions/checkout can reach
  # Gitea at its ROOT_URL (http://localhost:3001)
  network: host
  privileged: false
  valid_volumes: []
  force_pull: false

host:
  workdir_parent: /data/workdir
YAML
}

wait_for_gitea() {
    for i in $(seq 1 30); do
        if docker exec $CONTAINER_NAME curl -sf http://localhost:3000/api/healthz >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
    done
    return 1
}

start_runner() {
    echo "Starting Gitea Actions runner..."

    docker rm -f $RUNNER_CONTAINER_NAME 2>/dev/null || true

    mkdir -p "$RUNNER_DATA_PATH"
    write_runner_config

    local token=""
    if [ ! -s "$RUNNER_DATA_PATH/.runner" ]; then
        if ! wait_for_gitea; then
            echo "Warning: Gitea did not become ready; skipping runner start"
            return 0
        fi

        # Fails until the first-run installation wizard has been completed
        token=$(docker exec -u git $CONTAINER_NAME gitea actions generate-runner-token 2>/dev/null | tail -n 1)
        if [ -z "$token" ]; then
            echo "Runner not registered: complete the Gitea installation wizard, then restart the service."
            return 0
        fi
        echo "Registering runner '$RUNNER_NAME'..."
    fi

    # Host network so the runner and its job containers both reach Gitea at
    # its ROOT_URL. Run as the service user so runner files stay owned by it;
    # the docker socket group grants access to start job containers
    docker run -d \
        --name $RUNNER_CONTAINER_NAME \
        --network host \
        --restart=unless-stopped \
        --user "$(id -u):$(id -g)" \
        --group-add "$(stat -c %g $DOCKER_SOCKET)" \
        -v "$RUNNER_DATA_PATH:/data" \
        -v "$DOCKER_SOCKET:/var/run/docker.sock" \
        -e HOME=/data \
        -e CONFIG_FILE=/data/config.yaml \
        -e GITEA_INSTANCE_URL=http://localhost:${PORT_WEB} \
        -e "GITEA_RUNNER_REGISTRATION_TOKEN=$token" \
        -e "GITEA_RUNNER_NAME=$RUNNER_NAME" \
        "$RUNNER_IMAGE"

    echo "Gitea Actions runner started successfully."
}

stop_container() {
    echo "Stopping Gitea Actions runner..."
    docker stop "$RUNNER_CONTAINER_NAME" 2>/dev/null || echo "Runner container is not running."
    docker rm "$RUNNER_CONTAINER_NAME" 2>/dev/null || echo "Runner container already removed."

    echo "Stopping Gitea container..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || echo "Container is not running."
    docker rm "$CONTAINER_NAME" 2>/dev/null || echo "Container already removed."

    echo "Stopping Gitea PostgreSQL container..."
    docker stop "$DB_CONTAINER_NAME" 2>/dev/null || echo "Database container is not running."
    docker rm "$DB_CONTAINER_NAME" 2>/dev/null || echo "Database container already removed."
}

status_container() {
    docker ps -a --filter "name=$CONTAINER_NAME"
}

check_health() {
    echo "Checking Gitea container health..."

    if ! docker ps --format "{{.Names}}" | grep -q "^${DB_CONTAINER_NAME}$"; then
        echo "Database container is not running"
        return 1
    fi

    if ! docker exec "$DB_CONTAINER_NAME" pg_isready -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
        echo "PostgreSQL is not responding"
        return 1
    fi

    if ! docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        echo "Container is not running"
        return 1
    fi

    if ! curl -sf "http://127.0.0.1:${PORT_WEB}" >/dev/null 2>&1; then
        echo "Gitea web UI is not responding"
        return 1
    fi

    if [ -s "$RUNNER_DATA_PATH/.runner" ]; then
        if ! docker ps --format "{{.Names}}" | grep -q "^${RUNNER_CONTAINER_NAME}$"; then
            echo "Actions runner is registered but not running"
            return 1
        fi
    else
        echo "Note: Actions runner is not registered yet"
    fi

    echo "Gitea is healthy and accessible at http://localhost:${PORT_WEB} (database: ${DB_CONTAINER_NAME})"
    return 0
}

case "$1" in
    start) start_container ;;
    stop) stop_container ;;
    status) status_container ;;
    health) check_health ;;
    *) echo "Usage: $0 {start|stop|status|health}" ;;
esac
