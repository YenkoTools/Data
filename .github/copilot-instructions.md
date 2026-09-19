# Copilot Instructions for Data Tools

This repository contains management scripts and utilities for running development infrastructure services in Docker containers on Linux systems using systemd.

## Project Architecture

### Service Structure Pattern

Each service directory follows a consistent pattern:

```
service-name/
├── README.md              # Service-specific documentation
├── install.sh             # Installation script (requires root/sudo)
├── service-name.sh        # Container management script
└── service-name.service   # systemd service file
```

**Key architectural principles:**
- **Dedicated system users**: Each service runs as its own Linux user (e.g., `azurite`, `mssql`, `seq`) created at `/opt/service-name/`
- **User lingering**: All services use `loginctl enable-linger` to allow the service to run when the user is not logged in
- **Docker group membership**: Service users are added to the `docker` group for container access
- **Persistent data**: Services store data in `$HOME/.local/share/service-name-data` directories
- **Network mode**: Services typically use `--network host` for simplified networking (exception: `seq` uses a custom bridge network with explicit port mapping)
- **Container lifecycle**: Containers use `--restart=unless-stopped` policy
- **Security**: Services run as non-root users where possible (e.g., SQL Server runs as UID 10001)

### Management Script Pattern

All service management scripts (`*.sh`) follow this interface:

```bash
./service-name.sh {start|stop|status|health}
```

- `start`: Removes existing container (if present) and starts a new one
- `stop`: Stops and removes the container
- `status`: Shows container status via `docker ps -a`
- `health`: Performs service-specific health checks (e.g., HTTP endpoint tests)

### systemd Service Pattern

All `.service` files share common configuration:

- **Type**: `oneshot` with `RemainAfterExit=true`
- **Dependencies**: `After=network-online.target docker.service`, `Requires=docker.service`
- **ExecStart/Stop/Reload**: Calls the management script with appropriate command
- **Timeouts**: 60s start timeout, 30s stop timeout
- **Restart**: `Restart=on-failure`
- **User/Group**: Runs as dedicated service user

## Installation Workflow

All services follow this installation pattern:

1. Run `install.sh` with sudo/root
2. Script creates dedicated system user (if not exists)
3. Script adds user to docker group and enables lingering
4. Copies management script to `/opt/service-name/` with execute permissions
5. Copies systemd service file to `/etc/systemd/system/`
6. Runs `systemctl daemon-reload` and `systemctl enable`
7. User manually starts with `sudo systemctl start service-name.service`

**Important**: Installation scripts must be run as root/sudo and check for this at the start.

## New Service Template

When adding a new service to this repository, use the `azurite/` directory as the canonical template. It demonstrates the complete correct pattern for all four required files:

- **`install.sh`**: root check, dedicated user creation, docker group membership, linger enablement, file copy to `/opt/service-name/`, systemd enable
- **`service-name.sh`**: `CONTAINER_NAME`/`IMAGE`/port/`DATA_PATH` variables at the top, `start`/`stop`/`status`/`health` functions, embedded Docker `--health-cmd`
- **`service-name.service`**: `Type=oneshot`, `RemainAfterExit=true`, `After=network-online.target docker.service`, `Requires=docker.service`
- **`README.md`**: Overview table, Prerequisites, Files Overview, Installation, Managing the Service, Accessing the Service, Health Checks, Troubleshooting sections

## Services Overview

### azurite/
Azure Storage Emulator
- Image: `mcr.microsoft.com/azure-storage/azurite:latest`
- Port 10000 (Blob), 10001 (Queue), 10002 (Table)

### aspire-dashboard/
.NET Aspire dashboard for application monitoring
- Image: `mcr.microsoft.com/dotnet/aspire-dashboard:latest`
- Port 18888 (UI), 18889, 18890
- Runs with `DOTNET_DASHBOARD_UNSECURED_ALLOW_ANONYMOUS=true`

### dockhand/
Docker container management web UI
- Image: `fnsys/dockhand:latest`
- Port 3000 (Web UI)
- Mounts `/var/run/docker.sock` for Docker API access
- Data directory: `/opt/dockhand`

### gitea/
Self-hosted Git service with web UI, issue tracking, and pull requests
- Image: `docker.gitea.com/gitea:latest`
- Port 3001 (Web UI; port 3000 is occupied by Dockhand), port 2222 (SSH)
- Uses explicit port mapping (not `--network host`)
- Data path: `/home/gitea/.local/share/gitea-data`
- Git repositories stored at `/home/jim/Vault` (configurable via `GITEA__repository__ROOT`)

### json-server/
RESTful API mock server — multiple instances on ports 3010, 3011, 3012
- Uses `npx json-server` directly (not a container); no management shell script
- Separate systemd service files for each port (`json-server-3010.service`, etc.)
- Each service references a per-port db file at `/opt/json-server/db*.json`
- Runs as `jsonserver` user

### pgsql/
PostgreSQL database
- Image: `postgres:latest`
- Port 5432; default credentials: user `admin`, database `default_database`
- Uses standard systemd/install.sh pattern with `pgsql.sh`
- `compose.yml` also available as a Docker Compose alternative

### qdrant/
High-performance vector database and similarity search engine
- Image: `qdrant/qdrant:latest`
- REST API port 6333, gRPC port 6334
- Web UI at `http://127.0.0.1:6333/dashboard`

### seq/
Datalust SEQ structured logging server
- Image: `docker.io/datalust/seq:latest`
- Web dashboard port 8081 (maps to container port 80)
- Ingestion API port 5341
- Uses a custom Docker bridge network `seq-network` with explicit port mapping (not `--network host`)
- `compose.yml` also available as a Docker Compose alternative

### sqlserver/
SQL Server 2025 container
- Image: `mcr.microsoft.com/mssql/server:2025-latest`
- Port 1433
- Includes sample database setup scripts (`setup-acmedb.sh`, `setup-acmedb.sql`)

### valkey/
Valkey (Redis-compatible) in-memory data store
- Image: `docker.io/valkey/valkey:latest`
- Port 6379
- **Non-standard setup**: uses **podman** instead of Docker; runs as user `jim` (no dedicated service user or `install.sh`)
- Script: `valkey-ultra3.sh` (does not follow the standard `service-name.sh` naming convention)
- `valkey.service` runs directly as `User=jim` with `After=network.target` (no Docker dependency)
- Password-authenticated; config at `/home/jim/.valkey-ultra3/valkey.conf`, data at `/home/jim/.valkey-ultra3/valkey-data`

## Conventions

### File Naming
- Management scripts: `service-name.sh` (lowercase with hyphens)
- systemd files: `service-name.service` (must match for systemd)
- Installation scripts: Always named `install.sh`

### Script Requirements
- All scripts use `#!/bin/bash` or `#!/usr/bin/bash` shebang
- Installation scripts check for root with: `if [ "$EUID" -ne 0 ]`
- Management scripts define configuration variables at the top (CONTAINER_NAME, IMAGE, PORTS, DATA_PATH)
- All scripts provide helpful echo messages for user feedback

### Container Configuration
- Container names match the service name (e.g., `azurite`, `mssql-server`)
- Data persistence uses named volumes mapped to user's home directory
- Images pulled from official sources (MCR, Docker Hub)
- Containers removed before starting to ensure clean state (`docker rm -f`)

### Health Checks
- HTTP services use `curl` to test endpoints
- Health check functions return 0 for healthy, 1 for unhealthy
- Health checks verify both container running and endpoint responsiveness

## Version Management

- Uses PowerShell script `git-tag.ps1` for annotated Git tags
- Follows Semantic Versioning (MAJOR.MINOR.PATCH)
- CHANGELOG.md follows Keep a Changelog format

## Documentation Standards

Each service directory must have:
- README.md with Prerequisites, Files Overview, Installation, Usage, and Troubleshooting sections
- Clear distinction between installation (one-time) and usage (ongoing) commands
- Examples of systemd commands (start, stop, status, journalctl)
- Port numbers and access URLs prominently displayed
