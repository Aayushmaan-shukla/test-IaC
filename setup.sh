#!/bin/bash

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration files
SECRETS_FILE="$SCRIPT_DIR/secrets"
ENV_FILE="$SCRIPT_DIR/.env"

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

# Function to get system architecture
get_system_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            echo "linux/amd64"
            ;;
        aarch64|arm64)
            echo "linux/arm64"
            ;;
        *)
            echo "linux/$arch"
            ;;
    esac
}

# Function to reset parameters
reset_parameters() {
    if [ -f "$SECRETS_FILE" ]; then
        print_warning "Removing existing secrets file..."
        rm "$SECRETS_FILE"
        print_info "Secrets file removed: $SECRETS_FILE"
    else
        print_info "No secrets file found at $SECRETS_FILE"
    fi
}

# Function to get Docker Hub parameters
get_docker_parameters() {
    if [ -f "$SECRETS_FILE" ]; then
        print_info "Found existing secrets file at $SECRETS_FILE"
        source "$SECRETS_FILE"
        return
    fi

    print_info "Please provide your Docker Hub parameters"

    read -p "Enter Docker username: " username
    read -s -p "Enter Docker password/access token: " password
    echo ""
    read -p "Enter Docker registry (default: docker.io): " registry
    read -p "Enter Docker image prefix: " image_prefix
    read -p "Enter Docker image pull name: " image_pull_name

    # Use defaults if empty
    registry="${registry:-docker.io}"

    # Save parameters to secrets file (with restricted permissions)
    cat > "$SECRETS_FILE" <<EOF
export DOCKER_USERNAME="$username"
export DOCKER_PASSWORD="$password"
export DOCKER_REGISTRY="$registry"
export DOCKER_IMAGE_PREFIX="$image_prefix"
export DOCKER_IMAGE_PULL_NAME="$image_pull_name"
EOF
    chmod 600 "$SECRETS_FILE"

    print_info "Parameters saved to: $SECRETS_FILE"
}

# Function to load parameters
load_parameters() {
    if [ -f "$SECRETS_FILE" ]; then
        source "$SECRETS_FILE"
    else
        print_error "Parameters not found. Please run setup first."
        exit 1
    fi
}

# Function to login to Docker Hub
docker_login() {
    load_parameters

    print_info "Logging in to Docker Hub as $DOCKER_USERNAME..."
    echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin "$DOCKER_REGISTRY" || {
        print_error "Failed to login to Docker Hub. Please check your credentials."
        exit 1
    }

    print_info "Successfully logged in to Docker Hub"
}

# Function to pull Docker images
pull_images() {
    load_parameters

    local system_arch=$(get_system_arch)
    local full_image="$DOCKER_IMAGE_PREFIX/$DOCKER_IMAGE_PULL_NAME"

    print_info "Pulling Docker images from Docker Hub..."
    print_info "Registry: $DOCKER_REGISTRY"
    print_info "Image: $full_image"
    print_info "System architecture: $system_arch"
    echo ""

    docker_login

    print_info "Pulling image: $full_image"

    # Try to pull with platform specification
    if docker pull --platform "$system_arch" "$full_image" 2>/dev/null; then
        print_info "Successfully pulled: $full_image"
    else
        # Try without platform specification
        print_warning "Platform-specific pull failed, trying without platform specification..."
        if docker pull "$full_image"; then
            print_info "Successfully pulled: $full_image"
        else
            print_error "Failed to pull image: $full_image"
            echo ""
            print_error "Possible issues:"
            print_error "1. Image doesn't exist on Docker Hub"
            print_error "2. Image tag is incorrect (check for typos)"
            print_error "3. Image was built for a different architecture"
            print_error "4. Image is private and you don't have access"
            echo ""
            print_info "Troubleshooting steps:"
            print_info "1. Verify image exists: docker search $DOCKER_IMAGE_PREFIX"
            print_info "2. Check image tags at: https://hub.docker.com/r/$DOCKER_IMAGE_PREFIX"
            print_info "3. Try pulling manually: docker pull $full_image"
            print_info "4. Check if image supports your platform: docker manifest inspect $full_image"
            exit 1
        fi
    fi
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
        read -p "Have you pasted .env file? (yes/no): " response
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
    if [ ! -f "$SCRIPT_DIR/docker-compose.yml" ]; then
        print_error "docker-compose.yml not found in $SCRIPT_DIR"
        exit 1
    fi

    cd "$SCRIPT_DIR"

    print_info "Starting services..."

    # Login to Docker Hub
    docker_login

    # Check for docker-compose file
    if [ -f "deploy.sh" ]; then
        print_info "Running deploy.sh..."
        chmod +x deploy.sh
        source "$SECRETS_FILE"
        export DOCKER_USERNAME DOCKER_PASSWORD DOCKER_REGISTRY DOCKER_IMAGE_PREFIX DOCKER_IMAGE_PULL_NAME
        ./deploy.sh start
    else
        docker-compose up -d
        print_info "Services started with docker-compose"
    fi
}

# Function to rebuild services
rebuild_services() {
    if [ ! -f "$SCRIPT_DIR/docker-compose.yml" ]; then
        print_error "docker-compose.yml not found in $SCRIPT_DIR"
        exit 1
    fi

    cd "$SCRIPT_DIR"

    print_info "Rebuilding services..."

    # Login to Docker Hub
    docker_login

    # Pull images first
    pull_images
    echo ""

    # Check for docker-compose file
    if [ -f "deploy.sh" ]; then
        print_info "Running deploy.sh..."
        chmod +x deploy.sh
        source "$SECRETS_FILE"
        export DOCKER_USERNAME DOCKER_PASSWORD DOCKER_REGISTRY DOCKER_IMAGE_PREFIX DOCKER_IMAGE_PULL_NAME
        ./deploy.sh rebuild
    else
        docker-compose down
        docker-compose up -d --force-recreate
        print_info "Services rebuilt and started"
    fi
}

# Function to stop services
stop_services() {
    if [ ! -f "$SCRIPT_DIR/docker-compose.yml" ]; then
        print_error "docker-compose.yml not found in $SCRIPT_DIR"
        exit 1
    fi

    cd "$SCRIPT_DIR"

    print_info "Stopping services..."

    if [ -f "deploy.sh" ]; then
        print_info "Running deploy.sh..."
        chmod +x deploy.sh
        source "$SECRETS_FILE"
        ./deploy.sh stop
    else
        docker-compose down
        print_info "Services stopped"
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 {local|server|update|start|rebuild|stop|reset}"
    echo ""
    echo "Commands:"
    echo "  local      - Initial setup in local environment (Docker already installed)"
    echo "  server     - Initial setup in server environment (will install dependencies)"
    echo "  update     - Pull latest images from Docker Hub"
    echo "  start      - Start services"
    echo "  rebuild    - Stop, pull latest images, and restart services"
    echo "  stop       - Stop services"
    echo "  reset      - Remove secrets file (you'll need to re-enter parameters)"
    echo ""
    echo "Configuration file: $SECRETS_FILE"
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
        reset)
            reset_parameters
            echo ""
            print_info "Secrets reset! Next time you run 'local' or 'server', you'll be asked for parameters again."
            ;;

        local|server)
            print_step "Starting setup in $command environment..."
            echo ""

            # Setup server dependencies if needed
            if [ "$command" == "server" ]; then
                setup_server_dependencies
                echo ""
            fi

            # Get Docker Hub parameters
            get_docker_parameters
            echo ""

            # Wait for env file confirmation
            wait_for_env_confirmation "$ENV_FILE"
            echo ""

            # Login to Docker Hub
            docker_login
            echo ""

            # Pull images
            pull_images
            echo ""

            # Start services
            print_info "Starting services..."
            start_services
            echo ""

            print_info "Setup completed successfully!"
            ;;

        update)
            print_step "Updating from Docker Hub..."
            pull_images
            echo ""
            print_info "Update completed! You may need to restart services."
            print_info "Run: $0 rebuild"
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

        stop)
            print_step "Stopping services..."
            stop_services
            echo ""
            print_info "Services stopped successfully!"
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
