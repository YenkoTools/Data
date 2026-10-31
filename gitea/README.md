# Gitea

Gitea is a lightweight, self-hosted Git service with a web UI, issue tracking, pull requests, and CI/CD pipelines. It is compatible with GitHub workflows and runs entirely on your local infrastructure.

The service runs three containers: Gitea, a dedicated PostgreSQL database (`gitea-db`), and a Gitea Actions runner (`gitea-runner`). All three are started and stopped together by `gitea.sh`. Gitea and the database communicate over a private Docker network; the runner uses the host network.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Files](#files)
4. [Installation](#installation)
5. [Managing the Service](#managing-the-service)
6. [Management Script Commands](#management-script-commands)
7. [First-Run Setup](#first-run-setup)
8. [Accessing Gitea](#accessing-gitea)
9. [Configuring Repository Storage](#configuring-repository-storage)
10. [Backups](#backups)
11. [CI/CD with Gitea Actions](#cicd-with-gitea-actions)
12. [Health Checks](#health-checks)
13. [Troubleshooting](#troubleshooting)
14. [Additional Resources](#additional-resources)

---

## Overview

| Property | Value |
|----------|-------|
| Container image | `docker.gitea.com/gitea:latest` |
| Container name | `gitea` |
| Service user | `gitea` |
| Web UI | `http://127.0.0.1:3001` |
| SSH clone port | `2222` |
| Data path | `/opt/gitea/.local/share/gitea-data` |
| Database image | `postgres:17` |
| Database container | `gitea-db` |
| Database name / user | `gitea` / `gitea` |
| Database data path | `/opt/gitea/.local/share/gitea-db-data` |
| Runner container | `gitea-runner` (Gitea Actions) |
| Runner data path | `/opt/gitea/.local/share/gitea-runner-data` |
| Docker network | `gitea-network` |

Port 3001 is used for the web UI because port 3000 is occupied by [Dockhand](../dockhand/).

The database port is not published to the host. Gitea reaches PostgreSQL at `gitea-db:5432` on `gitea-network`, so it does not conflict with the standalone [pgsql](../pgsql/) service on port 5432. The database password is set by `DB_PASSWORD` in `gitea.sh`; change it before the first start.

---

## Prerequisites

- Docker installed and running on your system
- Root / sudo access (for systemd installation)

---

## Files

| File | Description |
|------|-------------|
| `gitea.sh` | Container management script for Gitea, its PostgreSQL database, and the Actions runner (start/stop/status/health) |
| `gitea.service` | systemd service unit file |
| `install.sh` | One-time installation script (requires root) |
| `README.md` | This file |

---

## Installation

Run the install script once to set up the service:

```bash
cd /path/to/Data/gitea
sudo ./install.sh
```

**What the install script does:**

1. Creates a `gitea` system user with home directory at `/opt/gitea`
2. Adds the `gitea` user to the `docker` group
3. Enables user lingering (`loginctl enable-linger gitea`)
4. Copies `gitea.sh` to `/opt/gitea/` with execute permissions
5. Copies `gitea.service` to `/etc/systemd/system/`
6. Runs `systemctl daemon-reload` and enables the service to start on boot

After installation, start the service manually for the first time:

```bash
sudo systemctl start gitea.service
```

---

## Managing the Service

```bash
# Start
sudo systemctl start gitea.service

# Stop
sudo systemctl stop gitea.service

# Check status
sudo systemctl status gitea.service

# Enable auto-start on boot (done by install script)
sudo systemctl enable gitea.service

# Disable auto-start
sudo systemctl disable gitea.service

# View logs
sudo journalctl -xeu gitea.service

# Follow real-time logs
sudo journalctl -fu gitea.service
```

---

## Management Script Commands

The `gitea.sh` script can also be called directly as the `gitea` user:

```bash
sudo -u gitea /opt/gitea/gitea.sh start
sudo -u gitea /opt/gitea/gitea.sh stop
sudo -u gitea /opt/gitea/gitea.sh status
sudo -u gitea /opt/gitea/gitea.sh health
```

---

## First-Run Setup

On the first visit to `http://localhost:3001`, Gitea presents an installation wizard. Recommended settings:

| Setting | Value |
|---------|-------|
| Database type | PostgreSQL (pre-filled from `gitea.sh`; host `gitea-db:5432`, database/user `gitea`) |
| Site URL | `http://localhost:3001` |
| SSH server domain | `localhost` |
| SSH port | `2222` (pre-filled from `PORT_SSH` in `gitea.sh`) |
| HTTP port | `3000` (internal container port, not the mapped host port) |
| Log path | `/data/gitea/log` |

The database fields are pre-filled from the environment variables set in `gitea.sh` and should not be changed. Create an administrator account on the same page, then click **Install Gitea**.

---

## Accessing Gitea

| Access | URL / Command |
|--------|---------------|
| Web UI | `http://localhost:3001` |
| SSH clone | `git clone ssh://git@localhost:2222/user/repo.git` |
| HTTP clone | `http://localhost:3001/user/repo.git` |

### Configuring the Git SSH remote

To use the non-standard SSH port transparently, add this to `~/.ssh/config`:

```
Host localhost
    HostName localhost
    User git
    Port 2222
```

Then SSH clones can be written as:

```bash
git clone git@localhost:user/repo.git
```

---

## Configuring Repository Storage

By default, Gitea stores all git repositories inside the data directory at:
```
/opt/gitea/.local/share/gitea-data/gitea/repositories/
```

### Using /home/jim/Vault as the repository root

To store Gitea repositories in `/home/jim/Vault`, edit `/opt/gitea/gitea.sh` and add the following to the `docker run` command:

```bash
-v "/home/jim/Vault:/vault" \
-e GITEA__repository__ROOT=/vault \
```

The `gitea` service user must have read/write access to `/home/jim/Vault`. Grant access with:

```bash
# Option A: add the gitea user to the jim group and grant group write
sudo usermod -aG jim gitea
chmod -R g+rwX /home/jim/Vault

# Option B: transfer ownership of the Vault to the gitea user
sudo chown -R gitea:gitea /home/jim/Vault
```

After editing `gitea.sh`, restart the service:

```bash
sudo systemctl restart gitea.service
```

**Note:** If you change `GITEA__repository__ROOT` after initial setup, also update the `ROOT` value under `[repository]` in Gitea's `app.ini` (found at `/opt/gitea/.local/share/gitea-data/gitea/conf/app.ini`) and migrate existing repositories via **Admin panel → Git Repositories → Resync**.

---

## Backups

Gitea state is split between the Gitea data directory (repositories, `app.ini`, attachments) and the PostgreSQL data directory. Back up both together while the service is stopped:

```bash
sudo systemctl stop gitea.service
sudo tar -czf gitea-backup-$(date +%F).tar.gz -C /opt/gitea/.local/share gitea-data gitea-db-data
sudo systemctl start gitea.service
```

Alternatively, back up while the service is running. `gitea dump` captures repositories, configuration, and a SQL dump of the database:

```bash
docker exec -u git -w /tmp gitea gitea dump -c /data/gitea/conf/app.ini -f /tmp/gitea-dump.zip
docker cp gitea:/tmp/gitea-dump.zip ./gitea-dump-$(date +%F).zip
docker exec gitea rm /tmp/gitea-dump.zip
```

For a database-only backup:

```bash
docker exec gitea-db pg_dump -U gitea -d gitea > gitea-db-$(date +%F).sql
```

If repositories are stored outside the data directory (see [Configuring Repository Storage](#configuring-repository-storage)), back up that location as well.

---

## CI/CD with Gitea Actions

Gitea Actions uses GitHub Actions–compatible workflow syntax (`.gitea/workflows/*.yml`). Actions is turned on by `gitea.sh` (`GITEA__actions__ENABLED=true`), and jobs run on an [`act_runner`](https://docs.gitea.com/usage/actions/act-runner) container (`gitea-runner`) that is started and stopped together with Gitea.

| Property | Value |
|----------|-------|
| Runner image | `docker.gitea.com/act_runner:latest` |
| Runner container | `gitea-runner` |
| Runner name | `<hostname>-runner` |
| Runner data path | `/opt/gitea/.local/share/gitea-runner-data` |
| Runner config | `/opt/gitea/.local/share/gitea-runner-data/config.yaml` |
| Labels | `ubuntu-latest`, `ubuntu-24.04`, `ubuntu-22.04` |

### Registration

The runner registers itself, so you do not need to copy a token by hand. When no registration exists yet, `gitea.sh start` runs `gitea actions generate-runner-token` inside the Gitea container and passes the token to the runner on its first start. The registration is stored in `.runner` in the runner data directory and reused on later starts.

Token generation only works after the [first-run installation wizard](#first-run-setup) is finished. On a brand-new install the runner is skipped. Once the wizard is done, restart the service:

```bash
sudo systemctl restart gitea.service
```

The runner then shows up under **Site Administration → Actions → Runners**.

### How jobs run

- The runner uses the host network and registers with Gitea at `http://localhost:3001`. act_runner passes this address to jobs as the server URL, so it must be reachable from job containers too.
- Jobs run in sibling containers that the runner starts through the host Docker socket (`/var/run/docker.sock`).
- Job containers also use the host network (`container.network: host`), so `actions/checkout` reaches Gitea at `http://localhost:3001`, which matches the Site URL (`ROOT_URL`).
- The runner container runs as the `gitea` user and gets the Docker socket's group, so runner files stay owned by `gitea`.

**Security note:** access to the Docker socket is equivalent to root on the host. Any workflow that runs on this runner can control the host's Docker daemon. Only run workflows from repositories you trust.

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

`config.yaml` is created on the first start and is not overwritten afterward. To change capacity, labels, or job container settings, edit it and restart the service. Run `docker run --rm docker.gitea.com/act_runner:latest generate-config` to see every available option.

To re-register the runner, for example after deleting it in the web UI, remove the registration file and restart:

```bash
sudo rm /opt/gitea/.local/share/gitea-runner-data/.runner
sudo systemctl restart gitea.service
```

---

## Health Checks

```bash
# Check service status
sudo systemctl status gitea.service

# Run the built-in health check
sudo -u gitea /opt/gitea/gitea.sh health

# Test the web UI endpoint directly
curl -I http://127.0.0.1:3001

# Check the database
docker exec gitea-db pg_isready -U gitea -d gitea

# View container logs
docker logs gitea
docker logs gitea-db
docker logs gitea-runner
```

---

## Troubleshooting

**Web UI not loading after start**
Gitea takes 15–30 seconds to initialize on first boot. Wait for the health check to pass before accessing the UI:
```bash
docker inspect --format='{{.State.Health.Status}}' gitea
```

**Permission denied on data directory**
The container's internal user UID is set to the `gitea` service user's UID at start time. If the data directory was created by a different user, fix ownership:
```bash
sudo chown -R gitea:gitea /opt/gitea/.local/share/gitea-data
```

**Gitea cannot connect to the database**
Confirm both containers are running and attached to `gitea-network`:
```bash
sudo -u gitea /opt/gitea/gitea.sh status
docker network inspect gitea-network --format '{{range .Containers}}{{.Name}} {{end}}'
docker logs gitea-db
```
If `DB_PASSWORD` in `gitea.sh` was changed after the database was first created, PostgreSQL keeps the original password. Either revert it, or update it in the database:
```bash
docker exec -it gitea-db psql -U gitea -d gitea -c "ALTER USER gitea PASSWORD 'new_password';"
```

**Upgrading PostgreSQL**
The database image is pinned to `postgres:17` because PostgreSQL major versions cannot read each other's data directories. To upgrade, take a `gitea dump` or `pg_dump`, change `DB_IMAGE`, start with an empty `gitea-db-data` directory, and restore.

**Actions runner not registered or not picking up jobs**
Check the runner log, and confirm the workflow's `runs-on` matches one of the runner's labels:
```bash
docker logs gitea-runner
```
If the log shows a registration error, delete `.runner` and restart (see [Customizing the runner](#customizing-the-runner)). If `actions/checkout` cannot connect, make sure the Site URL (`ROOT_URL` in `app.ini`) is `http://localhost:3001` and that `address` in `.runner` is the same URL.

**SSH clone failing on port 2222**
Confirm the container is running and port 2222 is bound:
```bash
docker port gitea
ss -tlnp | grep 2222
```

**Port 3001 already in use**
Edit `PORT_WEB` in `/opt/gitea/gitea.sh` and update the Site URL in Gitea's `app.ini` to match.

---

## Additional Resources

- [Gitea Docker Installation](https://docs.gitea.com/installation/install-with-docker)
- [Gitea Configuration Reference](https://docs.gitea.com/administration/config-cheat-sheet)
- [Gitea Database Preparation](https://docs.gitea.com/installation/database-prep)
- [Gitea Backup and Restore](https://docs.gitea.com/administration/backup-and-restore)
- [Gitea Actions Overview](https://docs.gitea.com/usage/actions/overview)
- [Gitea act_runner](https://docs.gitea.com/usage/actions/act-runner)
- [Gitea API Documentation](http://localhost:3001/api/swagger)
