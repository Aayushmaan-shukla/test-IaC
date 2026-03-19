#!/bin/bash
#
# deploy.sh - Main deployment orchestration for monitoring stack
#
# This script handles:
# - Running validate-environment.sh
# - Running setup-permissions.sh if needed
# - Docker Compose deployment
# - Waiting for containers to be healthy
# - Running health checks
# - Displaying URLs and credentials
# - Logging deployment status
# - Error handling and recovery
#
# Usage:
#   ./deploy.sh [--help] [--skip-validation] [--skip-permissions] [--detach]
#
# Author: DevOps Team
# Version: 1.0.0
#

set -euo pipefail

# Script metadata
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="${PROJECT_ROOT}/logs/deployment.log"
DEPLOYMENT_STATUS="${PROJECT_ROOT}/logs/deployment-status.json"

# Default values
SKIP_VALIDATION=false
SKIP_PERMISSIONS=false
DETACH=false
FORCE=false
TIMEOUT=600  # 10 minutes

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Deployment tracking
DEPLOYMENT_START=""
DEPLOYMENT_END=""
CONTAINERS_STARTED=()
CONTAINERS_FAILED=()

# Services to monitor
SERVICES=(
    "grafana"
    "prometheus"
    "loki"
    "promtail"
    "mongodb"
    "mongodb-exporter"
    "node-exporter"
)

# Health check URLs
HEALTH_URLS=(
    "http://localhost:4101/health"  # Grafana
    "http://localhost:4102/-/healthy"  # Prometheus
    "http://localhost:4103/ready"  # Loki
)

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

log_info() {
    local message="$1"
    echo -e "${BLUE}[INFO]${NC} $message"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $message" >> "${LOG_FILE}"
}

log_success() {
    local message="$1"
    echo -e "${GREEN}[SUCCESS]${NC} $message"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $message" >> "${LOG_FILE}"
}

log_warning() {
    local message="$1"
    echo -e "${YELLOW}[WARNING]${NC} $message"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $message" >> "${LOG_FILE}"
}

log_error() {
    local message="$1"
    echo -e "${RED}[ERROR]${NC} $message" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $message" >> "${LOG_FILE}"
}

log_verbose() {
    local message="$1"
    if [[ "${VERBOSE:-false}" == true ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $message"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [VERBOSE] $message" >> "${LOG_FILE}"
    fi
}

# ============================================================================
# DEPLOYMENT TRACKING
# ============================================================================

start_deployment_tracking() {
    DEPLOYMENT_START=$(date +%s)
    log_info "Starting deployment tracking..."

    # Initialize deployment status
    cat > "${DEPLOYMENT_STATUS}" << EOF
{
  "status": "in_progress",
  "start_time": "${DEPLOYMENT_START}",
  "end_time": null,
  "containers_started": [],
  "containers_failed": [],
  "health_checks": {},
  "errors": []
}
EOF
}

end_deployment_tracking() {
    DEPLOYMENT_END=$(date +%s)
    local duration=$((DEPLOYMENT_END - DEPLOYMENT_START))

    log_info "Deployment completed in ${duration} seconds"
}

# ============================================================================
# PRE-DEPLOYMENT CHECKS
# ============================================================================

run_validation() {
    if [[ "$SKIP_VALIDATION" == true ]]; then
        log_warning "Skipping environment validation (--skip-validation flag set)"
        return 0
    fi

    log_info "Running environment validation..."

    if [[ ! -f "${SCRIPT_DIR}/validate-environment.sh" ]]; then
        log_error "validate-environment.sh not found"
        return 1
    fi

    if bash "${SCRIPT_DIR}/validate-environment.sh"; then
        log_success "Environment validation passed"
        return 0
    else
        log_error "Environment validation failed"
        log_error "Run ./scripts/validate-environment.sh to see details"
        return 1
    fi
}

run_permission_setup() {
    if [[ "$SKIP_PERMISSIONS" == true ]]; then
        log_warning "Skipping permission setup (--skip-permissions flag set)"
        return 0
    fi

    log_info "Running permission setup..."

    if [[ ! -f "${SCRIPT_DIR}/setup-permissions.sh" ]]; then
        log_error "setup-permissions.sh not found"
        return 1
    fi

    if bash "${SCRIPT_DIR}/setup-permissions.sh"; then
        log_success "Permission setup completed"
        return 0
    else
        log_error "Permission setup failed"
        log_error "Run ./scripts/setup-permissions.sh to see details"
        return 1
    fi
}

check_docker_compose_file() {
    log_info "Checking for docker-compose.yml..."

    local compose_file="${PROJECT_ROOT}/docker-compose.yml"

    if [[ ! -f "$compose_file" ]]; then
        log_error "docker-compose.yml not found at: ${compose_file}"
        log_error "Please create docker-compose.yml before deploying"
        return 1
    fi

    log_success "docker-compose.yml found"
    return 0
}

check_env_file() {
    log_info "Checking for .env file..."

    local env_file="${PROJECT_ROOT}/.env"

    if [[ ! -f "$env_file" ]]; then
        log_error ".env file not found at: ${env_file}"
        log_error "Run ./scripts/setup-env.sh to create it"
        return 1
    fi

    log_success ".env file found"
    return 0
}

# ============================================================================
# DOCKER OPERATIONS
# ============================================================================

pull_docker_images() {
    log_info "Pulling Docker images..."

    cd "${PROJECT_ROOT}"

    if docker-compose pull; then
        log_success "Docker images pulled successfully"
        return 0
    else
        log_error "Failed to pull Docker images"
        return 1
    fi
}

start_containers() {
    log_info "Starting containers..."

    cd "${PROJECT_ROOT}"

    local detach_flag=""
    if [[ "$DETACH" == true ]]; then
        detach_flag="--detach"
    fi

    if docker-compose up -d $detach_flag; then
        log_success "Containers started successfully"

        # List started containers
        log_info "Started containers:"
        docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" | tee -a "${LOG_FILE}"

        # Track started containers
        while IFS= read -r line; do
            CONTAINERS_STARTED+=("$line")
        done < <(docker-compose ps --format "{{.Name}}")

        return 0
    else
        log_error "Failed to start containers"
        return 1
    fi
}

stop_containers() {
    log_info "Stopping containers..."

    cd "${PROJECT_ROOT}"

    if docker-compose down; then
        log_success "Containers stopped successfully"
        return 0
    else
        log_warning "Failed to stop some containers"
        return 1
    fi
}

# ============================================================================
# HEALTH CHECKS
# ============================================================================

wait_for_containers() {
    log_info "Waiting for containers to be healthy..."

    local timeout_seconds=300  # 5 minutes
    local elapsed=0
    local interval=10

    while [[ $elapsed -lt $timeout_seconds ]]; do
        local all_healthy=true

        for service in "${SERVICES[@]}"; do
            local container_status
            container_status=$(docker-compose ps -q "$service" | xargs -r docker inspect --format='{{.State.Health.Status}}' 2>/dev/null || echo "no_container")

            if [[ "$container_status" == "healthy" ]]; then
                log_verbose "Service ${service} is healthy"
            elif [[ "$container_status" == "no_container" ]]; then
                log_warning "Service ${service} has no health check defined"
            else
                log_info "Service ${service} status: ${container_status}"
                all_healthy=false
            fi
        done

        if [[ "$all_healthy" == true ]]; then
            log_success "All containers are healthy"
            return 0
        fi

        sleep "$interval"
        elapsed=$((elapsed + interval))
        log_info "Waiting for containers to be healthy... (${elapsed}/${timeout_seconds}s)"
    done

    log_error "Timeout waiting for containers to be healthy"
    log_warning "Some containers may still be starting up"
    return 1
}

run_health_checks() {
    log_info "Running health checks..."

    local all_passed=true

    # Check HTTP endpoints
    for url in "${HEALTH_URLS[@]}"; do
        log_info "Checking: ${url}"

        if curl -s -f "$url" > /dev/null 2>&1; then
            log_success "Health check passed: ${url}"
        else
            log_warning "Health check failed: ${url}"
            all_passed=false
        fi
    done

    # Check container status
    log_info "Checking container status..."
    for service in "${SERVICES[@]}"; do
        local status
        status=$(docker-compose ps "$service" --format "{{.State}}")

        if [[ "$status" == "running"* ]]; then
            log_success "Service ${service} is running"
        else
            log_error "Service ${service} is not running: ${status}"
            CONTAINERS_FAILED+=("$service")
            all_passed=false
        fi
    done

    if [[ "$all_passed" == true ]]; then
        log_success "All health checks passed"
        return 0
    else
        log_warning "Some health checks failed"
        return 1
    fi
}

# ============================================================================
# DEPLOYMENT STATUS
# ============================================================================

display_deployment_status() {
    echo ""
    echo "================================================================"
    echo "  DEPLOYMENT STATUS"
    echo "================================================================"
    echo ""

    echo "Containers:"
    docker-compose ps
    echo ""

    echo "Resource Usage:"
    docker-compose ps --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | head -10
    echo ""

    echo "Networks:"
    docker network ls | grep monitor || echo "No monitoring networks found"
    echo ""

    echo "Volumes:"
    docker volume ls | grep -E "monitoring|grafana|prometheus|loki|mongodb" || echo "No monitoring volumes found"
    echo ""
}

# ============================================================================
# CREDENTIALS AND URLS
# ============================================================================

display_credentials() {
    echo ""
    echo "================================================================"
    echo "  ACCESS CREDENTIALS"
    echo "================================================================"
    echo ""

    local env_file="${PROJECT_ROOT}/.env"

    if [[ -f "$env_file" ]]; then
        echo "Grafana:"
        echo "  URL: http://localhost:$(grep '^GRAFANA_PORT=' "$env_file" 2>/dev/null | cut -d= -f2 || echo "4101")"
        echo "  Username: $(grep '^GF_SECURITY_ADMIN_USER=' "$env_file" 2>/dev/null | cut -d= -f2 || echo "admin")"
        echo "  Password: [stored in .env.secrets]"
        echo ""

        echo "Prometheus:"
        echo "  URL: http://localhost:$(grep '^PROMETHEUS_PORT=' "$env_file" 2>/dev/null | cut -d= -f2 || echo "4102")"
        echo ""

        echo "Loki:"
        echo "  URL: http://localhost:$(grep '^LOKI_PORT=' "$env_file" 2>/dev/null | cut -d= -f2 || echo "4103")"
        echo ""

        echo "MongoDB:"
        echo "  Port: $(grep '^MONGODB_PORT=' "$env_file" 2>/dev/null | cut -d= -f2 || echo "27017")"
        echo "  Username: $(grep '^MONGO_INITDB_ROOT_USERNAME=' "$env_file" 2>/dev/null | cut -d= -f2 || echo "admin")"
        echo "  Password: [stored in .env.secrets]"
        echo ""
    else
        log_warning ".env file not found, cannot display credentials"
    fi

    echo "For detailed credentials, check: .env.secrets"
    echo ""
}

display_urls() {
    echo ""
    echo "================================================================"
    echo "  SERVICE URLS"
    echo "================================================================"
    echo ""

    local env_file="${PROJECT_ROOT}/.env"

    echo "Main Services:"
    echo "  Grafana Dashboard:  http://localhost:$(grep '^GRAFANA_PORT=' "$env_file" 2>/dev/null | cut -d= -f2 || echo "4101")"
    echo "  Prometheus:        http://localhost:$(grep '^PROMETHEUS_PORT=' "$env_file" 2>/dev/null | cut -d= -f2 || echo "4102")"
    echo "  Loki:              http://localhost:$(grep '^LOKI_PORT=' "$env_file" 2>/dev/null | cut -d= -f2 || echo "4103")"
    echo ""

    echo "Data Sources:"
    echo "  MongoDB:           mongodb://localhost:$(grep '^MONGODB_PORT=' "$env_file" 2>/dev/null | cut -d= -f2 || echo "27017")"
    echo "  Node Exporter:     http://localhost:9100/metrics"
    echo "  Mongo Exporter:    http://localhost:9214/metrics"
    echo ""

    echo "Quick Commands:"
    echo "  View logs:         docker-compose logs -f"
    echo "  Restart stack:     docker-compose restart"
    echo "  Stop stack:        docker-compose down"
    echo "  Restart service:   docker-compose restart [service-name]"
    echo ""
}

# ============================================================================
# ERROR HANDLING
# ============================================================================

handle_error() {
    local error_message="$1"
    log_error "$error_message"

    echo ""
    echo "================================================================"
    echo "  DEPLOYMENT FAILED"
    echo "================================================================"
    echo ""
    echo "Error: ${error_message}"
    echo ""
    echo "Troubleshooting Steps:"
    echo "  1. Check logs: docker-compose logs"
    echo "  2. Check specific service: docker-compose logs [service-name]"
    echo "  3. Validate environment: ./scripts/validate-environment.sh"
    echo "  4. Check permissions: ./scripts/setup-permissions.sh --verbose"
    echo ""
    echo "For detailed logs, check: ${LOG_FILE}"
    echo ""

    end_deployment_tracking
    exit 1
}

cleanup_on_error() {
    log_warning "Cleaning up after deployment failure..."

    cd "${PROJECT_ROOT}"

    # Don't automatically stop containers, let user decide
    log_warning "Containers are still running. Check logs to diagnose issues."
    log_warning "To stop containers: docker-compose down"
}

# ============================================================================
# SUMMARY
# ============================================================================

print_summary() {
    local duration
    duration=$((DEPLOYMENT_END - DEPLOYMENT_START))

    echo ""
    echo "================================================================"
    echo "  DEPLOYMENT SUMMARY"
    echo "================================================================"
    echo ""

    echo "Deployment Duration: ${duration} seconds"
    echo ""

    echo "Containers Started: ${#CONTAINERS_STARTED[@]}"
    for container in "${CONTAINERS_STARTED[@]}"; do
        echo "  ✓ ${container}"
    done
    echo ""

    if [[ ${#CONTAINERS_FAILED[@]} -gt 0 ]]; then
        echo "Containers Failed: ${#CONTAINERS_FAILED[@]}"
        for container in "${CONTAINERS_FAILED[@]}"; do
            echo "  ✗ ${container}"
        done
        echo ""
    fi

    echo "Log File: ${LOG_FILE}"
    echo "Status File: ${DEPLOYMENT_STATUS}"
    echo ""

    if [[ ${#CONTAINERS_FAILED[@]} -eq 0 ]]; then
        echo -e "${GREEN}Deployment completed successfully!${NC}"
        echo ""
        echo "Next Steps:"
        echo "  1. Access Grafana at the URL above"
        echo "  2. Import dashboards for your needs"
        echo "  3. Configure log sources in Promtail"
        echo "  4. Set up alerts if needed"
        echo ""
        echo "To manage the stack:"
        echo "  View logs: docker-compose logs -f [service]"
        echo "  Restart: docker-compose restart [service]"
        echo "  Stop: docker-compose down"
        echo ""
    else
        echo -e "${RED}Deployment completed with errors${NC}"
        echo ""
        echo "Some services failed to start. Check logs for details:"
        echo "  docker-compose logs [failed-service]"
        echo ""
    fi

    echo "For more information, check the documentation."
    echo ""
}

# ============================================================================
# HELP AND USAGE
# ============================================================================

print_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Deploy monitoring stack using Docker Compose.

This script will:
  - Validate environment (unless --skip-validation)
  - Setup permissions (unless --skip-permissions)
  - Pull Docker images
  - Start containers
  - Wait for containers to be healthy
  - Run health checks
  - Display access credentials and URLs

OPTIONS:
  -h, --help              Show this help message
  -s, --skip-validation   Skip environment validation
  -p, --skip-permissions  Skip permission setup
  -d, --detach            Run in detached mode (don't attach to logs)
  -f, --force             Continue despite warnings
  -v, --verbose           Enable verbose logging
  -t, --timeout SECONDS   Deployment timeout (default: 600)

EXAMPLES:
  # Normal deployment with validation
  $SCRIPT_NAME

  # Skip validation (for testing)
  $SCRIPT_NAME --skip-validation

  # Run in detached mode
  $SCRIPT_NAME --detach

  # Deploy with custom timeout
  $SCRIPT_NAME --timeout 1200

  # Skip all pre-flight checks
  $SCRIPT_NAME --skip-validation --skip-permissions

REQUIREMENTS:
  - Docker and Docker Compose installed
  - .env file configured (run setup-env.sh)
  - Proper permissions (run setup-permissions.sh)
  - Sufficient system resources

AFTER DEPLOYMENT:
  - Access Grafana dashboard
  - Import or create dashboards
  - Configure log sources
  - Set up alerts if needed

TROUBLESHOOTING:
  - View logs: docker-compose logs -f
  - Check status: docker-compose ps
  - Restart: docker-compose restart
  - Stop: docker-compose down

LOG FILES:
  Deployment log: ${LOG_FILE}
  Status file: ${DEPLOYMENT_STATUS}

EOF
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_help
                exit 0
                ;;
            -s|--skip-validation)
                SKIP_VALIDATION=true
                shift
                ;;
            -p|--skip-permissions)
                SKIP_PERMISSIONS=true
                shift
                ;;
            -d|--detach)
                DETACH=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -v|--verbose)
                export VERBOSE=true
                shift
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")"

    # Initialize log file
    echo "========================================" > "${LOG_FILE}"
    echo "Deployment Log - $(date)" >> "${LOG_FILE}"
    echo "========================================" >> "${LOG_FILE}"

    echo ""
    echo "================================================================"
    echo "  MONITORING STACK DEPLOYMENT"
    echo "================================================================"
    echo ""

    # Parse arguments
    parse_arguments "$@"

    # Start deployment tracking
    start_deployment_tracking

    # Trap errors
    trap 'handle_error "Deployment failed unexpectedly"' ERR

    # Pre-deployment checks
    if ! check_docker_compose_file; then
        handle_error "Docker Compose file not found"
    fi

    if ! check_env_file; then
        handle_error "Environment file not found"
    fi

    if ! run_validation; then
        if [[ "$FORCE" == false ]]; then
            handle_error "Environment validation failed"
        else
            log_warning "Continuing despite validation failure (--force)"
        fi
    fi

    if ! run_permission_setup; then
        if [[ "$FORCE" == false ]]; then
            handle_error "Permission setup failed"
        else
            log_warning "Continuing despite permission issues (--force)"
        fi
    fi

    # Pull images
    if ! pull_docker_images; then
        if [[ "$FORCE" == false ]]; then
            handle_error "Failed to pull Docker images"
        else
            log_warning "Continuing despite image pull failure (--force)"
        fi
    fi

    # Start containers
    if ! start_containers; then
        handle_error "Failed to start containers"
    fi

    # Wait for containers and health checks
    log_info "Waiting for containers to stabilize..."
    sleep 10  # Give containers time to initialize

    if ! wait_for_containers; then
        log_warning "Not all containers are healthy, but continuing..."
    fi

    if ! run_health_checks; then
        log_warning "Some health checks failed"
    fi

    # End deployment tracking
    end_deployment_tracking

    # Display status
    display_deployment_status
    display_credentials
    display_urls
    print_summary

    log_success "Deployment completed!"
    echo "================================================================"
}

# Run main function
main "$@"
