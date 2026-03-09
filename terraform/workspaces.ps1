# Terraform Workspace Management Script
# Run with: .\workspaces.ps1

param(
    [Parameter(Mandatory=$false)]
    [string]$Action,

    [Parameter(Mandatory=$false)]
    [string]$Name,

    [Parameter(Mandatory=$false)]
    [string]$VarFile,

    [Parameter(Mandatory=$false)]
    [string]$InstanceType,

    [Parameter(Mandatory=$false)]
    [string]$ServerName
)

function Show-Help {
    Write-Host "Terraform Workspace Management Script`n" -ForegroundColor Cyan
    Write-Host "Usage: .\workspaces.ps1 -Action <action> [options]`n" -ForegroundColor White
    Write-Host "Actions:" -ForegroundColor Yellow
    Write-Host "  list              - List all workspaces"
    Write-Host "  show              - Show current workspace"
    Write-Host "  new               - Create new workspace (requires -Name)"
    Write-Host "  select            - Switch to workspace (requires -Name)"
    Write-Host "  delete            - Delete workspace (requires -Name)"
    Write-Host "  init-all          - Initialize all workspaces (creates them if needed)"
    Write-Host "  deploy            - Deploy to current workspace"
    Write-Host "  destroy           - Destroy resources in current workspace"
    Write-Host "  output            - Show outputs for current workspace"
    Write-Host "`nOptions:" -ForegroundColor Yellow
    Write-Host "  -Name             - Workspace name"
    Write-Host "  -VarFile          - Variable file (e.g., dev.tfvars)"
    Write-Host "  -InstanceType     - Override instance type"
    Write-Host "  -ServerName       - Override server name"
    Write-Host "`nExamples:" -ForegroundColor Yellow
    Write-Host "  .\workspaces.ps1 -Action list"
    Write-Host "  .\workspaces.ps1 -Action new -Name staging"
    Write-Host "  .\workspaces.ps1 -Action select -Name prod"
    Write-Host "  .\workspaces.ps1 -Action deploy -VarFile prod.tfvars"
    Write-Host "  .\workspaces.ps1 -Action init-all"
}

function Get-TerraformPath {
    $terraformPath = Get-Command terraform -ErrorAction SilentlyContinue
    if (-not $terraformPath) {
        Write-Host "Error: Terraform not found. Please install Terraform first." -ForegroundColor Red
        exit 1
    }
    return $terraformPath
}

function Invoke-TerraformCommand {
    param([string]$Command, [string]$Args)

    Write-Host "Running: terraform $Command $Args" -ForegroundColor Gray
    & terraform $Command $Args
}

switch ($Action) {
    "list" {
        Invoke-TerraformCommand "workspace" "list"
    }

    "show" {
        Invoke-TerraformCommand "workspace" "show"
    }

    "new" {
        if (-not $Name) {
            Write-Host "Error: -Name is required for 'new' action" -ForegroundColor Red
            exit 1
        }
        Invoke-TerraformCommand "workspace" "new" @($Name)
    }

    "select" {
        if (-not $Name) {
            Write-Host "Error: -Name is required for 'select' action" -ForegroundColor Red
            exit 1
        }
        Invoke-TerraformCommand "workspace" "select" @($Name)
        Write-Host "`nSelected workspace: $Name" -ForegroundColor Green
    }

    "delete" {
        if (-not $Name) {
            Write-Host "Error: -Name is required for 'delete' action" -ForegroundColor Red
            exit 1
        }
        Invoke-TerraformCommand "workspace" "delete" @($Name)
    }

    "init-all" {
        $workspaces = @("dev", "test", "prod")
        Write-Host "Initializing workspaces: $($workspaces -join ', ')" -ForegroundColor Cyan

        foreach ($ws in $workspaces) {
            Write-Host "`nInitializing workspace: $ws" -ForegroundColor Yellow
            Invoke-TerraformCommand "workspace" "new" @($ws) 2>&1 | Out-Null
            Invoke-TerraformCommand "workspace" "select" @($ws)
            Invoke-TerraformCommand "init" @()
            Invoke-TerraformCommand "apply" @("-auto-approve")
        }

        Write-Host "`nAll workspaces initialized!" -ForegroundColor Green
    }

    "deploy" {
        $currentWorkspace = terraform workspace show
        Write-Host "`nDeploying to workspace: $currentWorkspace" -ForegroundColor Cyan

        Invoke-TerraformCommand "init" @()

        $applyArgs = @("-auto-approve")
        if ($VarFile) {
            $applyArgs += "-var-file=$VarFile"
        }
        if ($InstanceType) {
            $applyArgs += "instance_type=$InstanceType"
        }
        if ($ServerName) {
            $applyArgs += "server_name=$ServerName"
        }

        Invoke-TerraformCommand "apply" $applyArgs
    }

    "destroy" {
        $currentWorkspace = terraform workspace show
        Write-Host "`nDestroying resources in workspace: $currentWorkspace" -ForegroundColor Yellow
        Write-Host "This will destroy ALL resources in this workspace!" -ForegroundColor Red
        $confirm = Read-Host "Are you sure? (yes/no)"

        if ($confirm -eq "yes") {
            Invoke-TerraformCommand "destroy" @("-auto-approve")
        } else {
            Write-Host "Destroy cancelled." -ForegroundColor Yellow
        }
    }

    "output" {
        Invoke-TerraformCommand "output" @()
    }

    default {
        Show-Help
    }
}
