#!/bin/bash
#
# setup-permissions.sh - Setup permissions for monitoring stack deployment
#
# This script handles:
# - User context detection (root vs non-root)
# - Directory structure creation with correct ownership
# - Log access permissions (adm/systemd-journal groups)
# - Docker volume permissions
# - Idempotent operations (safe to run multiple times)
# - Comprehensive logging for rollback
#
# Usage:
#   ./setup-permissions.sh [--help] [--verbose] [--dry-run] [--skip-logs]
#
# Author: DevOps Team
# Version: 1.0.0
#

set -euo pipefail

# Script metadata
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="${PROJECT_ROOT}/logs/setup-permissions.log"
ROLLBACK_LOG="${PROJECT_ROOT}/logs/rollback-actions.log"

# Default values
VERBOSE=false
DRY_RUN=false
SKIP_LOGS=false
FORCE=false

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# System detection
OS_TYPE=""
OS_VERSION=""
PKG_MANAGER=""

# User context
CURRENT_USER=""
CURRENT_UID=""
CURRENT_HOME=""
IS_ROOT=false
DEPLOYMENT_ROOT=""

# Permission tracking
CREATED_DIRS=()
ADDED_GROUPS=()
MODIFIED_PERMISSIONS=()

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
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $message"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [VERBOSE] $message" >> "${LOG_FILE}"
    fi
}

# ============================================================================
# ROLLBACK LOGGING
# ============================================================================

rollback_log() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "${ROLLBACK_LOG}"
}

# ============================================================================
# SYSTEM DETECTION
# ============================================================================

detect_system() {
    log_info "Detecting system information..."

    # Detect OS type
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS_TYPE="$ID"
        OS_VERSION="$VERSION_ID"
        log_info "Detected OS: ${PRETTY_NAME}"
    else
        log_error "Cannot detect OS type. /etc/os-release not found."
        exit 1
    fi

    # Detect package manager
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
    else
        log_error "Unsupported package manager. Only apt, yum, and dnf are supported."
        exit 1
    fi

    log_verbose "Package manager: ${PKG_MANAGER}"
}

detect_user_context() {
    log_info "Detecting user context..."

    CURRENT_USER="$(whoami)"
    CURRENT_UID="$(id -u)"
    CURRENT_HOME="${HOME:-/home/$CURRENT_USER}"

    if [[ "$CURRENT_UID" -eq 0 ]]; then
        IS_ROOT=true
        DEPLOYMENT_ROOT="${PROJECT_ROOT}"
        log_info "Running as root user"
        log_verbose "Deployment root: ${DEPLOYMENT_ROOT}"
    else
        IS_ROOT=false
        DEPLOYMENT_ROOT="${PROJECT_ROOT}"
        log_info "Running as non-root user: ${CURRENT_USER} (UID: ${CURRENT_UID})"
        log_verbose "Deployment root: ${DEPLOYMENT_ROOT}"
    fi
}

# ============================================================================
# PERMISSION FUNCTIONS
# ============================================================================

check_sudo_access() {
    log_info "Checking sudo access..."

    if [[ "$IS_ROOT" == true ]]; then
        log_info "Root access confirmed"
        return 0
    fi

    if sudo -n true 2>/dev/null; then
        log_success "Sudo access confirmed (passwordless)"
        return 0
    elif sudo true 2>/dev/null; then
        log_warning "Sudo access confirmed (password required)"
        return 0
    else
        log_error "No sudo access detected. Sudo is required for permission setup."
        exit 1
    fi
}

run_with_sudo() {
    local command="$1"

    if [[ "$IS_ROOT" == true ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            log_verbose "[DRY RUN] Would execute: $command"
        else
            eval "$command"
        fi
    else
        if [[ "$DRY_RUN" == true ]]; then
            log_verbose "[DRY RUN] Would execute with sudo: $command"
        else
            sudo eval "$command"
        fi
    fi
}

# ============================================================================
# DIRECTORY MANAGEMENT
# ============================================================================

create_directory_structure() {
    log_info "Creating directory structure..."

    local dirs=(
        "${PROJECT_ROOT}/data"
        "${PROJECT_ROOT}/data/grafana"
        "${PROJECT_ROOT}/data/prometheus"
        "${PROJECT_ROOT}/data/loki"
        "${PROJECT_ROOT}/data/mongodb"
        "${PROJECT_ROOT}/config"
        "${PROJECT_ROOT}/logs"
        "${PROJECT_ROOT}/config/prometheus-file-sd"
    )

    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_verbose "Directory already exists: ${dir}"

            # Check ownership
            local owner="$(stat -c '%U:%G' "$dir" 2>/dev/null || stat -f '%Su:%Sg' "$dir" 2>/dev/null)"
            if [[ "$IS_ROOT" == true ]]; then
                expected_owner="root:root"
            else
                expected_owner="${CURRENT_USER}:${CURRENT_USER}"
            fi

            if [[ "$owner" != "$expected_owner" ]]; then
                log_warning "Directory $dir has incorrect ownership: $owner (expected: $expected_owner)"
                log_info "Fixing ownership..."

                if [[ "$DRY_RUN" == false ]]; then
                    if [[ "$IS_ROOT" == true ]]; then
                        chown -R root:root "$dir"
                    else
                        run_with_sudo "chown -R ${CURRENT_USER}:${CURRENT_USER} '$dir'"
                    fi
                    log_success "Fixed ownership for: ${dir}"
                    rollback_log "chown -R ${owner} '$dir'  # Restore original ownership"
                fi
            fi
        else
            log_info "Creating directory: ${dir}"

            if [[ "$DRY_RUN" == false ]]; then
                mkdir -p "$dir"

                if [[ "$IS_ROOT" == true ]]; then
                    chown -R root:root "$dir"
                else
                    run_with_sudo "chown -R ${CURRENT_USER}:${CURRENT_USER} '$dir'"
                fi

                chmod 755 "$dir"

                log_success "Created directory: ${dir}"
                CREATED_DIRS+=("$dir")
                rollback_log "rm -rf '$dir'  # Remove created directory"
            fi
        fi
    done

    log_success "Directory structure created/verified"
}

# ============================================================================
# LOG ACCESS PERMISSIONS
# ============================================================================

setup_log_access() {
    if [[ "$SKIP_LOGS" == true ]]; then
        log_warning "Skipping log access setup (--skip-logs flag set)"
        return 0
    fi

    log_info "Setting up log access permissions..."

    local groups_to_add=()

    # Check for 'adm' group (Debian/Ubuntu)
    if getent group adm > /dev/null 2>&1; then
        if ! groups "$CURRENT_USER" | grep -q '\badm\b'; then
            groups_to_add+=("adm")
            log_info "User not in 'adm' group, will add"
        else
            log_info "User already in 'adm' group"
        fi
    fi

    # Check for 'systemd-journal' group (RedHat/CentOS/Fedora)
    if getent group systemd-journal > /dev/null 2>&1; then
        if ! groups "$CURRENT_USER" | grep -q '\bsystemd-journal\b'; then
            groups_to_add+=("systemd-journal")
            log_info "User not in 'systemd-journal' group, will add"
        else
            log_info "User already in 'systemd-journal' group"
        fi
    fi

    # Add user to groups
    if [[ ${#groups_to_add[@]} -gt 0 ]]; then
        log_info "Adding user to groups: ${groups_to_add[*]}"

        if [[ "$DRY_RUN" == false ]]; then
            for group in "${groups_to_add[@]}"; do
                if [[ "$IS_ROOT" == true ]]; then
                    usermod -aG "$group" "$CURRENT_USER"
                else
                    run_with_sudo "usermod -aG $group $CURRENT_USER"
                fi
                log_success "Added user to group: ${group}"
                ADDED_GROUPS+=("$group")
                rollback_log "gpasswd -d $CURRENT_USER $group  # Remove from group"
            done

            # Note: Group changes require user to log out and back in
            log_warning "Group changes applied. You may need to log out and log back in for changes to take effect."
        fi
    else
        log_info "No log access groups to add"
    fi

    # Test log file access
    log_info "Testing log file access..."

    local log_files=(
        "/var/log/auth.log"
        "/var/log/syslog"
        "/var/log/messages"
    )

    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            if [[ -r "$log_file" ]]; then
                log_success "Can read: ${log_file}"
            else
                log_warning "Cannot read: ${log_file} (permission denied)"
                if [[ "$FORCE" == false ]]; then
                    log_error "Log file access required. Use --force to continue anyway (not recommended)."
                    exit 1
                fi
            fi
        else
            log_verbose "Log file does not exist: ${log_file}"
        fi
    done

    log_success "Log access setup completed"
}

# ============================================================================
# DOCKER VOLUME PERMISSIONS
# ============================================================================

setup_docker_permissions() {
    log_info "Setting up Docker permissions..."

    # Check if user is in docker group (for non-root)
    if [[ "$IS_ROOT" == false ]]; then
        if ! groups "$CURRENT_USER" | grep -q '\bdocker\b'; then
            log_info "User not in 'docker' group"

            if getent group docker > /dev/null 2>&1; then
                log_info "Adding user to 'docker' group"

                if [[ "$DRY_RUN" == false ]]; then
                    run_with_sudo "usermod -aG docker $CURRENT_USER"
                    log_success "Added user to 'docker' group"
                    ADDED_GROUPS+=("docker")
                    rollback_log "gpasswd -d $CURRENT_USER docker  # Remove from group"
                    log_warning "You may need to log out and log back in for Docker group changes to take effect."
                fi
            else
                log_error "Docker group does not exist. Docker may not be installed."
            fi
        else
            log_info "User already in 'docker' group"
        fi
    fi

    # Set proper permissions on data directories
    log_info "Setting permissions on data directories..."

    local data_dirs=(
        "${PROJECT_ROOT}/data/grafana"
        "${PROJECT_ROOT}/data/prometheus"
        "${PROJECT_ROOT}/data/loki"
        "${PROJECT_ROOT}/data/mongodb"
    )

    for dir in "${data_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            if [[ "$DRY_RUN" == false ]]; then
                chmod 775 "$dir"
                log_verbose "Set permissions 775 on: ${dir}"
            fi
        fi
    done

    log_success "Docker permissions setup completed"
}

# ============================================================================
# VALIDATION
# ============================================================================

validate_permissions() {
    log_info "Validating permissions..."

    local all_good=true

    # Check directory structure
    log_info "Validating directory structure..."
    local dirs=(
        "${PROJECT_ROOT}/data"
        "${PROJECT_ROOT}/config"
        "${PROJECT_ROOT}/logs"
        "${PROJECT_ROOT}/config/prometheus-file-sd"
    )

    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_error "Directory missing: ${dir}"
            all_good=false
        fi
    done

    if [[ "$all_good" == true ]]; then
        log_success "Directory structure validated"
    fi

    # Check write permissions on project root
    log_info "Validating write permissions..."
    if [[ -w "${PROJECT_ROOT}" ]]; then
        log_success "Write access confirmed on project root"
    else
        log_error "No write access on project root: ${PROJECT_ROOT}"
        all_good=false
    fi

    # Check Docker access
    log_info "Validating Docker access..."
    if docker --version &> /dev/null; then
        if docker ps &> /dev/null; then
            log_success "Docker access confirmed"
        else
            log_warning "Docker installed but cannot run containers (permission issue?)"
        fi
    else
        log_warning "Docker not installed or not in PATH"
    fi

    # Validate log access if not skipped
    if [[ "$SKIP_LOGS" == false ]]; then
        log_info "Validating log access..."
        local can_read_logs=false

        if [[ -r /var/log/auth.log ]] || [[ -r /var/log/syslog ]] || [[ -r /var/log/messages ]]; then
            can_read_logs=true
        fi

        if [[ "$can_read_logs" == true ]]; then
            log_success "Log access validated"
        else
            log_warning "Cannot read system logs. Log collection may not work properly."
        fi
    fi

    if [[ "$all_good" == true ]]; then
        log_success "Permission validation passed"
        return 0
    else
        log_error "Permission validation failed"
        return 1
    fi
}

# ============================================================================
# SUMMARY
# ============================================================================

print_summary() {
    echo ""
    echo "================================================================"
    echo "  SETUP PERMISSIONS SUMMARY"
    echo "================================================================"
    echo ""
    echo "User Context:"
    echo "  User: ${CURRENT_USER}"
    echo "  UID: ${CURRENT_UID}"
    echo "  Is Root: ${IS_ROOT}"
    echo "  Deployment Root: ${DEPLOYMENT_ROOT}"
    echo ""
    echo "System:"
    echo "  OS: ${OS_TYPE} ${OS_VERSION}"
    echo "  Package Manager: ${PKG_MANAGER}"
    echo ""
    echo "Actions Performed:"
    echo "  Directories Created: ${#CREATED_DIRS[@]}"
    echo "  Groups Added: ${#ADDED_GROUPS[@]}"
    echo "  Permissions Modified: ${#MODIFIED_PERMISSIONS[@]}"
    echo ""
    echo "Log File:"
    echo "  ${LOG_FILE}"
    echo ""
    echo "Rollback Log:"
    echo "  ${ROLLBACK_LOG}"
    echo ""

    if [[ ${#CREATED_DIRS[@]} -gt 0 ]]; then
        echo "Created Directories:"
        for dir in "${CREATED_DIRS[@]}"; do
            echo "  - ${dir}"
        done
        echo ""
    fi

    if [[ ${#ADDED_GROUPS[@]} -gt 0 ]]; then
        echo "Groups Added:"
        for group in "${ADDED_GROUPS[@]}"; do
            echo "  - ${group}"
        done
        echo ""
        echo "NOTE: You may need to log out and log back in for group changes to take effect."
        echo ""
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "DRY RUN MODE - No changes were actually made"
        echo ""
    fi

    echo "Next Steps:"
    echo "  1. Run: ./scripts/setup-env.sh"
    echo "  2. Run: ./scripts/deploy.sh"
    echo ""
    echo "For rollback, run: ./scripts/rollback-permissions.sh"
    echo ""
}

# ============================================================================
# HELP AND USAGE
# ============================================================================

print_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Setup permissions for monitoring stack deployment. This script handles:
  - User context detection (root vs non-root)
  - Directory structure creation with correct ownership
  - Log access permissions (adm/systemd-journal groups)
  - Docker volume permissions
  - Idempotent operations (safe to run multiple times)

OPTIONS:
  -h, --help        Show this help message
  -v, --verbose     Enable verbose logging
  -d, --dry-run     Show what would be done without making changes
  -s, --skip-logs   Skip log access permission setup
  -f, --force       Continue even if log access validation fails

EXAMPLES:
  # Normal setup with all permissions
  $SCRIPT_NAME

  # Verbose mode to see all operations
  $SCRIPT_NAME --verbose

  # Dry run to see what would be changed
  $SCRIPT_NAME --dry-run

  # Skip log access setup (if logs are handled differently)
  $SCRIPT_NAME --skip-logs

  # Force continue despite log access issues
  $SCRIPT_NAME --force

IDEMPOTENCY:
  This script is idempotent and can be run multiple times safely.
  It will detect existing setup and only make necessary changes.

LOGGING:
  All actions are logged to: ${LOG_FILE}
  Rollback actions are logged to: ${ROLLBACK_LOG}

REQUIREMENTS:
  - Sudo access (for non-root users)
  - Linux OS (Ubuntu/Debian or CentOS/RHEL)
  - Docker installed (optional but recommended)

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
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -s|--skip-logs)
                SKIP_LOGS=true
                shift
                ;;
            -f|--force)
                FORCE=true
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
    # Create log directories
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$ROLLBACK_LOG")"

    # Initialize log files
    echo "========================================" > "${LOG_FILE}"
    echo "Permission Setup Log - $(date)" >> "${LOG_FILE}"
    echo "========================================" >> "${LOG_FILE}"

    echo "========================================" > "${ROLLBACK_LOG}"
    echo "Rollback Actions Log - $(date)" >> "${ROLLBACK_LOG}"
    echo "========================================" >> "${ROLLBACK_LOG}"

    echo ""
    echo "========================================"
    echo "  MONITORING STACK PERMISSION SETUP"
    echo "========================================"
    echo ""

    # Parse arguments
    parse_arguments "$@"

    # Detect system and user context
    detect_system
    detect_user_context

    # Check sudo access
    check_sudo_access

    # Execute setup
    create_directory_structure
    setup_log_access
    setup_docker_permissions

    # Validate
    if ! validate_permissions; then
        log_error "Permission validation failed. Please review the errors above."
        exit 1
    fi

    # Print summary
    print_summary

    log_success "Permission setup completed successfully!"
    echo "================================================================"
}

# Run main function
main "$@"
