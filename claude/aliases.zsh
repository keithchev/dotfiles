# Load Claude OAuth token from dotfiles/.env if not already set
function _load_claude_credentials() {
  if [ -z "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
    local dotfiles_env="$HOME/projects/dotfiles/.env"
    if [ -f "$dotfiles_env" ]; then
      export CLAUDE_CODE_OAUTH_TOKEN=$(grep -E '^CLAUDE_CODE_OAUTH_TOKEN=' "$dotfiles_env" | cut -d '=' -f 2- | tr -d '"' | tr -d "'")
    fi

    if [ -z "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
      echo "Error: CLAUDE_CODE_OAUTH_TOKEN not found in environment or $dotfiles_env" >&2
      echo "Please create $dotfiles_env with: CLAUDE_CODE_OAUTH_TOKEN=your_token_here" >&2
      return 1
    fi
  fi
  return 0
}

# Run Claude Code in a Docker container
# This allows running Claude Code without installing it locally
function claude-docker() {
  _load_claude_credentials || return 1

  local workspace="${1:-.}"
  local output="${2:-/tmp/claude-output}"

  # Create output directory if it doesn't exist
  mkdir -p "$output"

  docker run -it --rm \
    --user "$(id -u):$(id -g)" \
    -v "$(cd "$workspace" && pwd)":/workspace:rw \
    -v "$output":/output:rw \
    -v "$HOME/.claude":/tmp/.claude:rw \
    -e CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_CODE_OAUTH_TOKEN" \
    -e HOME=/tmp \
    node:20 bash -c "echo '{\"hasCompletedOnboarding\":true}' > /tmp/.claude.json && cd /workspace && npx -y @anthropic-ai/claude-code --dangerously-skip-permissions"
}

# Run Claude Code in the current directory
function claude-docker-here() {
  claude-docker "$(pwd)" "${1:-/tmp/claude-output}"
}

# Run Claude Code in a specific project directory
# Usage: claude-docker-project <project-name>
function claude-docker-project() {
  if [ -z "$1" ]; then
    echo "Usage: claude-docker-project <project-name>" >&2
    return 1
  fi

  local project_path="$PROJECTS/$1"

  if [ ! -d "$project_path" ]; then
    echo "Project directory not found: $project_path" >&2
    return 1
  fi

  claude-docker "$project_path" "/tmp/claude-output-$1"
}

alias cdock='claude-docker'
alias cdock-here='claude-docker-here'
alias cdock-project='claude-docker-project'
