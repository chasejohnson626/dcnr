# dcnr

Per-project Docker dev containers with neovim (LazyVim), tmux, and yazi. Your configs come from your host; plugin binaries are isolated per container.

## Requirements

- macOS (tested with [OrbStack](https://orbstack.dev), works with Docker Desktop)
- Docker CLI in your PATH
- Your dotfiles on the host machine

## How the pieces fit together

```
dcnr/
├── Dockerfile          Base Docker image — Ubuntu 24.04 + tmux + dev tools.
│                       Intentionally minimal; editors go in your install script.
├── dcnr                The CLI you run on your Mac (list, new, shell, etc.)
├── scripts/
│   └── install.sh      Run once on your Mac to install the dcnr command.
└── examples/
    ├── config          Template for ~/.config/dcnr/config — tells dcnr how to
    │                   create containers (what to mount, which image, which shell).
    │                   Read by dcnr on your Mac BEFORE the container is created.
    └── install.sh      Runs INSIDE each new container to install your tools
                        (neovim, yazi, etc.). Copied here from ~/.config/dcnr/install.sh.
```

**The key distinction between the two files in `examples/`:**

- `examples/config` is read on your **Mac** before a container is created. It controls things like which host paths get mounted inside containers. By the time a container exists, this file has already done its job.
- `examples/install.sh` runs **inside** each container after it is created. It installs software. It cannot affect mounts or any other creation-time decisions.

## Installation

```bash
git clone https://github.com/your-username/dcnr ~/.dcnr
cd ~/.dcnr && ./scripts/install.sh
```

This symlinks `dcnr` to `~/.local/bin/dcnr` and creates `~/.config/dcnr/config` from `examples/config`. Make sure `~/.local/bin` is in your `$PATH`.

## Quick start

```bash
# 1. Edit your config to set your mount paths
$EDITOR ~/.config/dcnr/config

# 2. Build the base image (one-time, a few minutes)
dcnr build

# 3. Create a container for a project
dcnr new my-project

# 4. Enter it
dcnr shell my-project
# → opens zsh; git clone your project into ~/projects/, then start coding
```

## Commands

```
dcnr list              List all containers with status, CPU%, memory, and size
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

## Configuration (`~/.config/dcnr/config`)

Created from `examples/config` on install. The main thing to set is `DCNR_MOUNTS` — the host paths that get bind-mounted into every new container:

```bash
DCNR_MOUNTS=(
    "$HOME/.config:/home/dev/.config:ro"
    "$HOME/.tmux.conf:/home/dev/.tmux.conf:ro"
    "$HOME/.zshrc:/home/dev/.zshrc:ro"
    "$HOME/.gitconfig:/home/dev/.gitconfig:ro"
)
```

Mount paths that don't exist on the host are silently skipped.

**Do not mount `~/.ssh`.** Private keys inside a container are a security risk. Use SSH agent forwarding instead — on macOS with OrbStack this works automatically. See [`examples/config`](examples/config) for Docker Desktop instructions.

## Global install script (`~/.config/dcnr/install.sh`)

If this file exists, `dcnr new` copies it into each new container and runs it before the plugin sync step. Use it to install tools you want in every container — editors, file managers, language runtimes, etc.

The script runs as the `dev` user with passwordless sudo. It does not exist by default.

`examples/install.sh` in this repo installs neovim, yazi, Node.js, and pi, and can be symlinked directly:

```bash
ln -s "$(pwd)/examples/install.sh" ~/.config/dcnr/install.sh
```

It installs the official Node.js 22 binary to `/usr/local` (Node is a general-purpose runtime, not just for pi — Ubuntu 24.04's apt only ships Node 18, which is too old), then installs [pi](https://pi.dev) globally via `npm install -g --ignore-scripts @earendil-works/pi-coding-agent`. Both land in `/usr/local/bin`, which is already on the default `$PATH`, so no extra shell configuration is needed.

## How it works

Each container is a lean Ubuntu 24.04 environment with tmux and common dev tools pre-installed. Editors and other tools (including language runtimes like Node) are installed at container-creation time via your global install script — the base image intentionally does not ship nodejs/npm, since Ubuntu 24.04's versions are too old for modern tools. Everything the install script adds goes to `/usr/local/bin`, which is on the default `$PATH`. Your config files are bind-mounted from the host so you get your exact editor and shell setup in every container. Project files live inside the container — `git clone` your repos into `~/projects/` and commit/push as your backup strategy.

### Supply chain isolation

`~/.config` is mounted read-only from your host, but downloaded plugin binaries (`~/.local/share/nvim`) live only inside each container and are never shared. Each container downloads its own copy of every plugin independently, so a compromised plugin in one container cannot reach another.

```
Host                        Container A            Container B
~/.config ────────mount───▶ ~/.config              ~/.config ◀────mount──── Host
                             ~/.local/share/nvim    ~/.local/share/nvim
                             (isolated plugins)     (isolated plugins)
```

### Customizing the base image

Edit `Dockerfile` and run `dcnr build` to rebuild. To use a different username or UID (useful if your host UID isn't 1000):

```bash
docker build --build-arg USER_UID=$(id -u) --build-arg USER_GID=$(id -g) -t dcnr-base .
```

Or set `DCNR_IMAGE` in your config to point to a custom image.

## Workflow tips

**Multiple terminals in one container** — start tmux inside the container:
```bash
dcnr shell my-project
# inside the container:
tmux
```

**Save work before deleting** — containers are ephemeral. Push to git before `dcnr delete`.

**Per-container tool versions** — install language runtimes (Go, Rust, Node) inside the container however you like. They stay isolated from other containers and your host.
