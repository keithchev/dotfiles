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

# Build Claude Code Docker image if it doesn't exist
function _ensure_claude_docker_image() {
  if ! docker image inspect claude-code:local >/dev/null 2>&1; then
    echo "Building Claude Code Docker image..." >&2
    docker build -t claude-code:local \
      --build-arg USER_UID=$(id -u) \
      --build-arg USER_GID=$(id -g) \
      "$HOME/projects/dotfiles/claude" || return 1
  fi
  return 0
}

# Run Claude Code in a Docker container
# This allows running Claude Code without installing it locally
function claude-docker() {
  _load_claude_credentials || return 1
  _ensure_claude_docker_image || return 1

  local workspace="${1:-.}"
  local output="${2:-/tmp/claude-output}"

  # Create output directory if it doesn't exist
  mkdir -p "$output"

  docker run -it --rm \
    -v "$(cd "$workspace" && pwd)":/workspace:rw \
    -v "$output":/output:rw \
    -v "$HOME/.claude":/home/claude/.claude:rw \
    -e CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_CODE_OAUTH_TOKEN" \
    claude-code:local
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
