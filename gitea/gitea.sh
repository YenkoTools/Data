#!/bin/bash

CONTAINER_NAME="gitea"
IMAGE="docker.gitea.com/gitea:latest"
PORT_WEB=3001
PORT_SSH=2222
DATA_PATH="$HOME/.local/share/gitea-data"

start_container() {
    echo "Starting Gitea container..."

    # Remove existing container if present
    docker rm -f $CONTAINER_NAME 2>/dev/null || true

    # Create data directory if it doesn't exist
    mkdir -p "$DATA_PATH"

    docker run -d \
        --name $CONTAINER_NAME \
        -p ${PORT_WEB}:3000 \
        -p ${PORT_SSH}:22 \
        --restart=unless-stopped \
        -v "$DATA_PATH:/data" \
        -v /etc/timezone:/etc/timezone:ro \
        -v /etc/localtime:/etc/localtime:ro \
        -e USER_UID=$(id -u) \
        -e USER_GID=$(id -g) \
        --health-cmd "curl -sf http://localhost:3000 || exit 1" \
        --health-interval 30s \
        --health-timeout 5s \
        --health-retries 3 \
        --health-start-period 30s \
        "$IMAGE"

    echo "Gitea container started successfully."
}

stop_container() {
    echo "Stopping Gitea container..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || echo "Container is not running."
    docker rm "$CONTAINER_NAME" 2>/dev/null || echo "Container already removed."
}

status_container() {
    docker ps -a --filter "name=$CONTAINER_NAME"
}

check_health() {
    echo "Checking Gitea container health..."

    if ! docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        echo "Container is not running"
        return 1
    fi

    if ! curl -sf "http://127.0.0.1:${PORT_WEB}" >/dev/null 2>&1; then
        echo "Gitea web UI is not responding"
        return 1
    fi

    echo "Gitea is healthy and accessible at http://localhost:${PORT_WEB}"
    return 0
}

case "$1" in
    start) start_container ;;
    stop) stop_container ;;
    status) status_container ;;
    health) check_health ;;
    *) echo "Usage: $0 {start|stop|status|health}" ;;
esac
