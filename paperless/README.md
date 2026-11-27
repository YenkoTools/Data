# Paperless-ngx

Paperless-ngx is a self-hosted document management system. It scans, OCRs, indexes, and archives your documents and makes them searchable from a web UI and REST API.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Files](#files)
4. [Installation](#installation)
5. [Managing the Service](#managing-the-service)
6. [Management Script Commands](#management-script-commands)
7. [Connecting to Paperless-ngx](#connecting-to-paperless-ngx)
8. [Usage Examples](#usage-examples)
9. [Configuration](#configuration)
10. [Running Without systemd](#running-without-systemd)
11. [Data Persistence and Backups](#data-persistence-and-backups)
12. [Health Checks](#health-checks)
13. [Troubleshooting](#troubleshooting)
14. [Security Notes](#security-notes)
15. [Uninstall](#uninstall)
16. [Additional Resources](#additional-resources)

---

## Overview

| Property | Value |
|----------|-------|
| Container image | `ghcr.io/paperless-ngx/paperless-ngx:latest` |
| Container name | `paperless` |
| Database container | `paperless-db` (`postgres:18`, pinned) |
| Broker container | `paperless-broker` (`docker.io/valkey/valkey:9-alpine`) |
| Service user | `paperless` |
| systemd unit | `paperless.service` |
| Network mode | bridge (`paperless-network`) |
| Web UI and API | `http://localhost:8000` (this machine only) |
| Data path | `/opt/paperless/.local/share/paperless-data` |
| Database path | `/opt/paperless/.local/share/paperless-db-data` |
| Broker path | `/opt/paperless/.local/share/paperless-broker-data` |
| Secret key | `/opt/paperless/.config/paperless/secret_key` |
| Upstream | <https://github.com/paperless-ngx/paperless-ngx> |

The database and broker are not published to the host. The broker is separate from the `valkey` service in this project, and neither depends on the other.

---

## Prerequisites

- Docker installed and running
- Root or sudo access
- Port 8000 free on the host

---

## Files

| File | Purpose | Installed to |
|------|---------|--------------|
| `paperless.sh` | Container management script (`start`, `stop`, `status`, `health`) | `/opt/paperless/paperless.sh` |
| `paperless.service` | systemd unit file | `/etc/systemd/system/paperless.service` |
| `install.sh` | One-time installation script (requires root) | Not installed |
| `README.md` | This document | Not installed |

---

## Installation

1. Run the install script from this directory:

   ```bash
   cd /path/to/Data/paperless
   sudo ./install.sh
   ```

2. Start the service for the first time. This pulls three images, so it can take several minutes:

   ```bash
   sudo systemctl start paperless.service
   ```

3. Wait for the database migrations to finish, then confirm it is healthy:

   ```bash
   sudo -u paperless /opt/paperless/paperless.sh health
   ```

4. Open <http://localhost:8000> and create the administrator account.

**What `install.sh` does:**

1. Creates the `paperless` system user with home directory `/opt/paperless`
2. Adds `paperless` to the `docker` group
3. Enables user lingering (`loginctl enable-linger paperless`)
4. Copies `paperless.sh` to `/opt/paperless/` and makes it executable
5. Copies `paperless.service` to `/etc/systemd/system/`
6. Reloads systemd and enables the service to start on boot

---

## Managing the Service

```bash
# Start
sudo systemctl start paperless.service

# Stop
sudo systemctl stop paperless.service

# Check status
sudo systemctl status paperless.service

# Enable auto-start on boot (done by install.sh)
sudo systemctl enable paperless.service

# Disable auto-start
sudo systemctl disable paperless.service

# View logs
sudo journalctl -xeu paperless.service

# Follow logs in real time
sudo journalctl -fu paperless.service
```

---

## Management Script Commands

Run the management script directly as the service user:

```bash
sudo -u paperless /opt/paperless/paperless.sh <command>
```

| Command | Action |
|---------|--------|
| `start` | Recreates the broker, database, and web containers, waiting for PostgreSQL before starting Paperless |
| `stop` | Stops and removes all three containers |
| `status` | Shows the containers' state (`docker ps -a`) |
| `health` | Confirms all three containers are running and that the broker, database, and web UI respond |

---

## Connecting to Paperless-ngx

| Field | Value |
|-------|-------|
| URL | `http://localhost:8000` |
| Username | Chosen on first visit |
| Password | Chosen on first visit |
| API base | `http://localhost:8000/api/` |

To create an administrator from the command line instead, or to add another one:

```bash
docker exec -it paperless createsuperuser
```

---

## Usage Examples

### Add a document through the consume folder

Paperless imports any file placed in the consume folder, then **deletes it from that folder**. Copy the file so that the `paperless` user owns it:

```bash
sudo install -o paperless -g paperless -m 644 invoice.pdf \
  /opt/paperless/.local/share/paperless-data/consume/
```

### curl

`curl` prompts for the password:

```bash
# Upload a document
curl -u <username> --form "document=@invoice.pdf" \
  http://localhost:8000/api/documents/post_document/

# List documents
curl -u <username> http://localhost:8000/api/documents/
```

---

## Configuration

Settings are variables at the top of `paperless.sh`. Edit the installed copy (or edit the repository copy and run `sudo ./install.sh` again), then restart the service.

| Variable | Default | Purpose |
|----------|---------|---------|
| `PORT_WEB` | `8000` | Host port for the web UI |
| `BIND_ADDRESS` | `127.0.0.1` | Set to `0.0.0.0` to allow access from other machines |
| `PAPERLESS_URL` | empty | The URL you browse to, without a trailing slash. Set it for access under any name other than `localhost` |
| `OCR_LANGUAGE` | `eng` | Tesseract language code for OCR. The image includes `eng`, `deu`, `fra`, `ita`, and `spa` |

The time zone is read from the host's `/etc/timezone` and falls back to UTC.

Office documents and email (`.docx`, `.xlsx`, `.eml`) need the Tika and Gotenberg containers, which this setup does not run. PDFs, images, and plain text work as is.

---

## Running Without systemd

For a quick test, run Paperless with its default SQLite database. Data lives in Docker volumes.

```bash
docker network create paperless-test
docker run -d --name paperless-test-broker --network paperless-test \
  docker.io/valkey/valkey:9-alpine
docker run -d --name paperless-test --network paperless-test \
  -p 127.0.0.1:8000:8000 \
  -e PAPERLESS_REDIS=redis://paperless-test-broker:6379 \
  -e PAPERLESS_SECRET_KEY="$(openssl rand -base64 48)" \
  -v paperless-test-data:/usr/src/paperless/data \
  -v paperless-test-media:/usr/src/paperless/media \
  ghcr.io/paperless-ngx/paperless-ngx:latest
```

---

## Data Persistence and Backups

All data is stored on the host under `/opt/paperless/.local/share` and survives container restarts and re-creation.

| Host directory | Container path | Contents |
|----------------|----------------|----------|
| `paperless-data/data` | `/usr/src/paperless/data` | Search index and application data |
| `paperless-data/media` | `/usr/src/paperless/media` | Original and archived documents |
| `paperless-data/consume` | `/usr/src/paperless/consume` | Incoming files |
| `paperless-data/export` | `/usr/src/paperless/export` | Exporter output |
| `paperless-db-data` | `/var/lib/postgresql` (in `paperless-db`) | PostgreSQL database |
| `paperless-broker-data` | `/data` (in `paperless-broker`) | Task queue |

**Back up** with the document exporter, which writes documents, thumbnails, and a `manifest.json` while the service is running:

```bash
docker exec paperless document_exporter ../export
sudo tar -czf paperless-backup-$(date +%F).tar.gz \
  -C /opt/paperless/.local/share/paperless-data export
```

**Restore** into an empty installation running the **same Paperless version** as the export. Do not create an account first:

```bash
sudo tar -xzf paperless-backup-YYYY-MM-DD.tar.gz \
  -C /opt/paperless/.local/share/paperless-data
docker exec paperless document_importer ../export
```

**Upgrading:** restarting the service reuses the local image. Back up first, then pull and restart. Database migrations run on start.

```bash
docker pull ghcr.io/paperless-ngx/paperless-ngx:latest
sudo systemctl restart paperless.service
```

Read the [release notes](https://github.com/paperless-ngx/paperless-ngx/releases) before a major version upgrade. Changing the PostgreSQL major version needs a data migration, which is why `paperless-db` is pinned.

---

## Health Checks

```bash
# Check service status
sudo systemctl status paperless.service

# Run the built-in health check
sudo -u paperless /opt/paperless/paperless.sh health

# Check the containers' own health status
docker ps --filter name=paperless --format '{{.Names}}: {{.Status}}'

# Test the web UI directly
curl -s -o /dev/null -w '%{http_code}\n' -L http://127.0.0.1:8000

# View container logs
docker logs paperless
```

Expected:

- The built-in check prints `Paperless is healthy and accessible at http://localhost:8000`.
- All three containers report `(healthy)`.
- `curl` prints `200`.

---

## Troubleshooting

### Health check fails right after the first start

**Cause:** Paperless is still running database migrations.

**Fix:** Wait a few minutes and watch the logs:

```bash
docker logs -f paperless
```

### Service fails to start: port already in use

**Cause:** Another process is listening on port 8000.

**Fix:** Stop it, or change `PORT_WEB` in `/opt/paperless/paperless.sh`:

```bash
sudo ss -ltnp | grep -E ':8000\b'
sudo systemctl restart paperless.service
```

### `Bad Request (400)` or a CSRF error from another machine

**Cause:** The address in the browser does not match what Paperless expects.

**Fix:** In `/opt/paperless/paperless.sh`, set `BIND_ADDRESS="0.0.0.0"` and set `PAPERLESS_URL` to the exact URL you browse to, then restart:

```bash
sudo systemctl restart paperless.service
```

### Files stay in the consume folder

**Cause:** The `paperless` user cannot read or delete the file, or the file type is not supported.

**Fix:**

```bash
sudo chown paperless:paperless /opt/paperless/.local/share/paperless-data/consume/*
docker logs paperless
sudo systemctl restart paperless.service
```

### `permission denied` when the script calls Docker

**Cause:** The `paperless` user is not in the `docker` group, or the group change has not taken effect.

**Fix:**

```bash
id paperless                       # should list docker
sudo usermod -aG docker paperless
sudo systemctl restart paperless.service
```

---

## Security Notes

- This setup is for **local development only**. Think carefully before storing real personal documents in it.
- The web UI listens on `127.0.0.1` only. The first visitor creates the administrator account, so create it before changing `BIND_ADDRESS`.
- Endpoints use plain HTTP with no TLS. Put a TLS reverse proxy in front before using it across a network.
- The database password is `paperless`, set in `paperless.sh`. The database is only reachable on `paperless-network`. Changing the password after the first start also requires changing it inside PostgreSQL.
- The secret key is generated on first start and readable only by the `paperless` user. It is not stored in this repository.
- Documents are stored unencrypted on disk.

---

## Uninstall

There is no `uninstall.sh` for Paperless-ngx. Export anything you want to keep, then remove it manually:

```bash
sudo systemctl disable --now paperless.service
sudo rm /etc/systemd/system/paperless.service
sudo systemctl daemon-reload
docker rm -f paperless paperless-db paperless-broker
docker network rm paperless-network
sudo loginctl disable-linger paperless
sudo rm -rf /opt/paperless   # deletes all documents and the database
sudo userdel paperless
```

---

## Additional Resources

- [Paperless-ngx on GitHub](https://github.com/paperless-ngx/paperless-ngx)
- [Paperless-ngx documentation](https://docs.paperless-ngx.com/)
- [Configuration reference](https://docs.paperless-ngx.com/configuration/)
- [REST API](https://docs.paperless-ngx.com/api/)
