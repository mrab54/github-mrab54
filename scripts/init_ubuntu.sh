#!/usr/bin/env bash
#
# init_ubuntu.sh
# Script to bootstrap a fresh Ubuntu installation.
# 
# USAGE:
#   curl -sSL "https://raw.githubusercontent.com/mrab54/github-mrab54/refs/heads/master/scripts/init_ubuntu.sh" -o init_ubuntu.sh
#   chmod +x init_ubuntu.sh
#   sudo ./init_ubuntu.sh
#
# NOTE:
#   - You should always review external scripts before running them.
#   - This script is designed for Ubuntu-based distros and may need adjustments for others.
#   - Make sure you run as root or a user with sudo privileges.

set -euo pipefail

# -------------------------
# Variables
# -------------------------
GITHUB_USERNAME="mrab54"
REPO_NAME="github-mrab54"
REPO_URL="https://raw.githubusercontent.com/mrab54/github-mrab54/refs/heads/master"
REPO_SCRIPTS_DIR="scripts"
REPO_CONFIG_DIR="config/"

# -------------------------
# Helper functions
# -------------------------
info()    { echo -e "\e[34m[INFO]\e[0m  $*"; }
warning() { echo -e "\e[33m[WARN]\e[0m  $*"; }
error()   { echo -e "\e[31m[ERROR]\e[0m $*" >&2; }

# Check if script is run as root or with sudo
if [[ $EUID -ne 0 ]]; then
  error "This script must be run with sudo or as root."
  exit 1
fi

# -------------------------
# Update & Upgrade System
# -------------------------
info "Updating and upgrading the system..."
apt-get update -y
apt-get upgrade -y

# -------------------------
# Disable UFW Firewall (if installed and enabled)
# -------------------------
if command -v ufw &> /dev/null; then
  info "Disabling ufw firewall..."
  ufw disable || true
fi

# -------------------------
# Install Basic & Network Tools
# -------------------------
info "Installing base utilities, network tools, and development packages..."
apt-get install -y \
  curl \
  wget \
  git \
  jq \
  vim \
  neovim \
  tmux \
  traceroute \
  net-tools \
  iputils-ping \
  tcpdump \
  nmap \
  dnsutils \
  whois \
  build-essential \
  software-properties-common \
  htop \
  ca-certificates

# -------------------------
# Configure SSH
# -------------------------
info "Configuring SSH to disable root login and allow password auth..."
SSHD_CONFIG="/etc/ssh/sshd_config"

# Backup the original sshd_config
cp "${SSHD_CONFIG}" "${SSHD_CONFIG}.bak.$(date +%F-%T)"

# Enable password authentication
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/g' "${SSHD_CONFIG}"
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/g' "${SSHD_CONFIG}"

# Disable root login
sed -i 's/^PermitRootLogin yes/PermitRootLogin no/g' "${SSHD_CONFIG}"
sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin no/g' "${SSHD_CONFIG}"

# Ensure UsePAM is yes
sed -i 's/^#UsePAM yes/UsePAM yes/g' "${SSHD_CONFIG}"

systemctl restart ssh

# -------------------------
# Persist Shell History Across Sessions
# -------------------------
# We'll append a small block to each user's .bashrc to append/read history correctly.
# This is typically done for the "main" sudo user, so we attempt to detect that.

if [[ -n "${SUDO_USER-}" && "${SUDO_USER}" != "root" ]]; then
  USER_HOME_DIR="$(eval echo ~${SUDO_USER})"
  BASHRC="${USER_HOME_DIR}/.bashrc"
  info "Configuring persistent shell history in ${BASHRC}..."

  cat << 'EOF' >> "${BASHRC}"

# -------------- Persistent History --------------
# Append to history, don't overwrite
shopt -s histappend

# Save and reload the history after each command
# so multiple terminals and sessions stay in sync.
PROMPT_COMMAND="history -a; history -n; $PROMPT_COMMAND"

# Set bigger history limits
export HISTSIZE=100000
export HISTFILESIZE=100000
EOF
fi

# -------------------------
# Fetch Custom .vimrc
# -------------------------
# Replace the URL with your own .vimrc location on GitHub
info "Fetching custom .vimrc from GitHub..."
if [[ -n "${SUDO_USER-}" && "${SUDO_USER}" != "root" ]]; then
  USER_HOME_DIR="$(eval echo ~${SUDO_USER})"
  sudo -u "${SUDO_USER}" bash <<EOF
  curl -sSL "${REPO_URL}${REPO_CONFIG_DIR}.vimrc" -o "${USER_HOME_DIR}/.vimrc"
EOF
fi

# -------------------------
# Install NVM & Latest LTS Node
# -------------------------
info "Installing nvm and the latest LTS version of Node.js..."

# Install nvm only if it's not already present
if [[ -n "${SUDO_USER-}" && "${SUDO_USER}" != "root" ]]; then
  USER_HOME_DIR="$(eval echo ~${SUDO_USER})"
  NVM_DIR="${USER_HOME_DIR}/.nvm"
  if [[ ! -d "${NVM_DIR}" ]]; then
    # Download and run nvm install script as the sudo user
    sudo -u "${SUDO_USER}" bash <<EOF
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash
EOF
  fi

  # Load nvm in current shell, install Node (LTS), install pnpm
  sudo -u "${SUDO_USER}" bash <<EOF
  export NVM_DIR="${NVM_DIR}"
  [ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
  nvm install --lts
  nvm use --lts
  npm install --global pnpm
EOF
fi

# -------------------------
# Clean Up
# -------------------------
info "Cleaning up..."
apt-get autoremove -y
apt-get autoclean -y

# -------------------------
# Done
# -------------------------
info "Bootstrap script complete! System is updated, apps are installed, and configs are set."
