#!/usr/bin/env bash
#
# Install uv config

set -e

DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
UV_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/uv"

mkdir -p "$UV_CONFIG_DIR"
ln -sf "$DOTFILES_ROOT/uv/uv.toml" "$UV_CONFIG_DIR/uv.toml"
