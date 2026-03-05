# Docker Compose Deployment Script for PowerShell
# Handles both 'docker compose' and 'docker-compose' commands
# Supports AWS Secrets Manager for environment configuration

param(
    [string]$EnvFile,
    [string]$File = "docker-compose.yml",
    [int]$AppPort = 8000,
    [string]$Mode = "development",
    [int]$RedisPort = 6379,
    [string]$RedisPassword = "redis123",
    [int]$PostgresPort = 5432,
    [string]$PostgresUser = "postgres",
    [string]$PostgresPassword = "postgres123",
    [string]$PostgresDb = "sampledb",
    [string]$AwsRegion = "us-east-1",
    [string]$AwsSecretArn = "arn:aws:secretsmanager:us-east-1:850995546121:secret:app/dev/backend-config-D7tdKZ",
    [switch]$NoAws,
    [Parameter(ValueFromRemainingArguments=$true)]
    [ValidateSet("up", "down", "restart", "logs", "ps", "pull")]
    [string[]]$RemainingArgs,
    [switch]$Help
)

# Extract command from remaining args
$Command = "up"
if ($RemainingArgs -and $RemainingArgs[0] -in @("up", "down", "restart", "logs", "ps", "pull")) {
    $Command = $RemainingArgs[0]
}

# Helper function for colored output
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

# Usage function
function Show-Usage {
    Write-Host "Usage: .\deploy.ps1 [OPTIONS] [COMMAND]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -EnvFile FILE           Load environment variables from file"
    Write-Host "  -File FILE              Specify docker-compose file (default: docker-compose.yml)"
    Write-Host "  -AppPort PORT           Application port (default: 8000)"
    Write-Host "  -Mode MODE              Application mode (default: development)"
    Write-Host "  -RedisPort PORT         Redis port (default: 6379)"
    Write-Host "  -RedisPassword PASS      Redis password (default: redis123)"
    Write-Host "  -PostgresPort PORT      Postgres port (default: 5432)"
    Write-Host "  -PostgresUser USER      Postgres user (default: postgres)"
    Write-Host "  -PostgresPassword PASS  Postgres password (default: postgres123)"
    Write-Host "  -PostgresDb DB          Postgres database (default: sampledb)"
    Write-Host "  -AwsRegion REGION       AWS region (default: us-east-1)"
    Write-Host "  -AwsSecretArn ARN       AWS Secrets Manager secret ARN"
    Write-Host "  -NoAws                  Skip AWS Secrets Manager and use local values"
    Write-Host "  -Help                   Show this help message"
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Yellow
    Write-Host "  up       Start services (default)"
    Write-Host "  down     Stop and remove services"
    Write-Host "  restart  Restart services"
    Write-Host "  logs     Show logs"
    Write-Host "  ps       List running containers"
    Write-Host "  pull     Pull latest images"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\deploy.ps1 -EnvFile .env.prod up"
    Write-Host "  .\deploy.ps1 -AppPort 9000 -Mode production up"
    Write-Host "  .\deploy.ps1 -NoAws up"
    Write-Host "  .\deploy.ps1 down"
    Write-Host ""
    Write-Host "Environment Variables:" -ForegroundColor Yellow
    Write-Host "  Alternatively, set environment variables before running:"
    Write-Host "  `$env:APP_PORT=8000; `$env:MODE='production'; .\deploy.ps1 up"
    Write-Host ""
    Write-Host "AWS Secrets Manager:" -ForegroundColor Yellow
    Write-Host "  The script automatically fetches configuration from AWS Secrets Manager."
    Write-Host "  If fetch fails, it falls back to local values or .env file."
    exit 0
}

if ($Help) {
    Show-Usage
}

# Function to get environment from AWS Secrets Manager
function Get-AwsSecrets {
    # Check if AWS CLI is available
    $awsCmd = Get-Command aws -ErrorAction SilentlyContinue
    if (-not $awsCmd) {
        Write-ColorOutput "Warning: AWS CLI not found. Skipping AWS Secrets Manager." "Yellow"
        Write-ColorOutput "Install AWS CLI: https://aws.amazon.com/cli/" "Yellow"
        return $false
    }

    Write-ColorOutput "Fetching secrets from AWS Secrets Manager..." "Green"
    Write-Host "  Region: $AwsRegion"
    Write-Host "  Secret: $AwsSecretArn"

    # Fetch secret value
    try {
        $secretJson = aws secretsmanager get-secret-value `
            --region $AwsRegion `
            --secret-id $AwsSecretArn `
            --query SecretString `
            --output text 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "Error: Cannot fetch data from AWS Secrets Manager." "Red"
            Write-ColorOutput "Details: $secretJson" "Red"
            Write-Host ""
            Write-ColorOutput "Falling back to local environment values..." "Yellow"
            Write-Host ""
            Write-ColorOutput "If you want to use local .env file, create a file named '.env' in this directory:" "Yellow"
            Write-ColorOutput "Location: $PWD\.env" "Yellow"
            Write-ColorOutput "And run: .\deploy.ps1 -EnvFile .env up" "Yellow"
            return $false
        }
    } catch {
        Write-ColorOutput "Error: Failed to execute AWS CLI." "Red"
        Write-ColorOutput "Details: $_" "Red"
        return $false
    }

    Write-ColorOutput "Successfully fetched secrets from AWS!" "Green"
    Write-Host ""

    # Parse JSON
    try {
        $secretData = $secretJson | ConvertFrom-Json

        # Override defaults only if values exist and not already set by CLI args
        if ($secretData.APP_PORT -and -not $PSBoundParameters.ContainsKey('AppPort')) {
            $AppPort = [int]$secretData.APP_PORT
        }
        if ($secretData.MODE -and -not $PSBoundParameters.ContainsKey('Mode')) {
            $Mode = $secretData.MODE
        }
        if ($secretData.REDIS_PORT -and -not $PSBoundParameters.ContainsKey('RedisPort')) {
            $RedisPort = [int]$secretData.REDIS_PORT
        }
        if ($secretData.REDIS_PASSWORD -and -not $PSBoundParameters.ContainsKey('RedisPassword')) {
            $RedisPassword = $secretData.REDIS_PASSWORD
        }
        if ($secretData.POSTGRES_PORT -and -not $PSBoundParameters.ContainsKey('PostgresPort')) {
            $PostgresPort = [int]$secretData.POSTGRES_PORT
        }
        if ($secretData.POSTGRES_USER -and -not $PSBoundParameters.ContainsKey('PostgresUser')) {
            $PostgresUser = $secretData.POSTGRES_USER
        }
        if ($secretData.POSTGRES_PASSWORD -and -not $PSBoundParameters.ContainsKey('PostgresPassword')) {
            $PostgresPassword = $secretData.POSTGRES_PASSWORD
        }
        if ($secretData.POSTGRES_DB -and -not $PSBoundParameters.ContainsKey('PostgresDb')) {
            $PostgresDb = $secretData.POSTGRES_DB
        }

        return $true
    } catch {
        Write-ColorOutput "Error: Failed to parse JSON from AWS Secrets Manager." "Red"
        Write-ColorOutput "Details: $_" "Red"
        return $false
    }
}

# Load from AWS Secrets Manager unless explicitly disabled
if (-not $NoAws) {
    Get-AwsSecrets | Out-Null
}

# Load environment file if specified (lowest priority)
if ($EnvFile) {
    if (Test-Path $EnvFile) {
        Write-ColorOutput "Loading environment from: $EnvFile" "Green"
        Get-Content $EnvFile | ForEach-Object {
            # Skip comments and empty lines
            if ($_ -match '^\s*#' -or $_ -match '^\s*$') {
                return
            }
            if ($_ -match '^([^=]+)=(.*)$') {
                $name = $matches[1].Trim()
                $value = $matches[2].Trim()
                # Remove surrounding quotes if present
                if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
                    ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                    $value = $value.Substring(1, $value.Length - 2)
                }
                # Set environment variable (only if not already set by CLI args)
                if ($name -eq "APP_PORT" -and -not $PSBoundParameters.ContainsKey('AppPort')) {
                    [Environment]::SetEnvironmentVariable($name, $value, "Process")
                    $AppPort = [int]$value
                } elseif ($name -eq "MODE" -and -not $PSBoundParameters.ContainsKey('Mode')) {
                    [Environment]::SetEnvironmentVariable($name, $value, "Process")
                    $Mode = $value
                } elseif ($name -eq "REDIS_PORT" -and -not $PSBoundParameters.ContainsKey('RedisPort')) {
                    [Environment]::SetEnvironmentVariable($name, $value, "Process")
                    $RedisPort = [int]$value
                } elseif ($name -eq "REDIS_PASSWORD" -and -not $PSBoundParameters.ContainsKey('RedisPassword')) {
                    [Environment]::SetEnvironmentVariable($name, $value, "Process")
                    $RedisPassword = $value
                } elseif ($name -eq "POSTGRES_PORT" -and -not $PSBoundParameters.ContainsKey('PostgresPort')) {
                    [Environment]::SetEnvironmentVariable($name, $value, "Process")
                    $PostgresPort = [int]$value
                } elseif ($name -eq "POSTGRES_USER" -and -not $PSBoundParameters.ContainsKey('PostgresUser')) {
                    [Environment]::SetEnvironmentVariable($name, $value, "Process")
                    $PostgresUser = $value
                } elseif ($name -eq "POSTGRES_PASSWORD" -and -not $PSBoundParameters.ContainsKey('PostgresPassword')) {
                    [Environment]::SetEnvironmentVariable($name, $value, "Process")
                    $PostgresPassword = $value
                } elseif ($name -eq "POSTGRES_DB" -and -not $PSBoundParameters.ContainsKey('PostgresDb')) {
                    [Environment]::SetEnvironmentVariable($name, $value, "Process")
                    $PostgresDb = $value
                }
            }
        }
    } else {
        Write-ColorOutput "Error: Environment file not found: $EnvFile" "Red"
        exit 1
    }
}

# Override with environment variables from process (only if not set by CLI args)
if ($env:APP_PORT -and -not $PSBoundParameters.ContainsKey('AppPort')) { $AppPort = [int]$env:APP_PORT }
if ($env:MODE -and -not $PSBoundParameters.ContainsKey('Mode')) { $Mode = $env:MODE }
if ($env:REDIS_PORT -and -not $PSBoundParameters.ContainsKey('RedisPort')) { $RedisPort = [int]$env:REDIS_PORT }
if ($env:REDIS_PASSWORD -and -not $PSBoundParameters.ContainsKey('RedisPassword')) { $RedisPassword = $env:REDIS_PASSWORD }
if ($env:POSTGRES_PORT -and -not $PSBoundParameters.ContainsKey('PostgresPort')) { $PostgresPort = [int]$env:POSTGRES_PORT }
if ($env:POSTGRES_USER -and -not $PSBoundParameters.ContainsKey('PostgresUser')) { $PostgresUser = $env:POSTGRES_USER }
if ($env:POSTGRES_PASSWORD -and -not $PSBoundParameters.ContainsKey('PostgresPassword')) { $PostgresPassword = $env:POSTGRES_PASSWORD }
if ($env:POSTGRES_DB -and -not $PSBoundParameters.ContainsKey('PostgresDb')) { $PostgresDb = $env:POSTGRES_DB }

# Function to detect and use the correct docker compose command
function Get-DockerComposeCommand {
    # Check if docker compose (newer command) is available
    $dockerComposeCmd = Get-Command -CommandType Application -Name "docker" -ErrorAction SilentlyContinue
    if ($dockerComposeCmd) {
        # Test if docker compose subcommand is available
        $null = docker compose version 2>&1
        if ($LASTEXITCODE -eq 0) {
            return @("docker", "compose")
        }
    }

    # Check if docker-compose (older command) is available
    $dockerComposeBin = Get-Command -CommandType Application -Name "docker-compose" -ErrorAction SilentlyContinue
    if ($dockerComposeBin) {
        $null = docker-compose --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            return @("docker-compose")
        }
    }

    Write-ColorOutput "Error: Neither 'docker compose' nor 'docker-compose' command is available." "Red"
    Write-ColorOutput "Please install Docker Compose or ensure Docker is properly installed." "Red"
    exit 1
}

# Set environment variables for docker compose
$env:APP_PORT = $AppPort
$env:MODE = $Mode
$env:REDIS_PORT = $RedisPort
$env:REDIS_PASSWORD = $RedisPassword
$env:POSTGRES_PORT = $PostgresPort
$env:POSTGRES_USER = $PostgresUser
$env:POSTGRES_PASSWORD = $PostgresPassword
$env:POSTGRES_DB = $PostgresDb

# Get the correct docker compose command
$DockerComposeCmd = Get-DockerComposeCommand
$DockerComposeDisplay = $DockerComposeCmd -join " "
Write-ColorOutput "Using: $DockerComposeDisplay" "Green"

# Display configuration
Write-Host ""
Write-ColorOutput "=== Configuration ===" "Yellow"
Write-Host "App Port: $AppPort"
Write-Host "Mode: $Mode"
Write-Host "Redis Port: $RedisPort"
Write-Host "Postgres Port: $PostgresPort"
Write-Host "Compose File: $File"
Write-ColorOutput "====================" "Yellow"
Write-Host ""

# Execute the command
try {
    switch ($Command) {
        "up" {
            Write-ColorOutput "Starting services..." "Green"
            & $DockerComposeCmd -f $File up -d
            if ($LASTEXITCODE -ne 0) {
                Write-ColorOutput "Error: Failed to start services." "Red"
                exit 1
            }
            Write-ColorOutput "Services started successfully!" "Green"
        }
        "down" {
            Write-ColorOutput "Stopping and removing services..." "Yellow"
            & $DockerComposeCmd -f $File down
            if ($LASTEXITCODE -ne 0) {
                Write-ColorOutput "Error: Failed to stop services." "Red"
                exit 1
            }
            Write-ColorOutput "Services stopped and removed." "Green"
        }
        "restart" {
            Write-ColorOutput "Restarting services..." "Yellow"
            & $DockerComposeCmd -f $File restart
            if ($LASTEXITCODE -ne 0) {
                Write-ColorOutput "Error: Failed to restart services." "Red"
                exit 1
            }
            Write-ColorOutput "Services restarted successfully!" "Green"
        }
        "logs" {
            & $DockerComposeCmd -f $File logs -f
            exit $LASTEXITCODE
        }
        "ps" {
            & $DockerComposeCmd -f $File ps
            exit $LASTEXITCODE
        }
        "pull" {
            Write-ColorOutput "Pulling latest images..." "Green"
            & $DockerComposeCmd -f $File pull
            if ($LASTEXITCODE -ne 0) {
                Write-ColorOutput "Error: Failed to pull images." "Red"
                exit 1
            }
            Write-ColorOutput "Images pulled successfully!" "Green"
        }
    }
} catch {
    Write-ColorOutput "Error executing command: $_" "Red"
    exit 1
}
