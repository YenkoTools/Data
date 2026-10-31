#!/bin/bash

CONTAINER_NAME="valkey"
IMAGE="docker.io/valkey/valkey:latest"
PORT=6379
PASSWORD="P@ssword92"
DATA_PATH="$HOME/.local/share/valkey-data"

start_container() {
    echo "Starting Valkey container..."

    # Remove existing container if present
    docker rm -f $CONTAINER_NAME 2>/dev/null || true

    # Create data directory if it doesn't exist
    mkdir -p "$DATA_PATH"

    # Start the container; password and AOF persistence are passed as server arguments
    docker run -d \
        --name $CONTAINER_NAME \
        --network host \
        --restart=unless-stopped \
        -v "$DATA_PATH:/data" \
        --health-cmd "valkey-cli -p $PORT -a '$PASSWORD' --no-auth-warning ping | grep -q PONG || exit 1" \
        --health-interval 30s \
        --health-timeout 5s \
        --health-retries 3 \
        --health-start-period 10s \
        "$IMAGE" \
        valkey-server --port "$PORT" --requirepass "$PASSWORD" --appendonly yes

    echo "Valkey container started successfully."
}

stop_container() {
    echo "Stopping Valkey container..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || echo "Container is not running."
    docker rm "$CONTAINER_NAME" 2>/dev/null || echo "Container already removed."
}

status_container() {
    docker ps -a --filter "name=$CONTAINER_NAME"
}

check_health() {
    echo "Checking Valkey container health..."

    if ! docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        echo "Container is not running"
        return 1
    fi

    if ! docker exec "$CONTAINER_NAME" valkey-cli -p "$PORT" -a "$PASSWORD" --no-auth-warning ping 2>/dev/null | grep -q "PONG"; then
        echo "Valkey is not responding"
        return 1
    fi

    echo "Valkey is healthy and accepting connections on port $PORT"
    return 0
}

case "$1" in
    start) start_container ;;
    stop) stop_container ;;
    status) status_container ;;
    health) check_health ;;
    *) echo "Usage: $0 {start|stop|status|health}" ;;
esac
