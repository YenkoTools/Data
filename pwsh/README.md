# PowerShell

PowerShell 7 is Microsoft's cross-platform shell and scripting language. This directory installs it on the Linux host from Microsoft's apt repository, so repository scripts such as `git-tag.ps1` can run with `pwsh`.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Files](#files)
4. [Installation](#installation)
5. [Verifying the Installation](#verifying-the-installation)
6. [Upgrading](#upgrading)
7. [Uninstall](#uninstall)
8. [Troubleshooting](#troubleshooting)
9. [Additional Resources](#additional-resources)

---

## Overview

| Property | Value |
|----------|-------|
| Package | `powershell` |
| Install method | apt, from `https://packages.microsoft.com/debian/13/prod` |
| Repository package | `packages-microsoft-prod` (adds the apt source and signing key) |
| apt source file | `/etc/apt/sources.list.d/microsoft-prod.list` |
| Signing key | `/usr/share/keyrings/microsoft-prod.gpg` |
| Binary | `/usr/bin/pwsh` |
| Supported OS | Linux Mint Debian Edition 7 / Debian 13 (trixie) |
| Upstream | <https://learn.microsoft.com/powershell/scripting/install/install-debian> |

---

## Prerequisites

- Debian-based host: LMDE 7 or Debian 13. The script hardcodes the Debian 13 repository
- sudo access
- Internet access to `packages.microsoft.com`

---

## Files

| File | Purpose |
|------|---------|
| `install.sh` | Registers Microsoft's apt repository, installs `powershell`, and starts `pwsh` |
| `README.md` | This document |

---

## Installation

```bash
cd /path/to/Data/pwsh
./install.sh
```

The script uses `sudo` for the steps that need it; don't run the whole script as root. When it finishes it starts an interactive PowerShell session. Type `exit` to return to bash.

**What `install.sh` does:**

1. Updates the package lists and installs `wget`, `apt-transport-https`, and `software-properties-common`
2. Downloads `packages-microsoft-prod.deb` for Debian 13 and installs it, which adds the Microsoft apt source and signing key
3. Deletes the downloaded `.deb` and updates the package lists again
4. Installs the `powershell` package
5. Starts `pwsh`

---

## Verifying the Installation

```bash
pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
```

Expected output: a 7.x version number, for example:

```text
7.6.9
```

---

## Upgrading

The package is managed by apt, so it upgrades with the rest of the system:

```bash
sudo apt update && sudo apt install --only-upgrade powershell
```

---

## Uninstall

```bash
sudo apt remove powershell
```

To also remove the Microsoft repository:

```bash
sudo apt remove packages-microsoft-prod
sudo apt update
```

The Microsoft repository also provides other packages, such as the .NET SDK. Keep `packages-microsoft-prod` installed if you use any of them.

---

## Troubleshooting

### `E: Unable to locate package powershell`

**Cause:** The Microsoft repository was not added, or the package lists were not refreshed afterward.

**Fix:**

```bash
cat /etc/apt/sources.list.d/microsoft-prod.list
sudo apt update
sudo apt install -y powershell
```

### Installation fails on a release other than Debian 13

**Cause:** `install.sh` always downloads the Debian 13 repository package, whatever the host's version is.

**Fix:** Edit the `wget` URL in `install.sh` to match your Debian version (for example `debian/12` for Debian 12 or LMDE 6), or for Ubuntu follow Microsoft's Ubuntu instructions.

### The script stops at a `PS>` prompt

**Cause:** The last line of `install.sh` starts PowerShell. This is expected.

**Fix:** Type `exit`.

---

## Additional Resources

- [Install PowerShell on Debian](https://learn.microsoft.com/powershell/scripting/install/install-debian)
- [PowerShell documentation](https://learn.microsoft.com/powershell/)
- [PowerShell on GitHub](https://github.com/PowerShell/PowerShell)
