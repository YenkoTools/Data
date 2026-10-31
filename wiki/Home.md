# Data Tools Wiki

Welcome to the **Data Tools** wiki. This project provides management scripts and utilities for running development infrastructure services in Docker containers on Linux systems.

## Table of Contents

| Section | Description | Ports |
|---------|-------------|-------|
| [Aspire Dashboard](Aspire-Dashboard) | .NET Aspire Dashboard for telemetry visualization | 18888, 18889, 18890 |
| [Azurite](Azurite) | Azure Storage Emulator (Blob, Queue, Table) | 10000, 10001, 10002 |
| [Docker / WSL2 Setup](Docker-WSL2-Setup) | Guide to installing Docker CLI in WSL2 on Windows 11 | — |
| [Dockhand](Dockhand) | Modern Docker management UI with container and stack orchestration | 3000 |
| [Gitea](Gitea) | Self-hosted Git service with web UI, issues, pull requests, and Actions (with dedicated PostgreSQL) | 3001, 2222 |
| [JSON Server](JSON-Server) | Fake REST API server for testing and prototyping | 3010, 3011, 3012 |
| [PostgreSQL](PostgreSQL) | PostgreSQL database as a systemd-managed Docker container | 5432 |
| [Qdrant](Qdrant) | High-performance vector database and similarity search engine | 6333, 6334 |
| [SEQ](SEQ) | Datalust SEQ structured log server | 5341, 8081 |
| [SQL Server](SQL-Server) | Microsoft SQL Server 2025 as a systemd service | 1433 |
| [Valkey](Valkey) | Valkey open-source Redis-compatible cache | 6379 |

---

## Common Patterns

All systemd-managed services in this project follow a consistent pattern:

- **Dedicated system user** – each service runs as its own user for security isolation.
- **Docker group membership** – the service user is added to the `docker` group.
- **User lingering** – `loginctl enable-linger` allows the service to run when the user is not logged in.
- **Persistent data** – data is stored under `$HOME/.local/share/<service>-data`.
- **Host networking** – containers use `--network host` for simplified local networking.
- **Restart policy** – containers use `--restart=unless-stopped`.

### Standard Management Commands

Every service management script supports the same commands:

```bash
./service-name.sh start    # Remove existing container and start a new one
./service-name.sh stop     # Stop and remove the container
./service-name.sh status   # Show container status (docker ps -a)
./service-name.sh health   # Run service-specific health checks
```

### Standard systemd Commands

```bash
sudo systemctl start   <service>.service   # Start the service
sudo systemctl stop    <service>.service   # Stop the service
sudo systemctl status  <service>.service   # Check service status
sudo systemctl enable  <service>.service   # Enable auto-start on boot
sudo systemctl disable <service>.service   # Disable auto-start on boot
sudo journalctl -xeu   <service>.service   # View service logs
sudo journalctl -fu    <service>.service   # Follow real-time logs
```

---

## Prerequisites

All services require:

- Linux system with **systemd**
- **Docker** and Docker CLI installed ([setup guide](Docker-WSL2-Setup))
- **Root / sudo** access for service installation
