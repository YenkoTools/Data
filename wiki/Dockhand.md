# Dockhand

Dockhand is an open-source web UI for managing Docker. It provides real-time container management, Compose stack orchestration, and support for multiple Docker hosts.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Files](#files)
4. [Installation](#installation)
5. [Managing the Service](#managing-the-service)
6. [Management Script Commands](#management-script-commands)
7. [Connecting to Dockhand](#connecting-to-dockhand)
8. [Data Persistence and Backups](#data-persistence-and-backups)
9. [Health Checks](#health-checks)
10. [Troubleshooting](#troubleshooting)
11. [Security Notes](#security-notes)
12. [Uninstall](#uninstall)
13. [Additional Resources](#additional-resources)

---

## Overview

| Property | Value |
|----------|-------|
| Container image | `fnsys/dockhand:latest` |
| Container name | `dockhand` |
| Service user | `dockhand` |
| systemd unit | `dockhand.service` |
| Network mode | `host` |
| Web UI | `http://localhost:3000` |
| Data path | `/opt/dockhand` (mounted at the same path inside the container) |
| Upstream | <https://dockhand.pro> |

---

## Prerequisites

- Docker installed and running
- Root or sudo access
- Port 3000 free on the host

---

## Files

| File | Purpose | Installed to |
|------|---------|--------------|
| `dockhand.sh` | Container management script (`start`, `stop`, `status`, `health`) | `/opt/dockhand/dockhand.sh` |
| `dockhand.service` | systemd unit file | `/etc/systemd/system/dockhand.service` |
| `install.sh` | One-time installation script (requires root) | Not installed |
| `README.md` | This document | Not installed |

---

## Installation

1. Run the install script from this directory:

   ```bash
   cd /path/to/Data/dockhand
   sudo ./install.sh
   ```

2. Start the service for the first time:

   ```bash
   sudo systemctl start dockhand.service
   ```

3. Confirm it is healthy:

   ```bash
   sudo -u dockhand /opt/dockhand/dockhand.sh health
   ```

4. Open `http://localhost:3000` and enable authentication (see [Connecting to Dockhand](#connecting-to-dockhand)).

**What `install.sh` does:**

1. Creates the `dockhand` system user with home directory `/opt/dockhand`
2. Adds `dockhand` to the `docker` group
3. Enables user lingering (`loginctl enable-linger dockhand`)
4. Copies `dockhand.sh` to `/opt/dockhand/` and makes it executable
5. Copies `dockhand.service` to `/etc/systemd/system/`
6. Reloads systemd and enables the service to start on boot

---

## Managing the Service

```bash
# Start
sudo systemctl start dockhand.service

# Stop
sudo systemctl stop dockhand.service

# Check status
sudo systemctl status dockhand.service

# Enable auto-start on boot (done by install.sh)
sudo systemctl enable dockhand.service

# Disable auto-start
sudo systemctl disable dockhand.service

# View logs
sudo journalctl -xeu dockhand.service

# Follow logs in real time
sudo journalctl -fu dockhand.service
```

---

## Management Script Commands

Run the management script directly as the service user:

```bash
sudo -u dockhand /opt/dockhand/dockhand.sh <command>
```

| Command | Action |
|---------|--------|
| `start` | Removes any existing `dockhand` container and starts a new one |
| `stop` | Stops and removes the container |
| `status` | Shows the container's state (`docker ps -a`) |
| `health` | Confirms the container is running and the web UI on port 3000 responds |

---

## Connecting to Dockhand

| Field | Value |
|-------|-------|
| URL | `http://localhost:3000` |
| Authentication | Disabled on first launch |
| Docker host | The local daemon, through the mounted `/var/run/docker.sock` |

**First-time setup:** go to **Settings → Authentication**, enable authentication, and create the first admin user.

**Compose stacks with relative paths:** Dockhand's data directory is mounted at the same path inside and outside the container (`/opt/dockhand:/opt/dockhand`, with `DATA_DIR=/opt/dockhand`). This lets relative volume paths in stacks resolve to real paths on the host.

---

## Data Persistence and Backups

Data (settings, users, and stack files) is stored on the host at `/opt/dockhand`, which is also the service user's home directory and holds `dockhand.sh`. It survives container restarts and re-creation.

**Back up:**

```bash
sudo systemctl stop dockhand.service
sudo tar -czf dockhand-backup-$(date +%F).tar.gz -C /opt dockhand
sudo systemctl start dockhand.service
```

**Restore:**

```bash
sudo systemctl stop dockhand.service
sudo rm -rf /opt/dockhand
sudo tar -xzf dockhand-backup-YYYY-MM-DD.tar.gz -C /opt
sudo systemctl start dockhand.service
```

---

## Health Checks

```bash
# Check service status
sudo systemctl status dockhand.service

# Run the built-in health check
sudo -u dockhand /opt/dockhand/dockhand.sh health

# Check the container's own health status (health check defined by the image)
docker inspect --format '{{.State.Health.Status}}' dockhand

# Test the web UI directly
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3000

# View container logs
docker logs dockhand
```

Expected:

- The built-in check prints `Dockhand is healthy and accessible at http://localhost:3000`.
- `docker inspect` prints `healthy`.
- `curl` prints `200`.

---

## Troubleshooting

### Container fails to start: Docker socket permission denied

**Cause:** The `dockhand` user is not in the `docker` group.

**Fix:**

```bash
groups dockhand                  # should list docker
sudo usermod -aG docker dockhand
sudo systemctl restart dockhand.service
```

### Web UI not reachable after start

**Cause:** The container exited, or another process holds port 3000. Gitea in this repo uses port 3001 to avoid this conflict.

**Fix:**

```bash
docker logs dockhand
sudo ss -ltnp | grep ':3000\b'
```

### Relative volume paths in stacks mount as empty directories

**Cause:** The data directory is not mounted at the same path inside and outside the container.

**Fix:** Confirm the mount and `DATA_DIR` match:

```bash
docker inspect --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}' dockhand
docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' dockhand | grep DATA_DIR
```

Both should show `/opt/dockhand`. See the [Dockhand data storage documentation](https://dockhand.pro/manual/#data-storage).

---

## Security Notes

- This setup is for **local development only**.
- Authentication is **off** until you enable it. Until then, anyone who can reach port 3000 has full control of Docker.
- The container mounts `/var/run/docker.sock`, which is equivalent to root access on the host. Treat Dockhand logins as root credentials.
- With host networking, Dockhand listens on the host's interfaces. Block port 3000 at the firewall if the machine is on a shared network.

---

## Uninstall

There is no `uninstall.sh` for Dockhand. Remove it manually:

```bash
sudo systemctl disable --now dockhand.service
sudo rm /etc/systemd/system/dockhand.service
sudo systemctl daemon-reload
docker rm -f dockhand
sudo loginctl disable-linger dockhand
sudo userdel -r dockhand   # also deletes /opt/dockhand and all stored data
```

Containers and stacks that Dockhand created keep running; remove them separately if needed.

---

## Additional Resources

- [Dockhand website](https://dockhand.pro)
- [Dockhand manual](https://dockhand.pro/manual)
- [Dockhand on GitHub](https://github.com/Finsys/dockhand)
- [Dockhand on Docker Hub](https://hub.docker.com/r/fnsys/dockhand)
