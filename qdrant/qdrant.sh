#!/bin/bash

CONTAINER_NAME="qdrant"
IMAGE="qdrant/qdrant:latest"
PORT_REST=6333
PORT_GRPC=6334
DATA_PATH="$HOME/.local/share/qdrant-data"

start_container() {
    echo "Starting Qdrant container..."

    # Remove existing container if present
    docker rm -f $CONTAINER_NAME 2>/dev/null || true

    # Create data directory if it doesn't exist
    mkdir -p "$DATA_PATH"

    # Start the container
    docker run -d \
        --name $CONTAINER_NAME \
        --network host \
        --restart=unless-stopped \
        -v "$DATA_PATH:/qdrant/storage" \
        --health-cmd "curl -sf http://127.0.0.1:${PORT_REST}/healthz || exit 1" \
        --health-interval 30s \
        --health-timeout 5s \
        --health-retries 3 \
        --health-start-period 15s \
        "$IMAGE"

    echo "Qdrant container started successfully."
}

stop_container() {
    echo "Stopping Qdrant container..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || echo "Container is not running."
    docker rm "$CONTAINER_NAME" 2>/dev/null || echo "Container already removed."
}

status_container() {
    docker ps -a --filter "name=$CONTAINER_NAME"
}

check_health() {
    echo "Checking Qdrant container health..."

    if ! docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        echo "Container is not running"
        return 1
    fi

    if ! curl -sf "http://127.0.0.1:${PORT_REST}/healthz" >/dev/null 2>&1; then
        echo "Qdrant REST API is not responding"
        return 1
    fi

    echo "Qdrant is healthy and accepting connections on port $PORT_REST (REST) and $PORT_GRPC (gRPC)"
    return 0
}

case "$1" in
    start) start_container ;;
    stop) stop_container ;;
    status) status_container ;;
    health) check_health ;;
    *) echo "Usage: $0 {start|stop|status|health}" ;;
esac
