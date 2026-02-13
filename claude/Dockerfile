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
    && rm -rf /var/lib/apt/lists/*

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

# Add to PATH
ENV PATH="/home/$USERNAME/.local/bin:$PATH"

# Set working directory for projects
WORKDIR /workspace

# HACK: Create .claude.json to skip onboarding when using CLAUDE_CODE_OAUTH_TOKEN
# See: https://github.com/anthropics/claude-code/issues/8938
RUN echo '{"hasCompletedOnboarding":true}' > /home/$USERNAME/.claude.json

# Default command
CMD ["claude", "--dangerously-skip-permissions"]
