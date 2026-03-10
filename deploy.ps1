# Deployment script for docker-compose
# Usage: .\deploy.ps1 start|rebuild|stop

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('start', 'rebuild', 'stop')]
    [string]$Action = 'start'
)

# Prefer docker-compose over docker compose
$dockerComposeCommand = $null

# Check if docker-compose is available
if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
    $dockerComposeCommand = 'docker-compose'
}
# Fallback to docker compose
elseif (Get-Command docker -ErrorAction SilentlyContinue) {
    $output = docker compose version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $dockerComposeCommand = 'docker compose'
    }
}

if (-not $dockerComposeCommand) {
    Write-Error "Error: Neither docker-compose nor docker compose is installed"
    exit 1
}

switch ($Action) {
    'start' {
        Write-Host "Starting containers..."
        Invoke-Expression "$dockerComposeCommand up -d"
    }
    'rebuild' {
        Write-Host "Rebuilding and starting containers..."
        Invoke-Expression "$dockerComposeCommand up -d --build"
    }
    'stop' {
        Write-Host "Stopping containers..."
        Invoke-Expression "$dockerComposeCommand down"
    }
}
