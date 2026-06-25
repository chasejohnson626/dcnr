FROM ubuntu:24.04

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    unzip \
    tar \
    gzip \
    tmux \
    build-essential \
    cmake \
    python3 \
    python3-pip \
    python3-venv \
    # NOTE: nodejs/npm intentionally NOT installed here. Ubuntu 24.04 ships
    # Node 18, which is too old for modern tools (e.g. pi needs >= 22.19).
    # Node 22 is installed per-container by your install script instead —
    # see examples/install.sh. xz-utils is needed to extract that tarball.
    xz-utils \
    ripgrep \
    fd-find \
    fzf \
    zsh \
    locales \
    ca-certificates \
    openssh-client \
    sudo \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# Ubuntu 24.04 ships with an 'ubuntu' user at UID/GID 1000 — remove it first
# so we can claim that UID/GID for our dev user.
RUN userdel -r ubuntu 2>/dev/null || true \
    && groupdel ubuntu 2>/dev/null || true \
    && groupadd --gid "${USER_GID}" "${USERNAME}" \
    && useradd --uid "${USER_UID}" --gid "${USER_GID}" -m -s /usr/bin/zsh "${USERNAME}" \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}" \
    && chmod 0440 "/etc/sudoers.d/${USERNAME}"

USER ${USERNAME}
WORKDIR /home/${USERNAME}

# Pre-create the local share dir. Tool-specific data dirs (e.g.
# ~/.local/share/nvim) are intentionally NOT pre-created here — they are
# created by each tool on first run and always live in the container, never
# mounted from the host. This is the supply chain isolation boundary.
RUN mkdir -p \
    /home/${USERNAME}/.local/share

CMD ["/usr/bin/zsh"]
