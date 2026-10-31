#!/bin/bash

CONTAINER_NAME="pgsql"
IMAGE="postgres:18"   # pinned: major version upgrades require a data migration
PORT=5432
POSTGRES_USER="admin"
POSTGRES_PASSWORD="P@ssword92"
POSTGRES_DB="default_database"
DATA_PATH="$HOME/.local/share/pgsql-data"

start_container() {
    echo "Starting PostgreSQL container..."

    # Remove existing container if present
    docker rm -f $CONTAINER_NAME 2>/dev/null || true

    # Create data directory if it doesn't exist
    mkdir -p "$DATA_PATH"

    # Start the container
    docker run -d \
        --name $CONTAINER_NAME \
        --network host \
        --restart=unless-stopped \
        -e "POSTGRES_USER=$POSTGRES_USER" \
        -e "POSTGRES_PASSWORD=$POSTGRES_PASSWORD" \
        -e "POSTGRES_DB=$POSTGRES_DB" \
        -v "$DATA_PATH:/var/lib/postgresql" \
        --health-cmd "pg_isready -U $POSTGRES_USER || exit 1" \
        --health-interval 30s \
        --health-timeout 5s \
        --health-retries 3 \
        --health-start-period 30s \
        "$IMAGE"

    echo "PostgreSQL container started successfully."
}

stop_container() {
    echo "Stopping PostgreSQL container..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || echo "Container is not running."
    docker rm "$CONTAINER_NAME" 2>/dev/null || echo "Container already removed."
}

status_container() {
    docker ps -a --filter "name=$CONTAINER_NAME"
}

check_health() {
    echo "Checking PostgreSQL container health..."

    if ! docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        echo "Container is not running"
        return 1
    fi

    if ! docker exec "$CONTAINER_NAME" pg_isready -U "$POSTGRES_USER" >/dev/null 2>&1; then
        echo "PostgreSQL is not responding"
        return 1
    fi

    echo "PostgreSQL is healthy and accepting connections on port $PORT"
    return 0
}

case "$1" in
    start) start_container ;;
    stop) stop_container ;;
    status) status_container ;;
    health) check_health ;;
    *) echo "Usage: $0 {start|stop|status|health}" ;;
esac
