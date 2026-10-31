#!/bin/bash

CONTAINER_NAME="mssql-server"
IMAGE="mcr.microsoft.com/mssql/server:2025-latest"
SA_PASSWORD="P@ssword92"
PORT=1433
DATA_PATH="$HOME/.local/share/mssql-data"

start_container() {
    echo "Starting SQL Server container..."

    # Remove existing container if present
    docker rm -f $CONTAINER_NAME 2>/dev/null || true

    # Create data directory if it doesn't exist
    mkdir -p "$DATA_PATH"

    # Start the container
    docker run -d \
        --user root \
        --name $CONTAINER_NAME \
        --network host \
        --restart=unless-stopped \
        -e 'ACCEPT_EULA=Y' \
        -e "SA_PASSWORD=$SA_PASSWORD" \
        -v "$DATA_PATH:/var/opt/mssql" \
        --health-cmd "/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$SA_PASSWORD' -Q 'SELECT 1' -N -C || exit 1" \
        --health-interval 30s \
        --health-timeout 10s \
        --health-retries 3 \
        --health-start-period 30s \
        "$IMAGE"

    echo "SQL Server container started successfully."
}

stop_container() {
    echo "Stopping SQL Server container..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || echo "Container is not running."
    docker rm "$CONTAINER_NAME" 2>/dev/null || echo "Container already removed."
}

status_container() {
    docker ps -a --filter "name=$CONTAINER_NAME"
}

check_health() {
    # Construct the sqlcmd command to run inside the container
    SQLCMD_COMMAND="/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$SA_PASSWORD' -Q 'SELECT @@version' -N -C"

    echo "Checking SQL Server container health..."
    if ! docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        echo "Container is not running"
        return 1
    fi
    
    if ! docker exec "$CONTAINER_NAME" bash -c "$SQLCMD_COMMAND" >/dev/null 2>&1; then
        echo "SQL Server is not responding"
        return 1
    fi
    
    echo "SQL Server is healthy"
    return 0
}

case "$1" in
    start) start_container ;;
    stop) stop_container ;;
    status) status_container ;;
    health) check_health ;;
    *) echo "Usage: $0 {start|stop|status|health}" ;;
esac
