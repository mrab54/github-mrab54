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
  curl wget git jq vim neovim tmux traceroute net-tools iputils-ping \
  tcpdump nmap dnsutils whois build-essential software-properties-common \
  htop ca-certificates ufw make libssl-dev zlib1g-dev libbz2-dev \
  libreadline-dev libsqlite3-dev libffi-dev liblzma-dev

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
PROMPT_COMMAND="history -a; history -n; \$PROMPT_COMMAND"

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


# --- NVM (Idempotent) ---
info "Installing nvm and Node.js LTS..."
sudo -u "${TARGET_USER}" bash <<EOF
    NVM_DIR="$HOME/.nvm"  # Use $HOME for the NVM directory
    if [[ ! -d "${NVM_DIR}" ]]; then
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash
    fi
    export NVM_DIR="${NVM_DIR}"
    [ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
    nvm install --lts
    nvm use --lts
    npm install --global pnpm
EOF

# --- pyenv (Idempotent) ---
info "Installing pyenv and a newer Python version..."
sudo -u "${TARGET_USER}" bash <<EOF
if [ ! -d "$HOME/.pyenv" ]; then
  git clone https://github.com/pyenv/pyenv.git "$HOME/.pyenv"
fi

# Use $HOME directly inside the here-document
if ! grep -q 'export PYENV_ROOT=' "$HOME/.pyenv"; then
  cat <<'BASHRC' >> "$HOME/.bashrc"

# pyenv setup
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
BASHRC
fi

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

LATEST_STABLE=$(pyenv install --list | grep -E '^\s*3\.[0-9]+\.[0-9]+$' | grep -v "dev\|a\|b\|rc" | sort -V | tail -1 | tr -d '[:space:]')

if [[ -z "$LATEST_STABLE" ]]; then
  echo "Could not determine latest Python version. Defaulting to 3.13.2"
  LATEST_STABLE="3.13.2"
else
  echo "Latest stable Python version: $LATEST_STABLE"
fi
pyenv install -s "$LATEST_STABLE"
pyenv global "$LATEST_STABLE"
EOF

# --- Clean Up ---
info "Cleaning up..."
apt-get autoremove -y
apt-get autoclean -y

info "Bootstrap script complete (with upgrade)!"