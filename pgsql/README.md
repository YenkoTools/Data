# PostgreSQL

PostgreSQL is an open-source relational database. This directory runs a single PostgreSQL 18 instance in a Docker container, managed by systemd, with persistent data and health checks.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Files](#files)
4. [Installation](#installation)
5. [Managing the Service](#managing-the-service)
6. [Management Script Commands](#management-script-commands)
7. [Connecting to PostgreSQL](#connecting-to-postgresql)
8. [Usage Examples](#usage-examples)
9. [Running Without systemd](#running-without-systemd)
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
| Container image | `postgres:18` (pinned; see [Upgrading to a new major version](#upgrading-to-a-new-major-version)) |
| Container name | `pgsql` |
| Service user | `pgsql` |
| systemd unit | `pgsql.service` |
| Network mode | `host` |
| Port | `5432` |
| Database / user / password | `default_database` / `admin` / `P@ssword92` |
| Data path | `/opt/pgsql/.local/share/pgsql-data` |
| Upstream | <https://www.postgresql.org> |

---

## Prerequisites

- Docker installed and running
- Root or sudo access
- Port 5432 free on the host
- Optional: the `psql` client on the host (`sudo apt install postgresql-client`)

---

## Files

| File | Purpose | Installed to |
|------|---------|--------------|
| `pgsql.sh` | Container management script (`start`, `stop`, `status`, `health`) | `/opt/pgsql/pgsql.sh` |
| `pgsql.service` | systemd unit file | `/etc/systemd/system/pgsql.service` |
| `install.sh` | One-time installation script (requires root) | Not installed |
| `compose.yml` | Docker Compose alternative to the systemd service | Not installed |
| `docker-compose.yml` | Annotated Compose tutorial. Not used by the service, and it uses a different password | Not installed |
| `README.md` | This document | Not installed |

---

## Installation

1. Optional: change `POSTGRES_USER`, `POSTGRES_PASSWORD`, or `POSTGRES_DB` in `pgsql.sh`. PostgreSQL applies these only when it creates the data directory on first start.

2. Run the install script from this directory:

   ```bash
   cd /path/to/Data/pgsql
   sudo ./install.sh
   ```

3. Start the service for the first time:

   ```bash
   sudo systemctl start pgsql.service
   ```

4. Confirm it is healthy:

   ```bash
   sudo -u pgsql /opt/pgsql/pgsql.sh health
   ```

**What `install.sh` does:**

1. Creates the `pgsql` system user with home directory `/opt/pgsql`
2. Adds `pgsql` to the `docker` group
3. Enables user lingering (`loginctl enable-linger pgsql`)
4. Copies `pgsql.sh` to `/opt/pgsql/` and makes it executable
5. Copies `pgsql.service` to `/etc/systemd/system/`
6. Reloads systemd and enables the service to start on boot

---

## Managing the Service

```bash
# Start
sudo systemctl start pgsql.service

# Stop
sudo systemctl stop pgsql.service

# Check status
sudo systemctl status pgsql.service

# Enable auto-start on boot (done by install.sh)
sudo systemctl enable pgsql.service

# Disable auto-start
sudo systemctl disable pgsql.service

# View logs
sudo journalctl -xeu pgsql.service

# Follow logs in real time
sudo journalctl -fu pgsql.service
```

---

## Management Script Commands

Run the management script directly as the service user:

```bash
sudo -u pgsql /opt/pgsql/pgsql.sh <command>
```

| Command | Action |
|---------|--------|
| `start` | Removes any existing `pgsql` container and starts a new one |
| `stop` | Stops and removes the container |
| `status` | Shows the container's state (`docker ps -a`) |
| `health` | Confirms the container is running and `pg_isready` reports it is accepting connections |

---

## Connecting to PostgreSQL

| Field | Value |
|-------|-------|
| Host | `localhost` |
| Port | `5432` |
| Database | `default_database` |
| Username | `admin` |
| Password | `P@ssword92` |

**Connection strings:**

```text
# URI (the @ in the password is URL-encoded as %40)
postgresql://admin:P%40ssword92@localhost:5432/default_database

# libpq key/value
host=localhost port=5432 dbname=default_database user=admin password=P@ssword92

# .NET (Npgsql)
Host=localhost;Port=5432;Database=default_database;Username=admin;Password=P@ssword92
```

**From the host** (prompts for the password):

```bash
psql -h localhost -p 5432 -U admin -d default_database
```

**From inside the container** (no password needed):

```bash
docker exec -it pgsql psql -U admin -d default_database
```

---

## Usage Examples

### SQL

```sql
-- Create a database and connect to it
CREATE DATABASE myapp;
\c myapp

-- Create a table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert, query, update, delete
INSERT INTO users (name, email) VALUES
    ('Alice Johnson', 'alice@example.com'),
    ('Bob Smith', 'bob@example.com');
SELECT * FROM users;
UPDATE users SET name = 'Alice J. Johnson' WHERE id = 1;
DELETE FROM users WHERE id = 2;
```

---

## Running Without systemd

`compose.yml` runs the same image and credentials with Docker Compose. It publishes port 5432 and stores data in `./db-data` next to the file.

```bash
cd /path/to/Data/pgsql

# Start
docker compose up -d

# Stop and remove the container (data in ./db-data is kept)
docker compose down
```

Don't run Compose and the systemd service at the same time: both use the container name `pgsql` and port 5432.

---

## Data Persistence and Backups

Data is stored on the host at `/opt/pgsql/.local/share/pgsql-data`, mounted into the container at `/var/lib/postgresql`. PostgreSQL 18 keeps its cluster in a version-named subdirectory, so the files are in `pgsql-data/18/docker`. Data survives container restarts and re-creation.

**Back up one database (service running):**

```bash
docker exec pgsql pg_dump -U admin -d default_database > default_database-$(date +%F).sql
```

**Back up every database and role:**

```bash
docker exec pgsql pg_dumpall -U admin > pgsql-all-$(date +%F).sql
```

**Restore:**

```bash
docker exec -i pgsql psql -U admin -d default_database < default_database-YYYY-MM-DD.sql
```

---

## Health Checks

```bash
# Check service status
sudo systemctl status pgsql.service

# Run the built-in health check
sudo -u pgsql /opt/pgsql/pgsql.sh health

# Check the container's own health status
docker inspect --format '{{.State.Health.Status}}' pgsql

# Check that PostgreSQL accepts connections
docker exec pgsql pg_isready -U admin

# View container logs
docker logs pgsql
```

Expected:

- The built-in check prints `PostgreSQL is healthy and accepting connections on port 5432`.
- `docker inspect` prints `healthy`.
- `pg_isready` prints `/var/run/postgresql:5432 - accepting connections`.

---

## Troubleshooting

### Container exits: "there appears to be PostgreSQL data in /var/lib/postgresql/data"

**Cause:** The PostgreSQL 18 image refuses to start when something is mounted at `/var/lib/postgresql/data`, the location older versions used. This happens with an older copy of `pgsql.sh` installed, or a data directory created by PostgreSQL 17 or earlier.

**Fix:** Reinstall the current `pgsql.sh`, which mounts at `/var/lib/postgresql`. If the data directory holds an older cluster, follow [Upgrading to a new major version](#upgrading-to-a-new-major-version).

```bash
sudo ./install.sh
sudo systemctl restart pgsql.service
```

### Upgrading to a new major version

**Cause:** PostgreSQL major versions cannot read each other's data directories, so the image is pinned.

**Fix:** Dump, switch versions, then restore into a fresh data directory:

```bash
docker exec pgsql pg_dumpall -U admin > pgsql-all.sql
sudo systemctl stop pgsql.service
sudo mv /opt/pgsql/.local/share/pgsql-data /opt/pgsql/.local/share/pgsql-data.old
# edit IMAGE in pgsql.sh, then:
sudo ./install.sh
sudo systemctl start pgsql.service
docker exec -i pgsql psql -U admin -d default_database < pgsql-all.sql
```

### Password authentication failed

**Cause:** The credentials in `pgsql.sh` were changed after the data directory was created. PostgreSQL keeps the originals.

**Fix:** Use the original password, or change it in the database:

```bash
docker exec -it pgsql psql -U admin -d default_database -c "ALTER USER admin PASSWORD 'new_password';"
```

### Service fails to start: port 5432 already in use

**Cause:** Another PostgreSQL, such as a host install or the Compose setup, is listening on 5432. Gitea's database does not publish a port, so it never conflicts.

**Fix:**

```bash
sudo ss -ltnp | grep ':5432\b'
docker ps --filter publish=5432
```

### `permission denied` when the script calls Docker

**Cause:** The `pgsql` user is not in the `docker` group.

**Fix:**

```bash
groups pgsql                     # should list docker
sudo usermod -aG docker pgsql
sudo systemctl restart pgsql.service
```

---

## Security Notes

- This setup is for **local development only**.
- The default password `P@ssword92` is hardcoded in `pgsql.sh` and `compose.yml`. Change it before first start on any shared machine.
- With host networking, PostgreSQL listens on the host's interfaces. Block port 5432 at the firewall if the machine is on a shared network.

---

## Uninstall

There is no `uninstall.sh` for PostgreSQL. Remove it manually:

```bash
sudo systemctl disable --now pgsql.service
sudo rm /etc/systemd/system/pgsql.service
sudo systemctl daemon-reload
docker rm -f pgsql
sudo loginctl disable-linger pgsql
sudo userdel -r pgsql   # also deletes /opt/pgsql and all databases
```

---

## Additional Resources

- [PostgreSQL documentation](https://www.postgresql.org/docs/)
- [postgres image on Docker Hub](https://hub.docker.com/_/postgres)
- [PostgreSQL 18 image data directory change](https://github.com/docker-library/postgres/pull/1259)
