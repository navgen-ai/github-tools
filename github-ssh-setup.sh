#!/bin/bash

# GitHub SSH Setup Script
# This script sets up SSH keys for a GitHub account in a way that supports
# multiple accounts through repeated script runs.

set -e

# Text formatting
BOLD='\033[1m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function for user prompts
prompt() {
  echo -e "${BLUE}${BOLD}$1${NC}"
}

# Function for success messages
success() {
  echo -e "${GREEN}${BOLD}✓ $1${NC}"
}

# Function for warnings
warning() {
  echo -e "${YELLOW}${BOLD}! $1${NC}"
}

# Function for errors
error() {
  echo -e "${RED}${BOLD}✗ $1${NC}" >&2
}

# Check if xclip is installed
if ! command -v xclip &> /dev/null; then
  warning "xclip is not installed. You will need to manually copy the public key."
  warning "Install it with: sudo apt install xclip"
  COPY_COMMAND="cat"
else
  COPY_COMMAND="xclip -selection clipboard <"
fi

# Display script information
prompt "GitHub SSH Setup"
echo "This script will set up an SSH key for a GitHub account."
echo "Run it multiple times with different nicknames to set up multiple accounts."
echo ""

# Ask for information about the GitHub account
read -p "Enter a nickname for this GitHub account (e.g., personal, work): " account_name
read -p "Enter the email associated with this GitHub account: " account_email
read -p "Enter your GitHub username for this account: " account_user

# Determine whether this is the first account
is_first_account=false
ssh_config="$HOME/.ssh/config"

if [ ! -f "$ssh_config" ] || ! grep -q "Host github-" "$ssh_config"; then
  is_first_account=true
  prompt "This appears to be your first GitHub account setup."
else
  prompt "This appears to be an additional GitHub account setup."
fi

# Generate SSH key
prompt "Generating SSH key for $account_name account..."
key_path="$HOME/.ssh/github_$account_name"
ssh-keygen -t ed25519 -C "$account_email" -f "$key_path"
success "SSH key generated at $key_path"

# Ensure the SSH directory exists and has correct permissions
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Create or update the SSH config file
prompt "Updating SSH config at $ssh_config..."

# Check if SSH config already exists
if [ -f "$ssh_config" ]; then
  cp "$ssh_config" "$ssh_config.backup"
  success "Created backup of existing SSH config at $ssh_config.backup"
fi

# Add configuration for this account
if [ "$is_first_account" = true ]; then
  # First account uses the default github.com host
  cat >> "$ssh_config" << EOF
# GitHub account: $account_name ($account_email)
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/github_$account_name
  IdentitiesOnly yes

EOF
else
  # Additional accounts use github-nickname as host
  cat >> "$ssh_config" << EOF
# GitHub account: $account_name ($account_email)
Host github-$account_name
  HostName github.com
  User git
  IdentityFile ~/.ssh/github_$account_name
  IdentitiesOnly yes

EOF
fi

chmod 600 "$ssh_config"
success "SSH config updated"

# Configure shell to automatically load SSH keys
prompt "Setting up your shell to automatically load this SSH key..."
shell_rc=""

if [ -f "$HOME/.zshrc" ]; then
  shell_rc="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
  shell_rc="$HOME/.bashrc"
else
  warning "Could not find .zshrc or .bashrc. You will need to manually set up SSH agent."
fi

if [ -n "$shell_rc" ]; then
  # Check if SSH agent config already exists
  if grep -q "ssh-agent" "$shell_rc"; then
    # Check if this specific key is already configured
    if grep -q "github_$account_name" "$shell_rc"; then
      warning "SSH key $account_name already configured in $shell_rc"
    else
      # Add this key to the existing SSH agent config
      sed -i "/eval.*ssh-agent/a\\  ssh-add ~/.ssh/github_$account_name > /dev/null 2>&1" "$shell_rc"
      success "Added key to existing SSH agent configuration in $shell_rc"
    fi
  else
    # Add new SSH agent config
    cat >> "$shell_rc" << 'EOF'

# Start SSH agent and add keys automatically
if [ -z "$SSH_AUTH_SOCK" ]; then
  eval "$(ssh-agent -s)" > /dev/null
EOF
    
    echo "  ssh-add ~/.ssh/github_$account_name > /dev/null 2>&1" >> "$shell_rc"
    echo "fi" >> "$shell_rc"
    success "Added new SSH agent configuration to $shell_rc"
  fi
fi

# Start SSH agent and add key for the current session
eval "$(ssh-agent -s)" > /dev/null
ssh-add "$HOME/.ssh/github_$account_name" > /dev/null 2>&1
success "SSH agent started and key added for current session"

# Provide instructions for adding SSH key to GitHub account
prompt "Next steps:"
echo "1. Add your SSH public key to your GitHub account:"
echo ""
if [ "$COPY_COMMAND" = "cat" ]; then
  echo "   Copy the following key content:"
  cat "$HOME/.ssh/github_$account_name.pub"
else
  eval "$COPY_COMMAND $HOME/.ssh/github_${account_name}.pub"
  echo "   Key copied to clipboard! Paste it in GitHub."
fi
echo ""
echo "   - Go to GitHub → Settings → SSH and GPG keys → New SSH key"
echo "   - Title: $account_name"
echo "   - Paste the key and save"
echo ""

# Repository configuration guidelines
prompt "Working with repositories:"
if [ "$is_first_account" = true ]; then
  echo "For repositories linked to this account, use the standard URL:"
  echo "  git clone git@github.com:$account_user/repo-name.git"
  echo "  or for existing repos: git remote set-url origin git@github.com:$account_user/repo-name.git"
else
  echo "For repositories linked to this account, use the SSH host alias:"
  echo "  git clone git@github-$account_name:$account_user/repo-name.git"
  echo "  or for existing repos: git remote set-url origin git@github-$account_name:$account_user/repo-name.git"
fi
echo ""

echo "To set up per-repository Git configuration, run these commands in your repository:"
echo "  git config user.name \"Your Name\""
echo "  git config user.email \"$account_email\""
echo ""

success "Setup complete for account: $account_name!"
echo "You may need to restart your terminal or run 'source $shell_rc' to load the SSH agent configuration."
