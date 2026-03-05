#!/bin/bash

# Docker Compose Deployment Script
# Handles both 'docker compose' and 'docker-compose' commands

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"

# Usage function
usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  up       Start services (default)"
    echo "  down     Stop and remove services"
    echo "  restart  Restart services"
    echo "  logs     Show logs"
    echo "  ps       List running containers"
    echo "  pull     Pull latest images"
    echo ""
    echo "Options:"
    echo "  -f, --file FILE          Specify docker-compose file (default: docker-compose.yml)"
    echo "  -h, --help               Show this help message"
    echo ""
    exit 0
}

# Check for .env file
check_env_file() {
    if [ ! -f ".env" ]; then
        echo -e "${YELLOW}Warning: .env file not found in current directory.${NC}"
        echo -e "${YELLOW}Please ensure your .env file is correctly placed at: $(pwd)/.env${NC}"
        echo ""
        echo -e "Example .env file:"
        echo -e "APP_PORT=8000"
        echo -e "MODE=production"
        echo -e "REDIS_PORT=6379"
        echo -e "REDIS_PASSWORD=your_redis_password"
        echo -e "POSTGRES_PORT=5432"
        echo -e "POSTGRES_USER=postgres"
        echo -e "POSTGRES_PASSWORD=your_postgres_password"
        echo -e "POSTGRES_DB=sampledb"
        echo ""
        read -p "Do you want to continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}Deployment cancelled.${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}Found .env file at: $(pwd)/.env${NC}"
    fi
}

# Parse command line arguments
COMMAND="up"
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            COMPOSE_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        up|down|restart|logs|ps|pull)
            COMMAND="$1"
            shift
            ;;
        *)
            echo -e "${RED}Error: Unknown option or command: $1${NC}"
            usage
            ;;
    esac
done

# Display message about environment file
echo -e "${YELLOW}=== Environment Setup ===${NC}"
check_env_file

# Function to detect and use the correct docker compose command
get_docker_compose_cmd() {
    echo -e "${YELLOW}Checking for Docker installation...${NC}"

    # First try docker-compose (older, more stable)
    if command -v docker-compose &> /dev/null; then
        if docker-compose --version &>/dev/null; then
            echo -e "${GREEN}Found: docker-compose (Compose V1)${NC}"
            echo "docker-compose"
            return
        fi
    fi

    # Then try docker compose (newer, built into Docker)
    if command -v docker &> /dev/null; then
        if docker compose version &>/dev/null; then
            echo -e "${GREEN}Found: docker compose (Compose V2)${NC}"
            echo "docker compose"
            return
        fi
    fi

    # Neither found
    echo -e "${RED}Error: Docker is not installed or not found in PATH.${NC}"
    echo ""
    echo -e "${YELLOW}Please install Docker:${NC}"
    echo "  1. Download Docker Desktop from: https://www.docker.com/products/docker-desktop"
    echo "  2. Install and start Docker Desktop"
    echo "  3. Verify installation by running: docker --version"
    echo "  4. Verify Compose by running: docker-compose --version"
    echo ""
    exit 1
}

# Get the correct docker compose command
DOCKER_COMPOSE=$(get_docker_compose_cmd)
echo -e "${GREEN}Using: $DOCKER_COMPOSE${NC}"
echo -e "Compose File: $COMPOSE_FILE"
echo -e "${YELLOW}====================${NC}"
echo ""

# Execute the command
case $COMMAND in
    up)
        echo -e "${GREEN}Starting services...${NC}"
        $DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d
        echo -e "${GREEN}Services started successfully!${NC}"
        ;;
    down)
        echo -e "${YELLOW}Stopping and removing services...${NC}"
        $DOCKER_COMPOSE -f "$COMPOSE_FILE" down
        echo -e "${GREEN}Services stopped and removed.${NC}"
        ;;
    restart)
        echo -e "${YELLOW}Restarting services...${NC}"
        $DOCKER_COMPOSE -f "$COMPOSE_FILE" restart
        echo -e "${GREEN}Services restarted successfully!${NC}"
        ;;
    logs)
        $DOCKER_COMPOSE -f "$COMPOSE_FILE" logs -f
        ;;
    ps)
        $DOCKER_COMPOSE -f "$COMPOSE_FILE" ps
        ;;
    pull)
        echo -e "${GREEN}Pulling latest images...${NC}"
        $DOCKER_COMPOSE -f "$COMPOSE_FILE" pull
        echo -e "${GREEN}Images pulled successfully!${NC}"
        ;;
esac
