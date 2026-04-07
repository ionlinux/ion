#!/usr/bin/env bash
set -euo pipefail

locale-gen
chsh -s /bin/zsh root

# Install Oh My Zsh to skel so all users get it
export RUNZSH=no
export CHSH=no
export KEEP_ZSHRC=yes
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
mv /root/.oh-my-zsh /etc/skel/.oh-my-zsh

# Create default .zshrc for all users
cat > /etc/skel/.zshrc << 'ZSHRC'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git sudo)
source $ZSH/oh-my-zsh.sh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
ZSHRC

# Root gets a copy too
cp -r /etc/skel/.oh-my-zsh /root/.oh-my-zsh
cp /etc/skel/.zshrc /root/.zshrc
