# Valkey

Valkey is an open-source, Redis-compatible in-memory data store. It works as a drop-in replacement for Redis for caching, session storage, queues, and pub/sub messaging.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Files](#files)
4. [Installation](#installation)
5. [Managing the Service](#managing-the-service)
6. [Management Script Commands](#management-script-commands)
7. [Connecting to Valkey](#connecting-to-valkey)
8. [Usage Examples](#usage-examples)
9. [Migrating from the Podman Setup](#migrating-from-the-podman-setup)
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
| Container image | `docker.io/valkey/valkey:latest` |
| Container name | `valkey` |
| Service user | `valkey` |
| systemd unit | `valkey.service` |
| Network mode | `host` |
| Port | `6379` |
| Password | `P@ssword92` |
| Persistence | Append-only file (AOF) enabled |
| Data path | `/opt/valkey/.local/share/valkey-data` |
| Upstream | <https://valkey.io> |

---

## Prerequisites

- Docker installed and running
- Root or sudo access
- Port 6379 free on the host (stop any local Redis first)
- Optional: `valkey-cli` or `redis-cli` on the host. The container includes `valkey-cli`

---

## Files

| File | Purpose | Installed to |
|------|---------|--------------|
| `valkey.sh` | Container management script (`start`, `stop`, `status`, `health`) | `/opt/valkey/valkey.sh` |
| `valkey.service` | systemd unit file | `/etc/systemd/system/valkey.service` |
| `install.sh` | One-time installation script (requires root) | Not installed |
| `uninstall.sh` | Removes the service, and optionally its data and user (requires root) | Not installed |
| `README.md` | This document | Not installed |

---

## Installation

1. Optional: change `PASSWORD` in `valkey.sh`. Unlike the database services, Valkey reads the password on every start, so you can change it later too.

2. Run the install script from this directory:

   ```bash
   cd /path/to/Data/valkey
   sudo ./install.sh
   ```

3. Start the service for the first time:

   ```bash
   sudo systemctl start valkey.service
   ```

4. Confirm it is healthy:

   ```bash
   sudo -u valkey /opt/valkey/valkey.sh health
   ```

**What `install.sh` does:**

1. Creates the `valkey` system user with home directory `/opt/valkey`
2. Adds `valkey` to the `docker` group
3. Enables user lingering (`loginctl enable-linger valkey`)
4. Copies `valkey.sh` to `/opt/valkey/` and makes it executable
5. Copies `valkey.service` to `/etc/systemd/system/`
6. Reloads systemd and enables the service to start on boot

---

## Managing the Service

```bash
# Start
sudo systemctl start valkey.service

# Stop
sudo systemctl stop valkey.service

# Check status
sudo systemctl status valkey.service

# Enable auto-start on boot (done by install.sh)
sudo systemctl enable valkey.service

# Disable auto-start
sudo systemctl disable valkey.service

# View logs
sudo journalctl -xeu valkey.service

# Follow logs in real time
sudo journalctl -fu valkey.service
```

---

## Management Script Commands

Run the management script directly as the service user:

```bash
sudo -u valkey /opt/valkey/valkey.sh <command>
```

| Command | Action |
|---------|--------|
| `start` | Removes any existing `valkey` container and starts a new one with the password and AOF persistence set |
| `stop` | Stops and removes the container |
| `status` | Shows the container's state (`docker ps -a`) |
| `health` | Confirms the container is running and an authenticated `PING` returns `PONG` |

---

## Connecting to Valkey

| Field | Value |
|-------|-------|
| Host | `localhost` |
| Port | `6379` |
| Username | `default` (or none) |
| Password | `P@ssword92` |

**Connection strings:**

```text
# URI (the @ in the password is URL-encoded as %40)
redis://:P%40ssword92@localhost:6379/0

# StackExchange.Redis (.NET)
localhost:6379,password=P@ssword92
```

**From inside the container:**

```bash
docker exec -it valkey valkey-cli -a 'P@ssword92' --no-auth-warning
```

**From the host** (if `valkey-cli` or `redis-cli` is installed):

```bash
valkey-cli -h localhost -p 6379 -a 'P@ssword92' --no-auth-warning
```

---

## Usage Examples

### valkey-cli

Connect as shown above, then:

```text
# Strings, with and without expiry
SET greeting "Hello, Valkey!"
GET greeting
SET session:user123 "active" EX 10
TTL session:user123

# Lists (a simple queue)
RPUSH queue:jobs "job1" "job2" "job3"
LPOP queue:jobs
LRANGE queue:jobs 0 -1

# Hashes
HSET user:1 name "Alice" email "alice@example.com"
HGETALL user:1

# Sets
SADD tags:article1 "dotnet" "csharp" "azure"
SMEMBERS tags:article1
```

### .NET

Requires the `StackExchange.Redis` NuGet package.

```csharp
using StackExchange.Redis;

var redis = await ConnectionMultiplexer.ConnectAsync("localhost:6379,password=P@ssword92");
var db = redis.GetDatabase();

await db.StringSetAsync("greeting", "Hello, Valkey!");
Console.WriteLine(await db.StringGetAsync("greeting"));
```

### Python

Requires `pip install valkey` (or the `redis` package, which also works).

```python
import valkey

client = valkey.Valkey(host="localhost", port=6379, password="P@ssword92", decode_responses=True)
client.set("greeting", "Hello, Valkey!")
print(client.get("greeting"))
```

---

## Migrating from the Podman Setup

Earlier versions of this directory ran Valkey with Podman as the `jim` user, using `valkey-ultra3.sh`, a container named `valkey-ultra3`, and data in `/home/jim/.valkey-ultra3`. The port and password are unchanged, so clients need no changes. To move existing data to the new setup:

1. Stop and disable the old service, and remove the old container if Podman is still installed:

   ```bash
   sudo systemctl disable --now valkey.service
   podman rm -f valkey-ultra3 2>/dev/null || true
   ```

2. Install the new service, but don't start it yet:

   ```bash
   cd /path/to/Data/valkey
   sudo ./install.sh
   ```

   This replaces `/etc/systemd/system/valkey.service` with the new unit.

3. Copy the old data into the new data directory:

   ```bash
   sudo mkdir -p /opt/valkey/.local/share/valkey-data
   sudo cp -a /home/jim/.valkey-ultra3/valkey-data/. /opt/valkey/.local/share/valkey-data/
   ```

   The container takes ownership of the files when it starts, so no `chown` is needed.

4. Start the new service and check your keys are there:

   ```bash
   sudo systemctl start valkey.service
   docker exec valkey valkey-cli -a 'P@ssword92' --no-auth-warning DBSIZE
   ```

5. When you're satisfied, remove the old files:

   ```bash
   rm -rf /home/jim/.valkey-ultra3
   ```

The old `valkey.conf` is not used. Its two settings, `requirepass` and `appendonly yes`, are now passed to `valkey-server` by `valkey.sh`.

---

## Running Without systemd

For a quick test, or on a machine without systemd (such as Windows 11), run the container directly.

**Linux / macOS:**

```bash
docker run -d \
  --name valkey \
  -p 6379:6379 \
  -v $HOME/valkey-data:/data \
  valkey/valkey:latest \
  valkey-server --requirepass 'P@ssword92' --appendonly yes
```

**Windows 11 (PowerShell):**

```powershell
docker run -d `
  --name valkey `
  -p 6379:6379 `
  -v ${HOME}/valkey-data:/data `
  valkey/valkey:latest `
  valkey-server --requirepass 'P@ssword92' --appendonly yes
```

---

## Data Persistence and Backups

Data is stored on the host at `/opt/valkey/.local/share/valkey-data` and mounted into the container at `/data`. With AOF enabled, every write is logged to `appendonlydir/`, so data survives container restarts and re-creation. Valkey may also write `dump.rdb` snapshots there.

**Back up (service stopped):**

```bash
sudo systemctl stop valkey.service
sudo tar -czf valkey-backup-$(date +%F).tar.gz -C /opt/valkey/.local/share valkey-data
sudo systemctl start valkey.service
```

**Restore:**

```bash
sudo systemctl stop valkey.service
sudo rm -rf /opt/valkey/.local/share/valkey-data
sudo tar -xzf valkey-backup-YYYY-MM-DD.tar.gz -C /opt/valkey/.local/share
sudo systemctl start valkey.service
```

---

## Health Checks

```bash
# Check service status
sudo systemctl status valkey.service

# Run the built-in health check
sudo -u valkey /opt/valkey/valkey.sh health

# Check the container's own health status
docker inspect --format '{{.State.Health.Status}}' valkey

# Send an authenticated PING
docker exec valkey valkey-cli -a 'P@ssword92' --no-auth-warning ping

# View container logs
docker logs valkey
```

Expected:

- The built-in check prints `Valkey is healthy and accepting connections on port 6379`.
- `docker inspect` prints `healthy`.
- `ping` prints `PONG`.

---

## Troubleshooting

### `NOAUTH Authentication required`

**Cause:** The client connected without the password.

**Fix:** Pass the password: `-a 'P@ssword92'` for `valkey-cli`, or `password=` in the connection string.

### `WRONGPASS invalid username-password pair`

**Cause:** The client's password does not match `PASSWORD` in the installed `/opt/valkey/valkey.sh`.

**Fix:** Use the password from the installed script, or change `PASSWORD` in `valkey.sh`, reinstall with `sudo ./install.sh`, and restart.

### Service fails to start: port 6379 already in use

**Cause:** A local Redis server, or the old Podman container, is listening on 6379.

**Fix:**

```bash
sudo ss -ltnp | grep ':6379\b'
sudo systemctl disable --now redis-server 2>/dev/null
```

### Keys disappear after a restart

**Cause:** The data directory is not mounted, or the container was started by hand without `--appendonly yes`.

**Fix:** Check the mount and the server arguments:

```bash
docker inspect --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{end}}' valkey
docker inspect --format '{{.Args}}' valkey
```

---

## Security Notes

- This setup is for **local development only**.
- The password `P@ssword92` is hardcoded in `valkey.sh` and visible in the container's command line and health check.
- With host networking, Valkey listens on the host's interfaces. Block port 6379 at the firewall if the machine is on a shared network. An exposed Valkey or Redis instance can be abused even with a password.

---

## Uninstall

Run the uninstall script from this directory:

```bash
cd /path/to/Data/valkey
sudo ./uninstall.sh [--purge-data] [--remove-user]
```

| Option | Effect |
|--------|--------|
| *(none)* | Asks whether to delete the data directory |
| `--purge-data` | Deletes the data directory without asking |
| `--remove-user` | Also removes the `valkey` user and disables lingering |

The script always stops and disables the service, removes the container, the unit file, and `/opt/valkey/valkey.sh`. It removes `/opt/valkey` only when data is purged.

---

## Additional Resources

- [Valkey documentation](https://valkey.io/docs/)
- [Valkey command reference](https://valkey.io/commands/)
- [valkey/valkey on Docker Hub](https://hub.docker.com/r/valkey/valkey)
- [Valkey on GitHub](https://github.com/valkey-io/valkey)
