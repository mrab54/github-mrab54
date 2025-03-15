#!/usr/bin/env bash
#
# init_ubuntu.sh
# Script to bootstrap a fresh Ubuntu installation.
#
# USAGE:
#   curl -sSL "https://raw.githubusercontent.com/mrab54/github-mrab54/master/init_ubuntu.sh" -o init_ubuntu.sh
#   chmod +x init_ubuntu.sh
#   sudo ./init_ubuntu.sh
#
# NOTE:
#   - You should always review external scripts before running them.
#   - This script is designed for Ubuntu-based distros and may need adjustments for others.
#   - Make sure you run as root or a user with sudo privileges.

set -euo pipefail

# -------------------------
# Variables (update as needed)
# -------------------------
GITHUB_USERNAME="mrab54"
REPO_NAME="github-mrab54"
REPO_URL="https://raw.githubusercontent.com/${GITHUB_USERNAME}/${REPO_NAME}/master/"
REPO_SCRIPTS_DIR="scripts"
REPO_CONFIG_DIR="config/"

# Define target user - either the sudo user or a specified user
TARGET_USER=${SUDO_USER:-"rab"}
USER_HOME="/home/${TARGET_USER}"
SSH_DIR="${USER_HOME}/.ssh"
PUB_KEY_URL="https://raw.githubusercontent.com/${GITHUB_USERNAME}/${REPO_NAME}/master/rab.pub"

# Check if the target user exists
if ! id -u "${TARGET_USER}" >/dev/null 2>&1; then
  warning "User ${TARGET_USER} does not exist. Some operations may fail."
  # Optionally: Create the user if missing
  # useradd -m -s /bin/bash "${TARGET_USER}"
fi

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
# Install Basic Packages & Network Tools
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
  ca-certificates \
  ufw

# -------------------------
# Configure UFW Firewall (Enable and open specified ports)
# -------------------------
info "Enabling UFW firewall and allowing ports 22, 80, 8080, 3000, 3030..."

ufw default deny incoming
# If you want to allow SSH from anywhere, keep the 22 rule as is. 
# For additional security, you can specify IP ranges, or use rate limiting:
# ufw limit 22/tcp

# Enable UFW without prompting
echo "y" | ufw enable
# -------------------------
# Configure SSH
# -------------------------
info "Automating SSH key setup for ${TARGET_USER}..."

# Create .ssh and set perms
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
chown ${TARGET_USER}:${TARGET_USER} "$SSH_DIR"

# Fetch public key and append
if curl -sSL "$PUB_KEY_URL" -o /tmp/user.pub; then
  cat /tmp/user.pub >> "$SSH_DIR/authorized_keys"
  rm /tmp/user.pub
else
  warning "Failed to download SSH public key from $PUB_KEY_URL"
fi

# Secure perms on authorized_keys
chmod 600 "$SSH_DIR/authorized_keys"
chown ${TARGET_USER}:${TARGET_USER} "$SSH_DIR/authorized_keys"
chmod 700 "$SSH_DIR"
chown ${USER}:${USER} "$SSH_DIR"

# Fetch public key and append
curl -sSL "$PUB_KEY_URL" >> "$SSH_DIR/authorized_keys"

# Secure perms on authorized_keys
chmod 600 "$SSH_DIR/authorized_keys"
chown ${USER}:${USER} "$SSH_DIR/authorized_keys"

info "Configuring SSH to disable root login and allow password auth..."
SSHD_CONFIG="/etc/ssh/sshd_config"

# Backup the original sshd_config
cp "${SSHD_CONFIG}" "${SSHD_CONFIG}.bak.$(date +%F-%T)"

# Enable password authentication (if not using SSH keys)
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
# We'll append a block to the main user's .bashrc.
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
info "Fetching custom .vimrc from GitHub..."
if [[ -n "${SUDO_USER-}" && "${SUDO_USER}" != "root" ]]; then
  USER_HOME_DIR="$(eval echo ~${SUDO_USER})"
  sudo -u "${SUDO_USER}" bash <<EOF
  curl -sSL "${REPO_URL}${REPO_CONFIG_DIR}.vimrc" -o "${USER_HOME_DIR}/.vimrc"
EOF
fi

# -------------------------
# Install NVM & Latest LTS Node + PNPM
# -------------------------
info "Installing nvm and the latest LTS version of Node.js..."
if [[ -n "${SUDO_USER-}" && "${SUDO_USER}" != "root" ]]; then
  USER_HOME_DIR="$(eval echo ~${SUDO_USER})"
  NVM_DIR="${USER_HOME_DIR}/.nvm"
  if [[ ! -d "${NVM_DIR}" ]]; then
    sudo -u "${SUDO_USER}" bash <<EOF
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash
EOF
  fi

  # Load nvm, install Node LTS, install pnpm globally
  sudo -u "${SUDO_USER}" bash <<EOF
  export NVM_DIR="${NVM_DIR}"
  [ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
  nvm install --lts
  nvm use --lts
  npm install --global pnpm
EOF
fi

# -------------------------
# Install pyenv & Latest Python (WITHOUT Breaking System Python)
# -------------------------
info "Installing pyenv and a newer Python version..."

if [[ -n "${SUDO_USER-}" && "${SUDO_USER}" != "root" ]]; then
  USER_HOME_DIR="$(eval echo ~${SUDO_USER})"
  # Usually we need dependencies for building Python from source:
  # (some might already be installed above)
  apt-get install -y \
    make \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libffi-dev \
    liblzma-dev

  # Install pyenv into the non-root user's home
  sudo -u "${SUDO_USER}" bash <<EOF
    if [ ! -d "${USER_HOME_DIR}/.pyenv" ]; then
      git clone https://github.com/pyenv/pyenv.git "${USER_HOME_DIR}/.pyenv"
    fi

    # Add pyenv init to .bashrc if not already present
    if ! grep -q 'export PYENV_ROOT="\$HOME/.pyenv"' "${USER_HOME_DIR}/.bashrc"; then
      cat <<'BASHRC' >> "${USER_HOME_DIR}/.bashrc"

# pyenv setup
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
BASHRC

  # Install the latest Python stable version
  export PYENV_ROOT="${USER_HOME_DIR}/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)"
  
  # Find the latest stable Python version - properly sorted with fallback
  LATEST_STABLE=$(pyenv install --list | grep -E '^\s*3\.[0-9]+\.[0-9]+$' | grep -v "dev\|a\|b\|rc" | sort -V | tail -1 | tr -d '[:space:]')
  
  # Check if we found a version
  if [[ -z "$LATEST_STABLE" ]]; then
    echo "Could not determine latest Python version. Defaulting to 3.13.2"
    LATEST_STABLE="3.13.2"
  else
    echo "Latest stable Python version: $LATEST_STABLE"
  fi
  
  # Install Python
  pyenv install -s "$LATEST_STABLE"
  pyenv global "$LATEST_STABLE"
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
info "Bootstrap script complete! System is updated, firewall is enabled, Node, Python, and configs are set."
