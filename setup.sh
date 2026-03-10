#!/bin/bash

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Docker Hub configuration
DOCKER_REGISTRY="${DOCKER_REGISTRY:-docker.io}"
SECRETS_FILE="$SCRIPT_DIR/secrets"
ENV_FILE="$SCRIPT_DIR/.env"
IMAGE_CONFIG_FILE="$SCRIPT_DIR/images.conf"

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

# Function to check if secrets file exists
check_secrets() {
    if [ -f "$SECRETS_FILE" ]; then
        return 0
    else
        return 1
    fi
}

# Function to get Docker Hub credentials
get_docker_credentials() {
    if [ -f "$SECRETS_FILE" ]; then
        print_info "Found existing secrets file at $SECRETS_FILE"
        source "$SECRETS_FILE"
        return
    fi

    print_info "Please provide your Docker Hub credentials"
    read -p "Enter Docker username: " username
    read -s -p "Enter Docker password/access token: " password
    echo ""

    # Save credentials to secrets file (with restricted permissions)
    cat > "$SECRETS_FILE" <<EOF
export DOCKER_USERNAME="$username"
export DOCKER_PASSWORD="$password"
export DOCKER_REGISTRY="$DOCKER_REGISTRY"
EOF
    chmod 600 "$SECRETS_FILE"

    print_info "Credentials saved to: $SECRETS_FILE"
}

# Function to load credentials
load_credentials() {
    if [ -f "$SECRETS_FILE" ]; then
        source "$SECRETS_FILE"
    else
        print_error "Secrets file not found at $SECRETS_FILE. Please run setup first."
        exit 1
    fi
}

# Function to create default image configuration
create_default_image_config() {
    if [ ! -f "$IMAGE_CONFIG_FILE" ]; then
        cat > "$IMAGE_CONFIG_FILE" <<'EOF'
# Docker Hub Image Configuration
# Format: SERVICE_NAME=DOCKER_HUB_IMAGE:TAG
# Example: APP_IMAGE=archaeaplayground/archaea:latest

# Main application image
APP_IMAGE=archaeaplayground/archaea:latest

# Optional: Redis image (override if needed)
# REDIS_IMAGE=redis:7-alpine

# Optional: PostgreSQL image (override if needed)
# POSTGRES_IMAGE=postgres:16-alpine
EOF
        print_info "Created default image configuration at $IMAGE_CONFIG_FILE"
        print_warning "Please review and customize the image names and tags as needed"
    fi
}

# Function to load image configuration
load_image_config() {
    if [ -f "$IMAGE_CONFIG_FILE" ]; then
        source "$IMAGE_CONFIG_FILE"
    else
        create_default_image_config
        source "$IMAGE_CONFIG_FILE"
    fi
}

# Function to pull specific image from Docker Hub
pull_docker_image() {
    local image="$1"
    load_credentials

    print_info "Pulling image: $image"
    docker login -u "$DOCKER_USERNAME" --password-stdin "$DOCKER_REGISTRY" <<< "$DOCKER_PASSWORD" 2>/dev/null || true
    docker pull "$image" || {
        print_error "Failed to pull image: $image"
        return 1
    }
    print_info "Successfully pulled: $image"
}

# Function to pull all configured images
pull_all_images() {
    load_image_config

    print_info "Pulling Docker Hub images..."
    echo ""

    # Pull each configured image
    if [ -n "$APP_IMAGE" ]; then
        pull_docker_image "$APP_IMAGE"
    fi

    if [ -n "$REDIS_IMAGE" ]; then
        pull_docker_image "$REDIS_IMAGE"
    fi

    if [ -n "$POSTGRES_IMAGE" ]; then
        pull_docker_image "$POSTGRES_IMAGE"
    fi

    echo ""
    print_info "All images pulled successfully"
}

# Function to login to Docker Hub
docker_login() {
    load_credentials

    print_info "Logging in to Docker Hub as $DOCKER_USERNAME..."
    echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin "$DOCKER_REGISTRY" || {
        print_error "Failed to login to Docker Hub. Please check your credentials."
        exit 1
    }

    print_info "Successfully logged in to Docker Hub"
}

# Function to pull latest images from Docker Hub
pull_latest_images() {
    if [ ! -f "$SCRIPT_DIR/docker-compose.yml" ]; then
        print_error "docker-compose.yml not found in $SCRIPT_DIR"
        exit 1
    fi

    load_credentials

    cd "$SCRIPT_DIR"

    print_info "Pulling latest images from Docker Hub..."
    print_info "Registry: $DOCKER_REGISTRY"
    echo ""

    # Pull all configured images
    pull_all_images
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
        load_image_config
        export DOCKER_USERNAME DOCKER_PASSWORD DOCKER_REGISTRY
        export APP_IMAGE REDIS_IMAGE POSTGRES_IMAGE
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

    # Pull latest images first
    pull_latest_images
    echo ""

    # Check for docker-compose file
    if [ -f "deploy.sh" ]; then
        print_info "Running deploy.sh..."
        chmod +x deploy.sh
        source "$SECRETS_FILE"
        load_image_config
        export DOCKER_USERNAME DOCKER_PASSWORD DOCKER_REGISTRY
        export APP_IMAGE REDIS_IMAGE POSTGRES_IMAGE
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

# Function to show image configuration
show_image_config() {
    print_info "Current Docker Hub Image Configuration:"
    echo ""
    load_image_config

    if [ -n "$APP_IMAGE" ]; then
        echo "  App:     $APP_IMAGE"
    fi

    if [ -n "$REDIS_IMAGE" ]; then
        echo "  Redis:   $REDIS_IMAGE"
    fi

    if [ -n "$POSTGRES_IMAGE" ]; then
        echo "  Postgres: $POSTGRES_IMAGE"
    fi
    echo ""
}

# Function to show usage
show_usage() {
    echo "Usage: $0 {local|server|update|start|rebuild|stop|images}"
    echo ""
    echo "Commands:"
    echo "  local      - Initial setup in local environment (Docker already installed)"
    echo "  server     - Initial setup in server environment (will install dependencies)"
    echo "  update     - Pull latest images from Docker Hub"
    echo "  start      - Start services"
    echo "  rebuild    - Stop, pull latest images, and restart services"
    echo "  stop       - Stop services"
    echo "  images     - Show current Docker Hub image configuration"
    echo ""
    echo "Configuration Files:"
    echo "  Secrets:    $SECRETS_FILE"
    echo "  Images:     $IMAGE_CONFIG_FILE"
    echo "  Environment: $ENV_FILE"
    echo ""
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
            echo ""

            # Setup server dependencies if needed
            if [ "$command" == "server" ]; then
                setup_server_dependencies
                echo ""
            fi

            # Create default image configuration
            create_default_image_config
            echo ""

            # Get Docker Hub credentials
            get_docker_credentials
            echo ""

            # Wait for env file confirmation
            wait_for_env_confirmation "$ENV_FILE"
            echo ""

            # Login to Docker Hub
            docker_login
            echo ""

            # Start services
            print_info "Starting services..."
            start_services
            echo ""

            print_info "Setup completed successfully!"
            print_info "You can customize images in: $IMAGE_CONFIG_FILE"
            ;;

        update)
            print_step "Updating from Docker Hub..."
            pull_latest_images
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

        images)
            show_image_config
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
