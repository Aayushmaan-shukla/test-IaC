#!/bin/bash
# Terraform Workspace Management Script
# Run with: ./workspaces.sh

set -e

ACTION=""
NAME=""
VAR_FILE=""
INSTANCE_TYPE=""
SERVER_NAME=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --action)
            ACTION="$2"
            shift 2
            ;;
        --name)
            NAME="$2"
            shift 2
            ;;
        --var-file)
            VAR_FILE="$2"
            shift 2
            ;;
        --instance-type)
            INSTANCE_TYPE="$2"
            shift 2
            ;;
        --server-name)
            SERVER_NAME="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

function show_help() {
    cat << EOF
Terraform Workspace Management Script

Usage: ./workspaces.sh --action <action> [options]

Actions:
  list              - List all workspaces
  show              - Show current workspace
  new               - Create new workspace (requires --name)
  select            - Switch to workspace (requires --name)
  delete            - Delete workspace (requires --name)
  init-all          - Initialize all workspaces (creates them if needed)
  deploy            - Deploy to current workspace
  destroy           - Destroy resources in current workspace
  output            - Show outputs for current workspace

Options:
  --name            - Workspace name
  --var-file        - Variable file (e.g., dev.tfvars)
  --instance-type   - Override instance type
  --server-name     - Override server name

Examples:
  ./workspaces.sh --action list
  ./workspaces.sh --action new --name staging
  ./workspaces.sh --action select --name prod
  ./workspaces.sh --action deploy --var-file prod.tfvars
  ./workspaces.sh --action init-all
EOF
}

function check_terraform() {
    if ! command -v terraform &> /dev/null; then
        echo "Error: Terraform not found. Please install Terraform first."
        exit 1
    fi
}

function run_terraform() {
    echo "Running: terraform $@"
    terraform "$@"
}

case "$ACTION" in
    list)
        run_terraform workspace list
        ;;

    show)
        run_terraform workspace show
        ;;

    new)
        if [[ -z "$NAME" ]]; then
            echo "Error: --name is required for 'new' action"
            exit 1
        fi
        run_terraform workspace new "$NAME"
        ;;

    select)
        if [[ -z "$NAME" ]]; then
            echo "Error: --name is required for 'select' action"
            exit 1
        fi
        run_terraform workspace select "$NAME"
        echo ""
        echo "Selected workspace: $NAME"
        ;;

    delete)
        if [[ -z "$NAME" ]]; then
            echo "Error: --name is required for 'delete' action"
            exit 1
        fi
        run_terraform workspace delete "$NAME"
        ;;

    init-all)
        workspaces=("dev" "test" "prod")
        echo "Initializing workspaces: ${workspaces[*]}"

        for ws in "${workspaces[@]}"; do
            echo ""
            echo "Initializing workspace: $ws"
            run_terraform workspace new "$ws" 2>/dev/null || true
            run_terraform workspace select "$ws"
            run_terraform init
            run_terraform apply -auto-approve
        done

        echo ""
        echo "All workspaces initialized!"
        ;;

    deploy)
        check_terraform
        current_workspace=$(terraform workspace show)
        echo ""
        echo "Deploying to workspace: $current_workspace"

        run_terraform init

        apply_args="-auto-approve"
        if [[ -n "$VAR_FILE" ]]; then
            apply_args="$apply_args -var-file=$VAR_FILE"
        fi
        if [[ -n "$INSTANCE_TYPE" ]]; then
            apply_args="$apply_args -var='instance_type=$INSTANCE_TYPE'"
        fi
        if [[ -n "$SERVER_NAME" ]]; then
            apply_args="$apply_args -var='server_name=$SERVER_NAME'"
        fi

        run_terraform apply $apply_args
        ;;

    destroy)
        check_terraform
        current_workspace=$(terraform workspace show)
        echo ""
        echo "Destroying resources in workspace: $current_workspace"
        echo "This will destroy ALL resources in this workspace!"
        read -p "Are you sure? (yes/no): " confirm

        if [[ "$confirm" == "yes" ]]; then
            run_terraform destroy -auto-approve
        else
            echo "Destroy cancelled."
        fi
        ;;

    output)
        check_terraform
        run_terraform output
        ;;

    *)
        show_help
        exit 1
        ;;
esac
