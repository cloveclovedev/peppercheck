#!/usr/bin/env bash
# Installs the two CLIs the deploy-vps.yml reusable workflow needs on the
# GitHub Actions runner before it can render secrets
# (`bws run`) or pull/verify the release manifest (`oras pull`):
#
#   bws  -- Bitwarden Secrets Manager CLI, https://bitwarden.com/help/secrets-manager-cli/
#   oras -- OCI Registry As Storage CLI, https://oras.land/docs/installation
#
# Pinned release asset URLs (not `latest`, so a new upstream release can
# never silently change what a deploy runs) verified against each release's
# published sha256 checksums file -- both release processes publish one:
#   bws:  https://github.com/bitwarden/sdk-sm/releases/download/bws-v<ver>/bws-sha256-checksums-<ver>.txt
#   oras: https://github.com/oras-project/oras/releases/download/v<ver>/oras_<ver>_checksums.txt
#
# Only targets the runner architecture actually in play here: `ubuntu-latest`
# is linux/amd64 (see deploy-vps.yml's `runs-on: ubuntu-latest`) -- this
# script is not a general-purpose installer for other platforms.
#
# oras is pinned to 1.2.0 to match the same version ci-backend.yml and
# deploy-vps-production.yml install via `oras-project/setup-oras@v2`
# (`with: version: "1.2.0"`), so every workflow in the pipeline resolves,
# pushes, and pulls the release manifest with the identical oras build.
set -euo pipefail

readonly BWS_VERSION="2.1.0"
readonly ORAS_VERSION="1.2.0"

readonly BWS_ASSET="bws-x86_64-unknown-linux-gnu-${BWS_VERSION}.zip"
readonly BWS_CHECKSUMS="bws-sha256-checksums-${BWS_VERSION}.txt"
readonly BWS_BASE_URL="https://github.com/bitwarden/sdk-sm/releases/download/bws-v${BWS_VERSION}"

readonly ORAS_ASSET="oras_${ORAS_VERSION}_linux_amd64.tar.gz"
readonly ORAS_CHECKSUMS="oras_${ORAS_VERSION}_checksums.txt"
readonly ORAS_BASE_URL="https://github.com/oras-project/oras/releases/download/v${ORAS_VERSION}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "install-cli: downloading bws ${BWS_VERSION}"
curl -fsSL -o "$tmp/$BWS_ASSET" "$BWS_BASE_URL/$BWS_ASSET"
curl -fsSL -o "$tmp/$BWS_CHECKSUMS" "$BWS_BASE_URL/$BWS_CHECKSUMS"
(cd "$tmp" && grep " $BWS_ASSET\$" "$BWS_CHECKSUMS" | sha256sum -c -)
unzip -q -o "$tmp/$BWS_ASSET" -d "$tmp/bws-extracted"
sudo install -m 0755 "$tmp/bws-extracted/bws" /usr/local/bin/bws

echo "install-cli: downloading oras ${ORAS_VERSION}"
curl -fsSL -o "$tmp/$ORAS_ASSET" "$ORAS_BASE_URL/$ORAS_ASSET"
curl -fsSL -o "$tmp/$ORAS_CHECKSUMS" "$ORAS_BASE_URL/$ORAS_CHECKSUMS"
(cd "$tmp" && grep " $ORAS_ASSET\$" "$ORAS_CHECKSUMS" | sha256sum -c -)
mkdir -p "$tmp/oras-extracted"
tar -xzf "$tmp/$ORAS_ASSET" -C "$tmp/oras-extracted" oras
sudo install -m 0755 "$tmp/oras-extracted/oras" /usr/local/bin/oras

bws --version
oras version
