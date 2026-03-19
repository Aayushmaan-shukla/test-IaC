# Monitoring Stack - LGTM + MongoDB

A production-grade monitoring and observability stack using Docker Compose, featuring Grafana, Prometheus, Loki, Promtail, and MongoDB with comprehensive logging and metrics collection.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Accessing Services](#accessing-services)
- [Configuration](#configuration)
- [Adding API Monitoring](#adding-api-monitoring)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)

---

## Overview

This monitoring stack provides:

- **Metrics Collection**: System metrics, application metrics, and database metrics via Prometheus
- **Log Aggregation**: Centralized logging with Loki and Promtail
- **Visualization**: Pre-configured Grafana dashboards for system health and monitoring
- **User Auditing**: Real-time tracking of SSH IP addresses and command execution
- **Database Monitoring**: MongoDB metrics with dedicated exporter
- **API Health Monitoring**: Modular API monitoring with file-based service discovery

### Components

| Component | Purpose | External Port |
|-----------|---------|---------------|
| Grafana | Visualization & Dashboards | 4101 |
| Prometheus | Metrics Collection & Storage | 4102 |
| Loki | Log Aggregation & Storage | 4103 |
| Promtail | Log Collection Agent | - |
| Node Exporter | System Metrics Exporter | - |
| MongoDB | Database | 27017 |
| MongoDB Exporter | MongoDB Metrics Exporter | - |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    monitor-net (Bridge Network)              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │   Grafana    │◄──►│  Prometheus  │◄──►│     Loki     │  │
│  │   :3000      │    │    :9090     │    │    :3100     │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│         ▲                                        ▲          │
│         │                                        │          │
│         └────────────────────────────────────────┘          │
│                          ▲                                  │
│                          │                                  │
│         ┌────────────────┴────────────────┐                 │
│         │                                 │                 │
│  ┌──────────────┐               ┌──────────────┐           │
│  │  Promtail    │               │Node Exporter │           │
│  │  (Host Logs) │               │  :9100       │           │
│  └──────────────┘               └──────────────┘           │
│                                                             │
│  ┌──────────────┐    ┌──────────────┐                     │
│  │   MongoDB    │◄──►│ Mongo Exp.   │                     │
│  │   :27017     │    │    :9214     │                     │
│  └──────────────┘    └──────────────┘                     │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Metrics Flow**
   - Node Exporter → Prometheus → Grafana
   - MongoDB Exporter → Prometheus → Grafana
   - API Services → Prometheus → Grafana

2. **Logs Flow**
   - System Logs → Promtail → Loki → Grafana
   - SSH Authentication Logs → Promtail → Loki → Grafana
   - Shell Commands → Promtail → Loki → Grafana

---

## Quick Start

### Option 1: Root Deployment

For users with root access:

```bash
# Clone or extract the monitoring stack
cd /root/telemetry

# Run permission setup script
sudo ./scripts/setup-permissions.sh

# Set up environment variables
./scripts/setup-env.sh

# Deploy the stack
./scripts/deploy.sh

# Access Grafana
# URL: http://localhost:4101
# Default credentials: admin / <your-password>
```

### Option 2: Non-Root Deployment

For non-root users:

```bash
# Clone or extract to home directory
cd /home/your-user/telemetry

# Run permission setup script (requires sudo)
sudo ./scripts/setup-permissions.sh

# Set up environment variables
./scripts/setup-env.sh

# Deploy the stack
./scripts/deploy.sh

# Access Grafana
# URL: http://localhost:4101
# Default credentials: admin / <your-password>
```

### Quick Verification

```bash
# Check all containers are running
docker-compose ps

# View logs
docker-compose logs -f

# Check Prometheus targets
curl http://localhost:4102/api/v1/targets

# Check Loki health
curl http://localhost:4103/ready
```

---

## Prerequisites

### System Requirements

- **OS**: Linux (Ubuntu 20.04+, Debian 11+, CentOS 8+, RHEL 8+)
- **CPU**: Minimum 8 cores (recommended)
- **RAM**: Minimum 8 GB (recommended)
- **Disk**: Minimum 100 GB free space

### Software Requirements

- **Docker Engine**: Version 20.10 or higher
- **Docker Compose**: Version 2.20 or higher
- **jq**: For JSON parsing (optional, recommended)

### Network Requirements

- Ports 4101, 4102, 4103, 27017 must be available
- Firewall rules configured for external access
- Internet access for initial image pull

### Permission Requirements

- Root access OR sudo privileges for setup
- Ability to add user to `adm` or `systemd-journal` groups
- Write access to deployment directory

---

## Installation

### Step 1: Clone or Extract Repository

```bash
# From root
cd /root/telemetry

# OR from home directory
cd /home/your-user/telemetry
```

### Step 2: Run Permission Setup

```bash
# This script sets up required permissions
sudo ./scripts/setup-permissions.sh

# The script will:
# - Detect deployment context (root vs user)
# - Create directory structure
# - Grant log access permissions
# - Set correct ownership
# - Validate permissions
```

### Step 3: Configure Environment Variables

```bash
# Generate .env file from template
./scripts/setup-env.sh

# This will prompt for:
# - Grafana admin password
# - MongoDB root password
# - Other optional configuration
```

### Step 4: Deploy the Stack

```bash
# Deploy all services
./scripts/deploy.sh

# Or manually using docker-compose
docker-compose up -d

# Check status
docker-compose ps
```

### Step 5: Verify Deployment

```bash
# Check container health
docker-compose ps

# View Grafana
open http://localhost:4101

# Check Prometheus targets
open http://localhost:4102/targets
```

---

## Accessing Services

### Grafana

- **URL**: http://localhost:4101
- **Credentials**: admin / `<GRAFANA_PASSWORD>`
- **Features**:
  - Pre-configured dashboards
  - Metrics visualization
  - Log querying
  - Alert management

### Prometheus

- **URL**: http://localhost:4102
- **Features**:
  - Metrics browser
  - Target monitoring
  - Alert rules
  - Query interface

### Loki

- **URL**: http://localhost:4103
- **Features**:
  - Log aggregation
  - Log querying API
  - Stream management

### MongoDB

- **URL**: mongodb://localhost:27017
- **Credentials**:
  - Username: admin
  - Password: `<MONGO_PASSWORD>`

### API Endpoints

- **Prometheus API**: http://localhost:4102/api/v1
- **Loki API**: http://localhost:4103/loki/api/v1

---

## Configuration

### Environment Variables

All configuration is done via environment variables in `.env` file:

```bash
# View current configuration
cat .env

# Edit configuration
nano .env

# After changes, restart stack
docker-compose restart
```

### Key Configuration Files

- **docker-compose.yml**: Service definitions
- **config/prometheus.yml**: Prometheus configuration
- **config/loki-config.yml**: Loki configuration
- **config/promtail-config.yml**: Promtail configuration
- **config/grafana-provisioning/**: Grafana provisioning

For detailed configuration options, see:
- [Environment Variable Reference](ENV_REFERENCE.md)
- [Setup Guide](SETUP.md)

---

## Adding API Monitoring

### Quick Method: Using Helper Script

```bash
# Run the helper script
./scripts/add-api-monitoring.sh

# Follow prompts:
# - Enter API name (e.g., user-api)
# - Enter API target (e.g., api.example.com:8080)
# - Choose authentication type
# - Add optional labels

# Prometheus automatically picks up the new API
```

### Manual Method: Create JSON File

```bash
# Create configuration file
cat > config/prometheus-file-sd/api-my-api.json << EOF
{
  "targets": ["api.example.com:8080"],
  "labels": {
    "job": "my-api",
    "metrics_path": "/metrics",
    "env": "production"
  }
}
EOF

# Reload Prometheus
docker kill -s HUP prometheus
```

### With Authentication

```bash
# Basic authentication
{
  "targets": ["api.example.com:8080"],
  "labels": {
    "job": "my-api",
    "metrics_path": "/metrics",
    "auth_type": "basic",
    "auth_username": "prometheus",
    "auth_password": "secret"
  }
}

# Bearer token
{
  "targets": ["api.example.com:8080"],
  "labels": {
    "job": "my-api",
    "metrics_path": "/metrics",
    "auth_type": "bearer",
    "auth_token": "your-token-here"
  }
}
```

### Multiple Instances

```bash
{
  "targets": [
    "api1.example.com:8080",
    "api2.example.com:8080",
    "api3.example.com:8080"
  ],
  "labels": {
    "job": "load-balanced-api",
    "metrics_path": "/metrics",
    "env": "production"
  }
}
```

For detailed API monitoring guide, see [API_MONITORING.md](API_MONITORING.md)

---

## Troubleshooting

### Common Issues

#### 1. Permission Denied Errors

**Problem**: Cannot access /var/log files
```bash
# Solution: Run permission setup script
sudo ./scripts/setup-permissions.sh

# Verify permissions
groups $USER
```

#### 2. Containers Not Starting

**Problem**: Docker containers fail to start
```bash
# Check logs
docker-compose logs [service-name]

# Check disk space
df -h

# Check Docker daemon
docker info
```

#### 3. Prometheus Not Scraping Targets

**Problem**: Targets show as DOWN in Prometheus
```bash
# Check network connectivity
docker exec prometheus ping node-exporter

# Check Prometheus configuration
docker exec prometheus cat /etc/prometheus/prometheus.yml

# Check Prometheus logs
docker-compose logs prometheus
```

#### 4. Grafana Not Connecting to Data Sources

**Problem**: Dashboards show no data
```bash
# Check Grafana logs
docker-compose logs grafana

# Verify datasources in Grafana UI
# Configuration > Data Sources

# Test Prometheus connection
curl http://prometheus:9090/api/v1/query?query=up
```

#### 5. Logs Not Appearing in Loki

**Problem**: No logs in Grafana Explore
```bash
# Check Promtail logs
docker-compose logs promtail

# Verify log files exist
ls -la /var/log/auth.log /var/log/syslog

# Test Loki API
curl http://localhost:4103/loki/api/v1/label/job/values
```

#### 6. High Disk Usage

**Problem**: Monitoring stack consuming too much disk space
```bash
# Check volume usage
docker system df -v

# Clean up old data
# Configure retention in config files
# See ENV_REFERENCE.md for retention settings
```

### Debug Commands

```bash
# View all container logs
docker-compose logs -f

# Check container health
docker-compose ps

# Execute into container
docker-compose exec grafana bash

# Check network connectivity
docker network inspect telemetry_monitor-net

# Check disk usage
docker system df

# View resource usage
docker stats
```

### Getting Help

1. Check logs: `docker-compose logs -f [service]`
2. Review configuration files in `config/`
3. Consult detailed documentation:
   - [Setup Guide](SETUP.md)
   - [Permission Guide](PERMISSIONS.md)
   - [API Monitoring Guide](API_MONITORING.md)
   - [Environment Variable Reference](ENV_REFERENCE.md)

---

## Security Considerations

### Default Credentials

**CRITICAL**: Change default passwords immediately after deployment:

```bash
# Edit .env file
nano .env

# Update passwords
GRAFANA_PASSWORD=your-secure-password
MONGO_PASSWORD=your-secure-password

# Restart stack
docker-compose restart grafana mongodb
```

### Access Control

1. **Firewall Configuration**
   ```bash
   # Only expose necessary ports
   ufw allow 4101/tcp  # Grafana
   ufw allow 4102/tcp  # Prometheus (optional)
   ufw allow 4103/tcp  # Loki (optional)
   ufw allow 27017/tcp # MongoDB (restrict access)
   ```

2. **Reverse Proxy**
   - Use nginx or traefik for HTTPS
   - Enable SSL/TLS certificates
   - Implement authentication

3. **Grafana Security**
   - Disable sign-up: `GF_USERS_ALLOW_SIGN_UP=false`
   - Use strong admin password
   - Configure role-based access control

4. **Prometheus Security**
   - Don't expose Prometheus externally unless needed
   - Use network policies
   - Implement authentication for API access

5. **Log Security**
   - Redact sensitive information in Promtail
   - Implement log retention policies
   - Monitor for sensitive data leaks

### Secrets Management

**WARNING**: Never commit `.env` or `.env.secrets` to version control:

```bash
# .gitignore
.env
.env.secrets
data/
logs/
```

### Regular Maintenance

```bash
# Update container images
docker-compose pull
docker-compose up -d

# Rotate passwords
# Review access logs
# Check for vulnerabilities
docker scan [image-name]
```

---

## System Requirements

### Minimum Requirements

- **CPU**: 8 cores
- **RAM**: 8 GB
- **Disk**: 100 GB

### Recommended Requirements

- **CPU**: 12+ cores
- **RAM**: 16+ GB
- **Disk**: 200+ GB SSD

### Component Resource Usage

| Component | CPU | RAM | Disk Growth |
|-----------|-----|-----|-------------|
| Grafana | 1 core | 512 MB | Low |
| Prometheus | 2 cores | 2 GB | High (metrics) |
| Loki | 1 core | 1 GB | Medium (logs) |
| Promtail | 0.5 cores | 256 MB | N/A |
| MongoDB | 2 cores | 2 GB | Depends on data |
| Exporters | 0.5 cores each | 256 MB each | N/A |

---

## Maintenance

### Daily Tasks

- Check disk space: `df -h`
- Review system health dashboards
- Verify data ingestion

### Weekly Tasks

- Review alert notifications
- Check log retention
- Backup verification

### Monthly Tasks

- Update container images
- Review and rotate credentials
- Performance tuning
- Capacity planning

### Backup Strategy

```bash
# Backup configurations
tar -czf config-backup-$(date +%Y%m%d).tar.gz config/

# Backup Grafana dashboards
docker exec grafana grafana-cli admin export-dashboard

# Backup MongoDB
docker exec mongodb mongodump --archive=/data/backup/mongo-backup-$(date +%Y%m%d).gz

# Restore from backup
# See detailed backup procedures in SETUP.md
```

---

## Documentation

For detailed information on specific topics:

- [Setup Guide](SETUP.md) - Detailed installation and configuration
- [API Monitoring Guide](API_MONITORING.md) - How to add and configure API monitoring
- [Permission Guide](PERMISSIONS.md) - Permission setup and troubleshooting
- [Environment Variable Reference](ENV_REFERENCE.md) - Complete configuration reference

---

## Architecture Decisions

### Why LGTM Stack?

- **Loki**: Lightweight log aggregation, efficient for cloud-native
- **Grafana**: Unified visualization for metrics and logs
- **Tempo**: Distributed tracing (available for future expansion)
- **Mimir**: Scalable metrics backend (available for future expansion)

### Why File-Based Service Discovery?

- Dynamic configuration without restarts
- Easy to add/remove APIs
- Git-friendly configuration
- Simple troubleshooting

### Why Docker Compose?

- Simple deployment
- Easy to understand
- Good for single-server deployment
- Portable across environments

---

## Contributing

When modifying this stack:

1. Update documentation accordingly
2. Test in both root and non-root contexts
3. Validate configuration changes
4. Update version history

---

## License

This monitoring stack is provided as-is for internal use.

---

## Support

For issues and questions:

1. Check troubleshooting section above
2. Review detailed documentation
3. Check logs: `docker-compose logs -f [service]`
4. Verify configuration in config files

---

**Last Updated**: 2026-03-19
**Version**: 1.0.0
