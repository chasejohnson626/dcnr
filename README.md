# dcnr

Per-project Docker dev containers with neovim (LazyVim), tmux, and yazi. Your configs come from your host; plugin binaries are isolated per container.

## Requirements

- macOS (tested with [OrbStack](https://orbstack.dev), works with Docker Desktop)
- Docker CLI in your PATH
- Your dotfiles on the host machine

## Installation

```bash
git clone https://github.com/your-username/cnr ~/.dcnr
cd ~/.dcnr && ./scripts/install.sh
```

This symlinks `dcnr` to `~/.local/bin/dcnr` and creates `~/.config/dcnr/config` from the example. Make sure `~/.local/bin` is in your `$PATH`.

## Quick start

```bash
# 1. Edit your config to point at your dotfiles
$EDITOR ~/.config/dcnr/config

# 2. Build the base image (one-time, ~5 min)
dcnr build

# 3. Create a container for a project
dcnr new my-project

# 4. Enter it
dcnr shell my-project
# → opens zsh; git clone your project into ~/projects/, then start coding
```

## Commands

```
dcnr list              List all containers with status, CPU%, and memory
dcnr new <name>        Create and start a new dev container
dcnr shell <name>      Open an interactive shell (auto-starts if stopped)
dcnr stop <name>       Stop a running container
dcnr start <name>      Start a stopped container
dcnr delete <name>     Delete a container (prompts if running)
dcnr info <name>       Show detailed stats and mount info
dcnr build             Build/rebuild the dcnr base image
dcnr version           Print version
dcnr help              Show usage
```

## Configuration

`~/.config/dcnr/config` is sourced as a bash file. The main thing to set is `DCNR_MOUNTS`:

```bash
DCNR_MOUNTS=(
    "$HOME/.config:/home/dev/.config:ro"   # all XDG config in one mount
    "$HOME/.tmux.conf:/home/dev/.tmux.conf:ro"
    "$HOME/.zshrc:/home/dev/.zshrc:ro"
    "$HOME/.zprofile:/home/dev/.zprofile:ro"
    "$HOME/.gitconfig:/home/dev/.gitconfig:ro"
)
```

Mount paths that don't exist on the host are silently skipped, so the example config works for most setups without modification.

**Do not mount `~/.ssh`.** Private keys inside a container are a security risk. Use SSH agent forwarding instead — on macOS with OrbStack this works automatically. See [`config/config.example`](config/config.example) for Docker Desktop instructions.

See [`config/config.example`](config/config.example) for all options.

## Global install script

`~/.config/dcnr/install.sh` runs inside every new container before the plugin sync step. Use it to install tools you want in all your containers — editors, file managers, language runtimes, etc.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Install neovim
curl -fsSL https://github.com/neovim/neovim/releases/download/v0.10.4/nvim-linux-x86_64.tar.gz \
    -o /tmp/nvim.tar.gz
sudo tar -C /usr/local --strip-components=1 -xzf /tmp/nvim.tar.gz
rm /tmp/nvim.tar.gz
```

The script runs as the `dev` user with passwordless sudo. It does not exist by default — create it if you want per-user global tooling.

An example script that installs neovim and yazi is in [`examples/install.sh`](examples/install.sh). You can symlink it directly:

```bash
ln -s "$(pwd)/examples/install.sh" ~/.config/dcnr/install.sh
```

## How it works

Each container is a lean Ubuntu 24.04 environment with tmux and common dev tools pre-installed. Editors and other tools are installed at container-creation time via your global install script. Your config files are bind-mounted from the host so you get your exact setup in every container. Project files live inside the container — `git clone` your repos into `~/projects/` and commit/push as your backup strategy.

### Supply chain isolation

The entire `~/.config` directory is mounted read-only from your host, but the downloaded plugin binaries (`~/.local/share/nvim`) live only inside the container and are never shared. Each container independently downloads its own copy of every plugin. A compromised plugin in one container cannot reach another.

```
Host                        Container A            Container B
~/.config ────────mount───▶ ~/.config              ~/.config ◀────mount──── Host
                             ~/.local/share/nvim    ~/.local/share/nvim
                             (isolated plugins)     (isolated plugins)
```

### Customizing the base image

Edit the `Dockerfile` and run `dcnr build` to rebuild. To pin different tool versions:

```dockerfile
ARG NVIM_VERSION=0.10.4
ARG YAZI_VERSION=0.4.2
```

To use a different username or UID (useful if your host UID isn't 1000):

```bash
docker build --build-arg USER_UID=$(id -u) --build-arg USER_GID=$(id -g) -t dcnr-base .
```

Or set `DCNR_IMAGE` in your config to use a custom image name.

## Workflow tips

**Multiple terminals in one container** — start tmux inside the container:
```bash
dcnr shell my-project
# then inside the container:
tmux
```

**Check what's running:**
```bash
dcnr list
```

**Save work before deleting** — containers are ephemeral. Push to git or export files before `dcnr delete`.

**Per-container tool versions** — install language runtimes (Go, Rust, Node) inside the container however you like. They stay isolated from other containers and your host.
