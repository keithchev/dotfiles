FROM ubuntu:22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    git \
    sudo \
    ripgrep \
    jq \
    build-essential \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Install gh CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y gh && rm -rf /var/lib/apt/lists/*

# Install Node.js LTS and enable pnpm via corepack
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs && rm -rf /var/lib/apt/lists/* \
    && corepack enable \
    && corepack prepare pnpm@latest --activate

# Create non-root user
ARG USERNAME=claude
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME 2>/dev/null || groupmod -n $USERNAME $(getent group $USER_GID | cut -d: -f1) \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Switch to non-root user
USER $USERNAME
WORKDIR /home/$USERNAME

# Install Claude Code (installs to ~/.local/bin)
RUN curl -fsSL https://claude.ai/install.sh | bash

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Add to PATH
ENV PATH="/home/$USERNAME/.local/bin:$PATH"

# Configure pnpm to use node_modules_claude instead of node_modules
RUN pnpm config set modules-dir node_modules_claude --global \
    && pnpm config set virtual-store-dir node_modules_claude/.pnpm --global
ENV NODE_PATH=node_modules_claude

# Alias npm to pnpm so all installs go through pnpm (and use node_modules_claude)
RUN printf '#!/bin/sh\nexec pnpm "$@"\n' > /home/$USERNAME/.local/bin/npm \
    && chmod +x /home/$USERNAME/.local/bin/npm

# Working directory - workspace subdirectory is mounted at runtime
WORKDIR /workspace

# HACK: Create .claude.json to skip onboarding when using CLAUDE_CODE_OAUTH_TOKEN
# See: https://github.com/anthropics/claude-code/issues/8938
RUN echo '{"hasCompletedOnboarding":true}' > /home/$USERNAME/.claude.json

# Default: interactive session with permissions skipped
ENTRYPOINT ["claude"]
CMD ["--dangerously-skip-permissions"]
