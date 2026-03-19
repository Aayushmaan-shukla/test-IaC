# Monitoring Stack Scripts - Summary

## Created Scripts

All scripts have been created in `C:\Users\aayus\IAAC\telemetry\scripts\` directory.

### 1. setup-permissions.sh

**Purpose:** Permission setup script with user context detection and idempotent operations

**Key Features:**
- Detects if running as root or non-root user
- Creates directory structure with correct ownership
- Grants log access by adding user to adm/systemd-journal groups
- Sets correct permissions on Docker volumes
- Validates permissions before proceeding
- Logs all changes for potential rollback
- Fully idempotent (can run multiple times)
- Detects existing setup
- Handles both /root/ and /home/user/ contexts

**Usage:**
```bash
./scripts/setup-permissions.sh [--help] [--verbose] [--dry-run] [--skip-logs] [--force]
```

**Options:**
- `-h, --help` - Show help message
- `-v, --verbose` - Enable verbose logging
- `-d, --dry-run` - Show what would be done without making changes
- `-s, --skip-logs` - Skip log access permission setup
- `-f, --force` - Continue even if log access validation fails

**Requirements:**
- Sudo access for non-root users
- Linux OS (Ubuntu/Debian or CentOS/RHEL)

---

### 2. validate-environment.sh

**Purpose:** Pre-flight checks before deployment

**Key Features:**
- Checks if Docker is installed and running
- Checks if Docker Compose is installed
- Validates minimum system resources (CPU, RAM, disk)
- Checks if ports 4101, 4102, 4103, 27017 are available
- Validates .env file exists and is readable
- Checks if required directories exist
- Tests access to /var/log files
- Reports all issues before proceeding
- Exits with proper error codes

**Usage:**
```bash
./scripts/validate-environment.sh [--help] [--verbose] [--auto-fix] [--skip-port-check] [--continue-on-error]
```

**Options:**
- `-h, --help` - Show help message
- `-v, --verbose` - Enable verbose logging
- `-f, --auto-fix` - Attempt to automatically fix some issues
- `-s, --skip-port-check` - Skip port availability checks
- `-c, --continue-on-error` - Continue even if validation fails

**Minimum Requirements:**
- Docker: 20.10+
- Docker Compose: 2.20+
- CPU: 2+ cores
- RAM: 4+ GB
- Disk: 50+ GB available
- Linux Kernel: 3.10+

---

### 3. setup-env.sh

**Purpose:** Environment configuration and setup

**Key Features:**
- Copies .env.example to .env
- Prompts user for secrets (passwords)
- Sets default values for all variables
- Validates all environment variables
- Generates random passwords if not provided
- Creates .env.secrets file with sensitive data
- Documents each variable in the .env file

**Usage:**
```bash
./scripts/setup-env.sh [--help] [--non-interactive] [--generate-passwords] [--force]
```

**Options:**
- `-h, --help` - Show help message
- `-n, --non-interactive` - Run without user prompts (use defaults)
- `-g, --generate-passwords` - Generate random passwords for all secrets
- `-f, --force` - Overwrite existing .env file without prompting

**Password Requirements:**
- Minimum 12 characters
- Recommended: 24+ characters for production

**Security:**
- Generated passwords are cryptographically secure
- .env.secrets file is set to mode 600 (read/write by owner only)
- Add both .env and .env.secrets to .gitignore

---

### 4. deploy.sh

**Purpose:** Main deployment orchestration script

**Key Features:**
- Runs validate-environment.sh first
- Runs setup-permissions.sh if needed
- Pulls Docker images
- Starts containers with docker-compose
- Waits for containers to be healthy
- Runs health checks
- Displays URLs and credentials
- Logs deployment status
- Handles errors gracefully
- Supports detached mode

**Usage:**
```bash
./scripts/deploy.sh [--help] [--skip-validation] [--skip-permissions] [--detach] [--force] [--verbose] [--timeout SECONDS]
```

**Options:**
- `-h, --help` - Show help message
- `-s, --skip-validation` - Skip environment validation
- `-p, --skip-permissions` - Skip permission setup
- `-d, --detach` - Run in detached mode
- `-f, --force` - Continue despite warnings
- `-v, --verbose` - Enable verbose logging
- `-t, --timeout SECONDS` - Deployment timeout (default: 600)

**Requirements:**
- Docker and Docker Compose installed
- .env file configured (run setup-env.sh)
- Proper permissions (run setup-permissions.sh)
- Sufficient system resources

---

### 5. rollback-permissions.sh

**Purpose:** Undo permission changes made by setup-permissions.sh

**Key Features:**
- Removes user from adm/systemd-journal groups
- Removes created directories
- Restores original permissions
- Confirms with user before proceeding
- Logs rollback actions
- Validates rollback
- Safe rollback with dry-run mode

**Usage:**
```bash
./scripts/rollback-permissions.sh [--help] [--verbose] [--dry-run] [--force]
```

**Options:**
- `-h, --help` - Show help message
- `-v, --verbose` - Enable verbose logging
- `-d, --dry-run` - Show what would be done without making changes
- `-f, --force` - Skip confirmation prompts

**Warning:**
This will remove directories and their contents!
Make sure to backup important data before proceeding.

**What Gets Rolled Back:**
- Group memberships: adm, systemd-journal, docker
- Created directories: data/, logs/, config/
- File permissions: .env, .env.secrets
- Log files: all logs in logs/

**What Does Not Get Rolled Back:**
- Docker containers (must be stopped manually)
- Docker images
- Docker volumes (must be removed manually)
- System-wide configuration files
- Environment variables

---

## Common Workflows

### First-Time Deployment

```bash
# 1. Setup permissions
./scripts/setup-permissions.sh

# 2. Setup environment configuration
./scripts/setup-env.sh

# 3. Validate environment
./scripts/validate-environment.sh

# 4. Deploy
./scripts/deploy.sh
```

### Quick Deployment (After Initial Setup)

```bash
# Deploy with all checks
./scripts/deploy.sh
```

### Deployment with Custom Settings

```bash
# Generate passwords non-interactively
./scripts/setup-env.sh --non-interactive --generate-passwords

# Deploy with custom timeout
./scripts/deploy.sh --timeout 1200
```

### Cleanup and Rollback

```bash
# 1. Stop containers
docker-compose down

# 2. Rollback permissions
./scripts/rollback-permissions.sh
```

---

## Making Scripts Executable

Before running any script, make them executable:

```bash
chmod +x scripts/*.sh
```

Or make individual scripts executable:

```bash
chmod +x scripts/setup-permissions.sh
chmod +x scripts/validate-environment.sh
chmod +x scripts/setup-env.sh
chmod +x scripts/deploy.sh
chmod +x scripts/rollback-permissions.sh
```

---

## Log Files

All scripts create detailed log files in the `logs/` directory:

- `logs/setup-permissions.log` - Permission setup operations
- `logs/rollback-actions.log` - Rollback actions for undo
- `logs/setup-env.log` - Environment setup operations
- `logs/deployment.log` - Deployment operations
- `logs/validation.log` - Environment validation results

---

## Troubleshooting

### Permission Denied

If you get permission errors:
- Ensure scripts are executable: `chmod +x scripts/*.sh`
- Check sudo access for non-root users
- Run `./scripts/setup-permissions.sh` first

### Port Conflicts

If ports are already in use:
- Check what's using the ports: `netstat -tuln` or `ss -tuln`
- Stop conflicting services
- Or modify ports in .env file

### Docker Issues

If Docker is not working:
- Check Docker is installed: `docker --version`
- Check Docker is running: `docker ps`
- Check Docker Compose is installed: `docker-compose --version`

### Environment Issues

If .env file is missing:
- Run: `./scripts/setup-env.sh`
- Or copy from example: `cp .env.example .env`

---

## Additional Notes

- All scripts are production-quality with comprehensive error handling
- Each script includes detailed help messages with `--help` flag
- Scripts work on both Ubuntu/Debian and CentOS/RHEL
- Idempotent operations - safe to run multiple times
- Comprehensive logging for debugging and auditing
- Rollback capabilities for permission changes
- Security best practices implemented throughout

---

## Support

For detailed usage information, run each script with the `--help` flag:

```bash
./scripts/setup-permissions.sh --help
./scripts/validate-environment.sh --help
./scripts/setup-env.sh --help
./scripts/deploy.sh --help
./scripts/rollback-permissions.sh --help
```
