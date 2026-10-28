# Qdrant

Qdrant is a high-performance, open-source vector database and similarity search engine. It provides production-ready service with a convenient API to store, search, and manage vectors with an additional payload. Qdrant is designed to support extended filtering, making it useful for neural network or semantic-based matching, faceted search, and other applications.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Files](#files)
4. [Installation](#installation)
5. [Managing the Service](#managing-the-service)
6. [Management Script Commands](#management-script-commands)
7. [Running Manually with Docker](#running-manually-with-docker)
8. [Connection Details](#connection-details)
9. [Testing with Code](#testing-with-code)
10. [Health Checks](#health-checks)
11. [Troubleshooting](#troubleshooting)
12. [Additional Resources](#additional-resources)

---

## Overview

| Property | Value |
|----------|-------|
| Container image | `qdrant/qdrant:latest` |
| Container name | `qdrant` |
| Service user | `qdrant` |
| REST API | `http://127.0.0.1:6333` |
| gRPC API | `http://127.0.0.1:6334` |
| Web UI | `http://127.0.0.1:6333/dashboard` |
| Data path | `/home/qdrant/.local/share/qdrant-data` |

---

## Prerequisites

- Docker installed and running on your system
- Root / sudo access (for systemd installation)

---

## Files

| File | Description |
|------|-------------|
| `qdrant.sh` | Container management script (start/stop/status/health) |
| `qdrant.service` | systemd service unit file |
| `install.sh` | One-time installation script (requires root) |
| `README.md` | This file |

---

## Installation

Run the install script once to set up the service:

```bash
cd /path/to/Data/qdrant
sudo ./install.sh
```

**What the install script does:**

1. Creates a `qdrant` system user with home directory at `/opt/qdrant`
2. Adds the `qdrant` user to the `docker` group
3. Enables user lingering (`loginctl enable-linger qdrant`)
4. Copies `qdrant.sh` to `/opt/qdrant/` with execute permissions
5. Copies `qdrant.service` to `/etc/systemd/system/`
6. Runs `systemctl daemon-reload` and enables the service to start on boot

After installation, start the service manually for the first time:

```bash
sudo systemctl start qdrant.service
```

---

## Managing the Service

```bash
# Start
sudo systemctl start qdrant.service

# Stop
sudo systemctl stop qdrant.service

# Check status
sudo systemctl status qdrant.service

# Enable auto-start on boot (done by install script)
sudo systemctl enable qdrant.service

# Disable auto-start
sudo systemctl disable qdrant.service

# View logs
sudo journalctl -xeu qdrant.service

# Follow real-time logs
sudo journalctl -fu qdrant.service
```

---

## Management Script Commands

The `qdrant.sh` script can also be called directly as the `qdrant` user:

```bash
sudo -u qdrant /opt/qdrant/qdrant.sh start
sudo -u qdrant /opt/qdrant/qdrant.sh stop
sudo -u qdrant /opt/qdrant/qdrant.sh status
sudo -u qdrant /opt/qdrant/qdrant.sh health
```

The health check queries the REST API `/healthz` endpoint to confirm the service is responding.

---

## Running Manually with Docker

Use these commands when running without systemd (e.g., on Windows 11 or for a quick test):

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

| Port | Service |
|------|---------|
| 6333 | REST API and Web UI |
| 6334 | gRPC API |

---

## Connection Details

| Endpoint | URL |
|----------|-----|
| REST API | `http://127.0.0.1:6333` |
| gRPC API | `http://127.0.0.1:6334` |
| Web UI (dashboard) | `http://127.0.0.1:6333/dashboard` |
| Health check | `http://127.0.0.1:6333/healthz` |
| Collections list | `http://127.0.0.1:6333/collections` |

Qdrant does not require authentication by default. For production use, configure an API key via the `QDRANT__SERVICE__API_KEY` environment variable.

---

## Testing with Code

### Python Example

Install the client:

```bash
pip install qdrant-client
```

```python
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct

client = QdrantClient(host="127.0.0.1", port=6333)

# Create a collection
client.create_collection(
    collection_name="my_collection",
    vectors_config=VectorParams(size=4, distance=Distance.COSINE),
)

# Insert vectors
client.upsert(
    collection_name="my_collection",
    points=[
        PointStruct(id=1, vector=[0.1, 0.2, 0.3, 0.4], payload={"label": "first"}),
        PointStruct(id=2, vector=[0.5, 0.6, 0.7, 0.8], payload={"label": "second"}),
    ],
)

# Search for nearest neighbors
results = client.search(
    collection_name="my_collection",
    query_vector=[0.1, 0.2, 0.3, 0.4],
    limit=3,
)
print(results)
```

### .NET Example

Install the NuGet package:

```bash
dotnet add package Qdrant.Client
```

```csharp
using Qdrant.Client;
using Qdrant.Client.Grpc;

var client = new QdrantClient("127.0.0.1", 6334);

// Create a collection
await client.CreateCollectionAsync("my_collection", new VectorParams
{
    Size = 4,
    Distance = Distance.Cosine,
});

// Insert vectors
await client.UpsertAsync("my_collection", new[]
{
    new PointStruct
    {
        Id = 1,
        Vectors = new[] { 0.1f, 0.2f, 0.3f, 0.4f },
        Payload = { ["label"] = "first" },
    },
});

// Search for nearest neighbors
var results = await client.SearchAsync("my_collection",
    new[] { 0.1f, 0.2f, 0.3f, 0.4f }, limit: 3);
Console.WriteLine($"Found {results.Count} results");
```

### REST API Example (curl)

```bash
# Create a collection
curl -X PUT http://127.0.0.1:6333/collections/my_collection \
  -H "Content-Type: application/json" \
  -d '{
    "vectors": {
      "size": 4,
      "distance": "Cosine"
    }
  }'

# Insert vectors
curl -X PUT http://127.0.0.1:6333/collections/my_collection/points \
  -H "Content-Type: application/json" \
  -d '{
    "points": [
      {"id": 1, "vector": [0.1, 0.2, 0.3, 0.4], "payload": {"label": "first"}},
      {"id": 2, "vector": [0.5, 0.6, 0.7, 0.8], "payload": {"label": "second"}}
    ]
  }'

# Search for nearest neighbors
curl -X POST http://127.0.0.1:6333/collections/my_collection/points/search \
  -H "Content-Type: application/json" \
  -d '{
    "vector": [0.1, 0.2, 0.3, 0.4],
    "limit": 3
  }'
```

---

## Health Checks

```bash
# Check service status
sudo systemctl status qdrant.service

# Run the built-in health check
sudo -u qdrant /opt/qdrant/qdrant.sh health

# Test the REST API health endpoint directly
curl -s http://127.0.0.1:6333/healthz

# List all collections
curl -s http://127.0.0.1:6333/collections

# View container logs
docker logs qdrant
```

Expected: `{"title":"qdrant - vector search engine","version":"..."}` or `{}` from the health endpoint (both indicate the service is running).

---

## Troubleshooting

**Port already in use** — map to alternate host ports:

```bash
docker run -d \
  --name qdrant \
  -p 6433:6333 \
  -p 6434:6334 \
  qdrant/qdrant:latest
```

Update your client connection to use the new ports.

**Connection refused:**
- Verify the container is running: `docker ps`
- Check port mappings: `docker port qdrant`
- Ensure Docker is running: `sudo systemctl status docker`
- Check container logs: `docker logs qdrant`

**Data persistence:**
- Data is stored at `$HOME/.local/share/qdrant-data` (under the `qdrant` service user's home)
- To back up collections, stop the service and copy that directory
- To reset all data, stop the service, remove the directory, and restart

**Snapshots:**
Qdrant supports collection snapshots via the REST API:

```bash
# Create a snapshot
curl -X POST http://127.0.0.1:6333/collections/my_collection/snapshots

# List snapshots
curl http://127.0.0.1:6333/collections/my_collection/snapshots
```

---

## Additional Resources

- [Qdrant GitHub Repository](https://github.com/qdrant/qdrant)
- [Qdrant Documentation](https://qdrant.tech/documentation/)
- [Qdrant REST API Reference](https://api.qdrant.tech/)
- [Qdrant Python Client](https://github.com/qdrant/qdrant-client)
- [Qdrant .NET Client](https://github.com/qdrant/qdrant-dotnet)
