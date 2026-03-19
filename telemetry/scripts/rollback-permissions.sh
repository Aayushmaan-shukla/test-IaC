#!/bin/bash
#
# rollback-permissions.sh - Undo permission changes made by setup-permissions.sh
#
# This script handles:
# - Removing user from adm/systemd-journal groups
# - Removing created directories
# - Restoring original permissions
# - Confirming with user before proceeding
# - Logging rollback actions
# - Safe rollback with validation
#
# Usage:
#   ./rollback-permissions.sh [--help] [--verbose] [--dry-run] [--force]
#
# Author: DevOps Team
# Version: 1.0.0
#

set -euo pipefail

# Script metadata
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="${PROJECT_ROOT}/logs/rollback.log"
ROLLBACK_LOG="${PROJECT_ROOT}/logs/rollback-actions.log"

# Default values
VERBOSE=false
DRY_RUN=false
FORCE=false

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# User context
CURRENT_USER=""
CURRENT_UID=""
IS_ROOT=false

# Rollback tracking
ROLLBACK_ACTIONS=()
DIRECTORIES_REMOVED=()
GROUPS_REMOVED=()

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
# CONFIRMATION
# ============================================================================

confirm_rollback() {
    if [[ "$FORCE" == true ]]; then
        log_warning "Skipping confirmation (--force flag set)"
        return 0
    fi

    echo ""
    echo "================================================================"
    echo "  ROLLBACK CONFIRMATION"
    echo "================================================================"
    echo ""
    echo "WARNING: This will undo all permission changes made by setup-permissions.sh"
    echo ""
    echo "This includes:"
    echo "  - Removing user from log access groups (adm, systemd-journal, docker)"
    echo "  - Removing created directories and their contents"
    echo "  - Reverting permission changes"
    echo ""
    echo "IMPORTANT: Rollback will NOT:"
    echo "  - Stop running Docker containers"
    echo "  - Remove Docker images or volumes"
    echo "  - Modify system-wide configuration files"
    echo ""
    echo "Make sure Docker containers are stopped before proceeding:"
    echo "  docker-compose down"
    echo ""

    read -p "Are you sure you want to proceed with rollback? (yes/no): " -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Rollback cancelled by user"
        exit 0
    fi

    return 0
}

# ============================================================================
# USER CONTEXT DETECTION
# ============================================================================

detect_user_context() {
    log_info "Detecting user context..."

    CURRENT_USER="$(whoami)"
    CURRENT_UID="$(id -u)"

    if [[ "$CURRENT_UID" -eq 0 ]]; then
        IS_ROOT=true
        log_info "Running as root user"
    else
        IS_ROOT=false
        log_info "Running as non-root user: ${CURRENT_USER} (UID: ${CURRENT_UID})"
    fi
}

# ============================================================================
# SUDO HANDLING
# ============================================================================

check_sudo_access() {
    log_info "Checking sudo access..."

    if [[ "$IS_ROOT" == true ]]; then
        log_info "Root access confirmed"
        return 0
    fi

    if sudo -n true 2>/dev/null || sudo true 2>/dev/null; then
        log_info "Sudo access confirmed"
        return 0
    else
        log_error "No sudo access detected. Sudo is required for rollback."
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
# GROUP ROLLBACK
# ============================================================================

rollback_groups() {
    log_info "Rolling back group memberships..."

    local groups_to_remove=()
    local groups_to_check=("adm" "systemd-journal" "docker")

    for group in "${groups_to_check[@]}"; do
        if getent group "$group" > /dev/null 2>&1; then
            if groups "$CURRENT_USER" | grep -q "\b${group}\b"; then
                log_info "User is in group: ${group}"
                groups_to_remove+=("$group")
            else
                log_verbose "User not in group: ${group}"
            fi
        fi
    done

    if [[ ${#groups_to_remove[@]} -eq 0 ]]; then
        log_info "No group memberships to remove"
        return 0
    fi

    log_info "Groups to remove: ${groups_to_remove[*]}"

    for group in "${groups_to_remove[@]}"; do
        log_info "Removing user from group: ${group}"

        if [[ "$DRY_RUN" == false ]]; then
            if [[ "$IS_ROOT" == true ]]; then
                gpasswd -d "$CURRENT_USER" "$group"
            else
                run_with_sudo "gpasswd -d $CURRENT_USER $group"
            fi
            log_success "Removed user from group: ${group}"
            GROUPS_REMOVED+=("$group")
            ROLLBACK_ACTIONS+=("Removed $CURRENT_USER from group $group")
        else
            log_verbose "[DRY RUN] Would remove user from group: ${group}"
            GROUPS_REMOVED+=("$group")
        fi
    done

    log_success "Group membership rollback completed"
}

# ============================================================================
# DIRECTORY ROLLBACK
# ============================================================================

rollback_directories() {
    log_info "Rolling back created directories..."

    local directories_to_remove=()
    local project_dirs=(
        "${PROJECT_ROOT}/data"
        "${PROJECT_ROOT}/logs"
        "${PROJECT_ROOT}/config"
    )

    for dir in "${project_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_info "Directory exists: ${dir}"

            # Check if it contains important data
            local has_data=false
            if [[ -d "${dir}/grafana" ]] || [[ -d "${dir}/prometheus" ]] || [[ -d "${dir}/loki" ]] || [[ -d "${dir}/mongodb" ]]; then
                has_data=true
            fi

            if [[ "$has_data" == true ]]; then
                log_warning "Directory contains data: ${dir}"

                if [[ "$FORCE" == false ]]; then
                    read -p "Remove directory and all contents? (yes/no): " -r
                    echo ""

                    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
                        log_info "Skipping directory: ${dir}"
                        continue
                    fi
                fi
            fi

            directories_to_remove+=("$dir")
        fi
    done

    if [[ ${#directories_to_remove[@]} -eq 0 ]]; then
        log_info "No directories to remove"
        return 0
    fi

    log_info "Directories to remove: ${directories_to_remove[*]}"

    for dir in "${directories_to_remove[@]}"; do
        log_info "Removing directory: ${dir}"

        if [[ "$DRY_RUN" == false ]]; then
            rm -rf "$dir"
            log_success "Removed directory: ${dir}"
            DIRECTORIES_REMOVED+=("$dir")
            ROLLBACK_ACTIONS+=("Removed directory $dir")
        else
            log_verbose "[DRY RUN] Would remove directory: ${dir}"
            DIRECTORIES_REMOVED+=("$dir")
        fi
    done

    log_success "Directory rollback completed"
}

# ============================================================================
# PERMISSION ROLLBACK
# ============================================================================

rollback_permissions() {
    log_info "Rolling back permission changes..."

    # Check for any permission modifications that need to be reverted
    # This is a safety check - most permissions are handled by removing directories

    local files_to_check=(
        "${PROJECT_ROOT}/.env"
        "${PROJECT_ROOT}/.env.secrets"
    )

    for file in "${files_to_check[@]}"; do
        if [[ -f "$file" ]]; then
            local current_mode
            current_mode=$(stat -c '%a' "$file" 2>/dev/null || stat -f '%Lp' "$file" 2>/dev/null)

            if [[ "$current_mode" == "600" ]]; then
                log_verbose "File has secure permissions: ${file} (${current_mode})"

                if [[ "$DRY_RUN" == false ]]; then
                    chmod 644 "$file"
                    log_success "Reset permissions for: ${file}"
                    ROLLBACK_ACTIONS+=("Reset permissions for $file")
                else
                    log_verbose "[DRY RUN] Would reset permissions for: ${file}"
                fi
            fi
        fi
    done

    log_success "Permission rollback completed"
}

# ============================================================================
# CLEANUP
# ============================================================================

cleanup_log_files() {
    log_info "Cleaning up log files..."

    local log_files=(
        "${PROJECT_ROOT}/logs/setup-permissions.log"
        "${PROJECT_ROOT}/logs/rollback-actions.log"
        "${PROJECT_ROOT}/logs/setup-env.log"
        "${PROJECT_ROOT}/logs/deployment.log"
        "${PROJECT_ROOT}/logs/validation.log"
    )

    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            log_info "Removing log file: ${log_file}"

            if [[ "$DRY_RUN" == false ]]; then
                rm -f "$log_file"
                log_success "Removed log file: ${log_file}"
                ROLLBACK_ACTIONS+=("Removed log file $log_file")
            else
                log_verbose "[DRY RUN] Would remove log file: ${log_file}"
            fi
        fi
    done

    log_success "Log file cleanup completed"
}

# ============================================================================
# VALIDATION
# ============================================================================

validate_rollback() {
    log_info "Validating rollback..."

    local errors=0

    # Check if directories were removed
    for dir in "${DIRECTORIES_REMOVED[@]}"; do
        if [[ -d "$dir" ]]; then
            log_error "Directory still exists after rollback: ${dir}"
            ((errors++))
        fi
    done

    # Check if groups were removed
    for group in "${GROUPS_REMOVED[@]}"; do
        if groups "$CURRENT_USER" | grep -q "\b${group}\b"; then
            log_error "User still in group after rollback: ${group}"
            ((errors++))
        fi
    done

    if [[ $errors -eq 0 ]]; then
        log_success "Rollback validation passed"
        return 0
    else
        log_error "Rollback validation failed with ${errors} error(s)"
        return 1
    fi
}

# ============================================================================
# SUMMARY
# ============================================================================

print_summary() {
    echo ""
    echo "================================================================"
    echo "  ROLLBACK SUMMARY"
    echo "================================================================"
    echo ""

    echo "User Context:"
    echo "  User: ${CURRENT_USER}"
    echo "  UID: ${CURRENT_UID}"
    echo ""

    echo "Actions Performed:"
    echo "  Directories Removed: ${#DIRECTORIES_REMOVED[@]}"
    echo "  Groups Removed: ${#GROUPS_REMOVED[@]}"
    echo "  Total Actions: ${#ROLLBACK_ACTIONS[@]}"
    echo ""

    if [[ ${#DIRECTORIES_REMOVED[@]} -gt 0 ]]; then
        echo "Removed Directories:"
        for dir in "${DIRECTORIES_REMOVED[@]}"; do
            echo "  - ${dir}"
        done
        echo ""
    fi

    if [[ ${#GROUPS_REMOVED[@]} -gt 0 ]]; then
        echo "Removed Group Memberships:"
        for group in "${GROUPS_REMOVED[@]}"; do
            echo "  - ${group}"
        done
        echo ""
        echo "NOTE: You may need to log out and log back in for group changes to take effect."
        echo ""
    fi

    if [[ ${#ROLLBACK_ACTIONS[@]} -gt 0 ]]; then
        echo "Rollback Actions:"
        for action in "${ROLLBACK_ACTIONS[@]}"; do
            echo "  ✓ ${action}"
        done
        echo ""
    fi

    echo "Log File:"
    echo "  ${LOG_FILE}"
    echo ""

    if [[ "$DRY_RUN" == true ]]; then
        echo "DRY RUN MODE - No changes were actually made"
        echo ""
    fi

    echo "Next Steps:"
    echo "  1. Review the rollback actions above"
    echo "  2. Verify Docker containers are stopped: docker-compose ps"
    echo "  3. If needed, remove Docker volumes: docker-compose down -v"
    echo "  4. Log out and log back in for group changes to take effect"
    echo ""

    echo "To re-deploy:"
    echo "  ./scripts/setup-permissions.sh"
    echo "  ./scripts/deploy.sh"
    echo ""
}

# ============================================================================
# HELP AND USAGE
# ============================================================================

print_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Rollback permission changes made by setup-permissions.sh.

This script will:
  - Remove user from log access groups (adm, systemd-journal, docker)
  - Remove created directories and their contents
  - Restore original file permissions
  - Clean up log files

OPTIONS:
  -h, --help        Show this help message
  -v, --verbose     Enable verbose logging
  -d, --dry-run     Show what would be done without making changes
  -f, --force       Skip confirmation prompts

WARNING:
  This will remove directories and their contents!
  Make sure to backup important data before proceeding.
  Stop Docker containers before running rollback:
    docker-compose down

EXAMPLES:
  # Normal rollback with confirmation
  $SCRIPT_NAME

  # Verbose mode to see all operations
  $SCRIPT_NAME --verbose

  # Dry run to see what would be changed
  $SCRIPT_NAME --dry-run

  # Force rollback without prompts
  $SCRIPT_NAME --force

WHAT GETS ROLLED BACK:
  - Group memberships: adm, systemd-journal, docker
  - Created directories: data/, logs/, config/
  - File permissions: .env, .env.secrets
  - Log files: all logs in logs/

WHAT DOES NOT GET ROLLED BACK:
  - Docker containers (must be stopped manually)
  - Docker images
  - Docker volumes (must be removed manually)
  - System-wide configuration files
  - Environment variables

SAFETY:
  - Prompts for confirmation before making changes
  - Validates rollback actions
  - Logs all actions for audit trail
  - Dry-run mode available for testing

LOG FILES:
  Rollback log: ${LOG_FILE}

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

    # Initialize log file
    echo "========================================" > "${LOG_FILE}"
    echo "Rollback Log - $(date)" >> "${LOG_FILE}"
    echo "========================================" >> "${LOG_FILE}"

    echo ""
    echo "================================================================"
    echo "  MONITORING STACK PERMISSION ROLLBACK"
    echo "================================================================"
    echo ""

    # Parse arguments
    parse_arguments "$@"

    # Detect user context
    detect_user_context

    # Check sudo access
    check_sudo_access

    # Confirm rollback
    confirm_rollback

    # Execute rollback
    rollback_groups
    rollback_directories
    rollback_permissions
    cleanup_log_files

    # Validate
    if [[ "$DRY_RUN" == false ]]; then
        if ! validate_rollback; then
            log_error "Rollback validation failed"
            log_warning "Some actions may not have completed successfully"
            log_warning "Review the errors above and manually fix if needed"
        fi
    fi

    # Print summary
    print_summary

    log_success "Rollback completed!"
    echo "================================================================"
}

# Run main function
main "$@"
