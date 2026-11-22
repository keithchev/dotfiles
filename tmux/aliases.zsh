# `tmux ls` / `tmux list-sessions` with no extra args: show each session's cwd
# (the format is defined as @ls-format in tmux.conf)
function tmux() {
  if [[ ( "$1" == "ls" || "$1" == "list-sessions" ) && $# -eq 1 ]]; then
    local fmt
    fmt=$(command tmux show -gqv @ls-format 2>/dev/null)
    if [[ -n "$fmt" ]]; then
      command tmux list-sessions -F "$fmt"
      return
    fi
  fi
  command tmux "$@"
}

# tt: open the session/window tree (same as prefix + s), from inside or outside tmux
function tt() {
  local tree=(choose-tree -Zs -O name -F '#{E:@tree-format}')
  if [[ -n "$TMUX" ]]; then
    command tmux "${tree[@]}"
  elif command tmux has-session 2>/dev/null; then
    command tmux attach \; "${tree[@]}"
  else
    echo "tt: no tmux sessions running" >&2
    return 1
  fi
}
