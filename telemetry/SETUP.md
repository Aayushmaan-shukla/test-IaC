# Setup Guide - Monitoring Stack

Comprehensive guide for setting up and configuring the LGTM + MongoDB monitoring stack.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Pre-Installation Checklist](#pre-installation-checklist)
- [Installation Steps](#installation-steps)
- [Configuration](#configuration)
- [Validation](#validation)
- [Common Setup Issues](#common-setup-issues)
- [System-Specific Instructions](#system-specific-instructions)
- [Backup and Restore](#backup-and-restore)

---

## Prerequisites

### Software Requirements

#### Docker Engine

**Version**: 20.10 or higher

```bash
# Check Docker version
docker --version

# Install Docker on Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker on CentOS/RHEL
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
```

#### Docker Compose

**Version**: 2.20 or higher

```bash
# Check Docker Compose version
docker compose version

# Install Docker Compose (included with Docker)
# On older systems:
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

#### jq (Optional but Recommended)

```bash
# Install jq for JSON parsing
sudo apt-get install -y jq  # Ubuntu/Debian
sudo yum install -y jq      # CentOS/RHEL
```

### System Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU Cores | 8 | 12+ |
| RAM | 8 GB | 16+ GB |
| Disk Space | 100 GB | 200+ GB SSD |
| Network | 1 Gbps | 1+ Gbps |

### Network Requirements

- **Available Ports**: 4101, 4102, 4103, 27017
- **Firewall**: Must allow traffic on monitoring ports
- **DNS**: Working DNS resolution
- **Internet**: For initial image pull

### Permission Requirements

#### Root Deployment

- No special requirements beyond root access

#### Non-Root Deployment

- Sudo privileges for setup
- Ability to add user to `adm` or `systemd-journal` groups
- Write access to deployment directory

---

## Pre-Installation Checklist

Before starting installation, verify:

```bash
# 1. Check Docker is installed and running
docker info

# 2. Check Docker Compose is available
docker compose version

# 3. Check available ports
netstat -tuln | grep -E '4101|4102|4103|27017'

# 4. Check disk space
df -h

# 5. Check RAM
free -h

# 6. Check CPU
lscpu | grep '^CPU(s):'

# 7. Check log files exist (for Promtail)
ls -la /var/log/auth.log /var/log/syslog 2>/dev/null || \
ls -la /var/log/secure /var/log/messages 2>/dev/null

# 8. Check user groups (for non-root deployment)
groups $USER
```

---

## Installation Steps

### Step 1: Prepare Deployment Directory

```bash
# Root deployment
cd /root
mkdir -p telemetry
cd telemetry

# OR Non-root deployment
cd /home/your-user
mkdir -p telemetry
cd telemetry

# Extract or clone monitoring stack files here
```

### Step 2: Run Permission Setup

**For Root Users**:

```bash
./scripts/setup-permissions.sh

# Script will:
# - Detect root context
# - Create directory structure
# - Verify log access
# - Set appropriate permissions
```

**For Non-Root Users**:

```bash
sudo ./scripts/setup-permissions.sh

# Script will:
# - Detect user context
# - Create directory structure in $HOME
# - Add user to adm/systemd-journal groups
# - Set appropriate permissions
# - May require logout/login for group changes
```

**What the script does**:

1. Creates required directories:
   - `data/` - Persistent storage
   - `logs/` - Log symlinks
   - `config/` - Configuration files

2. Sets up permissions:
   - Adds user to log access groups (non-root)
   - Sets correct ownership on directories
   - Validates log file access

3. Validates setup:
   - Checks directory permissions
   - Verifies log file accessibility
   - Reports any issues

### Step 3: Configure Environment Variables

```bash
# Run environment setup script
./scripts/setup-env.sh

# This will:
# - Copy .env.example to .env
# - Prompt for required values
# - Validate inputs
# - Generate secure passwords if needed
```

**Manual Configuration** (if preferred):

```bash
# Copy template
cp .env.example .env

# Edit configuration
nano .env

# Required variables:
# GRAFANA_PASSWORD=admin_password_here
# MONGO_PASSWORD=mongo_password_here

# Optional variables (see ENV_REFERENCE.md)
```

### Step 4: Validate Environment

```bash
# Run validation script
./scripts/validate-environment.sh

# This will check:
# - Docker and Docker Compose availability
# - Environment variables
# - Port availability
# - Disk space
# - Directory permissions
# - Log file access
```

### Step 5: Deploy the Stack

```bash
# Option 1: Use deployment script
./scripts/deploy.sh

# Option 2: Manual deployment
docker compose up -d

# Option 3: Deploy with logs
docker compose up -d && docker compose logs -f
```

**What happens during deployment**:

1. Docker pulls required images
2. Creates Docker network `monitor-net`
3. Creates and starts all containers
4. Configures Grafana provisioning
5. Starts log collection
6. Begins metrics collection

### Step 6: Verify Deployment

```bash
# Check all containers are running
docker compose ps

# Expected output:
# NAME                STATUS              PORTS
# grafana             Up (healthy)        0.0.0.0:4101->3000/tcp
# prometheus          Up (healthy)        0.0.0.0:4102->9090/tcp
# loki                Up (healthy)        0.0.0.0:4103->3100/tcp
# promtail            Up                  -
# node-exporter       Up                  9100/tcp
# mongodb             Up (healthy)        0.0.0.0:27017->27017/tcp
# mongodb-exporter    Up                  9214/tcp

# Check logs for any errors
docker compose logs

# Test Grafana
curl -I http://localhost:4101

# Test Prometheus
curl http://localhost:4102/api/v1/status/config

# Test Loki
curl http://localhost:4103/ready

# Test MongoDB
docker exec mongodb mongosh --eval "db.adminCommand('ping')"
```

---

## Configuration

### Environment Variables

All configuration is done via environment variables in `.env` file.

#### Required Variables

```bash
# Grafana
GRAFANA_PASSWORD=secure_password_here

# MongoDB
MONGO_PASSWORD=secure_password_here
```

#### Optional Variables

```bash
# Grafana
GF_SERVER_ROOT_URL=http://localhost:4101
GF_INSTALL_PLUGINS=

# Prometheus
PROMETHEUS_RETENTION_TIME=15d
PROMETHEUS_SCRAPE_INTERVAL=15s

# Loki
LOKI_RETENTION_PERIOD=7d

# MongoDB
MONGO_INITDB_ROOT_USERNAME=admin
MONGO_INITDB_ROOT_DATABASE=admin

# Paths (automatically set)
DATA_DIR=./data
CONFIG_DIR=./config
LOGS_DIR=./logs
```

For complete reference, see [ENV_REFERENCE.md](ENV_REFERENCE.md)

### Prometheus Configuration

**File**: `config/prometheus.yml`

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'monitoring-stack'
    environment: 'production'

scrape_configs:
  # File-based service discovery for APIs
  - job_name: 'file-sd'
    file_sd_configs:
      - files:
          - '/etc/prometheus/file-sd/*.json'
        refresh_interval: 30s

  # Static targets
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'mongodb-exporter'
    static_configs:
      - targets: ['mongodb-exporter:9214']
```

### Loki Configuration

**File**: `config/loki-config.yml`

```yaml
server:
  http_listen_port: 3100

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  retention_period: 7d

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  filesystem:
    max_chunks: 0
  boltdb_shipper:
    active_index_directory: /loki/index
    cache_location: /loki/cache
```

### Promtail Configuration

**File**: `config/promtail-config.yml`

```yaml
server:
  http_listen_port: 9080

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  # SSH Authentication Logs
  - job_name: auth-logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: ssh-auth
          __path__: /var/log/auth.log
          stream: ssh

  # System Logs
  - job_name: syslog
    static_configs:
      - targets:
          - localhost
        labels:
          job: system-logs
          __path__: /var/log/syslog
          stream: syslog
```

### Grafana Provisioning

**Datasources**: `config/grafana-provisioning/datasources/datasources.yml`

**Dashboards**: `config/grafana-provisioning/dashboards/dashboards.yml`

---

## Validation

### Health Checks

```bash
# Check all containers
docker compose ps

# Check container health
docker inspect --format='{{.State.Health.Status}}' grafana

# Check Grafana health
curl http://localhost:4101/api/health

# Check Prometheus targets
curl http://localhost:4102/api/v1/targets | jq

# Check Loki health
curl http://localhost:4103/ready
```

### Metrics Validation

```bash
# Check if Prometheus is scraping
curl 'http://localhost:4102/api/v1/query?query=up' | jq

# Check specific metrics
curl 'http://localhost:4102/api/v1/query?query=node_cpu_seconds_total' | jq

# Check MongoDB metrics
curl 'http://localhost:4102/api/v1/query?query=mongodb_up' | jq
```

### Logs Validation

```bash
# Check if Promtail is sending logs
curl 'http://localhost:4103/loki/api/v1/label/job/values' | jq

# Query for recent logs
curl 'http://localhost:4103/loki/api/v1/query_range?query={job="system-logs"}&limit=10' | jq

# Check Promtail logs
docker compose logs promtail | tail -50
```

### Dashboard Validation

1. Access Grafana: http://localhost:4101
2. Login with admin credentials
3. Navigate to Dashboards
4. Verify pre-configured dashboards are present
5. Check that dashboards show data

---

## Common Setup Issues

### Issue 1: Permission Denied on /var/log

**Symptoms**:
```
Error: permission denied: /var/log/auth.log
```

**Solutions**:

```bash
# Add user to adm group (Ubuntu/Debian)
sudo usermod -aG adm $USER

# Add user to systemd-journal group (RHEL/CentOS)
sudo usermod -aG systemd-journal $USER

# Logout and login again for group changes
newgrp adm

# Verify
groups $USER
```

**Alternative**: Use systemd journal instead of log files:

```yaml
# In promtail-config.yml
scrape_configs:
  - job_name: journal
    journal:
      max_age: 12h
      labels:
        job: systemd-journal
        host: hostname
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        target_label: 'unit'
```

### Issue 2: Port Already in Use

**Symptoms**:
```
Error: port is already allocated
```

**Solutions**:

```bash
# Check what's using the port
sudo netstat -tuln | grep 4101
sudo lsof -i :4101

# Change port in .env file
# GF_INSTALL_PLUGINS=...
# GRAFANA_PORT=4105

# Or stop conflicting service
sudo systemctl stop [service-name]
```

### Issue 3: Docker Container Won't Start

**Symptoms**:
```
Container exited with code 1
```

**Solutions**:

```bash
# Check logs
docker compose logs [service-name]

# Check disk space
df -h

# Check Docker daemon
sudo systemctl status docker

# Restart Docker
sudo systemctl restart docker

# Remove and recreate container
docker compose down
docker compose up -d
```

### Issue 4: Prometheus Not Scraping Targets

**Symptoms**:
- Targets show as DOWN in Prometheus UI
- No metrics appearing in Grafana

**Solutions**:

```bash
# Check Prometheus configuration
docker exec prometheus cat /etc/prometheus/prometheus.yml

# Check Prometheus logs
docker compose logs prometheus

# Test network connectivity
docker exec prometheus ping node-exporter

# Reload Prometheus
docker kill -s HUP prometheus

# Check file-based service discovery files
ls -la config/prometheus-file-sd/
```

### Issue 5: Logs Not Appearing in Grafana

**Symptoms**:
- No logs in Grafana Explore
- Promtail shows errors

**Solutions**:

```bash
# Check Promtail logs
docker compose logs promtail

# Verify log files exist
ls -la /var/log/auth.log /var/log/syslog

# Check permissions
ls -la /var/log/auth.log

# Test Loki connection
curl http://loki:3100/loki/api/v1/push

# Restart Promtail
docker compose restart promtail
```

### Issue 6: Out of Disk Space

**Symptoms**:
```
No space left on device
```

**Solutions**:

```bash
# Check disk usage
df -h
docker system df -v

# Clean up Docker
docker system prune -a

# Clean up old logs
# Configure retention in loki-config.yml
# Configure retention in prometheus.yml

# Resize disk (if possible)
```

### Issue 7: Environment Variables Not Loaded

**Symptoms**:
- Default passwords used
- Configuration not applied

**Solutions**:

```bash
# Check .env file exists
ls -la .env

# Verify .env is in same directory as docker-compose.yml
pwd
ls -la docker-compose.yml .env

# Manually export variables
export $(cat .env | xargs)

# Restart stack
docker compose down
docker compose up -d
```

---

## System-Specific Instructions

### Ubuntu/Debian

```bash
# Install dependencies
sudo apt-get update
sudo apt-get install -y docker.io docker-compose jq

# Add user to docker group
sudo usermod -aG docker $USER

# Enable Docker
sudo systemctl enable docker
sudo systemctl start docker

# Set up permissions
sudo usermod -aG adm $USER

# Reboot or logout/login
```

### CentOS/RHEL

```bash
# Install dependencies
sudo yum install -y docker docker-compose jq

# Add user to docker group
sudo usermod -aG docker $USER

# Enable Docker
sudo systemctl enable docker
sudo systemctl start docker

# Set up permissions
sudo usermod -aG systemd-journal $USER

# Reboot or logout/login
```

### Log File Locations

**Ubuntu/Debian**:
- Auth logs: `/var/log/auth.log`
- System logs: `/var/log/syslog`
- Messages: `/var/log/messages`

**CentOS/RHEL**:
- Auth logs: `/var/log/secure`
- System logs: `/var/log/messages`

**Adjust Promtail configuration accordingly**:

```yaml
# For CentOS/RHEL
__path__: /var/log/secure  # SSH logs
__path__: /var/log/messages  # System logs
```

---

## Backup and Restore

### Backup Strategy

```bash
# Create backup directory
mkdir -p backups

# Backup configuration
tar -czf backups/config-$(date +%Y%m%d).tar.gz config/

# Backup Grafana dashboards
docker exec grafana grafana-cli admin export-dashboard \
  --home-dashboard-json > backups/grafana-dashboards-$(date +%Y%m%d).json

# Backup MongoDB
docker exec mongodb mongodump \
  --archive=/data/backup/mongo-backup-$(date +%Y%m%d).gz \
  --gzip

# Copy MongoDB backup to host
docker cp mongodb:/data/backup/mongo-backup-$(date +%Y%m%d).gz backups/

# Backup Docker volumes (optional)
docker run --rm -v telemetry_data:/data -v $(pwd)/backups:/backup \
  ubuntu tar czf /backup/data-$(date +%Y%m%d).tar.gz /data
```

### Automated Backups

```bash
# Create backup script
cat > scripts/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d-%H%M%S)

mkdir -p $BACKUP_DIR

# Backup configuration
tar -czf $BACKUP_DIR/config-$DATE.tar.gz config/

# Backup Grafana dashboards
docker exec grafana grafana-cli admin export-dashboard \
  --home-dashboard-json > $BACKUP_DIR/grafana-dashboards-$DATE.json

# Backup MongoDB
docker exec mongodb mongodump \
  --archive=/data/backup/mongo-backup-$DATE.gz \
  --gzip
docker cp mongodb:/data/backup/mongo-backup-$DATE.gz $BACKUP_DIR/

echo "Backup completed: $BACKUP_DIR/mongo-backup-$DATE.gz"
EOF

chmod +x scripts/backup.sh

# Add to crontab for daily backups
# 0 2 * * * /path/to/telemetry/scripts/backup.sh
```

### Restore from Backup

```bash
# Restore configuration
tar -xzf backups/config-20260319.tar.gz

# Restore Grafana dashboards
docker cp backups/grafana-dashboards-20260319.json \
  grafana:/etc/grafana/provisioning/dashboards/

# Restore MongoDB
docker cp backups/mongo-backup-20260319.gz \
  mongodb:/tmp/backup.gz
docker exec mongodb mongorestore --archive=/tmp/backup.gz --gzip

# Restart services
docker compose restart grafana mongodb
```

### Disaster Recovery

```bash
# 1. Stop all services
docker compose down

# 2. Restore data from backup
# Follow restore procedures above

# 3. Verify configuration
./scripts/validate-environment.sh

# 4. Restart services
docker compose up -d

# 5. Verify data
# Check Grafana dashboards
# Verify metrics in Prometheus
# Check logs in Loki
```

---

## Next Steps

After successful installation:

1. **Change default passwords**
2. **Configure firewall rules**
3. **Set up reverse proxy** (for HTTPS)
4. **Add custom dashboards**
5. **Configure alerting**
6. **Set up automated backups**
7. **Review and tune retention policies**
8. **Add API monitoring** (see [API_MONITORING.md](API_MONITORING.md))

---

## Support

For additional help:

1. Review [Troubleshooting](#common-setup-issues)
2. Check container logs: `docker compose logs -f [service]`
3. Consult [ENV_REFERENCE.md](ENV_REFERENCE.md) for configuration options
4. Review [PERMISSIONS.md](PERMISSIONS.md) for permission issues

---

**Last Updated**: 2026-03-19
**Version**: 1.0.0
