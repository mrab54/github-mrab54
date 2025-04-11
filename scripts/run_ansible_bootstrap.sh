#!/usr/bin/env bash
#
# run_ansible_bootstrap.sh - Fetches and runs the Ubuntu bootstrap Ansible playbook.
#
# This script should be run with sudo. It installs Ansible if necessary,
# downloads the playbook, and executes it, passing the original user's name.

set -euo pipefail

# Variables
GITHUB_USERNAME="mrab54"
REPO_NAME="github-mrab54"
PLAYBOOK_FILENAME="init_ubuntu_playbook.yml"
PLAYBOOK_URL="https://raw.githubusercontent.com/${GITHUB_USERNAME}/${REPO_NAME}/master/ansible/${PLAYBOOK_FILENAME}"
TEMP_PLAYBOOK_PATH="/tmp/${PLAYBOOK_FILENAME}"

# Helper functions
info()    { echo -e "\e[34m[INFO]\e[0m  $*"; }
warning() { echo -e "\e[33m[WARN]\e[0m  $*"; }
error()   { echo -e "\e[31m[ERROR]\e[0m $*" >&2; }

# --- Check for sudo and SUDO_USER ---
if [[ $EUID -ne 0 ]]; then
  error "This script must be run with sudo or as root."
  exit 1
fi

if [[ -z "${SUDO_USER}" ]]; then
  error "SUDO_USER environment variable is not set. Cannot determine the target user."
  error "Please run this script using sudo: sudo $0"
  exit 1
fi
TARGET_USER="${SUDO_USER}"
info "Running bootstrap for user: ${TARGET_USER}"

# --- Ensure Ansible is installed ---
info "Checking for Ansible..."
if ! command -v ansible-playbook &> /dev/null; then
  warning "Ansible not found. Attempting to install using apt..."
  # Update package list first
  apt-get update -y
  # Install Ansible using the system package manager
  apt-get install -y ansible
  # Verify installation
  if ! command -v ansible-playbook &> /dev/null; then
    error "Ansible installation via apt failed."
    exit 1
  fi
  info "Ansible installed successfully via apt."
else
  info "Ansible is already installed."
fi

# --- Download Ansible Playbook ---
info "Downloading Ansible playbook from ${PLAYBOOK_URL}..."
if ! curl -sSL -f "${PLAYBOOK_URL}" -o "${TEMP_PLAYBOOK_PATH}"; then
  error "Failed to download Ansible playbook from ${PLAYBOOK_URL}"
  exit 1
fi
info "Playbook downloaded to ${TEMP_PLAYBOOK_PATH}"

# --- Run Ansible Playbook ---
info "Running Ansible playbook..."
# Use --ask-become-pass if your sudo requires a password for privilege escalation within Ansible tasks
# If sudo is passwordless for the user running this script, you might not need it.
# However, it's safer to include it.
if ansible-playbook "${TEMP_PLAYBOOK_PATH}" --ask-become-pass -e "target_user=${TARGET_USER}"; then
  info "Ansible playbook completed successfully."
else
  error "Ansible playbook execution failed."
  # Consider leaving the playbook for debugging: rm -f "${TEMP_PLAYBOOK_PATH}"
  exit 1
fi

# --- Clean Up ---
info "Cleaning up downloaded playbook..."
rm -f "${TEMP_PLAYBOOK_PATH}"

info "Bootstrap process finished."
exit 0
