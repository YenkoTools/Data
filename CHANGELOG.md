# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Qdrant `uninstall.sh` script to stop/disable the service, remove the container and systemd unit, and clean up the install directory, with an interactive prompt (and `--purge-data` flag) before deleting the data directory, and an optional `--remove-user` flag to remove the service user
- SQL Server systemd-managed configuration with `mssql-systemd.sh` script for better security
- SQL Server standalone configuration with `mssql.sh` script for non-systemd usage
- Comprehensive SQL Server installation script with root/sudo verification
- Sample database setup scripts (`setup-acmedb.sh` and `setup-acmedb.sql`) with Star Wars themed test data
- Detailed SQL Server README with installation, usage, and troubleshooting documentation
- Seq dashboard port mapping fix (now accessible on port 8081)
- Data persistence documentation for SQL Server and Seq services

### Changed
- SQL Server container configuration to run as non-root user (removed `--user root` flag) for improved security
- SQL Server installation scripts to check for existing `mssql` user and continue gracefully
- Seq service configuration to properly expose web dashboard on host port 8081 (mapping to container port 80)
- systemd service files to include executable permissions during installation

### Fixed
- Seq dashboard not displaying due to incorrect port mapping (was only mapping port 5341 for ingestion API)
- SQL Server `mssql.sh` script removing problematic `chown` with undefined `HOST_UID` and `HOST_GID` variables
- SQL Server systemd service improved error handling in stop operations

### Security
- SQL Server container now runs as default non-root user (mssql UID 10001) instead of root
- Rootless Podman configuration properly documented for both SQL Server and Seq services

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

[Unreleased]: https://github.com/jkulba/Data/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/jkulba/Data/releases/tag/v1.0.0
