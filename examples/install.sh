#!/usr/bin/env bash
set -euo pipefail

# Global dcnr install script — runs inside each new container on creation.
# Add anything you want available in every dev container.

NVIM_VERSION="0.11.7"
YAZI_VERSION="0.4.2"
NODE_VERSION="22.23.1"

UARCH=$(uname -m)

echo "==> installing neovim v${NVIM_VERSION}..."
if [ "$UARCH" = "aarch64" ]; then NVIM_ARCH="arm64"; else NVIM_ARCH="x86_64"; fi
NVIM_FILE="nvim-linux-${NVIM_ARCH}.tar.gz"
NVIM_BASE="https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}"
curl -fsSL "${NVIM_BASE}/${NVIM_FILE}" -o "/tmp/${NVIM_FILE}"
if curl -fsSL "${NVIM_BASE}/${NVIM_FILE}.sha256sum" -o "/tmp/${NVIM_FILE}.sha256sum" 2>/dev/null; then
    (cd /tmp && sha256sum --check "${NVIM_FILE}.sha256sum")
    rm -f "/tmp/${NVIM_FILE}.sha256sum"
fi
sudo tar -C /usr/local --strip-components=1 -xzf "/tmp/${NVIM_FILE}"
rm -f "/tmp/${NVIM_FILE}"
echo "    $(nvim --version | head -1)"

echo "==> syncing neovim plugins..."
[[ -d "$HOME/.config/nvim" ]] && nvim --headless "+Lazy! sync" +qa 2>/dev/null || true

echo "==> installing yazi v${YAZI_VERSION}..."
# yazi does not publish checksums alongside its releases — no .sha256sum assets exist.
# To harden this further, pin a known-good hash here and verify with sha256sum manually.
if [ "$UARCH" = "aarch64" ]; then YAZI_ARCH="aarch64"; else YAZI_ARCH="x86_64"; fi
YAZI_FILE="yazi-${YAZI_ARCH}-unknown-linux-gnu.zip"
curl -fsSL "https://github.com/sxyazi/yazi/releases/download/v${YAZI_VERSION}/${YAZI_FILE}" \
    -o "/tmp/${YAZI_FILE}"
unzip -q "/tmp/${YAZI_FILE}" -d /tmp/yazi-extract
sudo mv "/tmp/yazi-extract/yazi-${YAZI_ARCH}-unknown-linux-gnu/yazi" /usr/local/bin/yazi
sudo mv "/tmp/yazi-extract/yazi-${YAZI_ARCH}-unknown-linux-gnu/ya" /usr/local/bin/ya 2>/dev/null || true
sudo chmod +x /usr/local/bin/yazi
rm -rf "/tmp/${YAZI_FILE}" /tmp/yazi-extract
echo "    $(yazi --version 2>/dev/null | head -1 || echo 'yazi installed')"

echo "==> installing Node.js v${NODE_VERSION}..."
# Node.js is a general-purpose runtime, not just for pi. Ubuntu 24.04's apt
# only ships Node 18, which is too old for modern tools (pi needs >= 22.19),
# so install the official Node 22 binary tarball to /usr/local. It lands in
# /usr/local/bin, which is on the default PATH for every shell — no env
# drop-in or PATH tweaking needed.
if [ "$UARCH" = "aarch64" ]; then NODE_ARCH="arm64"; else NODE_ARCH="x64"; fi
NODE_FILE="node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz"
NODE_BASE="https://nodejs.org/dist/v${NODE_VERSION}"
curl -fsSL "${NODE_BASE}/${NODE_FILE}"   -o "/tmp/${NODE_FILE}"
curl -fsSL "${NODE_BASE}/SHASUMS256.txt" -o "/tmp/SHASUMS256.txt"
(cd /tmp && grep " ${NODE_FILE}\$" SHASUMS256.txt | sha256sum --check -)
sudo tar -C /usr/local --strip-components=1 -xJf "/tmp/${NODE_FILE}"
rm "/tmp/${NODE_FILE}" "/tmp/SHASUMS256.txt"
echo "    $(node --version) / $(npm --version)"

echo "==> installing pi..."
# Install pi (https://pi.dev) as a global npm package, non-interactively.
# This avoids the pi.dev interactive installer entirely. --ignore-scripts
# skips the package's postinstall hooks. npm's global prefix is /usr/local,
# so the `pi` launcher lands in /usr/local/bin (already on the default PATH).
sudo npm install -g --ignore-scripts @earendil-works/pi-coding-agent
echo "    $(pi --version 2>/dev/null || echo 'pi installed')"

echo "==> setting up SSH key..."
# Generate an ed25519 SSH key (GitHub's recommended type) if one doesn't
# already exist, then wire up ssh-agent so the user never has to manage it —
# the key is auto-loaded on every interactive shell. The key is generated
# with an empty passphrase because it lives only inside this ephemeral,
# supply-chain-isolated dev container; if you'd prefer a passphrase, run
# ssh-keygen -p -f ~/.ssh/id_ed25519 yourself after first boot.
SSH_DIR="$HOME/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Label the key with git's configured email if present, else a sensible
# container-local default.
SSH_EMAIL="$(git config --global user.email 2>/dev/null || true)"
if [[ -z "$SSH_EMAIL" ]]; then
    SSH_EMAIL="${USER}@$(hostname)"
fi

SSH_KEY="$SSH_DIR/id_ed25519"
if [[ ! -f "$SSH_KEY" ]]; then
    ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$SSH_KEY" -N "" >/dev/null
    echo "    generated new ed25519 key: $SSH_KEY"
else
    echo "    existing ed25519 key found: $SSH_KEY"
fi

# Append an ssh-agent bootstrap to interactive shell rc files so the agent
# is started (and the key loaded) automatically on every new shell.
# Idempotent: only appended once, guarded by the marker comment.
#
# These rc files are container-local (not bind-mounted from the host), so
# they are writable. If you supplied a custom ~/.zshrc via
# ~/.config/dcnr/zshrc, the bootstrap is appended to it; otherwise one is
# created here.
SSH_AGENT_BLOCK='
# --- dcnr ssh-agent bootstrap ---
_DSNR_AGENT_ENV="$HOME/.ssh/agent-env"
if [[ -z "$SSH_AUTH_SOCK" ]] || ! kill -0 "${SSH_AGENT_PID:-0}" 2>/dev/null; then
    if [[ -f "$_DSNR_AGENT_ENV" ]] && kill -0 "$(sed -n "s/SSH_AGENT_PID=\([0-9]\+\).*/\1/p" "$_DSNR_AGENT_ENV" 2>/dev/null)" 2>/dev/null; then
        source "$_DSNR_AGENT_ENV" >/dev/null
    else
        ssh-agent -s > "$_DSNR_AGENT_ENV"
        source "$_DSNR_AGENT_ENV" >/dev/null
    fi
fi
if [[ -n "$SSH_AUTH_SOCK" ]] && ! ssh-add -l 2>/dev/null | grep -q "id_ed25519"; then
    ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null
fi
unset _DSNR_AGENT_ENV
# --- end dcnr ssh-agent bootstrap ---
'
append_once() {
    local rc="$1"
    # Create if missing (touch is a no-op if it exists) and append the
    # bootstrap block. Guarded by the marker so re-runs are idempotent.
    if ! touch "$rc" 2>/dev/null; then
        echo "    warn: cannot write to $rc — skipping ssh-agent bootstrap"
        return 0
    fi
    if ! grep -q "dcnr ssh-agent bootstrap" "$rc"; then
        printf '%s\n' "$SSH_AGENT_BLOCK" >> "$rc"
    fi
}
append_once "$HOME/.zshrc"
append_once "$HOME/.bashrc"

echo ""
echo "SSH public key (add this to GitHub / your Git host):"
echo "------------------------------------------------------------"
cat "$SSH_KEY.pub"
echo "------------------------------------------------------------"
