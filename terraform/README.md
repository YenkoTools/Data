# Terraform

Terraform is HashiCorp's infrastructure-as-code tool. This directory installs the Terraform CLI on the Linux host from HashiCorp's apt repository.

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
| Package | `terraform` |
| Install method | apt, from `https://apt.releases.hashicorp.com` |
| apt source file | `/etc/apt/sources.list.d/hashicorp.list` |
| Signing key | `/usr/share/keyrings/hashicorp-archive-keyring.gpg` |
| Binary | `/usr/bin/terraform` |
| Supported OS | Linux Mint Debian Edition 7 / Debian 13 (trixie) |
| Upstream | <https://developer.hashicorp.com/terraform> |

---

## Prerequisites

- Debian-based host: LMDE 7 or Debian 13
- sudo access
- Internet access to `apt.releases.hashicorp.com`

---

## Files

| File | Purpose |
|------|---------|
| `install.sh` | Adds the HashiCorp apt repository and installs `terraform` |
| `README.md` | This document |

---

## Installation

```bash
cd /path/to/Data/terraform
./install.sh
```

The script uses `sudo` for the steps that need it; don't run the whole script as root. It stops at the first failing command (`set -euo pipefail`).

**What `install.sh` does:**

1. Installs `gpg` and `wget`
2. Downloads HashiCorp's signing key to `/usr/share/keyrings/hashicorp-archive-keyring.gpg` and prints its fingerprint
3. Reads `DEBIAN_CODENAME` from `/etc/os-release`, falling back to `trixie`. LMDE reports its own codename (for example `gigi`), which HashiCorp's repository doesn't recognize, so the Debian codename is used instead
4. Writes the repository to `/etc/apt/sources.list.d/hashicorp.list`
5. Installs the `terraform` package and prints its version

Check that the printed fingerprint matches the one HashiCorp publishes on its [official packaging guide](https://www.hashicorp.com/official-packaging-guide).

---

## Verifying the Installation

```bash
terraform -version
```

Expected output, with your version:

```text
Terraform v1.17.1
on linux_amd64
```

---

## Upgrading

The package is managed by apt, so it upgrades with the rest of the system:

```bash
sudo apt update && sudo apt install --only-upgrade terraform
```

---

## Uninstall

```bash
sudo apt remove terraform
sudo rm /etc/apt/sources.list.d/hashicorp.list
sudo rm /usr/share/keyrings/hashicorp-archive-keyring.gpg
sudo apt update
```

The HashiCorp repository also provides other tools, such as Vault and Packer. Keep the source and key if you use any of them.

---

## Troubleshooting

### `apt update` fails: repository "does not have a Release file"

**Cause:** The repository line uses a codename HashiCorp doesn't publish, usually the LMDE or Mint codename instead of the Debian one.

**Fix:** Check the line and the host's Debian codename, then rerun `install.sh`:

```bash
cat /etc/apt/sources.list.d/hashicorp.list
grep DEBIAN_CODENAME /etc/os-release
```

### `NO_PUBKEY` or signature errors during `apt update`

**Cause:** The signing key file is missing or corrupt.

**Fix:** Rerun `install.sh`, which downloads the key again and overwrites it (`gpg --dearmor --yes`).

---

## Additional Resources

- [Install Terraform](https://developer.hashicorp.com/terraform/install)
- [Terraform documentation](https://developer.hashicorp.com/terraform/docs)
- [HashiCorp official packaging guide](https://www.hashicorp.com/official-packaging-guide)
