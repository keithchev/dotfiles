#!/bin/bash
# Status line modeled on the oh-my-zsh "ys" theme:
# # DIR on git:BRANCH STATE | DURATION | $COST | CTX% [TIME]
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

dir="${cwd/#$HOME/~}"
now=$(date +%H:%M:%S)

out=$(printf '\033[1;34m#\033[0m \033[1;33m%s\033[0m' "$dir")

branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null \
  || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
if [ -n "$branch" ]; then
  if [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
    state=$(printf ' \033[31mx\033[0m')
  else
    state=$(printf ' \033[32mo\033[0m')
  fi
  out="$out$(printf ' on \033[34mgit\033[0m:\033[36m%s\033[0m' "$branch")$state"
fi

if [ -n "$VIRTUAL_ENV" ]; then
  out="$out$(printf ' \033[32m%s\033[0m' "$(basename "$VIRTUAL_ENV")")"
fi

# Session start date and wall-clock duration
if [ -n "$duration_ms" ]; then
  s=$(( ${duration_ms%.*} / 1000 ))
  # `date -r <epoch>` is BSD/macOS syntax; on GNU/Linux (the Docker container)
  # -r means "read file mtime", so fall back to GNU's `-d @<epoch>`.
  epoch=$(( $(date +%s) - s ))
  start_date=$(date -r "$epoch" +%Y-%m-%d 2>/dev/null || date -d "@$epoch" +%Y-%m-%d 2>/dev/null)
  out="$out$(printf ' \033[2m|\033[0m \033[34m%s\033[0m' "$start_date")"
  h=$(( s / 3600 )); m=$(( s % 3600 / 60 )); s=$(( s % 60 ))
  if [ "$h" -gt 0 ]; then dur="${h}h${m}m"; else dur="${m}m${s}s"; fi
  out="$out$(printf ' \033[2m|\033[0m \033[35m%s\033[0m' "$dur")"
fi

# Session cost
if [ -n "$cost" ]; then
  out="$out$(printf ' \033[2m|\033[0m \033[33m$%.2f\033[0m' "$cost")"
fi

# Context window usage (green <50%, yellow <80%, red otherwise)
if [ -n "$ctx_pct" ]; then
  pct=$(printf '%.0f' "$ctx_pct")
  if [ "$pct" -lt 50 ]; then c=32; elif [ "$pct" -lt 80 ]; then c=33; else c=31; fi
  out="$out$(printf ' \033[2m|\033[0m \033[%smctx %s%%\033[0m' "$c" "$pct")"
fi

printf '%s [%s]' "$out" "$now"
