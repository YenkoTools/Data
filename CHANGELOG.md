# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-10-31

### Added
- Aspire Dashboard service (`aspire-dashboard/`): .NET Aspire dashboard for OpenTelemetry data, with the UI on port 18888 and OTLP endpoints on 18889 (gRPC) and 18890 (HTTP)
- Dockhand service (`dockhand/`): Docker management web UI on port 3000
- Gitea service (`gitea/`): self-hosted Git on ports 3001 (web) and 2222 (SSH), with a dedicated PostgreSQL container (`gitea-db`, pinned to `postgres:17`) on a private `gitea-network` bridge network
- Gitea Actions runner (`gitea-runner`, `act_runner`) managed by `gitea.sh`. It registers itself with a token from `gitea actions generate-runner-token`, runs jobs in sibling containers through the host Docker socket, and ships a default `config.yaml` with `ubuntu-latest`, `ubuntu-24.04`, and `ubuntu-22.04` labels
- PostgreSQL service (`pgsql/`) on port 5432, with `install.sh`, `pgsql.sh`, `pgsql.service`, and a `compose.yml` alternative
- Qdrant service (`qdrant/`): vector database with REST on port 6333 and gRPC on 6334
- `uninstall.sh` for Gitea, Qdrant, and Valkey, with an interactive prompt (or `--purge-data`) before deleting data and an optional `--remove-user`
- PowerShell installer (`pwsh/install.sh`): PowerShell 7 from Microsoft's apt repository for Debian 13
- Terraform installer (`terraform/install.sh`): Terraform CLI from HashiCorp's apt repository, using the Debian codename so it works on LMDE
- Valkey `install.sh` and `uninstall.sh` following the standard service pattern
- README templates in `docs/`: `README-template-service.md` for container services and `README-template-tool.md` for tool installers
- READMEs for `valkey/`, `pwsh/`, `terraform/`, and `docker/`
- GitHub wiki pages for every service and tool in `wiki/`, published by a workflow on every push to `main`
- `.github/copilot-instructions.md` describing the repository's architecture and conventions

### Changed
- All component READMEs rewritten to the shared templates, adding Data Persistence and Backups, Security Notes, and Uninstall sections and symptom/cause/fix troubleshooting. Each `wiki/` page is an exact copy of its README
- Valkey moved from Podman as user `jim` (`valkey-ultra3.sh`) to Docker with a dedicated `valkey` user (`valkey.sh`, container `valkey`, data in `/opt/valkey/.local/share/valkey-data`). The password and AOF setting are passed as server arguments instead of a generated `valkey.conf`. The README includes migration steps
- Seq moved from a Podman pod to Docker: `seq.sh` runs the container on a `seq-network` bridge network, and the separate `seq-docker.sh` script was removed
- SQL Server image upgraded from `mssql/server:2022-latest` to `2025-latest`. SQL Server 2025 upgrades existing data files in place on first start
- PostgreSQL (`pgsql.sh`, `compose.yml`) pinned to `postgres:18`, with data mounted at `/var/lib/postgresql`
- Service scripts for Azurite, Seq, and SQL Server standardized, with Docker health check parameters
- `install.sh` scripts create the install directory if it does not exist
- Gitea's SSH port is set from `gitea.sh` instead of the installation wizard
- Gitea Actions runner uses the host network and registers at `http://localhost:3001` instead of `http://gitea:3000`, so job containers can clone repositories

### Fixed
- PostgreSQL failing to start on a fresh install: `postgres:latest` (now 18) refuses a mount at `/var/lib/postgresql/data`
- Qdrant container always reporting `unhealthy`: the image has no `curl`, so the health check now uses a bash TCP probe
- Qdrant `uninstall.sh` deleting the data directory even when asked to keep it (wrong `DATA_PATH` and unconditional `rm -rf /opt/qdrant`)
- SQL Server `setup-acmedb.sh` copying a non-existent `setup-acmedb-database.sql`; `mssql.sh health` and `setup-acmedb.sh` no longer require a TTY
- Data paths in READMEs (`/home/<service>/...` corrected to `/opt/<service>/...`), JSON Server's per-instance data files and write persistence, and the broken `seq/readme.md` link in the root README

## [1.0.1] - 2026-01-16

### Added
- Azurite service (`azurite/`): `install.sh`, `azurite.sh` management script (`start`, `stop`, `status`, `health`), and `azurite.service` systemd unit, with persistent data and auto-start on boot
- Azurite README covering systemd setup, manual Docker usage on Windows 11, Python and .NET examples, and troubleshooting
- WSL2 and Docker setup guide for Windows 11 (`docker/WSL2-Docker-Setup-Guide.md`)
- `seq-docker.sh`, a Docker CLI variant of the Seq script
- Sample SQL Server database scripts (`setup-acmedb.sh` and `setup-acmedb.sql`) with Star Wars–themed test data
- SQL Server README with installation, usage, and troubleshooting
- Data persistence documentation for SQL Server and Seq

### Changed
- Root README restructured into a section per folder, with links to each README, external resources, and shared Common Features and Prerequisites sections
- SQL Server `install.sh` checks for root and continues if the `mssql` user already exists
- SQL Server data moved to a directory in the service user's home
- Seq exposes its web UI on host port 8081, mapped to container port 80
- Installation scripts set executable permissions on the files they copy

### Fixed
- Seq web UI not reachable, because only the ingestion port 5341 was published
- SQL Server `mssql.sh` running a `chown` with undefined `HOST_UID` and `HOST_GID` variables
- SQL Server stop handling in the systemd service

## [1.0.0] - 2025-12-02

### Added
- Git tagging script for version management
- PostgreSQL container setup with docker-compose
- Seq logging service with systemd integration
- Valkey (Redis) container setup scripts
- JSON server mock API setup with multiple service files
- Comprehensive README documentation for each service

### Changed
- Updated SQL Server setup documentation
- Improved installation script output formatting
- Refactored service configurations for consistency

### Removed
- Obsolete SQL Server scripts and configurations
- FakeClient project files (C# test client)
- Outdated folder structure

[Unreleased]: https://github.com/YenkoTools/Data/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/YenkoTools/Data/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/YenkoTools/Data/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/YenkoTools/Data/releases/tag/v1.0.0
