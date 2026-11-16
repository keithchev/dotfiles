#!/usr/bin/env bash
# Set up a fresh Ubuntu 24.04 (arm64) EC2 instance like our dev box:
# apt packages, swap + earlyoom, dotfiles (minor-tweaks branch), oh-my-zsh, linuxbrew (eza, gh),
# nvm + node 26 + pnpm, uv + awscli, Claude Code, and tailscale (not logged in).
# Safe to re-run.
#
# Usage, from a machine with ssh access to the new box (e.g. after ec2-clone):
#   ssh <host> "GIT_NAME='$(git config user.name)' GIT_EMAIL='$(git config user.email)' bash -s" \
#     < $DOTFILES/aws/setup-dev-box.sh
#
# GitHub over ssh (needed under mosh, which doesn't forward the ssh agent):
# copy a GitHub key to the box first and this script adds the ssh config for it.
#   ssh 2026-dev-box 'cat ~/.ssh/keith-ed25519' | ssh <host> 'umask 077; cat > ~/.ssh/keith-ed25519'
# (Remember to delete it from the box if the box is handed off or terminated.)
#
# Afterwards, on the box: `sudo tailscale up`, `claude` (login), `gh auth login`.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
step() { echo; echo "=== $* ==="; }

step "apt packages"
sudo apt-get update -qq
sudo apt-get install -y -qq \
  zsh tmux vim mosh git curl jq unzip zip rsync dnsutils build-essential pkg-config \
  libssl-dev python3-dev fuse3 bubblewrap libgeos-dev libproj-dev proj-bin htop \
  xvfb xfonts-scalable xfonts-cyrillic fonts-liberation fonts-noto-color-emoji \
  fonts-freefont-ttf fonts-ipafont-gothic fonts-tlwg-loma-otf fonts-unifont fonts-wqy-zenhei \
  libnss3 libnspr4 libatk1.0-0t64 libatk-bridge2.0-0t64 libcups2t64 libdrm2 libgbm1 \
  libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libpango-1.0-0 \
  libcairo2 libasound2t64 libatspi2.0-0t64 >/dev/null

step "swap + earlyoom"
# Without swap, memory pressure makes the box thrash (sshd stops answering)
# instead of OOM-killing anything. Swap buys headroom, and earlyoom kills the
# largest process well before the kernel gets stuck.
SWAP_SIZE="${SWAP_SIZE:-4G}"
if ! sudo swapon --show=NAME --noheadings | grep -qx /swapfile; then
  [ -f /swapfile ] || { sudo fallocate -l "$SWAP_SIZE" /swapfile && sudo chmod 600 /swapfile && sudo mkswap -q /swapfile; }
  sudo swapon /swapfile
fi
grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
# Prefer dropping page cache over swapping out the apps in use.
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf >/dev/null
sudo sysctl -q -p /etc/sysctl.d/99-swappiness.conf
sudo apt-get install -y -qq earlyoom >/dev/null
# Kill when available memory < 5% and swap free < 10%; never kill the
# processes that keep the box reachable.
sudo tee /etc/default/earlyoom >/dev/null <<'EOF'
EARLYOOM_ARGS="-m 5 -s 10 -r 3600 --avoid '^(sshd|mosh-server|tailscaled|systemd|systemd-journal)$' --prefer '^(python3?|uvicorn)$'"
EOF
sudo systemctl enable -q earlyoom
sudo systemctl restart earlyoom

step "tailscale (installed, not logged in)"
command -v tailscale >/dev/null || curl -fsSL https://tailscale.com/install.sh | sh

step "github ssh"
mkdir -p ~/.ssh && chmod 700 ~/.ssh
if [ -f ~/.ssh/keith-ed25519 ]; then
  chmod 600 ~/.ssh/keith-ed25519
  grep -q '^Host github.com' ~/.ssh/config 2>/dev/null || \
    printf 'Host github.com\n    IdentityFile ~/.ssh/keith-ed25519\n    IdentitiesOnly yes\n' >> ~/.ssh/config
  chmod 600 ~/.ssh/config
else
  echo "no ~/.ssh/keith-ed25519; skipping (see header to copy it)"
fi
ssh-keygen -F github.com >/dev/null || ssh-keyscan -t ed25519 github.com 2>/dev/null >> ~/.ssh/known_hosts

step "dotfiles"
mkdir -p ~/projects
if [ ! -d ~/projects/dotfiles ]; then
  git clone -q -b minor-tweaks https://github.com/keithchev/dotfiles.git ~/projects/dotfiles
  git -C ~/projects/dotfiles remote set-url origin git@github.com:keithchev/dotfiles
fi

step "oh-my-zsh"
if [ ! -d ~/.oh-my-zsh ]; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

step "link dotfiles (script/bootstrap)"
# Replace default rc files with the dotfiles' symlinks.
for f in .zshrc .gitconfig .gitignore .npmrc .tmux.conf .bunfig.toml; do
  [ -e ~/$f ] && [ ! -L ~/$f ] && mv ~/$f ~/$f.pre-dotfiles
done
echo O | ~/projects/dotfiles/script/bootstrap
if [ ! -f ~/.gitconfig.local ] && [ -n "${GIT_NAME:-}" ] && [ -n "${GIT_EMAIL:-}" ]; then
  printf '[user]\n\tname = %s\n\temail = %s\n' "$GIT_NAME" "$GIT_EMAIL" > ~/.gitconfig.local
fi
sudo chsh -s /usr/bin/zsh "$USER"

step "linuxbrew + eza gh"
if [ ! -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  NONINTERACTIVE=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
brew install -q eza gh

step "nvm + node 26 + pnpm"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] || PROFILE=/dev/null bash -c "$(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh)"
set +u; . "$NVM_DIR/nvm.sh"; nvm install 26 >/dev/null; nvm alias default 26 >/dev/null; set -u
npm install -g pnpm >/dev/null

step "uv + awscli"
command -v ~/.local/bin/uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh
~/.local/bin/uv tool install -q awscli || true

step "claude code"
[ -x ~/.local/bin/claude ] || curl -fsSL https://claude.ai/install.sh | bash

step "done"
