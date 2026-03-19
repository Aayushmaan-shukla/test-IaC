# Environment Variable Reference

Complete reference for all environment variables used in the monitoring stack configuration.

## Table of Contents

- [Overview](#overview)
- [Required Variables](#required-variables)
- [Optional Variables](#optional-variables)
- [Grafana Variables](#grafana-variables)
- [Prometheus Variables](#prometheus-variables)
- [Loki Variables](#loki-variables)
- [MongoDB Variables](#mongodb-variables)
- [Path Variables](#path-variables)
- [Security Notes](#security-notes)
- [Default Values](#default-values)

---

## Overview

Environment variables are defined in the `.env` file and used by Docker Compose to configure services. This document provides a complete reference of all available variables.

### File Structure

```bash
.env                    # Main configuration file (git-ignored)
.env.example            # Template with defaults (git-tracked)
.env.secrets            # Sensitive data (git-ignored)
```

### Usage

```bash
# Copy template
cp .env.example .env

# Edit configuration
nano .env

# Restart services to apply changes
docker compose restart [service-name]
```

---

## Required Variables

These variables must be set for the stack to function correctly.

### GRAFANA_PASSWORD

**Description**: Administrator password for Grafana

**Default**: None (must be set)

**Security**: High

**Example**:
```bash
GRAFANA_PASSWORD=your-secure-password-here
```

**Impact**:
- Used for Grafana admin login
- Required for accessing Grafana UI
- Should be changed from default

**Recommendations**:
- Use strong password (16+ characters)
- Include numbers, symbols, uppercase, lowercase
- Rotate regularly (every 90 days)
- Never commit to version control

### MONGO_PASSWORD

**Description**: Root password for MongoDB

**Default**: None (must be set)

**Security**: Critical

**Example**:
```bash
MONGO_PASSWORD=your-secure-mongodb-password
```

**Impact**:
- Used for MongoDB root authentication
- Required for MongoDB access
- Affects MongoDB exporter

**Recommendations**:
- Use very strong password (20+ characters)
- Different from Grafana password
- Rotate regularly (every 60 days)
- Never commit to version control

---

## Optional Variables

These variables have default values but can be customized.

### Environment

### DEPLOYMENT_ENV

**Description**: Deployment environment identifier

**Default**: `production`

**Options**: `production`, `staging`, `development`, `testing`

**Example**:
```bash
DEPLOYMENT_ENV=production
```

**Impact**:
- Used for labeling and organization
- Helps separate environments
- May affect default configurations

**Recommendations**:
- Use consistent naming
- Match environment to actual use case

### HOSTNAME

**Description**: Hostname for the monitoring server

**Default**: Auto-detected from system

**Example**:
```bash
HOSTNAME=monitoring-server-01
```

**Impact**:
- Used for service identification
- Appears in logs and metrics
- Helpful in multi-server setups

**Recommendations**:
- Use descriptive hostname
- Keep consistent across restarts

---

## Grafana Variables

### GF_SECURITY_ADMIN_USER

**Description**: Grafana admin username

**Default**: `admin`

**Example**:
```bash
GF_SECURITY_ADMIN_USER=admin
```

**Impact**:
- Login username for Grafana
- Should not be changed after initial setup
- Affects provisioning

**Recommendations**:
- Keep as `admin` unless required otherwise
- If changing, update documentation
- Ensure dashboards and datasources are updated

### GF_SERVER_ROOT_URL

**Description**: Public URL for Grafana

**Default**: `http://localhost:4101`

**Example**:
```bash
GF_SERVER_ROOT_URL=https://grafana.example.com
```

**Impact**:
- Used for links and redirects
- Affects generated URLs
- Required for reverse proxy setups

**Recommendations**:
- Use HTTPS in production
- Include domain name for external access
- Update if using reverse proxy

### GF_USERS_ALLOW_SIGN_UP

**Description**: Allow user self-registration

**Default**: `false`

**Options**: `true`, `false`

**Example**:
```bash
GF_USERS_ALLOW_SIGN_UP=false
```

**Impact**:
- Controls user registration
- Security setting
- Affects user management

**Recommendations**:
- Keep `false` for security
- Enable `true` only in development
- Manually create users instead

### GF_INSTALL_PLUGINS

**Description**: Comma-separated list of Grafana plugins to install

**Default**: Empty

**Example**:
```bash
GF_INSTALL_PLUGINS=grafana-piechart-panel,grafana-worldmap-panel
```

**Impact**:
- Plugins installed on startup
- Adds functionality to Grafana
- May increase startup time

**Recommendations**:
- Only install necessary plugins
- Test plugins in staging first
- Keep list minimal

### GF_ANALYTICS_REPORTING_ENABLED

**Description**: Enable anonymous usage analytics

**Default**: `false`

**Options**: `true`, `false`

**Example**:
```bash
GF_ANALYTICS_REPORTING_ENABLED=false
```

**Impact**:
- Sends anonymous usage data to Grafana
- No personal data sent
- Helps improve Grafana

**Recommendations**:
- Set to `false` for privacy
- Set to `true` to contribute
- Check company policy

### GF_SECURITY_SECRET_KEY

**Description**: Secret key for Grafana

**Default**: Auto-generated (not recommended for production)

**Example**:
```bash
GF_SECURITY_SECRET_KEY=sw8f93js93kd9sk3d9sk3d93ks93dk93k
```

**Impact**:
- Used for encryption and signing
- Critical for security
- Should be set in production

**Recommendations**:
- Generate strong random key (32+ chars)
- Keep secret, never commit to git
- Rotate regularly (every 180 days)
- Generate using: `openssl rand -hex 16`

---

## Prometheus Variables

### PROMETHEUS_RETENTION_TIME

**Description**: How long Prometheus keeps metrics

**Default**: `15d`

**Format**: `<number><unit>` (s, m, h, d)

**Examples**:
```bash
PROMETHEUS_RETENTION_TIME=15d
PROMETHEUS_RETENTION_TIME=7d
PROMETHEUS_RETENTION_TIME=720h
```

**Impact**:
- Determines disk space usage
- Affects query time range
- Longer retention = more disk space

**Disk Space Estimates**:
- 7 days: ~23 GB
- 15 days: ~50 GB
- 30 days: ~100 GB

**Recommendations**:
- Balance between data needs and disk space
- Monitor disk usage regularly
- Consider 7-15 days for most use cases

### PROMETHEUS_SCRAPE_INTERVAL

**Description**: How often Prometheus scrapes metrics

**Default**: `15s`

**Format**: `<number><unit>` (s, m)

**Examples**:
```bash
PROMETHEUS_SCRAPE_INTERVAL=15s
PROMETHEUS_SCRAPE_INTERVAL=30s
PROMETHEUS_SCRAPE_INTERVAL=1m
```

**Impact**:
- Determines metric granularity
- Affects performance and storage
- Shorter interval = more data

**Performance Impact**:
- 15s: High granularity, high load
- 30s: Balanced
- 1m: Low granularity, low load

**Recommendations**:
- Use 15s for critical systems
- Use 30s for general monitoring
- Use 1m for less critical systems

### PROMETHEUS_STORAGE_TSDB_RETENTION_SIZE

**Description**: Maximum disk space for Prometheus data

**Default**: Not set (uses retention time)

**Format**: `<number><unit>` (B, KB, MB, GB)

**Examples**:
```bash
PROMETHEUS_STORAGE_TSDB_RETENTION_SIZE=50GB
PROMETHEUS_STORAGE_TSDB_RETENTION_SIZE=100GB
```

**Impact**:
- Limits Prometheus disk usage
- Takes priority over retention time
- Prevents disk filling

**Recommendations**:
- Set slightly below actual disk space
- Monitor disk usage regularly
- Leave space for other services

---

## Loki Variables

### LOKI_RETENTION_PERIOD

**Description**: How long Loki keeps logs

**Default**: `7d`

**Format**: `<number><unit>` (h, d)

**Examples**:
```bash
LOKI_RETENTION_PERIOD=7d
LOKI_RETENTION_PERIOD=30d
LOKI_RETENTION_PERIOD=168h
```

**Impact**:
- Determines disk space usage
- Affects log query time range
- Longer retention = more disk space

**Disk Space Estimates**:
- 7 days: ~20 GB
- 30 days: ~85 GB

**Recommendations**:
- Balance between logging needs and disk space
- Consider log volume when setting
- Monitor disk usage regularly

### LOKI_LIMIT_MAX_STREAMS_PER_USER

**Description**: Maximum number of active streams per user

**Default**: `0` (unlimited)

**Example**:
```bash
LOKI_LIMIT_MAX_STREAMS_PER_USER=10000
```

**Impact**:
- Controls stream cardinality
- Prevents runaway stream creation
- Too high = performance issues

**Recommendations**:
- Set to reasonable limit (10,000-100,000)
- Monitor stream count
- Adjust based on usage

### LOKI_LIMIT_MAX_GLOBAL_STREAMS

**Description**: Maximum total streams across all users

**Default**: `0` (unlimited)

**Example**:
```bash
LOKI_LIMIT_MAX_GLOBAL_STREAMS=500000
```

**Impact**:
- Controls total stream cardinality
- Prevents system overload
- Affects index size

**Recommendations**:
- Set based on expected load
- Monitor total stream count
- Prevent unbounded growth

---

## MongoDB Variables

### MONGO_INITDB_ROOT_USERNAME

**Description**: MongoDB root username

**Default**: `admin`

**Example**:
```bash
MONGO_INITDB_ROOT_USERNAME=admin
```

**Impact**:
- Used for root authentication
- Required for MongoDB access
- Should not be changed after setup

**Recommendations**:
- Keep as `admin` unless required
- Document if changed
- Update exporter configuration

### MONGO_INITDB_ROOT_DATABASE

**Description**: MongoDB root database

**Default**: `admin`

**Example**:
```bash
MONGO_INITDB_ROOT_DATABASE=admin
```

**Impact**:
- Database for root authentication
- Should not be changed after setup
- Affects initial database creation

**Recommendations**:
- Keep as `admin`
- Only change if required by application

### MONGO_INITDB_DATABASE

**Description**: Initial database to create

**Default**: Not set

**Example**:
```bash
MONGO_INITDB_DATABASE=telemetry
```

**Impact**:
- Creates specified database on startup
- Optional, for convenience
- Not required for monitoring

**Recommendations**:
- Set if you need initial database
- Leave unset if not needed
- Can be created later if needed

---

## Path Variables

### DATA_DIR

**Description**: Directory for persistent data storage

**Default**: `./data`

**Example**:
```bash
DATA_DIR=./data
```

**Impact**:
- Location for all data volumes
- Affects disk usage
- Should be on disk with sufficient space

**Recommendations**:
- Use absolute paths in production
- Ensure sufficient disk space
- Mount to dedicated disk if possible
- Example: `/mnt/monitoring/data`

### CONFIG_DIR

**Description**: Directory for configuration files

**Default**: `./config`

**Example**:
```bash
CONFIG_DIR=./config
```

**Impact**:
- Location for all config files
- Mounted into containers
- Should contain prometheus.yml, loki-config.yml, etc.

**Recommendations**:
- Keep default in most cases
- Use absolute paths in production
- Ensure files are readable by Docker

### LOGS_DIR

**Description**: Directory for log symlinks

**Default**: `./logs`

**Example**:
```bash
LOGS_DIR=./logs
```

**Impact**:
- Location for log file symlinks
- Used by Promtail
- Should link to actual log locations

**Recommendations**:
- Keep default in most cases
- Ensure symlinks are created correctly
- Monitor symlink health

---

## Security Notes

### Password Security

**Critical Security Variables**:
- `GRAFANA_PASSWORD`
- `MONGO_PASSWORD`
- `GF_SECURITY_SECRET_KEY`

**Security Requirements**:
1. Never commit to version control
2. Use strong, unique passwords
3. Rotate regularly (60-90 days)
4. Use different passwords for each service
5. Store in secure location

**Password Generation**:
```bash
# Generate strong password
openssl rand -base64 32

# Or use /dev/urandom
head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32
```

### Secrets Management

**Best Practices**:

1. **Separate Files**
   ```bash
   # .env for non-sensitive config
   GRAFANA_PORT=4101

   # .env.secrets for sensitive data
   GRAFANA_PASSWORD=secret
   MONGO_PASSWORD=secret
   ```

2. **File Permissions**
   ```bash
   chmod 600 .env
   chmod 600 .env.secrets
   chown $USER:$USER .env .env.secrets
   ```

3. **Git Ignore**
   ```bash
   # .gitignore
   .env
   .env.secrets
   *.key
   *.pem
   ```

4. **Environment-Specific**
   ```bash
   # Production: .env.production
   # Staging: .env.staging
   # Development: .env.development
   ```

5. **Vault Integration** (Advanced)
   - Use HashiCorp Vault for secrets
   - Mount secrets as volumes
   - Use Docker secrets in swarm mode

### Container Security

**UID/GID**:
```bash
# Run containers as non-root user
# Set in docker-compose.yml
user: "1000:1000"
```

**Read-Only Root**:
```yaml
# Make containers more secure
read_only: true
tmpfs:
  - /tmp
  - /run
```

**Capabilities**:
```yaml
# Drop unnecessary capabilities
cap_drop:
  - ALL
cap_add:
  - CHOWN
  - SETGID
  - SETUID
```

---

## Default Values

### Complete .env.example

```bash
# ================================
# Required Variables
# ================================
GRAFANA_PASSWORD=changeme_immediately
MONGO_PASSWORD=changeme_immediately

# ================================
# Environment
# ================================
DEPLOYMENT_ENV=production
HOSTNAME=monitoring-server

# ================================
# Grafana Configuration
# ================================
GF_SECURITY_ADMIN_USER=admin
GF_SERVER_ROOT_URL=http://localhost:4101
GF_USERS_ALLOW_SIGN_UP=false
GF_INSTALL_PLUGINS=
GF_ANALYTICS_REPORTING_ENABLED=false
# GF_SECURITY_SECRET_KEY=auto-generated

# ================================
# Prometheus Configuration
# ================================
PROMETHEUS_RETENTION_TIME=15d
PROMETHEUS_SCRAPE_INTERVAL=15s
# PROMETHEUS_STORAGE_TSDB_RETENTION_SIZE=

# ================================
# Loki Configuration
# ================================
LOKI_RETENTION_PERIOD=7d
LOKI_LIMIT_MAX_STREAMS_PER_USER=0
LOKI_LIMIT_MAX_GLOBAL_STREAMS=0

# ================================
# MongoDB Configuration
# ================================
MONGO_INITDB_ROOT_USERNAME=admin
MONGO_INITDB_ROOT_DATABASE=admin
# MONGO_INITDB_DATABASE=

# ================================
# Paths (usually auto-detected)
# ================================
DATA_DIR=./data
CONFIG_DIR=./config
LOGS_DIR=./logs

# ================================
# Ports (usually set in docker-compose.yml)
# ================================
GRAFANA_PORT=4101
PROMETHEUS_PORT=4102
LOKI_PORT=4103
MONGODB_PORT=27017
```

---

## Impact of Changing Variables

### Variables Requiring Restart

These variables require full container restart:
- `GRAFANA_PASSWORD`
- `MONGO_PASSWORD`
- `GF_SECURITY_SECRET_KEY`
- `PROMETHEUS_RETENTION_TIME`
- `PROMETHEUS_STORAGE_TSDB_RETENTION_SIZE`
- `LOKI_RETENTION_PERIOD`

### Variables Requiring Reload

These variables can be reloaded without restart:
- `PROMETHEUS_SCRAPE_INTERVAL` (via Prometheus reload)
- Most configuration file changes

### Variables Taking Effect Immediately

These variables take effect without restart:
- Environment variables used by scripts
- Labels used for organization

---

## Validation

### Before Deployment

```bash
# Check all required variables are set
grep -E "^(GRAFANA_PASSWORD|MONGO_PASSWORD)=" .env

# Check syntax
source .env

# Check passwords are not default
grep "changeme" .env
```

### After Deployment

```bash
# Verify Grafana password works
curl -u admin:$GRAFANA_PASSWORD http://localhost:4101/api/health

# Verify MongoDB connection
docker exec mongodb mongosh --eval "db.adminCommand('ping')"

# Check Prometheus retention
curl http://localhost:4102/api/v1/status/config | jq .data.storage
```

---

## Common Mistakes

### 1. Using Default Passwords

**Problem**: Using `changeme` or default passwords

**Solution**:
```bash
# Generate strong password
openssl rand -base64 32

# Update .env
nano .env

# Restart services
docker compose restart grafana mongodb
```

### 2. Committing .env to Git

**Problem**: Sensitive data in version control

**Solution**:
```bash
# Remove from git history
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch .env" \
  --prune-empty --tag-name-filter cat -- --all

# Add to .gitignore
echo ".env" >> .gitignore
echo ".env.secrets" >> .gitignore
```

### 3. Wrong File Permissions

**Problem**: .env file readable by others

**Solution**:
```bash
# Restrict permissions
chmod 600 .env
chmod 600 .env.secrets

# Verify
ls -la .env
```

### 4. Inconsistent Retention Settings

**Problem**: Disk fills up unexpectedly

**Solution**:
```bash
# Set explicit limits
PROMETHEUS_STORAGE_TSDB_RETENTION_SIZE=50GB
PROMETHEUS_RETENTION_TIME=15d
LOKI_RETENTION_PERIOD=7d

# Monitor disk usage
df -h
docker system df
```

### 5. Missing Secret Key

**Problem**: Grafana uses auto-generated key

**Solution**:
```bash
# Generate secret key
openssl rand -hex 16

# Add to .env
GF_SECURITY_SECRET_KEY=sw8f93js93kd9sk3d9sk3d93ks93dk93k

# Restart Grafana
docker compose restart grafana
```

---

## Additional Resources

- [Grafana Environment Variables](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/)
- [Prometheus Configuration](https://prometheus.io/docs/prometheus/latest/configuration/configuration/)
- [Loki Configuration](https://grafana.com/docs/loki/latest/configuration/)
- [MongoDB Environment Variables](https://hub.docker.com/_/mongo)
- [Docker Compose Environment Variables](https://docs.docker.com/compose/environment-variables/)

---

**Last Updated**: 2026-03-19
**Version**: 1.0.0
