#!/usr/bin/env bash
set -euo pipefail

# Global dcnr install script — runs inside each new container on creation.
# Add anything you want available in every dev container.

NVIM_VERSION="0.10.4"
YAZI_VERSION="0.4.2"

UARCH=$(uname -m)

echo "==> installing neovim v${NVIM_VERSION}..."
if [ "$UARCH" = "aarch64" ]; then NVIM_ARCH="arm64"; else NVIM_ARCH="x86_64"; fi
curl -fsSL "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-linux-${NVIM_ARCH}.tar.gz" \
    -o /tmp/nvim.tar.gz
sudo tar -C /usr/local --strip-components=1 -xzf /tmp/nvim.tar.gz
rm /tmp/nvim.tar.gz
echo "    $(nvim --version | head -1)"

echo "==> syncing neovim plugins..."
[[ -d "$HOME/.config/nvim" ]] && nvim --headless "+Lazy! sync" +qa 2>/dev/null || true

echo "==> installing yazi v${YAZI_VERSION}..."
if [ "$UARCH" = "aarch64" ]; then YAZI_ARCH="aarch64"; else YAZI_ARCH="x86_64"; fi
curl -fsSL "https://github.com/sxyazi/yazi/releases/download/v${YAZI_VERSION}/yazi-${YAZI_ARCH}-unknown-linux-gnu.zip" \
    -o /tmp/yazi.zip
unzip -q /tmp/yazi.zip -d /tmp/yazi-extract
sudo mv "/tmp/yazi-extract/yazi-${YAZI_ARCH}-unknown-linux-gnu/yazi" /usr/local/bin/yazi
sudo mv "/tmp/yazi-extract/yazi-${YAZI_ARCH}-unknown-linux-gnu/ya" /usr/local/bin/ya 2>/dev/null || true
sudo chmod +x /usr/local/bin/yazi
rm -rf /tmp/yazi.zip /tmp/yazi-extract
echo "    $(yazi --version 2>/dev/null | head -1 || echo 'yazi installed')"
