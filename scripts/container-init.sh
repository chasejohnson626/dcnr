#!/usr/bin/env bash
set -euo pipefail

# Runs once inside the container on first creation.
# Guards against re-running with a sentinel file.

[[ -f "$HOME/.dcnr-initialized" ]] && exit 0

echo "dcnr: running first-time setup..."

# Pre-install neovim plugins into container-local ~/.local/share/nvim.
# The config (plugin specs) comes from the host mount; the downloaded plugin
# binaries land here in the container — never shared across containers.
if command -v nvim &>/dev/null && [[ -d "$HOME/.config/nvim" ]]; then
    echo "dcnr: installing neovim plugins (this may take a minute)..."
    nvim --headless "+Lazy! sync" +qa 2>/dev/null || {
        echo "dcnr: plugin install returned non-zero (may be harmless)"
    }
fi

touch "$HOME/.dcnr-initialized"
echo "dcnr: setup complete"
