#!/usr/bin/env bash
# Install Terraform on Linux Mint Debian Edition (LMDE).
# LMDE reports its own codename (e.g. "gigi") which HashiCorp's apt repo doesn't know,
# so we use the upstream Debian codename instead (LMDE 7 "Gigi" = Debian 13 "trixie").
set -euo pipefail

# gpg is required for the package signing key
sudo apt update && sudo apt install -y gpg wget

# Download the signing key to a new keyring
wget -O- https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor --yes -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Verify the key's fingerprint
gpg --no-default-keyring \
  --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint

# Use the Debian codename LMDE is built on (falls back to trixie if not set)
CODENAME=$(grep -oP '(?<=^DEBIAN_CODENAME=).*' /etc/os-release || echo trixie)
echo "Using Debian codename: ${CODENAME}"

# Add the repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${CODENAME} main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update && sudo apt install -y terraform
terraform -version
