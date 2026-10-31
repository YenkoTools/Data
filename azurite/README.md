# Azurite

Azurite is an open-source emulator for the Azure Storage APIs. It gives you local Blob, Queue, and Table storage for development and testing without an Azure subscription.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Files](#files)
4. [Installation](#installation)
5. [Managing the Service](#managing-the-service)
6. [Management Script Commands](#management-script-commands)
7. [Connecting to Azurite](#connecting-to-azurite)
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
| Container image | `mcr.microsoft.com/azure-storage/azurite:latest` |
| Container name | `azurite` |
| Service user | `azurite` |
| systemd unit | `azurite.service` |
| Network mode | `host` |
| Blob service | `http://127.0.0.1:10000` |
| Queue service | `http://127.0.0.1:10001` |
| Table service | `http://127.0.0.1:10002` |
| Data path | `/opt/azurite/.local/share/azurite-data` |
| Upstream | <https://github.com/Azure/Azurite> |

---

## Prerequisites

- Docker installed and running
- Root or sudo access
- Ports 10000, 10001, and 10002 free on the host

---

## Files

| File | Purpose | Installed to |
|------|---------|--------------|
| `azurite.sh` | Container management script (`start`, `stop`, `status`, `health`) | `/opt/azurite/azurite.sh` |
| `azurite.service` | systemd unit file | `/etc/systemd/system/azurite.service` |
| `install.sh` | One-time installation script (requires root) | Not installed |
| `README.md` | This document | Not installed |

---

## Installation

1. Run the install script from this directory:

   ```bash
   cd /path/to/Data/azurite
   sudo ./install.sh
   ```

2. Start the service for the first time:

   ```bash
   sudo systemctl start azurite.service
   ```

3. Confirm it is healthy:

   ```bash
   sudo -u azurite /opt/azurite/azurite.sh health
   ```

**What `install.sh` does:**

1. Creates the `azurite` system user with home directory `/opt/azurite`
2. Adds `azurite` to the `docker` group
3. Enables user lingering (`loginctl enable-linger azurite`)
4. Copies `azurite.sh` to `/opt/azurite/` and makes it executable
5. Copies `azurite.service` to `/etc/systemd/system/`
6. Reloads systemd and enables the service to start on boot

---

## Managing the Service

```bash
# Start
sudo systemctl start azurite.service

# Stop
sudo systemctl stop azurite.service

# Check status
sudo systemctl status azurite.service

# Enable auto-start on boot (done by install.sh)
sudo systemctl enable azurite.service

# Disable auto-start
sudo systemctl disable azurite.service

# View logs
sudo journalctl -xeu azurite.service

# Follow logs in real time
sudo journalctl -fu azurite.service
```

---

## Management Script Commands

Run the management script directly as the service user:

```bash
sudo -u azurite /opt/azurite/azurite.sh <command>
```

| Command | Action |
|---------|--------|
| `start` | Removes any existing `azurite` container and starts a new one |
| `stop` | Stops and removes the container |
| `status` | Shows the container's state (`docker ps -a`) |
| `health` | Confirms the container is running and that the Table and Blob endpoints respond |

---

## Connecting to Azurite

Azurite uses the well-known development storage account. These credentials are public and the same in every Azurite install.

| Field | Value |
|-------|-------|
| Account name | `devstoreaccount1` |
| Account key | `Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==` |
| Blob endpoint | `http://127.0.0.1:10000/devstoreaccount1` |
| Queue endpoint | `http://127.0.0.1:10001/devstoreaccount1` |
| Table endpoint | `http://127.0.0.1:10002/devstoreaccount1` |

**Connection string:**

```text
DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://127.0.0.1:10000/devstoreaccount1;QueueEndpoint=http://127.0.0.1:10001/devstoreaccount1;TableEndpoint=http://127.0.0.1:10002/devstoreaccount1;
```

Most Azure SDKs also accept the shortcut `UseDevelopmentStorage=true`, which expands to the same values.

**Azure Storage Explorer:** add a connection, choose **Local storage emulator**, and keep the default ports.

---

## Usage Examples

### Python

Requires `pip install azure-data-tables`.

```python
from azure.data.tables import TableServiceClient

connection_string = (
    "DefaultEndpointsProtocol=http;"
    "AccountName=devstoreaccount1;"
    "AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;"
    "TableEndpoint=http://127.0.0.1:10002/devstoreaccount1;"
)

client = TableServiceClient.from_connection_string(connection_string)
client.create_table_if_not_exists("testtable")
print("Table created successfully!")
```

### .NET

Requires the `Azure.Data.Tables` NuGet package.

```csharp
using Azure.Data.Tables;

var connectionString =
    "DefaultEndpointsProtocol=http;" +
    "AccountName=devstoreaccount1;" +
    "AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;" +
    "TableEndpoint=http://127.0.0.1:10002/devstoreaccount1;";

var tableServiceClient = new TableServiceClient(connectionString);
await tableServiceClient.CreateTableIfNotExistsAsync("testtable");
Console.WriteLine("Table created successfully!");
```

---

## Running Without systemd

For a quick test, or on a machine without systemd (such as Windows 11), run the container directly. This publishes the ports explicitly instead of using host networking.

**Linux / macOS:**

```bash
docker run -d \
  --name azurite \
  -p 10000:10000 \
  -p 10001:10001 \
  -p 10002:10002 \
  -v $HOME/azurite-data:/data \
  mcr.microsoft.com/azure-storage/azurite:latest
```

**Windows 11 (PowerShell):**

```powershell
docker run -d `
  --name azurite `
  -p 10000:10000 `
  -p 10001:10001 `
  -p 10002:10002 `
  -v ${HOME}/azurite-data:/data `
  mcr.microsoft.com/azure-storage/azurite:latest
```

---

## Data Persistence and Backups

Data is stored on the host at `/opt/azurite/.local/share/azurite-data` and mounted into the container at `/data`. It survives container restarts and re-creation. The directory is owned by `root` because the container process writes as root, so the commands below use `sudo`.

**Back up:**

```bash
sudo systemctl stop azurite.service
sudo tar -czf azurite-backup-$(date +%F).tar.gz -C /opt/azurite/.local/share azurite-data
sudo systemctl start azurite.service
```

**Restore:**

```bash
sudo systemctl stop azurite.service
sudo rm -rf /opt/azurite/.local/share/azurite-data
sudo tar -xzf azurite-backup-YYYY-MM-DD.tar.gz -C /opt/azurite/.local/share
sudo systemctl start azurite.service
```

---

## Health Checks

```bash
# Check service status
sudo systemctl status azurite.service

# Run the built-in health check
sudo -u azurite /opt/azurite/azurite.sh health

# Check the container's own health status
docker inspect --format '{{.State.Health.Status}}' azurite

# Test the Table and Blob endpoints directly
curl -s -o /dev/null -w '%{http_code}\n' -I "http://127.0.0.1:10002/devstoreaccount1?comp=properties"
curl -s -o /dev/null -w '%{http_code}\n' -I "http://127.0.0.1:10000/devstoreaccount1?comp=properties"

# View container logs
docker logs azurite
```

Expected:

- The built-in check prints `Azurite is healthy (Blob, Queue, and Table services running)`.
- `docker inspect` prints `healthy`. The container's health check opens a TCP connection to all three ports every 30 seconds.
- Each `curl` prints `400`. The request has no credentials, so Azurite rejects it, but any HTTP response means the endpoint is up.

---

## Troubleshooting

### Service fails to start: port already in use

**Cause:** Another process, often a second Azurite instance, is listening on 10000, 10001, or 10002. The service uses host networking, so it cannot remap ports.

**Fix:** Find and stop the other process, then restart the service:

```bash
sudo ss -ltnp | grep -E ':1000[0-2]\b'
sudo systemctl restart azurite.service
```

### Connection refused

**Cause:** The container is not running, or Docker is down.

**Fix:**

```bash
sudo systemctl status docker
sudo systemctl status azurite.service
docker ps -a --filter name=azurite
sudo journalctl -xeu azurite.service
```

### Container is running but reports `unhealthy`

**Cause:** One of the three ports is not accepting connections, usually because Azurite failed to read its data directory.

**Fix:** Check the logs, then recreate the container:

```bash
docker logs azurite
sudo systemctl restart azurite.service
```

### `permission denied` when the script calls Docker

**Cause:** The `azurite` user is not in the `docker` group, or the group change has not taken effect.

**Fix:**

```bash
id azurite                       # should list docker
sudo usermod -aG docker azurite
sudo systemctl restart azurite.service
```

---

## Security Notes

- This setup is for **local development only**.
- The account name and key are Azurite's public defaults. Never use them for real data, and don't reuse them anywhere else.
- Endpoints use plain HTTP with no TLS.
- With host networking, Azurite listens on the host's interfaces. Block ports 10000–10002 at the firewall if the machine is on a shared network.

---

## Uninstall

There is no `uninstall.sh` for Azurite. Remove it manually:

```bash
sudo systemctl disable --now azurite.service
sudo rm /etc/systemd/system/azurite.service
sudo systemctl daemon-reload
docker rm -f azurite
sudo loginctl disable-linger azurite
sudo userdel -r azurite   # also deletes /opt/azurite and all stored data
```

---

## Additional Resources

- [Azurite on GitHub](https://github.com/Azure/Azurite)
- [Use Azurite for local Azure Storage development](https://learn.microsoft.com/azure/storage/common/storage-use-azurite)
- [Azure Storage documentation](https://learn.microsoft.com/azure/storage/)
- [Azure Storage Explorer](https://azure.microsoft.com/products/storage/storage-explorer/)
