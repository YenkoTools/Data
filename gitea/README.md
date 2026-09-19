# Gitea

Gitea is a lightweight, self-hosted Git service with a web UI, issue tracking, pull requests, and CI/CD pipelines. It is compatible with GitHub workflows and runs entirely on your local infrastructure.

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
10. [Health Checks](#health-checks)
11. [Troubleshooting](#troubleshooting)
12. [Additional Resources](#additional-resources)

---

## Overview

| Property | Value |
|----------|-------|
| Container image | `docker.gitea.com/gitea:latest` |
| Container name | `gitea` |
| Service user | `gitea` |
| Web UI | `http://127.0.0.1:3001` |
| SSH clone port | `2222` |
| Data path | `/home/gitea/.local/share/gitea-data` |

Port 3001 is used for the web UI because port 3000 is occupied by [Dockhand](../dockhand/).

---

## Prerequisites

- Docker installed and running on your system
- Root / sudo access (for systemd installation)

---

## Files

| File | Description |
|------|-------------|
| `gitea.sh` | Container management script (start/stop/status/health) |
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
| Database type | SQLite3 (simplest; no external DB needed) |
| Site URL | `http://localhost:3001` |
| SSH server domain | `localhost` |
| SSH port | `2222` |
| HTTP port | `3000` (internal container port, not the mapped host port) |
| Log path | `/data/gitea/log` |

Create an administrator account on the same page, then click **Install Gitea**.

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
/home/gitea/.local/share/gitea-data/gitea/repositories/
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

**Note:** If you change `GITEA__repository__ROOT` after initial setup, also update the `ROOT` value under `[repository]` in Gitea's `app.ini` (found at `/home/gitea/.local/share/gitea-data/gitea/conf/app.ini`) and migrate existing repositories via **Admin panel → Git Repositories → Resync**.

---

## Health Checks

```bash
# Check service status
sudo systemctl status gitea.service

# Run the built-in health check
sudo -u gitea /opt/gitea/gitea.sh health

# Test the web UI endpoint directly
curl -I http://127.0.0.1:3001

# View container logs
docker logs gitea
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
sudo chown -R gitea:gitea /home/gitea/.local/share/gitea-data
```

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
- [Gitea API Documentation](http://localhost:3001/api/swagger)
