# Qdrant

Qdrant is an open-source vector database and similarity search engine. It stores vectors with a JSON payload and supports filtered nearest-neighbor search, which makes it useful for semantic search, recommendations, and retrieval-augmented generation (RAG).

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Files](#files)
4. [Installation](#installation)
5. [Managing the Service](#managing-the-service)
6. [Management Script Commands](#management-script-commands)
7. [Connecting to Qdrant](#connecting-to-qdrant)
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
| Container image | `qdrant/qdrant:latest` |
| Container name | `qdrant` |
| Service user | `qdrant` |
| systemd unit | `qdrant.service` |
| Network mode | `host` |
| REST API | `http://127.0.0.1:6333` |
| gRPC API | `127.0.0.1:6334` |
| Web UI | `http://127.0.0.1:6333/dashboard` |
| Data path | `/opt/qdrant/.local/share/qdrant-data` |
| Upstream | <https://qdrant.tech> |

---

## Prerequisites

- Docker installed and running
- Root or sudo access
- Ports 6333 and 6334 free on the host

---

## Files

| File | Purpose | Installed to |
|------|---------|--------------|
| `qdrant.sh` | Container management script (`start`, `stop`, `status`, `health`) | `/opt/qdrant/qdrant.sh` |
| `qdrant.service` | systemd unit file | `/etc/systemd/system/qdrant.service` |
| `install.sh` | One-time installation script (requires root) | Not installed |
| `uninstall.sh` | Removes the service, and optionally its data and user (requires root) | Not installed |
| `README.md` | This document | Not installed |

---

## Installation

1. Run the install script from this directory:

   ```bash
   cd /path/to/Data/qdrant
   sudo ./install.sh
   ```

2. Start the service for the first time:

   ```bash
   sudo systemctl start qdrant.service
   ```

3. Confirm it is healthy:

   ```bash
   sudo -u qdrant /opt/qdrant/qdrant.sh health
   ```

**What `install.sh` does:**

1. Creates the `qdrant` system user with home directory `/opt/qdrant`
2. Adds `qdrant` to the `docker` group
3. Enables user lingering (`loginctl enable-linger qdrant`)
4. Copies `qdrant.sh` to `/opt/qdrant/` and makes it executable
5. Copies `qdrant.service` to `/etc/systemd/system/`
6. Reloads systemd and enables the service to start on boot

---

## Managing the Service

```bash
# Start
sudo systemctl start qdrant.service

# Stop
sudo systemctl stop qdrant.service

# Check status
sudo systemctl status qdrant.service

# Enable auto-start on boot (done by install.sh)
sudo systemctl enable qdrant.service

# Disable auto-start
sudo systemctl disable qdrant.service

# View logs
sudo journalctl -xeu qdrant.service

# Follow logs in real time
sudo journalctl -fu qdrant.service
```

---

## Management Script Commands

Run the management script directly as the service user:

```bash
sudo -u qdrant /opt/qdrant/qdrant.sh <command>
```

| Command | Action |
|---------|--------|
| `start` | Removes any existing `qdrant` container and starts a new one |
| `stop` | Stops and removes the container |
| `status` | Shows the container's state (`docker ps -a`) |
| `health` | Confirms the container is running and the REST API `/healthz` endpoint responds |

---

## Connecting to Qdrant

| Endpoint | Address |
|----------|---------|
| REST API | `http://127.0.0.1:6333` |
| gRPC API | `127.0.0.1:6334` |
| Web UI | `http://127.0.0.1:6333/dashboard` |
| Health | `http://127.0.0.1:6333/healthz` |
| Collections | `http://127.0.0.1:6333/collections` |

No API key is configured, so clients connect without authentication. The Python client uses REST (6333) by default; the .NET client uses gRPC (6334).

---

## Usage Examples

Each example creates a 4-dimensional collection, inserts two points, and finds the nearest neighbors.

### curl

```bash
# Create a collection
curl -X PUT http://127.0.0.1:6333/collections/my_collection \
  -H "Content-Type: application/json" \
  -d '{"vectors": {"size": 4, "distance": "Cosine"}}'

# Insert points
curl -X PUT "http://127.0.0.1:6333/collections/my_collection/points?wait=true" \
  -H "Content-Type: application/json" \
  -d '{
    "points": [
      {"id": 1, "vector": [0.1, 0.2, 0.3, 0.4], "payload": {"label": "first"}},
      {"id": 2, "vector": [0.5, 0.6, 0.7, 0.8], "payload": {"label": "second"}}
    ]
  }'

# Query for nearest neighbors
curl -X POST http://127.0.0.1:6333/collections/my_collection/points/query \
  -H "Content-Type: application/json" \
  -d '{"query": [0.1, 0.2, 0.3, 0.4], "limit": 3, "with_payload": true}'
```

### Python

Requires `pip install qdrant-client`.

```python
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, PointStruct, VectorParams

client = QdrantClient(host="127.0.0.1", port=6333)

client.create_collection(
    collection_name="my_collection",
    vectors_config=VectorParams(size=4, distance=Distance.COSINE),
)

client.upsert(
    collection_name="my_collection",
    points=[
        PointStruct(id=1, vector=[0.1, 0.2, 0.3, 0.4], payload={"label": "first"}),
        PointStruct(id=2, vector=[0.5, 0.6, 0.7, 0.8], payload={"label": "second"}),
    ],
)

results = client.query_points(
    collection_name="my_collection",
    query=[0.1, 0.2, 0.3, 0.4],
    limit=3,
)
print(results.points)
```

### .NET

Requires `dotnet add package Qdrant.Client`.

```csharp
using Qdrant.Client;
using Qdrant.Client.Grpc;

var client = new QdrantClient("127.0.0.1", 6334);

await client.CreateCollectionAsync("my_collection", new VectorParams
{
    Size = 4,
    Distance = Distance.Cosine,
});

await client.UpsertAsync("my_collection", new[]
{
    new PointStruct
    {
        Id = 1,
        Vectors = new[] { 0.1f, 0.2f, 0.3f, 0.4f },
        Payload = { ["label"] = "first" },
    },
    new PointStruct
    {
        Id = 2,
        Vectors = new[] { 0.5f, 0.6f, 0.7f, 0.8f },
        Payload = { ["label"] = "second" },
    },
});

var results = await client.SearchAsync("my_collection",
    new[] { 0.1f, 0.2f, 0.3f, 0.4f }, limit: 3);
Console.WriteLine($"Found {results.Count} results");
```

---

## Running Without systemd

For a quick test, or on a machine without systemd (such as Windows 11), run the container directly.

**Linux / macOS:**

```bash
docker run -d \
  --name qdrant \
  -p 6333:6333 \
  -p 6334:6334 \
  -v $HOME/qdrant-data:/qdrant/storage \
  qdrant/qdrant:latest
```

**Windows 11 (PowerShell):**

```powershell
docker run -d `
  --name qdrant `
  -p 6333:6333 `
  -p 6334:6334 `
  -v ${HOME}/qdrant-data:/qdrant/storage `
  qdrant/qdrant:latest
```

---

## Data Persistence and Backups

Data is stored on the host at `/opt/qdrant/.local/share/qdrant-data` and mounted into the container at `/qdrant/storage`. It survives container restarts and re-creation.

**Back up everything (service stopped):**

```bash
sudo systemctl stop qdrant.service
sudo tar -czf qdrant-backup-$(date +%F).tar.gz -C /opt/qdrant/.local/share qdrant-data
sudo systemctl start qdrant.service
```

**Restore everything:**

```bash
sudo systemctl stop qdrant.service
sudo rm -rf /opt/qdrant/.local/share/qdrant-data
sudo tar -xzf qdrant-backup-YYYY-MM-DD.tar.gz -C /opt/qdrant/.local/share
sudo systemctl start qdrant.service
```

**Snapshot one collection (service running):** snapshots are written to `snapshots/` inside the data directory.

```bash
# Create a snapshot
curl -X POST http://127.0.0.1:6333/collections/my_collection/snapshots

# List snapshots
curl http://127.0.0.1:6333/collections/my_collection/snapshots
```

---

## Health Checks

```bash
# Check service status
sudo systemctl status qdrant.service

# Run the built-in health check
sudo -u qdrant /opt/qdrant/qdrant.sh health

# Check the container's own health status
docker inspect --format '{{.State.Health.Status}}' qdrant

# Test the REST API directly
curl -s http://127.0.0.1:6333/healthz
curl -s http://127.0.0.1:6333/

# View container logs
docker logs qdrant
```

Expected:

- The built-in check prints `Qdrant is healthy and accepting connections on port 6333 (REST) and 6334 (gRPC)`.
- `docker inspect` prints `healthy`. The container's health check opens a TCP connection to port 6333, because the image does not include `curl`.
- `/healthz` returns `healthz check passed`, and `/` returns JSON with the Qdrant version.

---

## Troubleshooting

### Service fails to start: port already in use

**Cause:** Another process is listening on 6333 or 6334. The service uses host networking, so it cannot remap ports.

**Fix:**

```bash
sudo ss -ltnp | grep -E ':633[34]\b'
```

### Connection refused

**Cause:** The container is not running, or Docker is down.

**Fix:**

```bash
sudo systemctl status docker
sudo systemctl status qdrant.service
docker logs qdrant
```

### Container reports `unhealthy` but the API works

**Cause:** An older `qdrant.sh` is installed. Its health check called `curl`, which the Qdrant image does not include.

**Fix:** Reinstall the current script and restart:

```bash
sudo ./install.sh
sudo systemctl restart qdrant.service
```

### Python client raises `AttributeError: 'QdrantClient' object has no attribute 'search'`

**Cause:** Recent `qdrant-client` releases replaced `search` with `query_points`.

**Fix:** Use `query_points` as in [Usage Examples](#usage-examples).

### Reset all data

**Fix:**

```bash
sudo systemctl stop qdrant.service
sudo rm -rf /opt/qdrant/.local/share/qdrant-data
sudo systemctl start qdrant.service
```

---

## Security Notes

- This setup is for **local development only**.
- No API key is set: anyone who can reach ports 6333 or 6334 can read and change every collection. To require a key, add `-e QDRANT__SERVICE__API_KEY=<key>` to the `docker run` command in `qdrant.sh` and reinstall.
- With host networking, Qdrant listens on the host's interfaces. Block 6333 and 6334 at the firewall if the machine is on a shared network.

---

## Uninstall

Run the uninstall script from this directory:

```bash
cd /path/to/Data/qdrant
sudo ./uninstall.sh [--purge-data] [--remove-user]
```

| Option | Effect |
|--------|--------|
| *(none)* | Asks whether to delete the data directory |
| `--purge-data` | Deletes the data directory without asking |
| `--remove-user` | Also removes the `qdrant` user and disables lingering |

The script always stops and disables the service, removes the container, the unit file, and `/opt/qdrant/qdrant.sh`. It removes `/opt/qdrant` only when data is purged.

---

## Additional Resources

- [Qdrant documentation](https://qdrant.tech/documentation/)
- [Qdrant REST API reference](https://api.qdrant.tech/)
- [Qdrant on GitHub](https://github.com/qdrant/qdrant)
- [Python client](https://github.com/qdrant/qdrant-client)
- [.NET client](https://github.com/qdrant/qdrant-dotnet)
