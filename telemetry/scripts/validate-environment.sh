#!/bin/bash
#
# validate-environment.sh - Pre-flight environment validation for monitoring stack
#
# This script performs comprehensive checks before deployment:
# - Docker installation
# - Docker Compose installation
# - System resources (CPU, RAM, disk)
# - Port availability (4101, 4102, 4103, 27017)
# - .env file existence and readability
# - Required directories
# - Log file access
# - Reports all issues with proper error codes
#
# Usage:
#   ./validate-environment.sh [--help] [--verbose] [--fix] [--skip-port-check]
#
# Author: DevOps Team
# Version: 1.0.0
#

set -euo pipefail

# Script metadata
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="${PROJECT_ROOT}/logs/validation.log"

# Default values
VERBOSE=false
AUTO_FIX=false
SKIP_PORT_CHECK=false
EXIT_ON_ERROR=true

# Validation results
VALIDATION_ERRORS=()
VALIDATION_WARNINGS=()
VALIDATION_PASS=()

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ports to check
REQUIRED_PORTS=(
    4101  # Grafana
    4102  # Prometheus
    4103  # Loki
    27017 # MongoDB
)

# Minimum requirements
MIN_CPU_CORES=2
MIN_RAM_GB=4
MIN_DISK_GB=50

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
    echo -e "${GREEN}[PASS]${NC} $message"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PASS] $message" >> "${LOG_FILE}"
    VALIDATION_PASS+=("$message")
}

log_warning() {
    local message="$1"
    echo -e "${YELLOW}[WARN]${NC} $message"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $message" >> "${LOG_FILE}"
    VALIDATION_WARNINGS+=("$message")
}

log_error() {
    local message="$1"
    echo -e "${RED}[FAIL]${NC} $message" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [FAIL] $message" >> "${LOG_FILE}"
    VALIDATION_ERRORS+=("$message")
}

log_verbose() {
    local message="$1"
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $message"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [VERBOSE] $message" >> "${LOG_FILE}"
    fi
}

# ============================================================================
# DOCKER CHECKS
# ============================================================================

check_docker_installed() {
    log_info "Checking Docker installation..."

    if command -v docker &> /dev/null; then
        local docker_version
        docker_version=$(docker --version | awk '{print $3}' | sed 's/,//')
        log_success "Docker is installed (version: ${docker_version})"

        # Check version (require 20.10+)
        local major minor
        major=$(echo "$docker_version" | cut -d. -f1)
        minor=$(echo "$docker_version" | cut -d. -f2)

        if [[ "$major" -gt 20 ]] || [[ "$major" -eq 20 && "$minor" -ge 10 ]]; then
            log_success "Docker version meets requirements (>= 20.10)"
        else
            log_error "Docker version ${docker_version} is too old. Minimum required: 20.10"
        fi
    else
        log_error "Docker is not installed"
        if [[ "$AUTO_FIX" == true ]]; then
            log_info "Attempting to install Docker..."
            attempt_docker_installation
        else
            log_error "Install Docker from: https://docs.docker.com/engine/install/"
        fi
    fi
}

check_docker_compose_installed() {
    log_info "Checking Docker Compose installation..."

    if command -v docker-compose &> /dev/null; then
        local compose_version
        compose_version=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
        log_success "Docker Compose is installed (version: ${compose_version})"

        # Check version (require 2.20+)
        if [[ -n "$compose_version" ]]; then
            local major minor
            major=$(echo "$compose_version" | cut -d. -f1)
            minor=$(echo "$compose_version" | cut -d. -f2)

            if [[ "$major" -gt 2 ]] || [[ "$major" -eq 2 && "$minor" -ge 20 ]]; then
                log_success "Docker Compose version meets requirements (>= 2.20)"
            else
                log_warning "Docker Compose version ${compose_version} is old. Recommended: 2.20+"
            fi
        else
            log_warning "Could not determine Docker Compose version"
        fi
    elif docker compose version &> /dev/null; then
        local compose_version
        compose_version=$(docker compose version | awk '{print $5}' | sed 's/,//')
        log_success "Docker Compose (v2 plugin) is installed (version: ${compose_version})"
    else
        log_error "Docker Compose is not installed"
        if [[ "$AUTO_FIX" == true ]]; then
            log_info "Attempting to install Docker Compose..."
            attempt_docker_compose_installation
        else
            log_error "Install Docker Compose from: https://docs.docker.com/compose/install/"
        fi
    fi
}

check_docker_running() {
    log_info "Checking if Docker daemon is running..."

    if docker info &> /dev/null; then
        log_success "Docker daemon is running"

        # Check Docker registry connectivity
        if docker pull hello-world:latest &> /dev/null; then
            log_success "Docker registry connectivity confirmed"
        else
            log_warning "Cannot pull images from Docker registry. Check internet connection."
        fi
    else
        log_error "Docker daemon is not running"
        log_info "Start Docker with: sudo systemctl start docker"
    fi
}

attempt_docker_installation() {
    log_info "Docker installation is not automatic. Please install manually:"
    echo "  Ubuntu/Debian: https://docs.docker.com/engine/install/ubuntu/"
    echo "  CentOS/RHEL: https://docs.docker.com/engine/install/centos/"
    log_error "Docker installation requires manual intervention"
}

attempt_docker_compose_installation() {
    log_info "Docker Compose installation is not automatic. Please install manually:"
    echo "  Latest release: https://github.com/docker/compose/releases"
    log_error "Docker Compose installation requires manual intervention"
}

# ============================================================================
# SYSTEM RESOURCE CHECKS
# ============================================================================

check_cpu_cores() {
    log_info "Checking CPU cores..."

    local cpu_cores
    cpu_cores=$(nproc 2>/dev/null || echo "1")

    if [[ "$cpu_cores" -ge "$MIN_CPU_CORES" ]]; then
        log_success "CPU cores: ${cpu_cores} (required: ${MIN_CPU_CORES}+)"
    else
        log_error "CPU cores: ${cpu_cores} (required: ${MIN_CPU_CORES}+)"
        log_error "Insufficient CPU resources. Monitoring stack requires at least ${MIN_CPU_CORES} cores."
    fi
}

check_ram() {
    log_info "Checking available RAM..."

    local total_ram_gb
    # Get total RAM in GB (works on both Linux and macOS)
    if [[ -f /proc/meminfo ]]; then
        total_ram_gb=$(awk '/MemTotal/ {printf "%.1f", $2/1024/1024}' /proc/meminfo)
    else
        total_ram_gb=$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.1f", $1/1024/1024/1024}')
    fi

    # Use awk for floating-point comparison that works across platforms
    local ram_check=$(awk -v ram="$total_ram_gb" -v min="$MIN_RAM_GB" 'BEGIN { print (ram >= min) ? 1 : 0 }')
    if [[ "$ram_check" == "1" ]]; then
        log_success "Total RAM: ${total_ram_gb} GB (required: ${MIN_RAM_GB}+ GB)"
    else
        log_error "Total RAM: ${total_ram_gb} GB (required: ${MIN_RAM_GB}+ GB)"
        log_error "Insufficient RAM. Monitoring stack requires at least ${MIN_RAM_GB} GB."
    fi
}

check_disk_space() {
    log_info "Checking available disk space..."

    local available_disk_gb
    local mount_point="${PROJECT_ROOT}"

    # Get available disk space in GB
    available_disk_gb=$(df -BG "$mount_point" | awk 'NR==2 {print $4}' | sed 's/G//')

    if [[ "$available_disk_gb" -ge "$MIN_DISK_GB" ]]; then
        log_success "Available disk space: ${available_disk_gb} GB (required: ${MIN_DISK_GB}+ GB)"
    else
        log_error "Available disk space: ${available_disk_gb} GB (required: ${MIN_DISK_GB}+ GB)"
        log_error "Insufficient disk space. Monitoring stack requires at least ${MIN_DISK_GB} GB."
    fi
}

# ============================================================================
# PORT CHECKS
# ============================================================================

check_port_availability() {
    if [[ "$SKIP_PORT_CHECK" == true ]]; then
        log_warning "Skipping port availability check (--skip-port-check flag set)"
        return
    fi

    log_info "Checking port availability..."

    for port in "${REQUIRED_PORTS[@]}"; do
        local port_in_use=false
        local process_name=""

        # Check if port is in use (Linux)
        if command -v ss &> /dev/null; then
            if ss -tuln | grep -q ":${port} "; then
                port_in_use=true
                process_name=$(ss -tulnp | grep ":${port} " | awk '{print $7}' | head -1)
            fi
        elif command -v netstat &> /dev/null; then
            if netstat -tuln | grep -q ":${port} "; then
                port_in_use=true
                process_name=$(netstat -tulnp | grep ":${port} " | awk '{print $7}' | head -1)
            fi
        fi

        if [[ "$port_in_use" == false ]]; then
            local service_name
            case "$port" in
                4101) service_name="Grafana" ;;
                4102) service_name="Prometheus" ;;
                4103) service_name="Loki" ;;
                27017) service_name="MongoDB" ;;
            esac
            log_success "Port ${port} is available (${service_name})"
        else
            log_error "Port ${port} is already in use by: ${process_name}"
            log_error "Stop the conflicting process or change the port in .env file"
        fi
    done
}

# ============================================================================
# ENVIRONMENT FILE CHECKS
# ============================================================================

check_env_file() {
    log_info "Checking environment file..."

    local env_file="${PROJECT_ROOT}/.env"

    if [[ -f "$env_file" ]]; then
        log_success ".env file exists"

        if [[ -r "$env_file" ]]; then
            log_success ".env file is readable"
        else
            log_error ".env file is not readable"
        fi

        # Check for required variables
        local required_vars=(
            "GF_SECURITY_ADMIN_PASSWORD"
            "MONGO_INITDB_ROOT_PASSWORD"
        )

        for var in "${required_vars[@]}"; do
            if grep -q "^${var}=" "$env_file" 2>/dev/null; then
                local value
                value=$(grep "^${var}=" "$env_file" | cut -d= -f2-)
                if [[ -n "$value" && "$value" != "" ]]; then
                    log_success "Environment variable ${var} is set"
                else
                    log_error "Environment variable ${var} is empty"
                fi
            else
                log_error "Environment variable ${var} is not set"
            fi
        done
    else
        log_error ".env file does not exist"
        log_error "Run ./scripts/setup-env.sh to create it"
    fi
}

# ============================================================================
# DIRECTORY CHECKS
# ============================================================================

check_directories() {
    log_info "Checking required directories..."

    local required_dirs=(
        "${PROJECT_ROOT}/config"
        "${PROJECT_ROOT}/data"
        "${PROJECT_ROOT}/data/grafana"
        "${PROJECT_ROOT}/data/prometheus"
        "${PROJECT_ROOT}/data/loki"
        "${PROJECT_ROOT}/data/mongodb"
        "${PROJECT_ROOT}/logs"
        "${PROJECT_ROOT}/config/prometheus-file-sd"
    )

    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            if [[ -w "$dir" ]]; then
                log_success "Directory exists and writable: ${dir}"
            else
                log_error "Directory exists but not writable: ${dir}"
            fi
        else
            log_error "Directory missing: ${dir}"
            log_error "Run ./scripts/setup-permissions.sh to create directories"
        fi
    done
}

# ============================================================================
# LOG ACCESS CHECKS
# ============================================================================

check_log_access() {
    log_info "Checking log file access..."

    local log_files=(
        "/var/log/auth.log"
        "/var/log/syslog"
        "/var/log/messages"
    )

    local can_read_any=false

    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            if [[ -r "$log_file" ]]; then
                log_success "Can read log file: ${log_file}"
                can_read_any=true
            else
                log_warning "Cannot read log file (permission denied): ${log_file}"
            fi
        fi
    done

    if [[ "$can_read_any" == false ]]; then
        log_error "Cannot read any system log files"
        log_error "Log collection will not work properly"
        log_error "Run ./scripts/setup-permissions.sh to fix log access"
    fi
}

# ============================================================================
# OS AND KERNEL CHECKS
# ============================================================================

check_os_compatibility() {
    log_info "Checking OS compatibility..."

    # Check if running on Linux
    if [[ "$(uname)" != "Linux" ]]; then
        log_warning "Not running on Linux. Some features may not work."
    else
        log_success "Running on Linux ($(uname -m) architecture)"
    fi

    # Check kernel version
    local kernel_version
    kernel_version=$(uname -r | cut -d- -f1)
    local major minor
    major=$(echo "$kernel_version" | cut -d. -f1)
    minor=$(echo "$kernel_version" | cut -d. -f2)

    if [[ "$major" -gt 3 ]] || [[ "$major" -eq 3 && "$minor" -ge 10 ]]; then
        log_success "Kernel version ${kernel_version} meets requirements (>= 3.10)"
    else
        log_warning "Kernel version ${kernel_version} is old. Some features may not work."
    fi
}

# ============================================================================
# SUMMARY AND REPORTING
# ============================================================================

print_summary() {
    echo ""
    echo "================================================================"
    echo "  ENVIRONMENT VALIDATION SUMMARY"
    echo "================================================================"
    echo ""

    echo "Passed Checks: ${#VALIDATION_PASS[@]}"
    if [[ ${#VALIDATION_PASS[@]} -gt 0 ]]; then
        for check in "${VALIDATION_PASS[@]}"; do
            echo "  ✓ ${check}"
        done
    fi
    echo ""

    if [[ ${#VALIDATION_WARNINGS[@]} -gt 0 ]]; then
        echo "Warnings: ${#VALIDATION_WARNINGS[@]}"
        for warning in "${VALIDATION_WARNINGS[@]}"; do
            echo "  ⚠ ${warning}"
        done
        echo ""
    fi

    if [[ ${#VALIDATION_ERRORS[@]} -gt 0 ]]; then
        echo "Errors: ${#VALIDATION_ERRORS[@]}"
        for error in "${VALIDATION_ERRORS[@]}"; do
            echo "  ✗ ${error}"
        done
        echo ""
    fi

    echo "Log file: ${LOG_FILE}"
    echo ""

    if [[ ${#VALIDATION_ERRORS[@]} -eq 0 ]]; then
        echo -e "${GREEN}All validation checks passed!${NC}"
        echo ""
        echo "You can proceed with deployment:"
        echo "  ./scripts/deploy.sh"
        echo ""
        return 0
    else
        echo -e "${RED}Validation failed with ${#VALIDATION_ERRORS[@]} error(s)${NC}"
        echo ""

        if [[ "$AUTO_FIX" == true ]]; then
            echo "Auto-fix mode was enabled, but some issues require manual intervention."
        else
            echo "Run with --auto-fix to attempt automatic fixes for some issues."
        fi

        echo ""
        echo "Please fix the errors above before proceeding."
        echo ""

        if [[ "$EXIT_ON_ERROR" == true ]]; then
            return 1
        else
            echo "Continuing despite errors (--continue-on-error flag set)"
            echo ""
            return 0
        fi
    fi
}

# ============================================================================
# HELP AND USAGE
# ============================================================================

print_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Pre-flight validation for monitoring stack deployment.

OPTIONS:
  -h, --help              Show this help message
  -v, --verbose           Enable verbose logging
  -f, --auto-fix          Attempt to automatically fix some issues
  -s, --skip-port-check   Skip port availability checks
  -c, --continue-on-error Continue even if validation fails

CHECKS PERFORMED:
  ✓ Docker installation and version
  ✓ Docker Compose installation and version
  ✓ Docker daemon running
  ✓ System resources (CPU, RAM, disk)
  ✓ Port availability (4101, 4102, 4103, 27017)
  ✓ .env file existence and variables
  ✓ Required directories
  ✓ Log file access permissions
  ✓ OS compatibility

MINIMUM REQUIREMENTS:
  - Docker: 20.10+
  - Docker Compose: 2.20+
  - CPU: ${MIN_CPU_CORES}+ cores
  - RAM: ${MIN_RAM_GB}+ GB
  - Disk: ${MIN_DISK_GB}+ GB available
  - Linux Kernel: 3.10+

PORTS REQUIRED:
  - 4101: Grafana
  - 4102: Prometheus
  - 4103: Loki
  - 27017: MongoDB

EXAMPLES:
  # Normal validation
  $SCRIPT_NAME

  # Verbose mode
  $SCRIPT_NAME --verbose

  # Auto-fix minor issues
  $SCRIPT_NAME --auto-fix

  # Skip port checks (for testing)
  $SCRIPT_NAME --skip-port-check

  # Continue despite errors
  $SCRIPT_NAME --continue-on-error

EXIT CODES:
  0: All checks passed or --continue-on-error used
  1: Validation failed with errors

LOG FILE:
  ${LOG_FILE}

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
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -f|--auto-fix)
                AUTO_FIX=true
                shift
                ;;
            -s|--skip-port-check)
                SKIP_PORT_CHECK=true
                shift
                ;;
            -c|--continue-on-error)
                EXIT_ON_ERROR=false
                shift
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
    echo "Environment Validation Log - $(date)" >> "${LOG_FILE}"
    echo "========================================" >> "${LOG_FILE}"

    echo ""
    echo "================================================================"
    echo "  MONITORING STACK ENVIRONMENT VALIDATION"
    echo "================================================================"
    echo ""

    # Parse arguments
    parse_arguments "$@"

    # Run all checks
    check_os_compatibility
    check_docker_installed
    check_docker_compose_installed
    check_docker_running
    check_cpu_cores
    check_ram
    check_disk_space
    check_port_availability
    check_env_file
    check_directories
    check_log_access

    # Print summary
    print_summary

    # Exit with appropriate code
    if [[ ${#VALIDATION_ERRORS[@]} -gt 0 && "$EXIT_ON_ERROR" == true ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main "$@"
