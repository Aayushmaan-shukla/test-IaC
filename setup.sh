#!/bin/bash

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Repository configuration
REPO_URL="https://github.com/Aayushmaan-shukla/test-IaC.git"
REPO_DIR="$SCRIPT_DIR/test-IaC"
CREDENTIALS_DIR="$SCRIPT_DIR/.credentials"
CREDENTIALS_FILE="$CREDENTIALS_DIR/.git_credentials"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Function to check if credentials exist
check_credentials() {
    if [ -f "$CREDENTIALS_FILE" ]; then
        return 0
    else
        return 1
    fi
}

# Function to get GitHub credentials (stores them persistently)
get_github_credentials() {
    # Create credentials directory if it doesn't exist
    mkdir -p "$CREDENTIALS_DIR"

    # Check if credentials already exist
    if [ -f "$CREDENTIALS_FILE" ]; then
        print_info "Found existing credentials at $CREDENTIALS_FILE"
        source "$CREDENTIALS_FILE"
        echo "$CREDENTIALS_FILE"
        return
    fi

    print_info "Please provide your GitHub credentials for cloning the repository"
    read -p "Enter GitHub username: " username
    read -s -p "Enter GitHub personal access token (with repo scope): " token
    echo ""

    # Save credentials to file (with restricted permissions)
    cat > "$CREDENTIALS_FILE" <<EOF
export GITHUB_USERNAME="$username"
export GITHUB_TOKEN="$token"
EOF
    chmod 600 "$CREDENTIALS_FILE"

    print_info "Credentials saved to: $CREDENTIALS_FILE"
    echo "$CREDENTIALS_FILE"
}

# Function to load credentials
load_credentials() {
    if [ -f "$CREDENTIALS_FILE" ]; then
        source "$CREDENTIALS_FILE"
    else
        print_error "Credentials not found. Please run setup first."
        exit 1
    fi
}

# Function to clean up temp credentials
cleanup_credentials() {
    local temp_dir="$1"
    if [ -d "$temp_dir" ]; then
        rm -rf "$temp_dir"
        print_info "Temporary credentials cleaned up"
    fi
}

# Function to prepare clone directory
prepare_clone_dir() {
    if [ -d "$REPO_DIR" ]; then
        print_warning "Directory $REPO_DIR already exists. Removing it..."
        rm -rf "$REPO_DIR"
        print_info "Directory $REPO_DIR removed"
    fi
}

# Function to clone repository
clone_repo() {
    local credentials_file="$1"
    source "$credentials_file"

    print_info "Cloning repository from $REPO_URL..."
    git clone "https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/Aayushmaan-shukla/test-IaC.git" "$REPO_DIR" || {
        print_error "Failed to clone repository. Please check your credentials."
        exit 1
    }
    print_info "Repository cloned successfully to $REPO_DIR"
}

# Function to update repository (git pull)
update_repo() {
    if [ ! -d "$REPO_DIR" ]; then
        print_error "Repository not found at $REPO_DIR. Please run 'setup.sh local' first."
        exit 1
    fi

    load_credentials

    cd "$REPO_DIR"
    print_info "Updating repository from $REPO_URL..."

    # Configure git to use credentials for this repo
    git config credential.helper store
    echo "https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com" > ~/.git-credentials

    # Fetch and pull
    git fetch --all
    git pull origin prod

    print_info "Repository updated successfully"
}

# Function to setup git and checkout branch
setup_git() {
    local repo_dir="$1"

    cd "$repo_dir"
    print_info "Fetching all branches..."
    git fetch --all

    print_info "Checking out 'prod' branch..."
    git checkout prod

    print_info "Git setup completed"
}

# Function to wait for env file confirmation
wait_for_env_confirmation() {
    local env_path="$1"
    local response=""

    print_info "Please paste your .env file to the following location:"
    print_warning "$env_path"
    echo ""

    # Check if file already exists
    if [ -f "$env_path" ]; then
        print_info ".env file already exists at $env_path"
        return
    fi

    while true; do
        read -p "Have you pasted the .env file? (yes/no): " response
        case $response in
            [Yy][Ee][Ss])
                if [ -f "$env_path" ]; then
                    print_info ".env file confirmed"
                    break
                else
                    print_warning ".env file not found at $env_path. Please paste it first."
                fi
                ;;
            [Nn][Oo])
                print_warning "Please paste the .env file to $env_path"
                ;;
            *)
                print_warning "Please answer with 'yes' or 'no'"
                ;;
        esac
    done
}

# Function to setup server dependencies
setup_server_dependencies() {
    print_info "Setting up server dependencies..."
    print_warning "This requires sudo privileges"

    # Update package list
    print_info "Updating package list..."
    sudo apt update

    # Install Docker
    print_info "Installing Docker..."
    sudo apt install -y docker.io

    # Start and enable Docker service
    print_info "Starting Docker service..."
    sudo systemctl start docker
    sudo systemctl enable docker

    # Install Docker Compose
    print_info "Installing Docker Compose..."
    sudo apt install -y docker-compose

    # Verify installations
    print_info "Verifying installations..."
    docker --version
    docker-compose --version

    print_info "Server dependencies setup completed"
}

# Function to start services
start_services() {
    if [ ! -d "$REPO_DIR" ]; then
        print_error "Repository not found at $REPO_DIR. Please run 'setup.sh local' first."
        exit 1
    fi

    cd "$REPO_DIR"

    print_info "Starting services..."

    # Check for docker-compose file
    if [ -f "docker-compose.yml" ]; then
        docker-compose up -d
        print_info "Services started with docker-compose"
    elif [ -f "deploy.sh" ]; then
        print_info "Running deploy.sh..."
        chmod +x deploy.sh
        ./deploy.sh
    else
        print_error "No docker-compose.yml or deploy.sh found"
        exit 1
    fi
}

# Function to rebuild services
rebuild_services() {
    if [ ! -d "$REPO_DIR" ]; then
        print_error "Repository not found at $REPO_DIR. Please run 'setup.sh local' first."
        exit 1
    fi

    cd "$REPO_DIR"

    print_info "Rebuilding services..."

    # Check for docker-compose file
    if [ -f "docker-compose.yml" ]; then
        docker-compose down
        docker-compose build
        docker-compose up -d
        print_info "Services rebuilt and started"
    elif [ -f "deploy.sh" ]; then
        print_info "Running deploy.sh..."
        chmod +x deploy.sh
        ./deploy.sh
    else
        print_error "No docker-compose.yml or deploy.sh found"
        exit 1
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 {local|server|update|start|rebuild}"
    echo ""
    echo "Commands:"
    echo "  local      - Full setup in local environment (Docker already installed)"
    echo "  server     - Full setup in server environment (will install dependencies)"
    echo "  update     - Update repository (git pull) using saved credentials"
    echo "  start      - Start services (docker-compose up or deploy.sh)"
    echo "  rebuild    - Rebuild and start services"
    echo ""
    echo "Repository: $REPO_URL"
    echo "Script location: $SCRIPT_DIR"
}

# Main script
main() {
    # Check if command parameter is provided
    if [ $# -eq 0 ]; then
        print_error "No command provided."
        show_usage
        exit 1
    fi

    local command="$1"

    case "$command" in
        local|server)
            print_step "Starting setup in $command environment..."
            print_info "Repository: $REPO_URL"
            echo ""

            # Setup server dependencies if needed
            if [ "$command" == "server" ]; then
                setup_server_dependencies
                echo ""
            fi

            # Get GitHub credentials
            get_github_credentials
            echo ""

            # Prepare clone directory (remove if exists)
            prepare_clone_dir
            echo ""

            # Clone repository
            clone_repo "$CREDENTIALS_FILE"
            echo ""

            # Setup git and checkout branch
            setup_git "$REPO_DIR"
            echo ""

            # Define env file path
            local env_path="$REPO_DIR/.env"

            # Wait for env file confirmation
            wait_for_env_confirmation "$env_path"
            echo ""

            # Run deploy.sh
            print_info "Running deploy.sh..."
            cd "$REPO_DIR"

            if [ -f "deploy.sh" ]; then
                chmod +x deploy.sh
                ./deploy.sh
            else
                print_error "deploy.sh not found in repository"
                exit 1
            fi

            print_info "Setup completed successfully!"
            ;;

        update)
            print_step "Updating repository..."
            update_repo
            echo ""
            print_info "Update completed! You may need to restart services."
            print_info "Run: $0 start or $0 rebuild"
            ;;

        start)
            print_step "Starting services..."
            start_services
            echo ""
            print_info "Services started successfully!"
            ;;

        rebuild)
            print_step "Rebuilding services..."
            rebuild_services
            echo ""
            print_info "Services rebuilt and started successfully!"
            ;;

        *)
            print_error "Invalid command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
