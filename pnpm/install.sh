#!/usr/bin/env bash
#
# Install pnpm config

set -e

DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"

case "$(uname -s)" in
  Darwin)
    PNPM_CONFIG_DIR="$HOME/Library/Preferences/pnpm"
    ;;
  *)
    PNPM_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/pnpm"
    ;;
esac

mkdir -p "$PNPM_CONFIG_DIR"
ln -sf "$DOTFILES_ROOT/pnpm/config.yaml" "$PNPM_CONFIG_DIR/config.yaml"
