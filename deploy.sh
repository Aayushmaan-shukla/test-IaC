#!/bin/bash

# Deployment script for docker-compose with Docker Hub authentication
# Usage: ./deploy.sh start|rebuild|stop

ACTION=${1:-start}

# Load Docker Hub credentials if secrets file exists
if [ -f "$(dirname "$0")/secrets" ]; then
    source "$(dirname "$0")/secrets"
fi

# Load image configuration if exists
if [ -f "$(dirname "$0")/images.conf" ]; then
    source "$(dirname "$0")/images.conf"
fi

# Default values (can be overridden by environment variables or config files)
DOCKER_REGISTRY="${DOCKER_REGISTRY:-docker.io}"
DOCKER_USERNAME="${DOCKER_USERNAME:-}"
DOCKER_PASSWORD="${DOCKER_PASSWORD:-}"
APP_IMAGE="${APP_IMAGE:-archaeaplayground/archaea:latest}"
REDIS_IMAGE="${REDIS_IMAGE:-redis:7-alpine}"
POSTGRES_IMAGE="${POSTGRES_IMAGE:-postgres:16-alpine}"

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
        echo "App image: $APP_IMAGE"
        echo "Redis image: $REDIS_IMAGE"
        echo "Postgres image: $POSTGRES_IMAGE"
        echo ""

        # Login to Docker Hub if credentials are available
        docker_hub_login

        $DOCKER_COMPOSE up -d
        ;;
    rebuild)
        echo "Rebuilding and starting containers..."
        echo "Registry: $DOCKER_REGISTRY"
        echo "App image: $APP_IMAGE"
        echo "Redis image: $REDIS_IMAGE"
        echo "Postgres image: $POSTGRES_IMAGE"
        echo ""

        # Login to Docker Hub if credentials are available
        docker_hub_login

        # Pull latest images
        echo "Pulling latest images..."
        docker pull "$APP_IMAGE" || echo "Warning: Failed to pull $APP_IMAGE"
        docker pull "$REDIS_IMAGE" || echo "Warning: Failed to pull $REDIS_IMAGE"
        docker pull "$POSTGRES_IMAGE" || echo "Warning: Failed to pull $POSTGRES_IMAGE"

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
