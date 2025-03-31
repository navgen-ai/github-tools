#!/bin/bash

# GitHub Repository Downloader with SSH Support
# This script clones a GitHub repository using SSH when available and sets up the environment

# Text formatting
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function for informational messages
info() {
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

# Check if git is installed
if ! command -v git &> /dev/null; then
    info "Git is not installed. Installing git..."
    sudo apt update
    sudo apt install -y git
fi

# Check if URL was provided
if [ -z "$1" ]; then
    error "Please provide a GitHub repository URL or path"
    echo "Usage: ./github_downloader.sh <repository_url_or_path> [target_directory] [branch_name]"
    echo "Examples:"
    echo "  ./github_downloader.sh https://github.com/username/repo.git"
    echo "  ./github_downloader.sh git@github.com:username/repo.git my-project"
    echo "  ./github_downloader.sh username/repo my-project develop"
    exit 1
fi

REPO_INPUT=$1
TARGET_DIR="${2:-}"
BRANCH_NAME="${3:-}"

# Get GitHub username if using shorthand format
if [[ $REPO_INPUT == *"/"* ]] && [[ $REPO_INPUT != *"github.com"* ]] && [[ $REPO_INPUT != git@* ]]; then
    # Input is in username/repo format
    GITHUB_USERNAME=$(echo $REPO_INPUT | cut -d'/' -f1)
    REPO_NAME=$(echo $REPO_INPUT | cut -d'/' -f2)
    
    # Prompt to confirm the username
    info "Using GitHub username: $GITHUB_USERNAME"
    read -p "Is this correct? (Y/n): " confirm
    if [[ $confirm =~ ^[Nn]$ ]]; then
        read -p "Enter the correct GitHub username: " GITHUB_USERNAME
    fi
    
    # Check if we should try HTTPS or SSH
    info "Checking for SSH authentication..."
    if ssh -o BatchMode=yes -o StrictHostKeyChecking=no -T git@github.com 2>&1 | grep -q "success"; then
        success "SSH authentication to GitHub is working!"
        REPO_URL="git@github.com:${GITHUB_USERNAME}/${REPO_NAME}.git"
        info "Using SSH URL: $REPO_URL"
    else
        warning "SSH authentication not available. Using HTTPS URL."
        REPO_URL="https://github.com/${GITHUB_USERNAME}/${REPO_NAME}.git"
        info "Using HTTPS URL: $REPO_URL"
    fi
    
elif [[ $REPO_INPUT == https://github.com/* ]]; then
    # Input is HTTPS URL
    REPO_URL=$REPO_INPUT
    REPO_NAME=$(basename "${REPO_URL%.git}")
    
    # Check if SSH is available and ask if they want to use it
    if ssh -o BatchMode=yes -o StrictHostKeyChecking=no -T git@github.com 2>&1 | grep -q "success"; then
        success "SSH authentication to GitHub is working!"
        
        # Extract username and repo from HTTPS URL
        REPO_PATH=${REPO_INPUT#https://github.com/}
        REPO_PATH=${REPO_PATH%.git}
        GITHUB_USERNAME=$(echo $REPO_PATH | cut -d'/' -f1)
        REPO_NAME=$(echo $REPO_PATH | cut -d'/' -f2)
        
        read -p "Would you like to use SSH instead of HTTPS? (Y/n): " use_ssh
        if [[ ! $use_ssh =~ ^[Nn]$ ]]; then
            REPO_URL="git@github.com:${GITHUB_USERNAME}/${REPO_NAME}.git"
            info "Converted to SSH URL: $REPO_URL"
        fi
    fi
    
else
    # Input is already SSH URL or other format
    REPO_URL=$REPO_INPUT
    REPO_NAME=$(basename "${REPO_URL%.git}")
fi

# Check if target directory was provided
if [ -z "$TARGET_DIR" ]; then
    TARGET_DIR=$REPO_NAME
fi

# If no branch was specified, ask if user wants to specify one
if [ -z "$BRANCH_NAME" ]; then
    read -p "Do you want to clone a specific branch? (y/N): " clone_branch
    if [[ $clone_branch =~ ^[Yy]$ ]]; then
        read -p "Enter branch name (leave empty for default branch): " BRANCH_NAME
    fi
fi

info "Cloning repository from $REPO_URL into $TARGET_DIR..."

# Clone the repository
git clone "$REPO_URL" "$TARGET_DIR"

if [ $? -ne 0 ]; then
    error "Failed to clone repository. Please check:"
    echo "  - Repository URL"
    echo "  - Repository permissions (private vs. public)"
    echo "  - Branch name (if specified: $BRANCH_NAME)"
    echo "  - Your authentication setup (SSH key or token)"
    echo "  - Your internet connection"
    
    # Offer fallback to HTTPS if SSH failed
    if [[ $REPO_URL == git@github.com* ]]; then
        REPO_PATH=${REPO_URL#git@github.com:}
        REPO_PATH=${REPO_PATH%.git}
        HTTPS_URL="https://github.com/${REPO_PATH}.git"
        
        read -p "Would you like to try with HTTPS instead? (Y/n): " try_https
        if [[ ! $try_https =~ ^[Nn]$ ]]; then
            if [ -n "$BRANCH_NAME" ]; then
                info "Trying with HTTPS URL: $HTTPS_URL (branch: $BRANCH_NAME)"
                git clone -b "$BRANCH_NAME" "$HTTPS_URL" "$TARGET_DIR"
            else
                info "Trying with HTTPS URL: $HTTPS_URL"
                git clone "$HTTPS_URL" "$TARGET_DIR"
            fi
            
            if [ $? -ne 0 ]; then
                error "HTTPS clone also failed. Please double-check the repository name and your permissions."
                exit 1
            else
                success "Repository cloned successfully using HTTPS!"
            fi
        else
            exit 1
        fi
    else
        exit 1
    fi
else
    success "Repository cloned successfully!"
fi

# Change into the target directory
cd "$TARGET_DIR" || exit
info "Changed to directory: $(pwd)"

# Check if this is a Python project
if [ -f "requirements.txt" ]; then
    info "Python project detected. Would you like to set up a virtual environment? (y/n)"
    read -r SETUP_VENV
    
    if [[ $SETUP_VENV =~ ^[Yy]$ ]]; then
        echo "Setting up Python virtual environment..."
        
        # Get available Python versions
        AVAILABLE_PYTHONS=()
        
        for version in 3.7 3.8 3.9 3.10 3.11 3.12; do
            if command -v python${version} &> /dev/null; then
                AVAILABLE_PYTHONS+=("python${version}")
            fi
        done
        
        # Check if python3 is available
        if command -v python3 &> /dev/null; then
            PYTHON3_VERSION=$(python3 --version | grep -oE '[0-9]+\.[0-9]+')
            AVAILABLE_PYTHONS+=("python3 (v${PYTHON3_VERSION})")
        fi
        
        # Choose the Python executable
        PYTHON_EXECUTABLE="python3"
        
        # Check for Python version requirement in requirements.txt
        PYTHON_VERSION_REQUIRED=""
        if grep -q "python_version" requirements.txt; then
            PYTHON_VERSION_REQUIRED=$(grep "python_version" requirements.txt | grep -oE '[0-9]+\.[0-9]+' | head -1)
            info "Python version ${PYTHON_VERSION_REQUIRED} required in requirements.txt"
            
            if command -v python${PYTHON_VERSION_REQUIRED} &> /dev/null; then
                PYTHON_EXECUTABLE="python${PYTHON_VERSION_REQUIRED}"
                success "Using Python ${PYTHON_VERSION_REQUIRED} as required by requirements.txt"
            else
                warning "Required Python ${PYTHON_VERSION_REQUIRED} not found in system"
                # Will fall through to the selection process below
            fi
        else
            # No Python version specified in requirements.txt, ask the user
            info "No Python version specified in requirements.txt"
        fi
        
        # If we don't have a definite Python version yet, let the user choose
        if [[ "$PYTHON_EXECUTABLE" == "python3" ]] || [[ ! -n "$PYTHON_VERSION_REQUIRED" ]] || ! command -v python${PYTHON_VERSION_REQUIRED} &> /dev/null; then
            # List available Python versions
            if [ ${#AVAILABLE_PYTHONS[@]} -gt 0 ]; then
                echo "Available Python versions:"
                for i in "${!AVAILABLE_PYTHONS[@]}"; do
                    echo "  $((i+1)). ${AVAILABLE_PYTHONS[$i]}"
                done
                
                read -p "Choose a Python version (1-${#AVAILABLE_PYTHONS[@]}) or press Enter for default python3: " choice
                
                if [[ -n "$choice" ]]; then
                    index=$((choice-1))
                    if [[ $index -ge 0 && $index -lt ${#AVAILABLE_PYTHONS[@]} ]]; then
                        selected=${AVAILABLE_PYTHONS[$index]}
                        PYTHON_EXECUTABLE=${selected%% *}  # Extract just the command part
                        info "Using $selected"
                    else
                        warning "Invalid selection. Using default Python 3."
                    fi
                else
                    info "Using default Python 3 ($(python3 --version))"
                fi
            else
                warning "No alternative Python versions found. Using default Python 3."
            fi
        fi
        
        # Create the virtual environment
        info "Creating virtual environment with $PYTHON_EXECUTABLE..."
        $PYTHON_EXECUTABLE -m venv venv
        
        # Verify the virtual environment was created correctly
        if [ ! -f "venv/bin/activate" ]; then
            warning "Virtual environment activation script not found!"
            warning "Trying alternative approach with virtualenv..."
            
            # Try using virtualenv as a fallback
            if ! command -v virtualenv &> /dev/null; then
                info "Installing virtualenv..."
                pip3 install virtualenv
            fi
            
            # Remove the failed venv directory
            rm -rf venv
            
            # Create virtual environment with virtualenv
            virtualenv -p $PYTHON_EXECUTABLE venv
            
            # Check again for activation script
            if [ ! -f "venv/bin/activate" ]; then
                error "Failed to create virtual environment. Please create it manually."
                info "You can try: $PYTHON_EXECUTABLE -m virtualenv venv"
                return 1
            fi
        fi
        
        # Activate the virtual environment
        source venv/bin/activate
        
        # Verify activation worked
        if [[ "$VIRTUAL_ENV" != *"venv"* ]]; then
            warning "Virtual environment activation failed. Please activate it manually."
            info "Run: source venv/bin/activate"
            return 1
        fi
        
        # Upgrade pip
        pip install --upgrade pip
        
        # Install requirements
        pip install -r requirements.txt
        
        success "Virtual environment set up successfully using $(python --version)"
        info "Activate it with: source venv/bin/activate"
    fi
fi

# Check if this is a React project
if [ -f "package.json" ]; then
    info "React/Node.js project detected. Would you like to install dependencies? (y/n)"
    read -r INSTALL_DEPS
    
    if [[ $INSTALL_DEPS =~ ^[Yy]$ ]]; then
        echo "Installing dependencies..."
        if [ -f "yarn.lock" ]; then
            yarn install
        else
            npm install
        fi
        success "Dependencies installed successfully."
    fi
fi

success "Repository successfully cloned and set up at: $(pwd)"
info "Happy coding!"

exit 0
