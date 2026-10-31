# <Service Name>

<!--
Template A: container service README.

How to use this template:
- Copy this file to <service>/README.md and replace every <placeholder>.
- Keep every section marked "Required", in this order, with these exact headings.
- Include an "Optional" section only when it applies; delete it otherwise and
  remove it from the Table of Contents.
- Service-specific sections (e.g. "CI/CD with Gitea Actions") go between
  "Usage Examples" and "Running Without systemd", as their own H2.
- Every value (ports, paths, users, image) must match the scripts in the
  directory. Note: install.sh sets the service user's home to /opt/<service>,
  so data lives under /opt/<service>/.local/share/<service>-data.
- Copy the finished README to wiki/<Page-Name>.md so the two stay identical.
- Delete these comments.
-->

<One or two sentences: what the service is and what it gives a developer locally.>

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Files](#files)
4. [Installation](#installation)
5. [Managing the Service](#managing-the-service)
6. [Management Script Commands](#management-script-commands)
7. [Connecting to <Service Name>](#connecting-to-service-name)
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

<!-- Required. Reference: facts only, one row per property. -->

| Property | Value |
|----------|-------|
| Container image | `<registry/image:tag>` |
| Container name | `<container-name>` |
| Service user | `<service-user>` |
| systemd unit | `<service>.service` |
| Network mode | `host` |
| <Endpoint name> | `<http://127.0.0.1:port>` |
| Data path | `/opt/<service>/.local/share/<service>-data` |
| Upstream | <https://project-homepage> |

---

## Prerequisites

<!-- Required. -->

- Docker installed and running
- Root or sudo access
- Ports <list> free on the host

---

## Files

<!-- Required. One row per file in the directory. -->

| File | Purpose | Installed to |
|------|---------|--------------|
| `<service>.sh` | Container management script (`start`, `stop`, `status`, `health`) | `/opt/<service>/<service>.sh` |
| `<service>.service` | systemd unit file | `/etc/systemd/system/<service>.service` |
| `install.sh` | One-time installation script (requires root) | Not installed |
| `uninstall.sh` | Removes the service, user, and data (requires root) | Not installed |
| `README.md` | This document | Not installed |

---

## Installation

<!-- Required. How-to: numbered steps. -->

1. Run the install script from this directory:

   ```bash
   cd /path/to/Data/<service>
   sudo ./install.sh
   ```

2. Start the service for the first time:

   ```bash
   sudo systemctl start <service>.service
   ```

3. Confirm it is healthy:

   ```bash
   sudo -u <service-user> /opt/<service>/<service>.sh health
   ```

**What `install.sh` does:**

1. Creates the `<service-user>` system user with home directory `/opt/<service>`
2. Adds `<service-user>` to the `docker` group
3. Enables user lingering (`loginctl enable-linger <service-user>`)
4. Copies `<service>.sh` to `/opt/<service>/` and makes it executable
5. Copies `<service>.service` to `/etc/systemd/system/`
6. Reloads systemd and enables the service to start on boot

---

## Managing the Service

<!-- Required. Keep this block identical across services apart from the name. -->

```bash
# Start
sudo systemctl start <service>.service

# Stop
sudo systemctl stop <service>.service

# Check status
sudo systemctl status <service>.service

# Enable auto-start on boot (done by install.sh)
sudo systemctl enable <service>.service

# Disable auto-start
sudo systemctl disable <service>.service

# View logs
sudo journalctl -xeu <service>.service

# Follow logs in real time
sudo journalctl -fu <service>.service
```

---

## Management Script Commands

<!-- Required. Reference. -->

Run the management script directly as the service user:

```bash
sudo -u <service-user> /opt/<service>/<service>.sh <command>
```

| Command | Action |
|---------|--------|
| `start` | Removes any existing `<container-name>` container and starts a new one |
| `stop` | Stops and removes the container |
| `status` | Shows the container's state (`docker ps -a`) |
| `health` | <What the health check tests> |

---

## Connecting to <Service Name>

<!-- Required. Reference: everything a client needs to connect. -->

| Field | Value |
|-------|-------|
| Host | `127.0.0.1` |
| Port | `<port>` |
| Username | `<user>` |
| Password | `<password>` |

**Connection string:**

```text
<connection string>
```

---

## Usage Examples

<!-- Optional. How-to: short, runnable snippets (curl, .NET, Python). -->

### curl

```bash
<command>
```

### .NET

```csharp
<code>
```

### Python

```python
<code>
```

---

## Running Without systemd

<!-- Optional. A one-off docker run (or compose) for quick tests or Windows. -->

```bash
docker run -d \
  --name <container-name> \
  -p <port>:<port> \
  -v $HOME/<service>-data:<container-path> \
  <registry/image:tag>
```

---

## Data Persistence and Backups

<!-- Required. -->

Data is stored on the host at `/opt/<service>/.local/share/<service>-data` and mounted into the container at `<container-path>`. It survives container restarts and re-creation.

**Back up:**

```bash
<backup command>
```

**Restore:**

```bash
<restore command>
```

---

## Health Checks

<!-- Required. How-to. State the expected result. -->

```bash
# Check service status
sudo systemctl status <service>.service

# Run the built-in health check
sudo -u <service-user> /opt/<service>/<service>.sh health

# Check the container's own health status
docker inspect --format '{{.State.Health.Status}}' <container-name>

# Test the endpoint directly
<curl or client command>

# View container logs
docker logs <container-name>
```

Expected: <what a healthy result looks like>.

---

## Troubleshooting

<!-- Required. One H3 per symptom, then cause and fix. -->

### <Symptom>

**Cause:** <why it happens>

**Fix:**

```bash
<commands>
```

---

## Security Notes

<!-- Required. -->

- This setup is for **local development only**.
- <Default credentials and where they are set>
- <Network exposure: host networking binds to all interfaces unless configured otherwise>

---

## Uninstall

<!-- Required. Use uninstall.sh if it exists; otherwise list the manual steps. -->

```bash
sudo systemctl disable --now <service>.service
sudo rm /etc/systemd/system/<service>.service
sudo systemctl daemon-reload
docker rm -f <container-name>
sudo loginctl disable-linger <service-user>
sudo userdel -r <service-user>   # also deletes /opt/<service> and all data
```

---

## Additional Resources

<!-- Required. -->

- [<Project documentation>](<url>)
- [<Image on registry>](<url>)
