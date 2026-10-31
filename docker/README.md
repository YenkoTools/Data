# Docker

This directory holds setup documentation for Docker, which every container service in this repository requires. It contains no scripts.

## Contents

| File | Type | Use it to |
|------|------|-----------|
| [WSL2-Docker-Setup-Guide.md](WSL2-Docker-Setup-Guide.md) | Step-by-step guide | Install WSL2 and Docker Engine (without Docker Desktop) on Windows 11 Pro, then build sample AstroJS and .NET 10 images |
| `README.md` | Index | Find the right document (this file) |

The same guide is published on the wiki as **Docker / WSL2 Setup**.

## Which document do I need?

- **Windows 11 with WSL2:** follow the [WSL2 and Docker setup guide](WSL2-Docker-Setup-Guide.md) from the start.
- **Native Linux (Debian, LMDE, Ubuntu):** follow Docker's official [Install Docker Engine on Debian](https://docs.docker.com/engine/install/debian/) instructions. The guide's sections from "Install Docker in WSL2" onward also apply, except the WSL-specific steps.

## Requirements for this repository

Whichever path you take, the services here expect:

- Docker Engine running and enabled at boot (`sudo systemctl enable --now docker`)
- systemd available. On WSL2 it is off by default (see below)
- The `docker` group present. Each service's `install.sh` adds its own service user to it

**Enable systemd on WSL2:** add this to `/etc/wsl.conf` inside the distribution, then run `wsl --shutdown` from Windows and reopen it:

```ini
[boot]
systemd=true
```

Check with:

```bash
docker --version
sudo systemctl is-active docker
getent group docker
```

## Additional Resources

- [Docker Engine installation](https://docs.docker.com/engine/install/)
- [Linux post-installation steps](https://docs.docker.com/engine/install/linux-postinstall/)
- [Docker on WSL2](https://learn.microsoft.com/windows/wsl/tutorials/wsl-containers)
