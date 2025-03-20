#!/usr/bin/env bash
#
# init_ubuntu.sh - Corrected and Simplified
#
# Bootstraps an Ubuntu system, setting configurations for the user who invoked sudo.

set -euo pipefail

# Variables
GITHUB_USERNAME="mrab54"
REPO_NAME="github-mrab54"
REPO_URL="https://raw.githubusercontent.com/${GITHUB_USERNAME}/${REPO_NAME}/master"
REPO_SCRIPTS_DIR="scripts"
REPO_CONFIG_DIR="config"

# --- Get the Target User (the user who invoked sudo) ---
# SUDO_USER is set by sudo to the original user.  This is what we want.
# If SUDO_USER is not set (which would be unusual), we exit with an error.
if [[ -z "${SUDO_USER}" ]]; then
  echo "ERROR: SUDO_USER is not set.  This script must be run with sudo." >&2
  exit 1
fi

TARGET_USER="${SUDO_USER}"
USER_HOME="/home/${TARGET_USER}"
SSH_DIR="${USER_HOME}/.ssh"
PUB_KEY_URL="${REPO_URL}/${REPO_CONFIG_DIR}/rab.pub"
# PUB_KEY_URL="https://raw.githubusercontent.com/${GITHUB_USERNAME}/${REPO_NAME}/master/rab.pub"


# Helper functions
info()    { echo -e "\e[34m[INFO]\e[0m  $*"; }
warning() { echo -e "\e[33m[WARN]\e[0m  $*"; }
error()   { echo -e "\e[31m[ERROR]\e[0m $*" >&2; }

# Check if root/sudo (This is redundant now, but harmless)
if [[ $EUID -ne 0 ]]; then
  error "This script must be run with sudo or as root." # This should never happen
  exit 1
fi

# --- Debugging: Echo Variables ---
echo "----------------------------------------"
echo "Debugging Variables:"
echo "  GITHUB_USERNAME: ${GITHUB_USERNAME}"
echo "  REPO_NAME: ${REPO_NAME}"
echo "  REPO_URL: ${REPO_URL}"
echo "  REPO_SCRIPTS_DIR: ${REPO_SCRIPTS_DIR}"
echo "  REPO_CONFIG_DIR: ${REPO_CONFIG_DIR}"
echo "  SUDO_USER: ${SUDO_USER}"
echo "  TARGET_USER: ${TARGET_USER}"
echo "  USER_HOME: ${USER_HOME}"
echo "  SSH_DIR: ${SSH_DIR}"
echo "  PUB_KEY_URL: ${PUB_KEY_URL}"
echo "----------------------------------------"

# Check/create user
if ! id -u "${TARGET_USER}" >/dev/null 2>&1; then
  warning "User ${TARGET_USER} does not exist.  Creating..."
  adduser --system --group --home "${USER_HOME}" "${TARGET_USER}" || {
    error "Failed to create user ${TARGET_USER}."
    exit 1
  }
fi

# Ensure the user's home directory has correct ownership.
chown -R "${TARGET_USER}:${TARGET_USER}" "${USER_HOME}"

# Update package list
info "Updating package list..."
add-apt-repository universe
add-apt-repository multiverse
apt update
apt-get update -y

# --- Record pre-upgrade package state ---
info "Recording pre-upgrade package state..."
dpkg --get-selections > /tmp/pre_upgrade_packages

# Upgrade packages
info "Upgrading packages..."
apt-get upgrade -y

# --- Record post-upgrade package state and compare ---
info "Recording post-upgrade package state and comparing..."
dpkg --get-selections > /tmp/post_upgrade_packages

if ! diff -q /tmp/pre_upgrade_packages /tmp/post_upgrade_packages >/dev/null 2>&1; then
  info "Package upgrade performed changes:"
  diff -u /tmp/pre_upgrade_packages /tmp/post_upgrade_packages
else
  info "Package upgrade did not make any changes."
fi

# Clean up temporary files
rm /tmp/pre_upgrade_packages /tmp/post_upgrade_packages


# Install packages
info "Installing packages..."



apt-get install -y \
  nasm yasm curl wget git jq vim neovim tmux traceroute net-tools iputils-ping \
  tcpdump nmap dnsutils whois build-essential software-properties-common \
  htop ca-certificates ufw make libssl-dev zlib1g-dev libbz2-dev \
  libreadline-dev libsqlite3-dev libffi-dev liblzma-dev postgresql \
  postgresql-contrib libpq-dev python3-dev glances libgl1 \
  autoconf automake build-essential cmake git libtool pkg-config texinfo \
  libass-dev libfreetype6-dev libgnutls28-dev libvorbis-dev libx264-dev libx265-dev libnuma-dev \
  libvpx-dev libfdk-aac-dev libmp3lame-dev libopus-dev libunistring-dev libdrm-dev \
  autoconf automake build-essential cmake git libtool pkg-config texinfo \
  curl wget yasm nasm libunistring-dev libssl-dev libgnutls28-dev \
  libdrm-dev libxext-dev libxfixes-dev zlib1g-dev libxml2-dev libfreetype6-dev \
  libfribidi-dev libfontconfig1-dev libass-dev libvorbis-dev libxvidcore-dev \
  libx264-dev libx265-dev libnuma-dev libvpx-dev libmp3lame-dev libopus-dev \
  libtheora-dev libwebp-dev libspeex-dev libtesseract-dev \
  libdav1d-dev libaom-dev libgme-dev libbluray-dev libvulkan-dev \
  liblzma-dev libzimg-dev libzvbi-dev librsvg2-dev libvidstab-dev libsoxr-dev \
  libmodplug-dev libopenmpt-dev libssh-dev libvidstab-dev \
  frei0r-plugins-dev libaribb24-dev libcdio-dev libcdio++-dev libdvdread-dev \
  libdvdnav-dev libtiff-dev libpng-dev libsnappy-dev libfdk-aac-dev \
  libbrotli-dev libopenjp2-7 libopenjp2-7-dev librtmp-dev pkg-config tesseract-ocr \
  libtesseract-dev libleptonica-dev libgif-dev libtwolame-dev meson ninja-build \
  doxygen libzmq3-dev libcdio-paranoia-dev vulkan-tools libvulkan-dev \
  spirv-tools glslang-dev

  # apt-get install -y nvidia-cuda-toolkit

# Install Rust for the target user
info "SKIPPING !!! Installing Rust for ${TARGET_USER}..."
#sudo -u "${TARGET_USER}" bash -c 'curl https://sh.rustup.rs -sSf | sh -s -- -y'

# UFW setup
info "Configuring UFW firewall..."
ufw default deny incoming
for port in 22 80 8080 3000 3030; do
    if ! ufw status | grep -q " ${port}/tcp.*ALLOW"; then
       ufw allow "${port}"/tcp
    fi
done
echo "y" | ufw enable

# SSH setup
info "Configuring SSH..."
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
chown "${TARGET_USER}:${TARGET_USER}" "$SSH_DIR"

# Idempotent SSH key addition
if ! curl -sSL "$PUB_KEY_URL" -o /tmp/user.pub; then
  warning "Failed to download SSH public key."
else
  NEW_KEY=$(cat /tmp/user.pub)
  if ! grep -qF "$NEW_KEY" "$SSH_DIR/authorized_keys"; then
    echo "$NEW_KEY" >> "$SSH_DIR/authorized_keys"
  fi
  rm /tmp/user.pub
  chmod 600 "$SSH_DIR/authorized_keys"
  chown "${TARGET_USER}:${TARGET_USER}" "$SSH_DIR/authorized_keys"
fi

SSHD_CONFIG="/etc/ssh/sshd_config"
cp "${SSHD_CONFIG}" "${SSHD_CONFIG}.bak.$(date +%F-%T)"

# Idempotent sed replacements
sed -i -E -e '/PasswordAuthentication[[:space:]]+(yes|no)/s/(PasswordAuthentication[[:space:]]+)(yes|no)/\1yes/' \
       -e '/PermitRootLogin[[:space:]]+(yes|no|prohibit-password)/s/(PermitRootLogin[[:space:]]+)(yes|no|prohibit-password)/\1no/' \
       -e '/UsePAM[[:space:]]+(yes|no)/s/(UsePAM[[:space:]]+)(yes|no)/\1yes/' "${SSHD_CONFIG}"

systemctl restart ssh

# --- Persistent History (Idempotent) ---
info "Configuring persistent shell history for ${TARGET_USER}..."
sudo -u "${TARGET_USER}" bash <<'EOF'
if ! grep -q "Persistent History" "$HOME/.bashrc"; then
  cat <<'INNER_EOF' >> "$HOME/.bashrc"

# -------------- Persistent History --------------
# Append to history, don't overwrite
shopt -s histappend

# Save and reload after each command
PROMPT_COMMAND="history -a; history -n"

# Bigger history limits
export HISTSIZE=100000
export HISTFILESIZE=100000
INNER_EOF
fi
EOF

# --- .vimrc (Simplified - Always Overwrite) ---
info "Fetching and overwriting custom .vimrc from GitHub..."
info "TARGET_USER: ${TARGET_USER} REPO_URL: ${REPO_URL} REPO_CONFIG_DIR: ${REPO_CONFIG_DIR} HOME: $USER_HOME"
sudo -u "${TARGET_USER}" bash -c "curl -sSL '${REPO_URL}/${REPO_CONFIG_DIR}/.vimrc' -o '$USER_HOME/.vimrc'"

info "Setting alias vi='vim' in ${TARGET_USER}'s .bashrc if it does not exist..."
sudo -u "${TARGET_USER}" bash <<'EOF'
if ! grep -q "alias vi='vim'" "$HOME/.bashrc"; then
  echo "alias vi='vim'" >> "$HOME/.bashrc"
fi
EOF


# NPM/NVM
info "Installing nvm, pnpm, and Node.js LTS..."

sudo -u "${TARGET_USER}" bash <<'EOF'
# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash

# Load nvm (this is for the current subshell)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

nvm install --lts
nvm use --lts

# Install pnpm
curl -fsSL https://get.pnpm.io/install.sh | sh -
# Persist pnpm env variables
if ! grep -q 'export PNPM_HOME=' "$HOME/.bashrc"; then
  cat <<'BASHRC' >> "$HOME/.bashrc"

# ---- pnpm setup ----
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
eval "$(pnpm env use --shell bash)"
BASHRC
fi

# For the current shell, do the same
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

# Setting up pnpm environment so the global bin directory is created
pnpm setup

# Example: install yarn globally via pnpm
pnpm add --global yarn
EOF


# --- pyenv (Idempotent) ---
info "Installing pyenv and a newer Python version..."
sudo -u "${TARGET_USER}" bash <<'EOF'
set -euo pipefail

# 1. Install pyenv if it's not already installed
if [ ! -d "$HOME/.pyenv" ]; then
  echo "Pyenv not found, installing pyenv..."
  curl https://pyenv.run | bash             # Install pyenv automatically
  # You might also need to install build dependencies for Python here, e.g. using apt or yum
fi

# 2. Set up pyenv environment variables for this script
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"

# 3. Initialize pyenv in the current shell session
if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init -)"  # Load pyenv shim scripts and functions&#8203;:contentReference[oaicite:6]{index=6}
  # If using pyenv-virtualenv, also do: eval "$(pyenv virtualenv-init -)"
else
  echo "ERROR: pyenv command not found on PATH. Check that installation succeeded and PATH is set."
  exit 1
fi

# 4. Determine the latest stable Python version available
# Using pyenv plugin (if installed):
# latest_python_version=$(pyenv latest install)   # This requires the 'pyenv latest' plugin
#
# Or without plugin, parse the list of installable versions:
latest_python_version=$(pyenv install -l | grep -E '^[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+$' | tail -1)
echo "Latest stable Python version is $latest_python_version"

# 5. Install the latest stable Python using pyenv
pyenv install "$latest_python_version"

# (Optional) Set this version as the global default
pyenv global "$latest_python_version"

echo "Pyenv has been initialized and Python $latest_python_version is installed."
EOF

# --- Clean Up ---
info "Cleaning up..."
apt-get autoremove -y
apt-get autoclean -y

info "Bootstrap script complete (with upgrade)!"