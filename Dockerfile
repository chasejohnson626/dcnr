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
    nodejs \
    npm \
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

# Pre-create the projects dir and local share dir. Tool-specific data dirs
# (e.g. ~/.local/share/nvim) are intentionally NOT pre-created here — they are
# created by each tool on first run and always live in the container, never
# mounted from the host. This is the supply chain isolation boundary.
RUN mkdir -p \
    /home/${USERNAME}/.local/share \
    /home/${USERNAME}/projects

CMD ["/usr/bin/zsh"]
