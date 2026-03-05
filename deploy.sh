#!/bin/bash

# Deployment script for docker-compose
# Usage: ./deploy.sh start|rebuild|stop

ACTION=${1:-start}

# Prefer docker-compose over docker compose
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    echo "Error: Neither docker-compose nor docker compose is installed"
    exit 1
fi

case $ACTION in
    start)
        echo "Starting containers..."
        $DOCKER_COMPOSE up -d
        ;;
    rebuild)
        echo "Rebuilding and starting containers..."
        $DOCKER_COMPOSE up -d --build
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
