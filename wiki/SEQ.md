# Seq

Seq is a structured log server from Datalust. It ingests logs and events from applications and gives you a web UI to search, filter, and analyze them.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Files](#files)
4. [Installation](#installation)
5. [Managing the Service](#managing-the-service)
6. [Management Script Commands](#management-script-commands)
7. [Connecting to Seq](#connecting-to-seq)
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
| Container image | `docker.io/datalust/seq:latest` |
| Container name | `seq` |
| Service user | `seq` |
| systemd unit | `seq.service` |
| Network mode | `seq-network` bridge, with ports published to the host |
| Web UI and API | `http://localhost:8081` (container port 80) |
| Ingestion endpoint | `http://localhost:5341` |
| Admin login | `admin` / `P@ssword92` (set on first run) |
| Data path | `/opt/seq/.local/share/seq-data` |
| Upstream | <https://datalust.co/seq> |

---

## Prerequisites

- Docker installed and running
- Root or sudo access
- Ports 5341 and 8081 free on the host

---

## Files

| File | Purpose | Installed to |
|------|---------|--------------|
| `seq.sh` | Container management script (`start`, `stop`, `status`, `health`) | `/opt/seq/seq.sh` |
| `seq.service` | systemd unit file | `/etc/systemd/system/seq.service` |
| `install.sh` | One-time installation script (requires root) | Not installed |
| `compose.yml` | Docker Compose alternative to the systemd service | Not installed |
| `README.md` | This document | Not installed |

---

## Installation

1. Optional: change the admin password in `seq.sh` (the `echo 'P@ssword92'` line) before the first start. Seq applies it only when it creates its data directory.

2. Run the install script from this directory:

   ```bash
   cd /path/to/Data/seq
   sudo ./install.sh
   ```

3. Start the service for the first time:

   ```bash
   sudo systemctl start seq.service
   ```

4. Confirm it is healthy:

   ```bash
   sudo -u seq /opt/seq/seq.sh health
   ```

**What `install.sh` does:**

1. Creates the `seq` system user with home directory `/opt/seq`
2. Adds `seq` to the `docker` group
3. Enables user lingering (`loginctl enable-linger seq`)
4. Copies `seq.sh` to `/opt/seq/` and makes it executable
5. Copies `seq.service` to `/etc/systemd/system/`
6. Reloads systemd and enables the service to start on boot

---

## Managing the Service

```bash
# Start
sudo systemctl start seq.service

# Stop
sudo systemctl stop seq.service

# Check status
sudo systemctl status seq.service

# Enable auto-start on boot (done by install.sh)
sudo systemctl enable seq.service

# Disable auto-start
sudo systemctl disable seq.service

# View logs
sudo journalctl -xeu seq.service

# Follow logs in real time
sudo journalctl -fu seq.service
```

---

## Management Script Commands

Run the management script directly as the service user:

```bash
sudo -u seq /opt/seq/seq.sh <command>
```

| Command | Action |
|---------|--------|
| `start` | Creates `seq-network` if needed, hashes the admin password, removes any existing `seq` container, and starts a new one |
| `stop` | Stops and removes the container |
| `status` | Shows the container's state (`docker ps -a`) |
| `health` | Confirms the container is running and the web UI on port 8081 responds |

---

## Connecting to Seq

| Field | Value |
|-------|-------|
| Web UI | `http://localhost:8081` |
| Username | `admin` |
| Password | `P@ssword92` |
| Ingestion URL (for log sinks) | `http://localhost:5341` |
| CLEF ingestion endpoint | `http://localhost:5341/ingest/clef` |

Port 5341 accepts ingestion only. The UI and the full HTTP API are on 8081.

No API key is needed to send events. To require one, create an API key in **Settings → API Keys** and pass it in the `X-Seq-ApiKey` header (most sinks have an `apiKey` option).

---

## Usage Examples

### .NET with Serilog

Requires `dotnet add package Serilog.Sinks.Seq`.

```csharp
using Serilog;

Log.Logger = new LoggerConfiguration()
    .WriteTo.Seq("http://localhost:5341")
    .CreateLogger();

Log.Information("Hello from {App}", "MyApp");
Log.CloseAndFlush();
```

### curl (raw CLEF)

```bash
curl -X POST http://localhost:5341/ingest/clef \
  -H "Content-Type: application/vnd.serilog.clef" \
  -d '{"@t":"2026-01-01T00:00:00Z","@mt":"Hello from {Source}","@l":"Information","Source":"curl"}'
```

Expected: HTTP `201` and the body `{"MinimumLevelAccepted":null}`.

---

## Running Without systemd

`compose.yml` runs Seq with the same ports and stores data in `./data` next to the file. Compose cannot compute the password hash, so set it in the environment first:

```bash
cd /path/to/Data/seq
export SEQ_FIRSTRUN_ADMINPASSWORDHASH=$(echo 'P@ssword92' | docker run --rm -i datalust/seq config hash)
docker compose up -d
```

Stop it with `docker compose down`. Don't run Compose and the systemd service at the same time: both use the container name `seq` and the same ports.

---

## Data Persistence and Backups

Data (events, settings, users, API keys) is stored on the host at `/opt/seq/.local/share/seq-data` and mounted into the container at `/data`. It survives container restarts and re-creation.

**Back up:**

```bash
sudo systemctl stop seq.service
sudo tar -czf seq-backup-$(date +%F).tar.gz -C /opt/seq/.local/share seq-data
sudo systemctl start seq.service
```

**Restore:**

```bash
sudo systemctl stop seq.service
sudo rm -rf /opt/seq/.local/share/seq-data
sudo tar -xzf seq-backup-YYYY-MM-DD.tar.gz -C /opt/seq/.local/share
sudo systemctl start seq.service
```

To limit disk use, set retention policies in **Settings → Data → Retention**.

---

## Health Checks

```bash
# Check service status
sudo systemctl status seq.service

# Run the built-in health check
sudo -u seq /opt/seq/seq.sh health

# Check the container's own health status
docker inspect --format '{{.State.Health.Status}}' seq

# Query Seq's health endpoint
curl -s http://localhost:8081/health

# View container logs
docker logs seq
```

Expected:

- The built-in check prints `Seq is healthy and accessible at http://localhost:8081`.
- `docker inspect` prints `healthy`.
- `/health` returns `{"status":"healthy","description":"The Seq node is in service."}`.

---

## Troubleshooting

### Container fails to start

**Cause:** Docker is down, a port is taken, or the password hash step failed.

**Fix:**

```bash
sudo systemctl status docker
sudo journalctl -xeu seq.service
docker logs seq
sudo ss -ltnp | grep -E ':5341\b|:8081\b'
```

### Admin password does not work

**Cause:** The password in `seq.sh` was changed after the first run. `SEQ_FIRSTRUN_ADMINPASSWORDHASH` is applied only when the data directory is empty.

**Fix:** Log in with the original password and change it under your user profile. To start over instead, delete the data directory (this deletes all events):

```bash
sudo systemctl stop seq.service
sudo rm -rf /opt/seq/.local/share/seq-data
sudo systemctl start seq.service
```

### Events do not appear

**Cause:** The app sends to the wrong port, or the events are filtered out by the app's minimum level.

**Fix:** Send to `http://localhost:5341`, not 8081, and test with the [curl example](#curl-raw-clef). A `201` response means Seq accepted the event.

---

## Security Notes

- This setup is for **local development only**.
- The admin password `P@ssword92` is hardcoded in `seq.sh` and shown in this document.
- Ingestion needs no API key, so anything that can reach port 5341 can write events.
- Published ports bind to all host interfaces. Block 5341 and 8081 at the firewall if the machine is on a shared network.
- Logs often contain sensitive data. Don't send production logs to this instance.

---

## Uninstall

There is no `uninstall.sh` for Seq. Remove it manually:

```bash
sudo systemctl disable --now seq.service
sudo rm /etc/systemd/system/seq.service
sudo systemctl daemon-reload
docker rm -f seq
docker network rm seq-network
sudo loginctl disable-linger seq
sudo userdel -r seq   # also deletes /opt/seq and all stored events
```

---

## Additional Resources

- [Seq documentation](https://docs.datalust.co/docs)
- [Getting started with Docker](https://docs.datalust.co/docs/getting-started-with-docker)
- [datalust/seq on Docker Hub](https://hub.docker.com/r/datalust/seq)
- [Serilog.Sinks.Seq](https://github.com/datalust/serilog-sinks-seq)
