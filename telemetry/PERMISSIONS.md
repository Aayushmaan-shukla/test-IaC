# Permission Setup Guide

Complete guide for understanding and managing permissions in the monitoring stack deployment.

## Table of Contents

- [Overview](#overview)
- [Permission Requirements](#permission-requirements)
- [Setup Script](#setup-script)
- [What the Script Does](#what-the-script-does)
- [Rollback Procedure](#rollback-procedure)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)
- [Manual Setup](#manual-setup)

---

## Overview

The monitoring stack requires specific permissions to function correctly, particularly for:

1. **Log File Access**: Promtail needs to read system logs
2. **Directory Ownership**: Data volumes need correct ownership
3. **Docker Access**: User needs Docker access
4. **File Permissions**: Configuration files need appropriate permissions

### Root vs Non-Root Deployment

**Root Deployment**:
- Minimal permission issues
- Higher security risk
- Not recommended for production

**Non-Root Deployment** (Recommended):
- Requires sudo for setup
- More secure
- Follows principle of least privilege

---

## Permission Requirements

### System Log Access

**Ubuntu/Debian**:
- Required: `adm` group membership
- Log files: `/var/log/auth.log`, `/var/log/syslog`

```bash
# Check current groups
groups $USER

# Add user to adm group
sudo usermod -aG adm $USER

# Verify
groups $USER
```

**CentOS/RHEL**:
- Required: `systemd-journal` group membership
- Log files: `/var/log/secure`, `/var/log/messages`

```bash
# Add user to systemd-journal group
sudo usermod -aG systemd-journal $USER

# Verify
groups $USER
```

### Docker Access

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Verify
groups $USER

# Test docker access
docker ps
```

### Directory Permissions

```bash
# Data directory (./data)
# Should be owned by deployment user
chown -R $USER:$USER ./data

# Config directory (./config)
# Should be owned by deployment user
chown -R $USER:$USER ./config

# Logs directory (./logs)
# Should be owned by deployment user
chown -R $USER:$USER ./logs
```

### Docker Volume Permissions

```bash
# After stack starts, ensure volumes have correct ownership
# Volumes are created automatically by Docker

# Check volume permissions
ls -la /var/lib/docker/volumes/

# Fix volume permissions if needed
sudo chown -R $USER:$USER /var/lib/docker/volumes/telemetry_*
```

---

## Setup Script

### Overview

The `setup-permissions.sh` script automates permission setup for both root and non-root deployments.

### Usage

```bash
# Run the script
sudo ./scripts/setup-permissions.sh

# For root users, sudo is optional but recommended for consistency
# For non-root users, sudo is required
```

### Script Flow

1. **Detect Deployment Context**
   - Check if running as root
   - Determine user vs root deployment

2. **Create Directory Structure**
   - Create `data/` directory
   - Create `logs/` directory
   - Verify `config/` exists

3. **Grant Log Access**
   - Add user to appropriate group (adm or systemd-journal)
   - Verify log file accessibility

4. **Set Directory Permissions**
   - Set correct ownership on directories
   - Set appropriate permissions (755 for dirs, 644 for files)

5. **Validate Setup**
   - Test log file access
   - Verify directory permissions
   - Report any issues

6. **Generate Rollback Info**
   - Log all changes made
   - Create rollback file for undo operations

### Example Output

```bash
$ sudo ./scripts/setup-permissions.sh

============================================
Permission Setup Script
============================================

Detecting deployment context...
✓ Running as non-root user
✓ User: aayus
✓ Home: /home/aayus

Creating directory structure...
✓ Created: /home/aayus/telemetry/data
✓ Created: /home/aayus/telemetry/logs
✓ Verified: /home/aayus/telemetry/config

Setting up log access...
✓ Added user to adm group
✓ Verified /var/log/auth.log access
✓ Verified /var/log/syslog access

Setting directory permissions...
✓ Set ownership on /home/aayus/telemetry/data
✓ Set ownership on /home/aayus/telemetry/logs

Validating setup...
✓ Log files accessible
✓ Directory permissions correct
✓ User has necessary groups

============================================
Setup completed successfully!
============================================

Next steps:
1. Logout and login again for group changes to take effect
2. Run: ./scripts/setup-env.sh
3. Run: ./scripts/deploy.sh

Rollback information saved to: .permissions-rollback-20260319-143022.txt
```

---

## What the Script Does

### Changes Made

#### 1. Directory Creation

```bash
# Creates these directories:
./data/grafana/
./data/prometheus/
./data/loki/
./data/mongodb/
./logs/
```

#### 2. Group Membership (Non-Root Only)

```bash
# Ubuntu/Debian
sudo usermod -aG adm $USER

# CentOS/RHEL
sudo usermod -aG systemd-journal $USER
```

**Why**: To read system log files for Promtail

#### 3. Directory Ownership

```bash
# Non-root deployment
chown -R $USER:$USER ./data
chown -R $USER:$USER ./logs

# Root deployment
# Owned by root, no changes needed
```

**Why**: Ensures Docker containers can write to mounted volumes

#### 4. Directory Permissions

```bash
# Directories: 755 (rwxr-xr-x)
chmod -R 755 ./data
chmod -R 755 ./logs

# Files: 644 (rw-r--r--)
find ./config -type f -exec chmod 644 {} \;
```

**Why**: Balance between security and accessibility

#### 5. Log File Access

```bash
# Tests access to log files
test -r /var/log/auth.log
test -r /var/log/syslog
```

**Why**: Verify Promtail can read system logs

### What the Script Does NOT Do

1. **Does NOT modify system-wide configuration**
   - No changes to `/etc/` (except group membership)
   - No changes to systemd services

2. **Does NOT run Docker commands**
   - Does not start containers
   - Does not pull images

3. **Does NOT install software**
   - Assumes Docker and Docker Compose are installed

4. **Does NOT modify Docker daemon**
   - No changes to Docker configuration

5. **Does NOT modify network configuration**
   - No firewall changes
   - No network interface changes

---

## Rollback Procedure

### Using Rollback Script

```bash
# Run rollback script
sudo ./scripts/rollback-permissions.sh

# This will:
# - Remove user from groups added during setup
# - Remove directories created during setup
# - Restore original permissions
# - Provide detailed report
```

### Manual Rollback

#### 1. Remove Group Membership

```bash
# Ubuntu/Debian - Remove from adm group
sudo gpasswd -d $USER adm

# CentOS/RHEL - Remove from systemd-journal group
sudo gpasswd -d $USER systemd-journal

# Verify
groups $USER
```

#### 2. Remove Created Directories

```bash
# Remove data directory (WARNING: deletes all data!)
rm -rf ./data

# Remove logs directory
rm -rf ./logs

# NOTE: config/ is not removed as it may contain important configs
```

#### 3. Restore Permissions

```bash
# If you backed up original permissions, restore them
# Otherwise, reset to defaults:

# Directories: 755
chmod -R 755 ./config

# Files: 644
find ./config -type f -exec chmod 644 {} \;
```

#### 4. Verify Rollback

```bash
# Verify groups
groups $USER

# Verify directories
ls -la

# Verify log access
ls -la /var/log/auth.log
```

### Rollback Limitations

1. **Data Loss**: Removing `./data` deletes all monitoring data
2. **Group Changes**: May affect other system components
3. **Container State**: Does not stop running containers
4. **Configuration**: Does not revert `.env` changes

**Recommendation**: Backup data before rollback

---

## Security Considerations

### Why Sudo is Required

The script requires sudo because:

1. **Group Membership**: Adding users to groups requires root privileges
2. **Directory Creation**: May create directories in restricted paths
3. **Permission Changes**: Changing file ownership requires root

### Security Risks

**Running with sudo**:
- Script executes with root privileges
- If compromised, entire system is at risk
- Should only run scripts you trust

**Mitigations**:
- Review script content before running
- Use checksum verification
- Run in isolated environment if possible
- Use separate monitoring user

### Permission Best Practices

1. **Principle of Least Privilege**
   - Grant only necessary permissions
   - Avoid running everything as root
   - Use specific user accounts

2. **Audit Trail**
   - Log all permission changes
   - Review regularly
   - Monitor for unauthorized changes

3. **Regular Review**
   - Review group memberships
   - Check file permissions
   - Audit access logs

4. **Separation of Concerns**
   - Separate monitoring user from regular users
   - Use different accounts for different environments
   - Implement role-based access control

### Sensitive Files

**Files to protect**:
- `.env` - Contains passwords
- `.env.secrets` - Contains sensitive data
- `config/*` - May contain credentials

**Protection**:
```bash
# Set restrictive permissions
chmod 600 .env
chmod 600 .env.secrets
chmod 640 config/*-secrets.*

# Ensure ownership is correct
chown $USER:$USER .env
chown $USER:$USER .env.secrets
```

---

## Troubleshooting

### Issue 1: Permission Denied on Log Files

**Symptoms**:
```
Error: permission denied: /var/log/auth.log
```

**Solutions**:

```bash
# Check current groups
groups $USER

# Add to appropriate group
sudo usermod -aG adm $USER          # Ubuntu/Debian
sudo usermod -aG systemd-journal $USER  # CentOS/RHEL

# Logout and login again
# Groups are only updated on new login session
```

### Issue 2: Docker Permission Denied

**Symptoms**:
```
Got permission denied while trying to connect to the Docker daemon socket
```

**Solutions**:

```bash
# Add to docker group
sudo usermod -aG docker $USER

# Logout and login again
# Or use newgrp for immediate effect
newgrp docker

# Verify
docker ps
```

### Issue 3: Cannot Write to Data Directory

**Symptoms**:
```
Error: permission denied: ./data/prometheus
```

**Solutions**:

```bash
# Check ownership
ls -la ./data

# Fix ownership
sudo chown -R $USER:$USER ./data

# Fix permissions
sudo chmod -R 755 ./data

# Verify
touch ./data/test
rm ./data/test
```

### Issue 4: Group Changes Not Taking Effect

**Symptoms**:
```bash
$ groups $USER
# adm group not showing up
```

**Solutions**:

```bash
# Option 1: Logout and login again
# Most reliable method

# Option 2: Use newgrp for temporary effect
newgrp adm

# Option 3: Start new shell
su - $USER

# Verify
groups $USER
```

### Issue 5: Script Fails with Permission Error

**Symptoms**:
```
Error: cannot create directory: Permission denied
```

**Solutions**:

```bash
# Check current user
whoami

# Check if directory already exists
ls -la ./

# Try with sudo
sudo ./scripts/setup-permissions.sh

# Check if script is executable
chmod +x scripts/setup-permissions.sh
```

### Issue 6: Rollback Script Fails

**Symptoms**:
```
Error: cannot remove user from group
```

**Solutions**:

```bash
# Check if user is in group
groups $USER

# Remove from group manually
sudo gpasswd -d $USER adm

# If group doesn't exist, ignore error
# Some distributions don't use adm group
```

### Issue 7: Docker Volume Permissions Wrong

**Symptoms**:
```
Error: permission denied in container logs
```

**Solutions**:

```bash
# Stop containers
docker compose down

# Find volume
docker volume ls | grep telemetry

# Check volume permissions
ls -la /var/lib/docker/volumes/

# Fix permissions
sudo chown -R $USER:$USER /var/lib/docker/volumes/telemetry_*

# Restart containers
docker compose up -d
```

### Issue 8: SELinux Blocking Access

**Symptoms** (CentOS/RHEL):
```
Permission denied (SELinux blocking)
```

**Solutions**:

```bash
# Check SELinux status
getenforce

# Temporarily disable (not recommended for production)
sudo setenforce 0

# Or set to permissive mode
sudo setenforce Permissive

# For proper fix, configure SELinux contexts
sudo chcon -R -t svirt_sandbox_file_t ./data
sudo chcon -R -t svirt_sandbox_file_t ./logs

# Make permanent
semanage fcontext -a -t svirt_sandbox_file_t "/path/to/telemetry/data(/.*)?"
restorecon -R -v /path/to/telemetry/data
```

---

## Manual Setup

If you prefer manual setup instead of using the script:

### Step 1: Create Directories

```bash
# Create data directory
mkdir -p ./data/grafana
mkdir -p ./data/prometheus
mkdir -p ./data/loki
mkdir -p ./data/mongodb

# Create logs directory
mkdir -p ./logs
```

### Step 2: Set Permissions

```bash
# Set ownership
chown -R $USER:$USER ./data
chown -R $USER:$USER ./logs

# Set directory permissions
chmod -R 755 ./data
chmod -R 755 ./logs

# Set file permissions in config
find ./config -type d -exec chmod 755 {} \;
find ./config -type f -exec chmod 644 {} \;
```

### Step 3: Add to Groups

```bash
# Ubuntu/Debian
sudo usermod -aG adm $USER
sudo usermod -aG docker $USER

# CentOS/RHEL
sudo usermod -aG systemd-journal $USER
sudo usermod -aG docker $USER
```

### Step 4: Verify Access

```bash
# Test log file access
test -r /var/log/auth.log && echo "✓ Auth log accessible"
test -r /var/log/syslog && echo "✓ Syslog accessible"

# Test docker access
docker ps &> /dev/null && echo "✓ Docker accessible"

# Test directory permissions
touch ./data/test && rm ./data/test && echo "✓ Data directory writable"
```

### Step 5: Logout and Login

```bash
# Groups only update on new login session
# Either logout and login, or:
newgrp docker
newgrp adm
```

---

## Verification

After permission setup, verify everything works:

```bash
# Check groups
groups $USER

# Check log access
ls -la /var/log/auth.log
ls -la /var/log/syslog

# Check directory permissions
ls -la ./data
ls -la ./logs

# Test docker
docker ps

# Run validation script
./scripts/validate-environment.sh
```

---

## Best Practices

1. **Always Review Scripts**
   - Read `setup-permissions.sh` before running
   - Understand what changes will be made
   - Verify script source

2. **Backup Before Changes**
   - Backup configuration files
   - Note current permissions
   - Document group memberships

3. **Use Dedicated User**
   - Create separate monitoring user
   - Don't use root for monitoring
   - Implement role separation

4. **Regular Audits**
   - Review group memberships monthly
   - Check file permissions
   - Audit access logs

5. **Document Changes**
   - Keep log of permission changes
   - Document exceptions
   - Maintain configuration history

6. **Test in Non-Production**
   - Test permission changes in staging
   - Validate before production
   - Document any issues

---

## Additional Resources

- [Linux File Permissions](https://wiki.archlinux.org/title/File_permissions_and_attributes)
- [Docker Security](https://docs.docker.com/engine/security/)
- [Systemd Journal Access](https://www.freedesktop.org/software/systemd/man/systemd-journal-gatewayd.html)
- [SELinux Configuration](https://selinuxproject.org/page/Main_Page)

---

**Last Updated**: 2026-03-19
**Version**: 1.0.0
