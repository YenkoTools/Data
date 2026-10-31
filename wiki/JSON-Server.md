# JSON Server

JSON Server turns a JSON file into a full fake REST API with no code. This directory runs three independent instances as systemd services on ports 3010, 3011, and 3012, each with its own data file, for front-end prototyping and API testing.

Unlike the other services in this repository, JSON Server runs directly on Node.js through `npx`, not in a Docker container, and has no install or management script.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Files](#files)
4. [Installation](#installation)
5. [Managing the Service](#managing-the-service)
6. [Management Script Commands](#management-script-commands)
7. [Connecting to JSON Server](#connecting-to-json-server)
8. [Usage Examples](#usage-examples)
9. [Data Persistence and Backups](#data-persistence-and-backups)
10. [Health Checks](#health-checks)
11. [Troubleshooting](#troubleshooting)
12. [Security Notes](#security-notes)
13. [Uninstall](#uninstall)
14. [Additional Resources](#additional-resources)

---

## Overview

| Property | Value |
|----------|-------|
| Runtime | Node.js, `npx json-server` (latest from npm; currently 1.0 beta) |
| Service user | `jsonserver` |
| systemd units | `json-server-3010.service`, `json-server-3011.service`, `json-server-3012.service` |
| Instance on 3010 | `http://localhost:3010`, serves `/opt/json-server/db1.json` |
| Instance on 3011 | `http://localhost:3011`, serves `/opt/json-server/db2.json` |
| Instance on 3012 | `http://localhost:3012`, serves `/opt/json-server/db3.json` |
| Data path | `/opt/json-server` |
| Upstream | <https://github.com/typicode/json-server> |

---

## Prerequisites

- Node.js and npm installed, with `npx` at `/usr/bin/npx` (the path the unit files use)
- Root or sudo access
- Internet access on first start, so `npx` can download `json-server`
- Ports 3010, 3011, and 3012 free on the host

Install Node.js on Debian:

```bash
sudo apt update && sudo apt install -y nodejs npm
```

---

## Files

| File | Purpose | Installed to |
|------|---------|--------------|
| `db.json` | Seed data (a `users` collection) copied to each instance's data file | `/opt/json-server/db1.json`, `db2.json`, `db3.json` |
| `json-server-3010.service` | systemd unit for the port 3010 instance | `/etc/systemd/system/json-server-3010.service` |
| `json-server-3011.service` | systemd unit for the port 3011 instance | `/etc/systemd/system/json-server-3011.service` |
| `json-server-3012.service` | systemd unit for the port 3012 instance | `/etc/systemd/system/json-server-3012.service` |
| `README.md` | This document | Not installed |

---

## Installation

There is no `install.sh`; run these steps from this directory.

1. Create the service user and data directory:

   ```bash
   sudo useradd --system --home /opt/json-server --shell /usr/sbin/nologin jsonserver
   sudo mkdir -p /opt/json-server
   ```

2. Copy the seed data to one file per instance:

   ```bash
   for n in 1 2 3; do sudo cp db.json /opt/json-server/db$n.json; done
   sudo chown -R jsonserver:jsonserver /opt/json-server
   ```

3. Install and enable the units:

   ```bash
   sudo cp json-server-301[0-2].service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable --now json-server-3010.service json-server-3011.service json-server-3012.service
   ```

4. Confirm all three respond (see [Health Checks](#health-checks)).

---

## Managing the Service

Each instance is a separate unit. The examples use 3010; replace it with 3011 or 3012 for the others.

```bash
# Start
sudo systemctl start json-server-3010.service

# Stop
sudo systemctl stop json-server-3010.service

# Check status
sudo systemctl status json-server-3010.service

# Enable auto-start on boot
sudo systemctl enable json-server-3010.service

# Disable auto-start
sudo systemctl disable json-server-3010.service

# View logs
sudo journalctl -xeu json-server-3010.service

# Follow logs in real time
sudo journalctl -fu json-server-3010.service
```

To act on all three at once, use a glob:

```bash
sudo systemctl restart 'json-server-301*.service'
```

---

## Management Script Commands

JSON Server has no management script. Use the `systemctl` commands above.

The units run `npx json-server` directly with `Restart=always`, so systemd restarts an instance if it exits.

---

## Connecting to JSON Server

Every top-level key in an instance's data file becomes a REST resource. With the seed data, each instance serves `/users`.

| Method | URL | Action |
|--------|-----|--------|
| GET | `http://localhost:3010/users` | List all users |
| GET | `http://localhost:3010/users/1` | Get one user by `id` |
| POST | `http://localhost:3010/users` | Create a user |
| PUT | `http://localhost:3010/users/1` | Replace a user |
| PATCH | `http://localhost:3010/users/1` | Update fields of a user |
| DELETE | `http://localhost:3010/users/1` | Delete a user |

Query parameters (json-server 1.0 syntax):

| Parameter | Example | Effect |
|-----------|---------|--------|
| Field match | `?username=amelyan` | Filter by exact value |
| `_sort` | `?_sort=name`, `?_sort=-name` | Sort ascending, or descending with `-` |
| `_page`, `_per_page` | `?_page=1&_per_page=2` | Paginate |
| `_start`, `_end` | `?_start=0&_end=2` | Slice |
| `_embed` | `?_embed=posts` | Include related resources |

---

## Usage Examples

### curl

```bash
# List all users
curl http://localhost:3010/users

# Get a single user
curl http://localhost:3010/users/1

# Create a user
curl -X POST http://localhost:3010/users \
  -H "Content-Type: application/json" \
  -d '{"id":"10","name":"Zoey Miller","username":"zoey","email":"zoey@mail.com"}'

# Update one field
curl -X PATCH http://localhost:3010/users/3 \
  -H "Content-Type: application/json" \
  -d '{"email":"newemail@example.com"}'

# Delete a user
curl -X DELETE http://localhost:3010/users/3

# Sort by name and take the first page of two
curl "http://localhost:3010/users?_sort=name&_page=1&_per_page=2"
```

---

## Data Persistence and Backups

Each instance reads and **writes** its own file: POST, PUT, PATCH, and DELETE requests change `/opt/json-server/db1.json`, `db2.json`, or `db3.json` on disk. Changes survive restarts, and the three instances never share data.

**Back up:**

```bash
sudo tar -czf json-server-backup-$(date +%F).tar.gz -C /opt json-server
```

**Reset an instance to the seed data** (here, port 3010):

```bash
sudo systemctl stop json-server-3010.service
sudo install -o jsonserver -g jsonserver -m 644 db.json /opt/json-server/db1.json
sudo systemctl start json-server-3010.service
```

---

## Health Checks

```bash
# Check service status for all three
systemctl status 'json-server-301*.service' --no-pager

# Test each instance
for port in 3010 3011 3012; do
  echo -n "Port $port: "
  curl -s -o /dev/null -w '%{http_code}\n' http://localhost:$port/users
done
```

Expected: each unit is `active (running)` and each port prints `200`.

---

## Troubleshooting

### Service fails to start: `npx` not found

**Cause:** Node.js is not installed system-wide, or `npx` is not at `/usr/bin/npx`. A per-user Node install such as nvm is not visible to the `jsonserver` user.

**Fix:** Install the Debian packages, or change `ExecStart` in the unit files to the real `npx` path:

```bash
sudo apt install -y nodejs npm
ls -l /usr/bin/npx
```

### Service fails to start: data file missing

**Cause:** The instance's `dbN.json` file was not created.

**Fix:**

```bash
ls -l /opt/json-server/
sudo journalctl -xeu json-server-3010.service
```

Recreate the file as shown in [Data Persistence and Backups](#data-persistence-and-backups).

### Port already in use

**Cause:** Another process holds 3010, 3011, or 3012.

**Fix:**

```bash
sudo ss -ltnp | grep -E ':301[0-2]\b'
```

### Pagination or sorting parameters are ignored

**Cause:** `_limit` and `_order` are json-server 0.x parameters. `npx` installs the latest release, which is 1.0 and uses `_per_page` and `_sort=-field`.

**Fix:** Use the parameters in [Connecting to JSON Server](#connecting-to-json-server).

---

## Security Notes

- This setup is for **local development only**.
- There is no authentication: anyone who can reach ports 3010–3012 can read and change the data.
- `npx` downloads the latest `json-server` on first start, so the version can change without warning. Pin it (for example `npx json-server@1.0.0-beta.15`) in the unit files if you need a fixed version.
- The servers bind to the host's interfaces. Block ports 3010–3012 at the firewall if the machine is on a shared network.

---

## Uninstall

```bash
sudo systemctl disable --now json-server-3010.service json-server-3011.service json-server-3012.service
sudo rm /etc/systemd/system/json-server-301[0-2].service
sudo systemctl daemon-reload
sudo userdel jsonserver
sudo rm -rf /opt/json-server   # deletes all three data files
```

---

## Additional Resources

- [json-server on GitHub](https://github.com/typicode/json-server)
- [json-server on npm](https://www.npmjs.com/package/json-server)
