#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dcnr"

echo "Installing dcnr from $REPO_DIR"
echo ""

# Create bin dir and symlink
mkdir -p "$BIN_DIR"
chmod +x "$REPO_DIR/dcnr" "$REPO_DIR/examples/install.sh"
ln -sf "$REPO_DIR/dcnr" "$BIN_DIR/dcnr"
echo "  linked: $BIN_DIR/dcnr -> $REPO_DIR/dcnr"

# Warn if bin dir is not in PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo ""
    echo "  ⚠  $BIN_DIR is not in your PATH"
    echo "     Add to your shell config:"
    echo "       export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# Create config dir and copy example if no config exists yet
mkdir -p "$CONFIG_DIR"
if [[ ! -f "$CONFIG_DIR/config" ]]; then
    cp "$REPO_DIR/examples/config" "$CONFIG_DIR/config"
    echo "  config: $CONFIG_DIR/config (created from example)"
    CONFIG_CREATED=true
else
    echo "  config: $CONFIG_DIR/config (already exists, not overwritten)"
    CONFIG_CREATED=false
fi

# Copy the in-container install script if none exists yet. dcnr new looks for
# this at $CONFIG_DIR/install.sh and runs it inside each new container to
# install tools (neovim, yazi, node, pi, SSH key, ...).
if [[ ! -f "$CONFIG_DIR/install.sh" ]]; then
    cp "$REPO_DIR/examples/install.sh" "$CONFIG_DIR/install.sh"
    echo "  install.sh: $CONFIG_DIR/install.sh (created from example)"
else
    echo "  install.sh: $CONFIG_DIR/install.sh (already exists, not overwritten)"
fi

echo ""
echo "Done. Next steps:"

if [[ "$CONFIG_CREATED" == "true" ]]; then
    echo "  1. Edit your config:   \$EDITOR $CONFIG_DIR/config"
    echo "  2. Build the image:    dcnr build"
    echo "  3. Create a container: dcnr new my-project"
else
    echo "  1. Build the image:    dcnr build"
    echo "  2. Create a container: dcnr new my-project"
fi
