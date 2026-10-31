# Gitea

Gitea is a lightweight, self-hosted Git service with a web UI, issue tracking, pull requests, and CI/CD through Gitea Actions, which uses GitHub Actions–compatible workflows.

The service runs three containers that `gitea.sh` starts and stops together: Gitea itself, a dedicated PostgreSQL database (`gitea-db`), and a Gitea Actions runner (`gitea-runner`).

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Files](#files)
4. [Installation](#installation)
5. [Managing the Service](#managing-the-service)
6. [Management Script Commands](#management-script-commands)
7. [Connecting to Gitea](#connecting-to-gitea)
8. [Configuring Repository Storage](#configuring-repository-storage)
9. [CI/CD with Gitea Actions](#cicd-with-gitea-actions)
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
| Container image | `docker.gitea.com/gitea:latest` |
| Container name | `gitea` |
| Service user | `gitea` |
| systemd unit | `gitea.service` |
| Network mode | `gitea-network` bridge, with ports published to the host |
| Web UI | `http://localhost:3001` |
| SSH clone port | `2222` |
| Data path | `/opt/gitea/.local/share/gitea-data` |
| Database image | `postgres:17` (pinned; see [Upgrading PostgreSQL](#upgrading-postgresql)) |
| Database container | `gitea-db`, on `gitea-network` only (not published to the host) |
| Database name / user | `gitea` / `gitea` |
| Database data path | `/opt/gitea/.local/share/gitea-db-data` |
| Runner image | `docker.gitea.com/act_runner:latest` |
| Runner container | `gitea-runner`, on the host network |
| Runner data path | `/opt/gitea/.local/share/gitea-runner-data` |
| Upstream | <https://about.gitea.com> |

The web UI uses host port 3001 because Dockhand uses 3000. The database is reachable only inside `gitea-network` at `gitea-db:5432`, so it does not conflict with the standalone PostgreSQL service on host port 5432.

---

## Prerequisites

- Docker installed and running
- Root or sudo access
- Ports 3001 and 2222 free on the host

---

## Files

| File | Purpose | Installed to |
|------|---------|--------------|
| `gitea.sh` | Management script for Gitea, its database, and the runner (`start`, `stop`, `status`, `health`) | `/opt/gitea/gitea.sh` |
| `gitea.service` | systemd unit file | `/etc/systemd/system/gitea.service` |
| `install.sh` | One-time installation script (requires root) | Not installed |
| `uninstall.sh` | Removes the service, and optionally its data and user (requires root) | Not installed |
| `README.md` | This document | Not installed |

---

## Installation

1. Optional: change `DB_PASSWORD` in `gitea.sh` before the first start. PostgreSQL stores the password when it creates the database and ignores later changes to the variable.

2. Run the install script from this directory:

   ```bash
   cd /path/to/Data/gitea
   sudo ./install.sh
   ```

3. Start the service for the first time:

   ```bash
   sudo systemctl start gitea.service
   ```

4. Open `http://localhost:3001` and complete the installation wizard (see below).

5. Restart the service so the Actions runner registers itself:

   ```bash
   sudo systemctl restart gitea.service
   ```

6. Confirm it is healthy:

   ```bash
   sudo -u gitea /opt/gitea/gitea.sh health
   ```

**What `install.sh` does:**

1. Creates the `gitea` system user with home directory `/opt/gitea`
2. Adds `gitea` to the `docker` group
3. Enables user lingering (`loginctl enable-linger gitea`)
4. Copies `gitea.sh` to `/opt/gitea/` and makes it executable
5. Copies `gitea.service` to `/etc/systemd/system/`
6. Reloads systemd and enables the service to start on boot

### First-run installation wizard

On the first visit, Gitea shows an installation wizard. Use these settings:

| Setting | Value |
|---------|-------|
| Database type | PostgreSQL (pre-filled: host `gitea-db:5432`, database and user `gitea`) |
| Site URL | `http://localhost:3001` |
| SSH server domain | `localhost` |
| SSH port | `2222` (pre-filled from `PORT_SSH`) |
| HTTP port | `3000` (the port inside the container, not the host port) |
| Log path | `/data/gitea/log` |

Don't change the pre-filled database fields; they come from `gitea.sh`. Create an administrator account on the same page, then click **Install Gitea**.

---

## Managing the Service

```bash
# Start
sudo systemctl start gitea.service

# Stop
sudo systemctl stop gitea.service

# Check status
sudo systemctl status gitea.service

# Enable auto-start on boot (done by install.sh)
sudo systemctl enable gitea.service

# Disable auto-start
sudo systemctl disable gitea.service

# View logs
sudo journalctl -xeu gitea.service

# Follow logs in real time
sudo journalctl -fu gitea.service
```

---

## Management Script Commands

Run the management script directly as the service user:

```bash
sudo -u gitea /opt/gitea/gitea.sh <command>
```

| Command | Action |
|---------|--------|
| `start` | Creates `gitea-network` if needed, then recreates and starts `gitea-db`, `gitea`, and `gitea-runner` in that order. Waits for PostgreSQL before starting Gitea |
| `stop` | Stops and removes `gitea-runner`, `gitea`, and `gitea-db` |
| `status` | Shows the state of all three containers (`docker ps -a`) |
| `health` | Checks the database responds, the web UI on port 3001 responds, and, if the runner is registered, that it is running |

---

## Connecting to Gitea

| Access | URL / Command |
|--------|---------------|
| Web UI | `http://localhost:3001` |
| HTTP clone | `git clone http://localhost:3001/<user>/<repo>.git` |
| SSH clone | `git clone ssh://git@localhost:2222/<user>/<repo>.git` |
| API docs | `http://localhost:3001/api/swagger` |

**Shorter SSH clone URLs:** add this to `~/.ssh/config`:

```text
Host localhost
    HostName localhost
    User git
    Port 2222
```

Then clone with:

```bash
git clone git@localhost:<user>/<repo>.git
```

---

## Configuring Repository Storage

By default, Gitea stores repositories inside its data directory at `/opt/gitea/.local/share/gitea-data/gitea/repositories/`.

To store them elsewhere, for example in `/home/jim/Vault`:

1. Add a volume and the repository root to the Gitea `docker run` command in `gitea.sh`:

   ```bash
   -v "/home/jim/Vault:/vault" \
   -e GITEA__repository__ROOT=/vault \
   ```

2. Give the `gitea` user read and write access to the directory. Choose one:

   ```bash
   # Option A: add gitea to the directory's group and grant group write
   sudo usermod -aG jim gitea
   chmod -R g+rwX /home/jim/Vault

   # Option B: make gitea the owner
   sudo chown -R gitea:gitea /home/jim/Vault
   ```

3. Reinstall the script and restart:

   ```bash
   sudo ./install.sh
   sudo systemctl restart gitea.service
   ```

If you change the root after the first setup, also update `ROOT` under `[repository]` in `/opt/gitea/.local/share/gitea-data/gitea/conf/app.ini`, move the existing repositories, and run **Site Administration → Maintenance → Resynchronize** for the repositories.

---

## CI/CD with Gitea Actions

Gitea Actions runs workflows from `.gitea/workflows/*.yml` using GitHub Actions syntax. `gitea.sh` enables it with `GITEA__actions__ENABLED=true` and runs jobs on the `gitea-runner` container ([act_runner](https://docs.gitea.com/usage/actions/act-runner)).

| Property | Value |
|----------|-------|
| Runner name | `<hostname>-runner` |
| Runner config | `/opt/gitea/.local/share/gitea-runner-data/config.yaml` |
| Registration file | `/opt/gitea/.local/share/gitea-runner-data/.runner` |
| Labels | `ubuntu-latest`, `ubuntu-24.04`, `ubuntu-22.04` |
| Capacity | 2 concurrent jobs |

### Registration

The runner registers itself; you don't need to copy a token. If no `.runner` file exists, `gitea.sh start` runs `gitea actions generate-runner-token` inside the Gitea container and passes the token to the runner. The registration is saved to `.runner` and reused on later starts.

Token generation fails until the installation wizard is finished, so on a new install the runner is skipped and the start log says `Runner not registered`. Restart the service after the wizard. The runner then appears under **Site Administration → Actions → Runners**.

### How jobs run

- The runner uses the host network and registers at `http://localhost:3001`. act_runner gives this address to jobs as the server URL.
- Jobs run in sibling containers that the runner starts through the host Docker socket.
- Job containers also use the host network (`container.network: host`), so `actions/checkout` reaches Gitea at the same `http://localhost:3001` address as the Site URL.
- The runner container runs as the `gitea` user with the Docker socket's group, so its files stay owned by `gitea`.

### Example workflow

Save as `.gitea/workflows/ci.yml` in a repository:

```yaml
name: CI
on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "Hello from Gitea Actions"
```

### Customizing the runner

`config.yaml` is written on the first start and never overwritten. To change capacity, labels, or job container settings, edit it and restart the service. To see every option:

```bash
docker run --rm docker.gitea.com/act_runner:latest generate-config
```

To re-register the runner, for example after deleting it in the web UI:

```bash
sudo rm /opt/gitea/.local/share/gitea-runner-data/.runner
sudo systemctl restart gitea.service
```

---

## Data Persistence and Backups

All state lives under `/opt/gitea/.local/share` and survives container restarts and re-creation:

| Directory | Contents |
|-----------|----------|
| `gitea-data` | Repositories, `app.ini`, attachments, avatars |
| `gitea-db-data` | PostgreSQL data |
| `gitea-runner-data` | Runner registration, config, cache, job work directories |

If repositories are stored outside the data directory (see [Configuring Repository Storage](#configuring-repository-storage)), back up that location too.

**Full backup (service stopped):**

```bash
sudo systemctl stop gitea.service
sudo tar -czf gitea-backup-$(date +%F).tar.gz -C /opt/gitea/.local/share gitea-data gitea-db-data
sudo systemctl start gitea.service
```

**Online backup with `gitea dump`** (repositories, configuration, and a SQL dump):

```bash
docker exec -u git -w /tmp gitea gitea dump -c /data/gitea/conf/app.ini -f /tmp/gitea-dump.zip
docker cp gitea:/tmp/gitea-dump.zip ./gitea-dump-$(date +%F).zip
docker exec gitea rm /tmp/gitea-dump.zip
```

**Database only:**

```bash
docker exec gitea-db pg_dump -U gitea -d gitea > gitea-db-$(date +%F).sql
```

**Restore a full backup:**

```bash
sudo systemctl stop gitea.service
sudo rm -rf /opt/gitea/.local/share/gitea-data /opt/gitea/.local/share/gitea-db-data
sudo tar -xzf gitea-backup-YYYY-MM-DD.tar.gz -C /opt/gitea/.local/share
sudo systemctl start gitea.service
```

---

## Health Checks

```bash
# Check service status
sudo systemctl status gitea.service

# Run the built-in health check
sudo -u gitea /opt/gitea/gitea.sh health

# Check each container's own health status
docker inspect --format '{{.Name}} {{.State.Health.Status}}' gitea gitea-db

# Test the web UI and the health API directly
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3001
curl -s http://127.0.0.1:3001/api/healthz

# Check the database
docker exec gitea-db pg_isready -U gitea -d gitea

# View container logs
docker logs gitea
docker logs gitea-db
docker logs gitea-runner
```

Expected:

- The built-in check prints `Gitea is healthy and accessible at http://localhost:3001 (database: gitea-db)`. Before the runner is registered it also prints `Note: Actions runner is not registered yet`.
- `docker inspect` prints `healthy` for both containers. The runner has no health check.
- `curl` prints `200`, and `/api/healthz` returns JSON with `"status": "pass"`.
- `pg_isready` prints `accepting connections`.

---

## Troubleshooting

### Web UI not loading right after start

**Cause:** Gitea takes 15–30 seconds to initialize, longer on first boot.

**Fix:** Wait until the container reports `healthy`:

```bash
docker inspect --format '{{.State.Health.Status}}' gitea
```

### Permission denied on the data directory

**Cause:** Gitea's internal user takes the `gitea` service user's UID at start. A directory created by another user is not writable.

**Fix:**

```bash
sudo chown -R gitea:gitea /opt/gitea/.local/share/gitea-data
sudo systemctl restart gitea.service
```

### Gitea cannot connect to the database

**Cause:** `gitea-db` is not running or not on `gitea-network`, or `DB_PASSWORD` was changed after the database was created.

**Fix:** Check the containers and network:

```bash
sudo -u gitea /opt/gitea/gitea.sh status
docker network inspect gitea-network --format '{{range .Containers}}{{.Name}} {{end}}'
docker logs gitea-db
```

If the password changed, either revert `DB_PASSWORD` or set the new one in the database:

```bash
docker exec -it gitea-db psql -U gitea -d gitea -c "ALTER USER gitea PASSWORD 'new_password';"
```

### Upgrading PostgreSQL

**Cause:** The database image is pinned to `postgres:17` because PostgreSQL major versions cannot read each other's data directories.

**Fix:** Take a `gitea dump` or `pg_dump`, change `DB_IMAGE` in `gitea.sh`, move `gitea-db-data` aside so the new version starts empty, reinstall and start the service, then restore the dump.

### Actions runner not registered or not picking up jobs

**Cause:** The wizard was not finished when the runner started, the registration is stale, or the workflow's `runs-on` matches no runner label.

**Fix:** Check the runner log:

```bash
docker logs gitea-runner
```

- For a registration error, delete `.runner` and restart (see [Customizing the runner](#customizing-the-runner)).
- Make sure `runs-on` uses `ubuntu-latest`, `ubuntu-24.04`, or `ubuntu-22.04`.
- If `actions/checkout` cannot connect, make sure `ROOT_URL` in `app.ini` and `address` in `.runner` are both `http://localhost:3001`.

### SSH clone fails on port 2222

**Cause:** The container is not running, or port 2222 is not published.

**Fix:**

```bash
docker port gitea
sudo ss -ltnp | grep ':2222\b'
```

### Port 3001 already in use

**Cause:** Another process holds the port.

**Fix:** Change `PORT_WEB` in `gitea.sh`, reinstall with `sudo ./install.sh`, restart, and update `ROOT_URL` in `app.ini` to match.

---

## Security Notes

- This setup is for **local development only**.
- The database password defaults to `P@ssword92` (`DB_PASSWORD` in `gitea.sh`). The database is not published to the host, which limits exposure.
- The runner mounts the host Docker socket, which is equivalent to root access on the host. Any workflow it runs can control the host's Docker daemon. Only run workflows from repositories you trust.
- Ports 3001 and 2222 bind to all host interfaces. Block them at the firewall if the machine is on a shared network.

---

## Uninstall

Run the uninstall script from this directory:

```bash
cd /path/to/Data/gitea
sudo ./uninstall.sh [--purge-data] [--remove-user]
```

| Option | Effect |
|--------|--------|
| *(none)* | Asks whether to delete the data directories |
| `--purge-data` | Deletes the repository, database, and runner data without asking |
| `--remove-user` | Also removes the `gitea` user and disables lingering |

The script always stops and disables the service, removes the three containers, `gitea-network`, the unit file, and `/opt/gitea/gitea.sh`. It removes `/opt/gitea` only when data is purged.

---

## Additional Resources

- [Installation with Docker](https://docs.gitea.com/installation/install-with-docker)
- [Configuration cheat sheet](https://docs.gitea.com/administration/config-cheat-sheet)
- [Database preparation](https://docs.gitea.com/installation/database-prep)
- [Backup and restore](https://docs.gitea.com/administration/backup-and-restore)
- [Gitea Actions overview](https://docs.gitea.com/usage/actions/overview)
- [act_runner](https://docs.gitea.com/usage/actions/act-runner)
