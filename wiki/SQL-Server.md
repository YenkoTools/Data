# SQL Server

Microsoft SQL Server 2025 runs in a Docker container managed by systemd, with persistent data, health checks, and a script that creates a sample database.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Files](#files)
4. [Installation](#installation)
5. [Managing the Service](#managing-the-service)
6. [Management Script Commands](#management-script-commands)
7. [Connecting to SQL Server](#connecting-to-sql-server)
8. [Usage Examples](#usage-examples)
9. [Sample Database (AcmeDB)](#sample-database-acmedb)
10. [Data Persistence and Backups](#data-persistence-and-backups)
11. [Health Checks](#health-checks)
12. [Troubleshooting](#troubleshooting)
13. [Security Notes](#security-notes)
14. [Uninstall](#uninstall)
15. [Additional Resources](#additional-resources)

---

## Overview

| Property | Value |
|----------|-------|
| Container image | `mcr.microsoft.com/mssql/server:2025-latest` |
| Container name | `mssql-server` |
| Service user | `mssql` |
| systemd unit | `mssql.service` |
| Network mode | `host` |
| Port | `1433` |
| Login / password | `sa` / `P@ssword92` |
| Data path | `/opt/mssql/.local/share/mssql-data` |
| Upstream | <https://learn.microsoft.com/sql/linux/quickstart-install-connect-docker> |

---

## Prerequisites

- Docker installed and running
- Root or sudo access
- At least 2 GB of RAM available to the container
- Port 1433 free on the host
- Optional: `sqlcmd` on the host. The container includes it at `/opt/mssql-tools18/bin/sqlcmd`

---

## Files

| File | Purpose | Installed to |
|------|---------|--------------|
| `mssql.sh` | Container management script (`start`, `stop`, `status`, `health`) | `/opt/mssql/mssql.sh` |
| `mssql.service` | systemd unit file | `/etc/systemd/system/mssql.service` |
| `install.sh` | One-time installation script (requires root) | Not installed |
| `setup-acmedb.sh` | Creates the sample `AcmeDB` database in the running container | Not installed |
| `setup-acmedb.sql` | T-SQL run by `setup-acmedb.sh` | Not installed |
| `README.md` | This document | Not installed |

---

## Installation

> **Upgrading from SQL Server 2022:** on first start, SQL Server 2025 upgrades existing 2022 data files in place. The upgrade cannot be reversed. Back up the data directory first (see [Data Persistence and Backups](#data-persistence-and-backups)).

1. Optional: change `SA_PASSWORD` in `mssql.sh` before the first start. It must meet SQL Server's complexity rules: at least 8 characters with three of uppercase, lowercase, digits, and symbols.

2. Run the install script from this directory:

   ```bash
   cd /path/to/Data/sqlserver
   sudo ./install.sh
   ```

3. Start the service for the first time:

   ```bash
   sudo systemctl start mssql.service
   ```

4. Confirm it is healthy (first start can take up to a minute):

   ```bash
   sudo -u mssql /opt/mssql/mssql.sh health
   ```

**What `install.sh` does:**

1. Creates the `mssql` system user with home directory `/opt/mssql`
2. Adds `mssql` to the `docker` group
3. Enables user lingering (`loginctl enable-linger mssql`)
4. Copies `mssql.sh` to `/opt/mssql/` and makes it executable
5. Copies `mssql.service` to `/etc/systemd/system/`
6. Reloads systemd and enables the service to start on boot

---

## Managing the Service

```bash
# Start
sudo systemctl start mssql.service

# Stop
sudo systemctl stop mssql.service

# Check status
sudo systemctl status mssql.service

# Enable auto-start on boot (done by install.sh)
sudo systemctl enable mssql.service

# Disable auto-start
sudo systemctl disable mssql.service

# View logs
sudo journalctl -xeu mssql.service

# Follow logs in real time
sudo journalctl -fu mssql.service
```

---

## Management Script Commands

Run the management script directly as the service user:

```bash
sudo -u mssql /opt/mssql/mssql.sh <command>
```

| Command | Action |
|---------|--------|
| `start` | Removes any existing `mssql-server` container and starts a new one |
| `stop` | Stops and removes the container |
| `status` | Shows the container's state (`docker ps -a`) |
| `health` | Confirms the container is running and `sqlcmd` can run `SELECT @@version` |

---

## Connecting to SQL Server

| Field | Value |
|-------|-------|
| Server | `localhost,1433` |
| Login | `sa` |
| Password | `P@ssword92` |
| Encryption | Self-signed certificate; clients must trust it |

**.NET connection string:**

```text
Server=localhost,1433;Database=master;User Id=sa;Password=P@ssword92;TrustServerCertificate=True;
```

**From inside the container:**

```bash
docker exec -it mssql-server \
  /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'P@ssword92' -N -C
```

**From the host** (if `sqlcmd` is installed):

```bash
sqlcmd -S localhost -U sa -P 'P@ssword92' -N -C
```

`-N` turns on encryption and `-C` trusts the server's self-signed certificate.

---

## Usage Examples

### T-SQL

```sql
CREATE DATABASE MyApp;
GO
USE MyApp;
GO
CREATE TABLE dbo.Products (
    Id INT IDENTITY PRIMARY KEY,
    Name NVARCHAR(100) NOT NULL,
    Price DECIMAL(10, 2) NOT NULL
);
INSERT INTO dbo.Products (Name, Price) VALUES (N'Widget', 9.99), (N'Gadget', 19.99);
SELECT * FROM dbo.Products;
GO
```

### .NET

Requires the `Microsoft.Data.SqlClient` NuGet package.

```csharp
using Microsoft.Data.SqlClient;

var connectionString =
    "Server=localhost,1433;Database=master;User Id=sa;Password=P@ssword92;TrustServerCertificate=True;";

await using var connection = new SqlConnection(connectionString);
await connection.OpenAsync();

await using var command = new SqlCommand("SELECT @@VERSION", connection);
Console.WriteLine(await command.ExecuteScalarAsync());
```

---

## Sample Database (AcmeDB)

`setup-acmedb.sh` copies `setup-acmedb.sql` into the running container and runs it with `sqlcmd`. Run it from this directory while the service is running:

```bash
cd /path/to/Data/sqlserver
./setup-acmedb.sh
```

| Object | Details |
|--------|---------|
| Database | `AcmeDB` |
| Schema | `Recruits` |
| Table | `Recruits.Users` |
| Columns | `UserID` (`UNIQUEIDENTIFIER` primary key), `FirstName`, `LastName`, `Email` (unique), `RegistrationDate` |
| Sample data | 25 rows with Star Wars–inspired names |

Query it:

```sql
USE AcmeDB;
SELECT * FROM Recruits.Users;
```

The script is not idempotent: running it a second time fails because `AcmeDB` already exists. Drop the database first to recreate it:

```bash
docker exec mssql-server /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'P@ssword92' -N -C \
  -Q "DROP DATABASE AcmeDB"
```

---

## Data Persistence and Backups

Data is stored on the host at `/opt/mssql/.local/share/mssql-data` and mounted into the container at `/var/opt/mssql`. It survives container restarts and re-creation. The container runs as root, so the files are owned by root.

**Back up the data directory (service stopped):**

```bash
sudo systemctl stop mssql.service
sudo tar -czf mssql-backup-$(date +%F).tar.gz -C /opt/mssql/.local/share mssql-data
sudo systemctl start mssql.service
```

**Back up one database (service running):** the `.bak` file is written inside the data directory, at `/opt/mssql/.local/share/mssql-data/backup/` on the host.

```bash
docker exec mssql-server mkdir -p /var/opt/mssql/backup
docker exec mssql-server /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'P@ssword92' -N -C \
  -Q "BACKUP DATABASE AcmeDB TO DISK = '/var/opt/mssql/backup/AcmeDB.bak' WITH INIT"
```

**Restore one database:**

```bash
docker exec mssql-server /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'P@ssword92' -N -C \
  -Q "RESTORE DATABASE AcmeDB FROM DISK = '/var/opt/mssql/backup/AcmeDB.bak' WITH REPLACE"
```

---

## Health Checks

```bash
# Check service status
sudo systemctl status mssql.service

# Run the built-in health check
sudo -u mssql /opt/mssql/mssql.sh health

# Check the container's own health status
docker inspect --format '{{.State.Health.Status}}' mssql-server

# Query the server directly
docker exec mssql-server /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'P@ssword92' -N -C \
  -Q "SELECT @@VERSION"

# View container logs
docker logs mssql-server
```

Expected:

- The built-in check prints `SQL Server is healthy`.
- `docker inspect` prints `healthy`.
- The query prints a version string starting with `Microsoft SQL Server`.

---

## Troubleshooting

### Container exits shortly after start

**Cause:** Usually the SA password does not meet the complexity rules, or the host has less than 2 GB of free memory.

**Fix:** Check the container log for the reason:

```bash
docker logs mssql-server 2>&1 | tail -20
free -h
```

### Login failed for user `sa`

**Cause:** `SA_PASSWORD` in `mssql.sh` was changed after the data directory was created. SQL Server keeps the original password.

**Fix:** Log in with the original password and change it:

```sql
ALTER LOGIN sa WITH PASSWORD = 'NewStr0ng!Password';
```

Then put the new password in `mssql.sh` (the health check uses it) and reinstall with `sudo ./install.sh`.

### `setup-acmedb.sh` fails with "Database 'AcmeDB' already exists"

**Cause:** The sample database was already created.

**Fix:** Drop it and run the script again (see [Sample Database (AcmeDB)](#sample-database-acmedb)).

### Client fails with a certificate or SSL error

**Cause:** The server uses a self-signed certificate.

**Fix:** Add `TrustServerCertificate=True` to the connection string, or `-C` to `sqlcmd`.

### `permission denied` when the script calls Docker

**Cause:** The `mssql` user is not in the `docker` group.

**Fix:**

```bash
groups mssql                     # should list docker
sudo usermod -aG docker mssql
sudo systemctl restart mssql.service
```

---

## Security Notes

- This setup is for **local development only**.
- The SA password `P@ssword92` is hardcoded in `mssql.sh` and `setup-acmedb.sh`, and it is visible in the container's environment and health check command.
- Apps connect as `sa`, which has full control of the server. Create a separate login for apps if you need to test permissions.
- The container runs as root (`--user root`).
- With host networking, SQL Server listens on the host's interfaces. Block port 1433 at the firewall if the machine is on a shared network.

---

## Uninstall

There is no `uninstall.sh` for SQL Server. Remove it manually:

```bash
sudo systemctl disable --now mssql.service
sudo rm /etc/systemd/system/mssql.service
sudo systemctl daemon-reload
docker rm -f mssql-server
sudo loginctl disable-linger mssql
sudo userdel -r mssql   # also deletes /opt/mssql and all databases
```

---

## Additional Resources

- [Quickstart: SQL Server Linux containers with Docker](https://learn.microsoft.com/sql/linux/quickstart-install-connect-docker)
- [Configure SQL Server container images](https://learn.microsoft.com/sql/linux/sql-server-linux-docker-container-configure)
- [mssql/server on Docker Hub](https://hub.docker.com/r/microsoft/mssql-server)
- [sqlcmd utility](https://learn.microsoft.com/sql/tools/sqlcmd/sqlcmd-utility)
