#!/bin/bash

# Deployment script for docker-compose with Docker Hub authentication
# Usage: ./deploy.sh start|rebuild|stop

ACTION=${1:-start}

# Load Docker Hub parameters if secrets file exists
if [ -f "$(dirname "$0")/secrets" ]; then
    source "$(dirname "$0")/secrets"
fi

# Default values
DOCKER_REGISTRY="${DOCKER_REGISTRY:-docker.io}"
DOCKER_USERNAME="${DOCKER_USERNAME:-}"
DOCKER_PASSWORD="${DOCKER_PASSWORD:-}"
DOCKER_IMAGE_PREFIX="${DOCKER_IMAGE_PREFIX:-}"
DOCKER_IMAGE_PULL_NAME="${DOCKER_IMAGE_PULL_NAME:-}"

# Prefer docker-compose over docker compose
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    echo "Error: Neither docker-compose nor docker compose is installed"
    exit 1
fi

# Function to login to Docker Hub
docker_hub_login() {
    if [ -n "$DOCKER_USERNAME" ] && [ -n "$DOCKER_PASSWORD" ]; then
        echo "Logging in to Docker Hub as $DOCKER_USERNAME..."
        echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin "$DOCKER_REGISTRY" || {
            echo "Warning: Failed to login to Docker Hub, but continuing..."
        }
        echo "Docker Hub login successful"
    else
        echo "Warning: No Docker Hub credentials found, pulling public images only"
    fi
}

case $ACTION in
    start)
        echo "Starting containers..."
        echo "Registry: $DOCKER_REGISTRY"
        if [ -n "$DOCKER_IMAGE_PREFIX" ] && [ -n "$DOCKER_IMAGE_PULL_NAME" ]; then
            echo "Image: $DOCKER_IMAGE_PREFIX/$DOCKER_IMAGE_PULL_NAME"
        fi
        echo ""

        # Login to Docker Hub if credentials are available
        docker_hub_login

        $DOCKER_COMPOSE up -d
        ;;
    rebuild)
        echo "Rebuilding and starting containers..."
        echo "Registry: $DOCKER_REGISTRY"
        if [ -n "$DOCKER_IMAGE_PREFIX" ] && [ -n "$DOCKER_IMAGE_PULL_NAME" ]; then
            echo "Image: $DOCKER_IMAGE_PREFIX/$DOCKER_IMAGE_PULL_NAME"
        fi
        echo ""

        # Login to Docker Hub if credentials are available
        docker_hub_login

        # Pull specified image if available
        if [ -n "$DOCKER_IMAGE_PREFIX" ] && [ -n "$DOCKER_IMAGE_PULL_NAME" ]; then
            echo "Pulling image: $DOCKER_IMAGE_PREFIX/$DOCKER_IMAGE_PULL_NAME"
            docker pull "$DOCKER_IMAGE_PREFIX/$DOCKER_IMAGE_PULL_NAME" || echo "Warning: Failed to pull image"
        fi

        # Restart containers
        $DOCKER_COMPOSE down
        $DOCKER_COMPOSE up -d --force-recreate
        ;;
    stop)
        echo "Stopping containers..."
        $DOCKER_COMPOSE down
        ;;
    *)
        echo "Usage: $0 {start|rebuild|stop}"
        exit 1
        ;;
esac
