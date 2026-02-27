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
# Usage: claude-docker [workspace] [-- claude-args...]
#   cdock .        -- --resume      → claude --dangerously-skip-permissions --resume
#   cdock ~/myproj -- mcp add foo   → claude mcp add foo
function claude-docker() {
  _load_claude_credentials || return 1
  _ensure_claude_docker_image || return 1

  local workspace="."
  local -a claude_args=()

  # Parse arguments: positional args before --, claude args after --
  local parsing_ours=true
  local positional=0
  for arg in "$@"; do
    if [[ "$arg" == "--" ]]; then
      parsing_ours=false
      continue
    fi
    if $parsing_ours; then
      case $positional in
        0) workspace="$arg" ;;
      esac
      ((positional++))
    else
      claude_args+=("$arg")
    fi
  done

  local abs_workspace
  abs_workspace="$(cd "$workspace" && pwd)"
  local workspace_name="${abs_workspace:t}"

  local -a cmd=(
    docker run -it --rm
    --add-host host.docker.internal:host-gateway
    -v "$abs_workspace":/workspace/"$workspace_name":rw
    -w /workspace/"$workspace_name"
    -v "$HOME/.claude":/home/claude/.claude:rw
    -e CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_CODE_OAUTH_TOKEN"
    claude-code:local
  )

  if (( ${#claude_args[@]} > 0 )); then
    # Flags (--resume, etc): prepend --dangerously-skip-permissions
    # Subcommands (mcp add, etc): pass through as-is
    if [[ "${claude_args[1]}" == -* ]]; then
      cmd+=(--dangerously-skip-permissions)
    fi
    cmd+=("${claude_args[@]}")
  fi
  # No extra args → Dockerfile CMD provides --dangerously-skip-permissions

  "${cmd[@]}"
}

# Run Claude Code in the current directory
# Usage: claude-docker-here [-- claude-args...]
function claude-docker-here() {
  claude-docker "$(pwd)" "$@"
}

# Run Claude Code in a specific project directory
# Usage: claude-docker-project <project-name> [-- claude-args...]
function claude-docker-project() {
  if [ -z "$1" ]; then
    echo "Usage: claude-docker-project <project-name> [-- claude-args...]" >&2
    return 1
  fi

  local project_name="$1"
  shift

  local project_path="$PROJECTS/$project_name"

  if [ ! -d "$project_path" ]; then
    echo "Project directory not found: $project_path" >&2
    return 1
  fi

  claude-docker "$project_path" "$@"
}

# Rebuild the Claude Code Docker image
function claude-docker-rebuild() {
  echo "Rebuilding Claude Code Docker image..." >&2
  docker build -t claude-code:local \
    --build-arg USER_UID=$(id -u) \
    --build-arg USER_GID=$(id -g) \
    "$HOME/projects/dotfiles/claude" || return 1
}

alias cdock='claude-docker'
alias cdock-here='claude-docker-here'
alias cdock-project='claude-docker-project'
alias cdock-rebuild='claude-docker-rebuild'
