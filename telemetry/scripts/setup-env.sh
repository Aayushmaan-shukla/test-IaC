#!/bin/bash
#
# setup-env.sh - Environment configuration for monitoring stack
#
# This script handles:
# - Creating .env file from .env.example
# - Prompting for secrets (passwords)
# - Setting default values for all variables
# - Validating environment variables
# - Generating random passwords if not provided
# - Creating .env.secrets file with sensitive data
# - Documenting each variable in the .env file
#
# Usage:
#   ./setup-env.sh [--help] [--non-interactive] [--generate-passwords]
#
# Author: DevOps Team
# Version: 1.0.0
#

set -euo pipefail

# Script metadata
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env"
ENV_EXAMPLE="${PROJECT_ROOT}/.env.example"
ENV_SECRETS="${PROJECT_ROOT}/.env.secrets"
LOG_FILE="${PROJECT_ROOT}/logs/setup-env.log"

# Default values
NON_INTERACTIVE=false
GENERATE_PASSWORDS=false
FORCE=false

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

generate_password() {
    local length=${1:-24}
    # Generate secure random password
    openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
}

prompt_user() {
    local prompt="$1"
    local default_value="$2"
    local is_secret="${3:-false}"

    if [[ "$NON_INTERACTIVE" == true ]]; then
        if [[ -n "$default_value" ]]; then
            echo "$default_value"
        else
            echo ""
        fi
        return
    fi

    if [[ "$is_secret" == true ]]; then
        local value
        read -s -p "${prompt}" value
        echo "" # New line after hidden input
        echo "$value"
    else
        local value
        read -p "${prompt} [${default_value}]: " value
        echo "${value:-$default_value}"
    fi
}

validate_password() {
    local password="$1"
    local min_length=12

    if [[ ${#password} -lt "$min_length" ]]; then
        log_error "Password must be at least ${min_length} characters long"
        return 1
    fi

    return 0
}

# ============================================================================
# ENVIRONMENT FILE CREATION
# ============================================================================

create_env_file() {
    log_info "Creating environment file..."

    if [[ -f "$ENV_FILE" ]]; then
        log_warning ".env file already exists"

        if [[ "$FORCE" == false ]]; then
            read -p "Overwrite existing .env file? (y/N): " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Keeping existing .env file"
                return 1
            fi
        fi

        log_info "Backing up existing .env file to .env.backup"
        cp "$ENV_FILE" "${ENV_FILE}.backup"
    fi

    # Create .env file from template
    if [[ -f "$ENV_EXAMPLE" ]]; then
        log_info "Using .env.example as template"
        cp "$ENV_EXAMPLE" "$ENV_FILE"
        log_success "Created .env file from .env.example"
    else
        log_warning ".env.example not found, creating minimal .env file"
        touch "$ENV_FILE"
    fi

    return 0
}

# ============================================================================
# ENVIRONMENT VARIABLES SETUP
# ============================================================================

setup_grafana_variables() {
    log_info "Setting up Grafana environment variables..."

    local grafana_password
    local generate_password_choice="no"

    if [[ "$GENERATE_PASSWORDS" == true ]]; then
        generate_password_choice="yes"
    elif [[ "$NON_INTERACTIVE" == false ]]; then
        generate_password_choice=$(prompt_user "Generate random Grafana password?" "no" "false")
    fi

    if [[ "$generate_password_choice" =~ ^[Yy] ]]; then
        grafana_password=$(generate_password 24)
        log_success "Generated secure Grafana password"
    else
        grafana_password=$(prompt_user "Enter Grafana admin password" "" "true")

        while ! validate_password "$grafana_password"; do
            if [[ "$NON_INTERACTIVE" == true ]]; then
                log_error "Invalid password. Generating random password instead."
                grafana_password=$(generate_password 24)
                break
            fi
            grafana_password=$(prompt_user "Enter Grafana admin password" "" "true")
        done
    fi

    # Update or add GRAFANA_ADMIN_PASSWORD
    if grep -q "^GRAFANA_ADMIN_PASSWORD=" "$ENV_FILE"; then
        sed -i "s/^GRAFANA_ADMIN_PASSWORD=.*/GRAFANA_ADMIN_PASSWORD=${grafana_password}/" "$ENV_FILE"
    else
        echo "GRAFANA_ADMIN_PASSWORD=${grafana_password}" >> "$ENV_FILE"
    fi

    # Add to secrets file
    echo "GRAFANA_ADMIN_PASSWORD=${grafana_password}" >> "$ENV_SECRETS"

    log_success "Grafana variables configured"
}

setup_mongodb_variables() {
    log_info "Setting up MongoDB environment variables..."

    local mongo_password
    local generate_password_choice="no"

    if [[ "$GENERATE_PASSWORDS" == true ]]; then
        generate_password_choice="yes"
    elif [[ "$NON_INTERACTIVE" == false ]]; then
        generate_password_choice=$(prompt_user "Generate random MongoDB password?" "no" "false")
    fi

    if [[ "$generate_password_choice" =~ ^[Yy] ]]; then
        mongo_password=$(generate_password 32)
        log_success "Generated secure MongoDB password"
    else
        mongo_password=$(prompt_user "Enter MongoDB root password" "" "true")

        while ! validate_password "$mongo_password"; do
            if [[ "$NON_INTERACTIVE" == true ]]; then
                log_error "Invalid password. Generating random password instead."
                mongo_password=$(generate_password 32)
                break
            fi
            mongo_password=$(prompt_user "Enter MongoDB root password" "" "true")
        done
    fi

    # Update or add MONGO_INITDB_ROOT_PASSWORD
    if grep -q "^MONGO_INITDB_ROOT_PASSWORD=" "$ENV_FILE"; then
        sed -i "s/^MONGO_INITDB_ROOT_PASSWORD=.*/MONGO_INITDB_ROOT_PASSWORD=${mongo_password}/" "$ENV_FILE"
    else
        echo "MONGO_INITDB_ROOT_PASSWORD=${mongo_password}" >> "$ENV_FILE"
    fi

    # Add to secrets file
    echo "MONGO_INITDB_ROOT_PASSWORD=${mongo_password}" >> "$ENV_SECRETS"

    log_success "MongoDB variables configured"
}

setup_network_variables() {
    log_info "Setting up network variables..."

    # Grafana port
    local grafana_port=$(prompt_user "Grafana external port" "4101" "false")
    update_env_variable "GRAFANA_PORT" "$grafana_port"

    # Prometheus port
    local prometheus_port=$(prompt_user "Prometheus external port" "4102" "false")
    update_env_variable "PROMETHEUS_PORT" "$prometheus_port"

    # Loki port
    local loki_port=$(prompt_user "Loki external port" "4103" "false")
    update_env_variable "LOKI_PORT" "$loki_port"

    # MongoDB port
    local mongodb_port=$(prompt_user "MongoDB external port" "27017" "false")
    update_env_variable "MONGODB_PORT" "$mongodb_port"

    log_success "Network variables configured"
}

setup_storage_variables() {
    log_info "Setting up storage variables..."

    # Prometheus retention
    local prometheus_retention=$(prompt_user "Prometheus data retention (e.g., 15d)" "15d" "false")
    update_env_variable "PROMETHEUS_RETENTION" "$prometheus_retention"

    # Loki retention
    local loki_retention=$(prompt_user "Loki data retention (e.g., 7d)" "7d" "false")
    update_env_variable "LOKI_RETENTION" "$loki_retention"

    log_success "Storage variables configured"
}

setup_security_variables() {
    log_info "Setting up security variables..."

    # Disable user sign-up
    update_env_variable "GF_USERS_ALLOW_SIGN_UP" "false"

    # Grafana server root URL
    local grafana_url=$(prompt_user "Grafana server root URL" "http://localhost:4101" "false")
    update_env_variable "GF_SERVER_ROOT_URL" "$grafana_url"

    log_success "Security variables configured"
}

update_env_variable() {
    local var_name="$1"
    local var_value="$2"

    if grep -q "^${var_name}=" "$ENV_FILE"; then
        sed -i "s/^${var_name}=.*/${var_name}=${var_value}/" "$ENV_FILE"
    else
        echo "${var_name}=${var_value}" >> "$ENV_FILE"
    fi
}

# ============================================================================
# DEFAULT VARIABLES SETUP
# ============================================================================

setup_default_variables() {
    log_info "Setting up default variables..."

    # Grafana defaults
    update_env_variable "GF_SECURITY_ADMIN_USER" "admin"
    update_env_variable "GF_INSTALL_PLUGINS" "grafana-piechart-panel"

    # MongoDB defaults
    update_env_variable "MONGO_INITDB_ROOT_USERNAME" "admin"
    update_env_variable "MONGO_INITDB_ROOT_DATABASE" "admin"

    # Loki defaults
    update_env_variable "LOKI_COMPRESSION_TYPE" "snappy"
    update_env_variable "LOKI_INGESTION_RATE_MB" "16"

    # Promtail defaults
    update_env_variable "PROMTAIL_POSITIONS_FILENAME" "/tmp/positions.yaml"

    log_success "Default variables configured"
}

# ============================================================================
# VALIDATION
# ============================================================================

validate_env_file() {
    log_info "Validating environment file..."

    local errors=0

    # Check if file exists
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error "Environment file does not exist: ${ENV_FILE}"
        return 1
    fi

    # Check for required variables
    local required_vars=(
        "GRAFANA_ADMIN_PASSWORD"
        "MONGO_INITDB_ROOT_PASSWORD"
        "GF_SECURITY_ADMIN_USER"
        "MONGO_INITDB_ROOT_USERNAME"
    )

    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" "$ENV_FILE" 2>/dev/null; then
            log_error "Required variable missing: ${var}"
            ((errors++))
        else
            local value
            value=$(grep "^${var}=" "$ENV_FILE" | cut -d= -f2-)
            if [[ -z "$value" ]]; then
                log_error "Required variable is empty: ${var}"
                ((errors++))
            fi
        fi
    done

    if [[ $errors -eq 0 ]]; then
        log_success "Environment file validation passed"
        return 0
    else
        log_error "Environment file validation failed with ${errors} error(s)"
        return 1
    fi
}

# ============================================================================
# DOCUMENTATION
# ============================================================================

document_env_file() {
    log_info "Documenting environment variables..."

    # Create documentation header in .env file
    local doc_header=$(cat << 'EOF'
# ==============================================================================
# Monitoring Stack Environment Configuration
# ==============================================================================
# This file contains all configuration variables for the monitoring stack.
# DO NOT COMMIT THIS FILE TO VERSION CONTROL!
# ==============================================================================

EOF
)

    # Add documentation to the beginning of the file
    local temp_file
    temp_file=$(mktemp)

    # Copy header
    echo "$doc_header" > "$temp_file"

    # Copy existing content
    cat "$ENV_FILE" >> "$temp_file"

    # Replace original file
    mv "$temp_file" "$ENV_FILE"

    log_success "Environment file documented"
}

# ============================================================================
# SECURE SECRETS FILE
# ============================================================================

setup_secrets_file() {
    log_info "Setting up secrets file..."

    # Remove existing secrets file
    if [[ -f "$ENV_SECRETS" ]]; then
        log_warning "Removing existing secrets file"
        rm -f "$ENV_SECRETS"
    fi

    # Create new secrets file
    touch "$ENV_SECRETS"
    chmod 600 "$ENV_SECRETS"

    log_success "Secrets file created"
}

# ============================================================================
# SUMMARY
# ============================================================================

print_summary() {
    echo ""
    echo "================================================================"
    echo "  ENVIRONMENT SETUP SUMMARY"
    echo "================================================================"
    echo ""
    echo "Files Created:"
    echo "  Environment File: ${ENV_FILE}"
    echo "  Secrets File: ${ENV_SECRETS}"
    echo ""

    echo "IMPORTANT SECURITY NOTES:"
    echo "  - DO NOT commit .env or .env.secrets to version control"
    echo "  - Ensure .env and .env.secrets are in .gitignore"
    echo "  - Keep passwords secure and rotate them regularly"
    echo "  - Use strong, unique passwords for each service"
    echo ""

    echo "Generated Passwords:"
    echo "  Grafana Admin Password: [stored in ${ENV_SECRETS}]"
    echo "  MongoDB Root Password: [stored in ${ENV_SECRETS}]"
    echo ""

    echo "Next Steps:"
    echo "  1. Review the generated .env file"
    echo "  2. Run: ./scripts/validate-environment.sh"
    echo "  3. Run: ./scripts/deploy.sh"
    echo ""

    echo "Access Credentials (saved to ${ENV_SECRETS}):"
    echo "  Grafana:"
    echo "    URL: http://localhost:$(grep '^GRAFANA_PORT=' "$ENV_FILE" | cut -d= -f2)"
    echo "    Username: $(grep '^GF_SECURITY_ADMIN_USER=' "$ENV_FILE" | cut -d= -f2)"
    echo "    Password: [see ${ENV_SECRETS}]"
    echo ""
    echo "  MongoDB:"
    echo "    Port: $(grep '^MONGODB_PORT=' "$ENV_FILE" | cut -d= -f2)"
    echo "    Username: $(grep '^MONGO_INITDB_ROOT_USERNAME=' "$ENV_FILE" | cut -d= -f2)"
    echo "    Password: [see ${ENV_SECRETS}]"
    echo ""
}

# ============================================================================
# HELP AND USAGE
# ============================================================================

print_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Setup environment configuration for monitoring stack deployment.

This script will:
  - Create .env file from .env.example (if it exists)
  - Prompt for and set up passwords
  - Configure network ports
  - Set default values for all variables
  - Validate all environment variables
  - Create .env.secrets file with sensitive data

OPTIONS:
  -h, --help                Show this help message
  -n, --non-interactive     Run without user prompts (use defaults)
  -g, --generate-passwords  Generate random passwords for all secrets
  -f, --force               Overwrite existing .env file without prompting

EXAMPLES:
  # Interactive mode (recommended for first setup)
  $SCRIPT_NAME

  # Non-interactive mode with auto-generated passwords
  $SCRIPT_NAME --non-interactive --generate-passwords

  # Force overwrite existing configuration
  $SCRIPT_NAME --force

  # Generate all passwords non-interactively
  $SCRIPT_NAME --non-interactive --generate-passwords --force

ENVIRONMENT FILES:
  - .env.example: Template with all variables and documentation
  - .env: Generated environment configuration (DO NOT COMMIT)
  - .env.secrets: Sensitive data only (DO NOT COMMIT)

SECURITY:
  - Generated passwords are cryptographically secure
  - .env.secrets file is set to mode 600 (read/write by owner only)
  - Add both .env and .env.secrets to .gitignore

PASSWORD REQUIREMENTS:
  - Minimum 12 characters
  - Recommended: 24+ characters for production
  - Use a mix of letters, numbers, and special characters

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
            -n|--non-interactive)
                NON_INTERACTIVE=true
                shift
                ;;
            -g|--generate-passwords)
                GENERATE_PASSWORDS=true
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
    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")"

    # Initialize log file
    echo "========================================" > "${LOG_FILE}"
    echo "Environment Setup Log - $(date)" >> "${LOG_FILE}"
    echo "========================================" >> "${LOG_FILE}"

    echo ""
    echo "================================================================"
    echo "  MONITORING STACK ENVIRONMENT SETUP"
    echo "================================================================"
    echo ""

    # Parse arguments
    parse_arguments "$@"

    # Setup secrets file
    setup_secrets_file

    # Create environment file
    if ! create_env_file; then
        log_info "Environment setup cancelled"
        exit 0
    fi

    # Setup variables
    setup_default_variables
    setup_grafana_variables
    setup_mongodb_variables

    if [[ "$NON_INTERACTIVE" == false ]]; then
        setup_network_variables
        setup_storage_variables
        setup_security_variables
    fi

    # Document and validate
    document_env_file

    if ! validate_env_file; then
        log_error "Environment validation failed"
        exit 1
    fi

    # Print summary
    print_summary

    log_success "Environment setup completed successfully!"
    echo "================================================================"
}

# Run main function
main "$@"
