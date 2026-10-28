# Qdrant

Qdrant is a high-performance vector database and similarity search engine for storing, searching, and managing high-dimensional vectors with extended filtering support.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Managing the Service](#managing-the-service)
5. [Management Script Commands](#management-script-commands)
6. [Running Manually with Docker](#running-manually-with-docker)
7. [Connection Details](#connection-details)
8. [Testing with Code](#testing-with-code)
9. [Health Checks](#health-checks)
10. [Troubleshooting](#troubleshooting)
11. [Additional Resources](#additional-resources)

---

## Overview

| Property | Value |
|----------|-------|
| Container image | `qdrant/qdrant` |
| Container name | `qdrant` |
| Service user | `qdrant` |
| REST API | `http://127.0.0.1:6333` |
| gRPC API | `http://127.0.0.1:6334` |
| Web UI | `http://127.0.0.1:6333/dashboard` |
| Health endpoint | `http://127.0.0.1:6333/healthz` |
| Data path | `/home/qdrant/.local/share/qdrant-data` |

---

## Prerequisites

- Docker CLI installed on your system
- Root / sudo access (for systemd installation)

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
# Start the container
sudo -u qdrant /opt/qdrant/qdrant.sh start

# Stop the container
sudo -u qdrant /opt/qdrant/qdrant.sh stop

# Check container status
sudo -u qdrant /opt/qdrant/qdrant.sh status

# Run health check (tests REST API endpoint)
sudo -u qdrant /opt/qdrant/qdrant.sh health
```

---

## Running Manually with Docker

Use these commands when running without systemd (e.g., on Windows 11 or for a quick test):

**Linux / macOS:**

```bash
docker run -d \
  --name qdrant \
  -p 6333:6333 \
  -p 6334:6334 \
  qdrant/qdrant
```

**With data persistence:**

```bash
docker run -d \
  --name qdrant \
  -p 6333:6333 \
  -p 6334:6334 \
  -v $HOME/qdrant-data:/qdrant/storage \
  qdrant/qdrant
```

**Windows 11 (PowerShell):**

```powershell
docker run -d `
  --name qdrant `
  -p 6333:6333 `
  -p 6334:6334 `
  qdrant/qdrant
```

**Port mappings:**

| Port | Service |
|------|---------|
| 6333 | REST API |
| 6334 | gRPC API |

---

## Connection Details

| Endpoint | URL |
|----------|-----|
| REST API | `http://127.0.0.1:6333` |
| gRPC API | `http://127.0.0.1:6334` |
| Web UI | `http://127.0.0.1:6333/dashboard` |
| Health | `http://127.0.0.1:6333/healthz` |

---

## Testing with Code

### Python Example

```bash
pip install qdrant-client
```

```python
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams

client = QdrantClient(url="http://localhost:6333")

# Create a collection
client.create_collection(
    collection_name="test_collection",
    vectors_config=VectorParams(size=4, distance=Distance.DOT),
)
print("Collection created successfully!")

# List collections
collections = client.get_collections()
print(collections)
```

### curl Example

```bash
# Create a collection
curl -X PUT http://127.0.0.1:6333/collections/test_collection \
  -H "Content-Type: application/json" \
  -d '{"vectors": {"size": 4, "distance": "Dot"}}'

# List collections
curl http://127.0.0.1:6333/collections
```

---

## Health Checks

```bash
# Verify the container is running
docker ps | grep qdrant

# Test the REST API health endpoint
curl http://127.0.0.1:6333/healthz

# View container logs
docker logs qdrant
```

Expected: JSON response with `title` and `version` fields from the health endpoint.

---

## Troubleshooting

### Port already in use

Map to alternate host ports:

```bash
docker run -d \
  --name qdrant \
  -p 6433:6333 \
  -p 6434:6334 \
  qdrant/qdrant
```

Update your client connection URL to `http://127.0.0.1:6433`.

### Connection refused

- Verify the container is running: `docker ps`
- Check port mappings: `docker port qdrant`
- Verify Docker is running: `sudo systemctl status docker`

---

## Additional Resources

- [Qdrant Docker Hub](https://hub.docker.com/r/qdrant/qdrant)
- [Qdrant Documentation](https://qdrant.tech/documentation/)
- [Qdrant GitHub Repository](https://github.com/qdrant/qdrant)
- [Qdrant Python Client](https://github.com/qdrant/qdrant-client)
