# Data Tools

A collection of management scripts and utilities for running development infrastructure services in Docker containers on Linux systems.

## Project Structure

### aspire-dashboard/
Management scripts to run the .NET Aspire Dashboard as a systemd service. Provides a web-based UI for viewing real-time logs, traces, and metrics from distributed applications via OpenTelemetry.

- Systemd service integration with auto-start on boot
- OTLP gRPC and HTTP endpoints for receiving telemetry (ports 18889, 18890)
- Dashboard UI on port 18888
- Installation and management scripts

See [aspire-dashboard/README.md](aspire-dashboard/README.md) for detailed setup and usage instructions.

### azurite/
Management scripts to run the Azure Storage Emulator (Azurite) as a systemd service. Provides local Azure Blob, Queue, and Table storage for development and testing.

- Systemd service integration with auto-start on boot
- Health check monitoring for storage endpoints
- Persistent data storage
- Installation and management scripts

See [azurite/README.md](azurite/README.md) for detailed setup and usage instructions.

### docker/
Runbook on how to install Docker CLI in WSL (Windows Subsystem for Linux).

- Step-by-step installation guide
- WSL2 configuration
- Docker Desktop integration

See [docker/WSL2-Docker-Setup-Guide.md](docker/WSL2-Docker-Setup-Guide.md) for installation instructions.

### dockhand/
Management scripts to run the Dockhand modern Docker management UI as a systemd service.

- Systemd service integration with auto-start on boot
- Real-time container management and Compose stack orchestration
- Multi-environment Docker host support
- Web UI on port 3000

See [dockhand/README.md](dockhand/README.md) for detailed setup and usage instructions.

Resource: https://dockhand.pro

### gitea/
Management scripts to run Gitea, a lightweight self-hosted Git service, as a systemd service.

- Systemd service integration with auto-start on boot
- Web UI on port 3001 (port 3000 is used by Dockhand)
- Git over SSH on port 2222
- Dedicated PostgreSQL database container (`gitea-db`) on a private Docker network
- Gitea Actions runner container (`gitea-runner`) that registers itself automatically
- Persistent data storage and health check monitoring

See [gitea/README.md](gitea/README.md) for detailed setup and usage instructions.

Resource: https://about.gitea.com

### json-server/
RESTful service for testing and prototyping. Provides a full fake REST API with zero coding.

- Systemd service configurations for multiple instances (ports 3010, 3011, 3012)
- Sample database (db.json)
- Quick setup for API testing and frontend development

See [json-server/README.md](json-server/README.md) for configuration details.

Resource: https://github.com/typicode/json-server

### pgsql/
Management scripts to run PostgreSQL as a systemd-managed Docker container.

- Systemd service integration with auto-start on boot
- Single instance configuration on port 5432
- Persistent data storage
- Health check monitoring
- Installation and management scripts
- Docker Compose alternative for non-systemd setups

See [pgsql/README.md](pgsql/README.md) for setup instructions.

Resource: https://hub.docker.com/_/postgres/

### seq/
Management scripts to run the Datalust SEQ logging server for centralized structured log collection and analysis.

- Systemd service integration
- Docker Compose configuration
- Management scripts for container lifecycle

See [seq/readme.md](seq/readme.md) for deployment details.

Resource: https://datalust.co/

### sqlserver/
Management scripts to run Microsoft SQL Server as a systemd service.

- Systemd service integration with auto-start on boot
- SQL Server 2022 container image
- Automated installation script
- Database initialization scripts (ACME DB)
- Health check monitoring

See [sqlserver/README.md](sqlserver/README.md) for installation and usage.

Resource: https://learn.microsoft.com/en-us/sql/linux/quickstart-install-connect-docker

### valkey/
Management scripts to run the Open Source Redis cache (Valkey).

- Systemd service integration
- High-performance in-memory data store
- Redis-compatible API

---

## Common Features

All systemd-managed services in this project share:
- Dedicated system users for security isolation
- Docker container deployment
- Automatic startup on boot
- Persistent data storage
- Health check capabilities
- Consistent management commands (start/stop/status/health)

## Prerequisites

- Linux system with systemd
- Docker and Docker CLI installed
- Root/sudo access for service installation
