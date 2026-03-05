#!/bin/bash

# Docker Compose Deployment Script
# Handles both 'docker compose' and 'docker-compose' commands
# Supports AWS Secrets Manager for environment configuration

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# AWS Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_SECRET_ARN="${AWS_SECRET_ARN:-arn:aws:secretsmanager:us-east-1:850995546121:secret:app/dev/backend-config-D7tdKZ}"

# Default values
APP_PORT="${APP_PORT:-8000}"
MODE="${MODE:-development}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PASSWORD="${REDIS_PASSWORD:-redis123}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres123}"
POSTGRES_DB="${POSTGRES_DB:-sampledb}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"

# Usage function
usage() {
    echo "Usage: $0 [OPTIONS] [COMMAND]"
    echo ""
    echo "Options:"
    echo "  -e, --env-file FILE      Load environment variables from file"
    echo "  -f, --file FILE          Specify docker-compose file (default: docker-compose.yml)"
    echo "  -p, --app-port PORT      Application port (default: 8000)"
    echo "  -m, --mode MODE          Application mode (default: development)"
    echo "  --redis-port PORT        Redis port (default: 6379)"
    echo "  --redis-password PASS    Redis password (default: redis123)"
    echo "  --postgres-port PORT     Postgres port (default: 5432)"
    echo "  --postgres-user USER     Postgres user (default: postgres)"
    echo "  --postgres-password PASS Postgres password (default: postgres123)"
    echo "  --postgres-db DB         Postgres database (default: sampledb)"
    echo "  --aws-region REGION      AWS region (default: us-east-1)"
    echo "  --aws-secret-arn ARN     AWS Secrets Manager secret ARN"
    echo "  --no-aws                 Skip AWS Secrets Manager and use local values"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Commands:"
    echo "  up       Start services (default)"
    echo "  down     Stop and remove services"
    echo "  restart  Restart services"
    echo "  logs     Show logs"
    echo "  ps       List running containers"
    echo "  pull     Pull latest images"
    echo ""
    echo "Environment Variables:"
    echo "  Alternatively, you can set environment variables before running this script:"
    echo "  APP_PORT, MODE, REDIS_PORT, REDIS_PASSWORD, POSTGRES_PORT,"
    echo "  POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB"
    echo "  AWS_REGION, AWS_SECRET_ARN"
    exit 0
}

# Parse command line arguments
COMMAND="up"
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--env-file)
            if [[ -f "$2" ]]; then
                set -a
                source "$2"
                set +a
                echo -e "${GREEN}Loaded environment from: $2${NC}"
            else
                echo -e "${RED}Error: Environment file not found: $2${NC}"
                exit 1
            fi
            shift 2
            ;;
        -f|--file)
            COMPOSE_FILE="$2"
            shift 2
            ;;
        -p|--app-port)
            APP_PORT="$2"
            shift 2
            ;;
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        --redis-port)
            REDIS_PORT="$2"
            shift 2
            ;;
        --redis-password)
            REDIS_PASSWORD="$2"
            shift 2
            ;;
        --postgres-port)
            POSTGRES_PORT="$2"
            shift 2
            ;;
        --postgres-user)
            POSTGRES_USER="$2"
            shift 2
            ;;
        --postgres-password)
            POSTGRES_PASSWORD="$2"
            shift 2
            ;;
        --postgres-db)
            POSTGRES_DB="$2"
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

# Function to load environment from AWS Secrets Manager
load_from_aws_secrets() {
    # Check if AWS CLI is available
    if ! command -v aws &> /dev/null; then
        echo -e "${YELLOW}Warning: AWS CLI not found. Skipping AWS Secrets Manager.${NC}"
        echo -e "${YELLOW}Install AWS CLI: https://aws.amazon.com/cli/${NC}"
        return 1
    fi

    echo -e "${GREEN}Fetching secrets from AWS Secrets Manager...${NC}"
    echo -e "  Region: $AWS_REGION"
    echo -e "  Secret: $AWS_SECRET_ARN"

    # Fetch secret value
    local secret_json
    secret_json=$(aws secretsmanager get-secret-value \
        --region "$AWS_REGION" \
        --secret-id "$AWS_SECRET_ARN" \
        --query SecretString \
        --output text 2>&1)

    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Cannot fetch data from AWS Secrets Manager.${NC}"
        echo -e "${RED}Details: $secret_json${NC}"
        echo ""
        echo -e "${YELLOW}Falling back to local environment values...${NC}"
        echo ""
        echo -e "${YELLOW}If you want to use local .env file, create a file named '.env' in this directory:${NC}"
        echo -e "${YELLOW}Location: $(pwd)/.env${NC}"
        echo -e "${YELLOW}And run: $0 -e .env up${NC}"
        return 1
    fi

    echo -e "${GREEN}Successfully fetched secrets from AWS!${NC}"
    echo ""

    # Parse JSON and export variables
    # Using jq if available, otherwise fallback to grep/sed
    if command -v jq &> /dev/null; then
        # Parse using jq
        local app_port=$(echo "$secret_json" | jq -r '.APP_PORT // empty')
        local mode=$(echo "$secret_json" | jq -r '.MODE // empty')
        local redis_port=$(echo "$secret_json" | jq -r '.REDIS_PORT // empty')
        local redis_password=$(echo "$secret_json" | jq -r '.REDIS_PASSWORD // empty')
        local postgres_port=$(echo "$secret_json" | jq -r '.POSTGRES_PORT // empty')
        local postgres_user=$(echo "$secret_json" | jq -r '.POSTGRES_USER // empty')
        local postgres_password=$(echo "$secret_json" | jq -r '.POSTGRES_PASSWORD // empty')
        local postgres_db=$(echo "$secret_json" | jq -r '.POSTGRES_DB // empty')
    else
        # Fallback: parse using grep and sed
        app_port=$(echo "$secret_json" | grep -o '"APP_PORT":[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/')
        mode=$(echo "$secret_json" | grep -o '"MODE":[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/')
        redis_port=$(echo "$secret_json" | grep -o '"REDIS_PORT":[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/')
        redis_password=$(echo "$secret_json" | grep -o '"REDIS_PASSWORD":[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/')
        postgres_port=$(echo "$secret_json" | grep -o '"POSTGRES_PORT":[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/')
        postgres_user=$(echo "$secret_json" | grep -o '"POSTGRES_USER":[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/')
        postgres_password=$(echo "$secret_json" | grep -o '"POSTGRES_PASSWORD":[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/')
        postgres_db=$(echo "$secret_json" | grep -o '"POSTGRES_DB":[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/')
    fi

    # Override defaults only if values exist
    [ -n "$app_port" ] && APP_PORT="$app_port"
    [ -n "$mode" ] && MODE="$mode"
    [ -n "$redis_port" ] && REDIS_PORT="$redis_port"
    [ -n "$redis_password" ] && REDIS_PASSWORD="$redis_password"
    [ -n "$postgres_port" ] && POSTGRES_PORT="$postgres_port"
    [ -n "$postgres_user" ] && POSTGRES_USER="$postgres_user"
    [ -n "$postgres_password" ] && POSTGRES_PASSWORD="$postgres_password"
    [ -n "$postgres_db" ] && POSTGRES_DB="$postgres_db"

    return 0
}

# Load from AWS Secrets Manager unless explicitly disabled
SKIP_AWS=false
if [[ "$@" == *"--no-aws"* ]]; then
    SKIP_AWS=true
fi

if [ "$SKIP_AWS" = false ]; then
    # Try to load from AWS Secrets Manager
    load_from_aws_secrets || true
fi

# Function to detect and use the correct docker compose command
get_docker_compose_cmd() {
    # Check if docker compose (newer command) is available
    if docker compose version &>/dev/null; then
        echo "docker compose"
        return
    fi

    # Check if docker-compose (older command) is available
    if docker-compose --version &>/dev/null; then
        echo "docker-compose"
        return
    fi

    echo -e "${RED}Error: Neither 'docker compose' nor 'docker-compose' command is available.${NC}"
    echo "Please install Docker Compose or ensure Docker is properly installed."
    exit 1
}

# Export environment variables
export APP_PORT
export MODE
export REDIS_PORT
export REDIS_PASSWORD
export POSTGRES_PORT
export POSTGRES_USER
export POSTGRES_PASSWORD
export POSTGRES_DB

# Get the correct docker compose command
DOCKER_COMPOSE=$(get_docker_compose_cmd)
echo -e "${GREEN}Using: $DOCKER_COMPOSE${NC}"

# Display configuration
echo -e "${YELLOW}=== Configuration ===${NC}"
echo "App Port: $APP_PORT"
echo "Mode: $MODE"
echo "Redis Port: $REDIS_PORT"
echo "Postgres Port: $POSTGRES_PORT"
echo "Compose File: $COMPOSE_FILE"
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
