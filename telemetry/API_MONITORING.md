# API Monitoring Guide

Complete guide for adding and configuring API monitoring in the monitoring stack using file-based service discovery.

## Table of Contents

- [Overview](#overview)
- [File-Based Service Discovery](#file-based-service-discovery)
- [Quick Start](#quick-start)
- [Configuration Format](#configuration-format)
- [Authentication Methods](#authentication-methods)
- [Examples](#examples)
- [Helper Script Usage](#helper-script-usage)
- [Testing and Validation](#testing-and-validation)
- [Advanced Configuration](#advanced-configuration)
- [Troubleshooting](#troubleshooting)

---

## Overview

API monitoring allows you to track the health and performance of external APIs and services. This monitoring stack uses Prometheus file-based service discovery to dynamically discover and monitor APIs without requiring Prometheus restarts.

### Key Features

- **Dynamic Configuration**: Add/remove APIs without restarting Prometheus
- **Multiple Instances**: Support for load-balanced or replicated APIs
- **Authentication**: Support for Basic Auth, Bearer Token, and custom headers
- **Flexible Labeling**: Add custom labels for organization and filtering
- **Git-Friendly**: Configuration files can be version controlled

### How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                    Monitoring Flow                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  API Endpoint (api.example.com:8080)                         │
│        │                                                      │
│        │ Prompts for Metrics (/metrics)                      │
│        ▼                                                      │
│  ┌──────────────┐                                            │
│  │  Prometheus  │◄─────────────────────────────────────────  │
│  │  :9090       │    File-Based Service Discovery            │
│  └──────────────┘         (config/prometheus-file-sd/)       │
│        │                                                      │
│        │ Scrapes Metrics                                     │
│        ▼                                                      │
│  ┌──────────────┐                                            │
│  │   Grafana    │     Visualizes API Metrics                 │
│  │   :4101      │     (Response Time, Error Rate, Uptime)    │
│  └──────────────┘                                            │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## File-Based Service Discovery

### What Is File-Based Service Discovery?

File-based service discovery allows Prometheus to automatically discover new targets by watching a directory for JSON files. When a new file is added, Prometheus automatically starts scraping the new target.

### Directory Structure

```
telemetry/
├── config/
│   ├── prometheus.yml                    # Base Prometheus config
│   ├── prometheus-file-sd/               # Service discovery directory
│   │   ├── node-exporter.json           # Static exporter targets
│   │   ├── mongodb-exporter.json        # Database exporter targets
│   │   ├── api-user-service.json        # User API monitoring
│   │   ├── api-payment-gateway.json     # Payment API monitoring
│   │   └── api-auth-service.json        # Auth API monitoring
│   └── api-monitoring.yml               # Configuration reference
```

### Prometheus Configuration

In `config/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'file-sd'
    file_sd_configs:
      - files:
          - '/etc/prometheus/file-sd/*.json'
        refresh_interval: 30s
```

**How it works**:
- Prometheus watches `/etc/prometheus/file-sd/*.json` every 30 seconds
- New files are automatically discovered and added to scrape targets
- Removed files stop being scraped
- No restart required

---

## Quick Start

### Method 1: Using Helper Script (Recommended)

```bash
# Run the helper script
./scripts/add-api-monitoring.sh

# Follow the prompts:
# 1. Enter API name (e.g., user-api)
# 2. Enter API target (e.g., api.example.com:8080)
# 3. Enter metrics path (default: /metrics)
# 4. Enter environment (e.g., production)
# 5. Choose authentication type
# 6. Add optional labels
# 7. Reload Prometheus (optional)

# View examples
./scripts/add-api-monitoring.sh --examples
```

### Method 2: Manual Configuration

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

# Verify JSON is valid
cat config/prometheus-file-sd/api-my-api.json | jq

# Reload Prometheus (optional)
docker kill -s HUP prometheus

# Check Prometheus targets
curl http://localhost:4102/api/v1/targets | jq
```

---

## Configuration Format

### Required Fields

```json
{
  "targets": ["api.example.com:8080"],
  "labels": {
    "job": "my-api-name"
  }
}
```

### Optional Fields

```json
{
  "targets": ["api.example.com:8080"],
  "labels": {
    "job": "my-api-name",
    "metrics_path": "/metrics",
    "env": "production",
    "team": "platform",
    "service": "user-service",
    "region": "us-east-1",
    "tier": "backend"
  }
}
```

### Field Descriptions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `targets` | Array | Yes | Array of host:port strings |
| `labels` | Object | Yes | Labels for the targets |
| `labels.job` | String | Yes | Name for the monitoring job |
| `labels.metrics_path` | String | No | Path to metrics endpoint (default: /metrics) |
| `labels.env` | String | No | Environment (production, staging, dev) |
| `labels.team` | String | No | Team responsible |
| `labels.service` | String | No | Service name |
| `labels.region` | String | No | Geographic region |
| `labels.tier` | String | No | Application tier |

---

## Authentication Methods

### No Authentication (Default)

Use for internal APIs or APIs that expose metrics publicly.

```json
{
  "targets": ["api.example.com:8080"],
  "labels": {
    "job": "public-api",
    "metrics_path": "/metrics",
    "env": "production"
  }
}
```

### Basic Authentication

Use when API requires username/password.

**Configuration**:

```json
{
  "targets": ["api.example.com:8080"],
  "labels": {
    "job": "api-with-auth",
    "metrics_path": "/metrics",
    "env": "production",
    "auth_type": "basic",
    "auth_username": "prometheus",
    "auth_password": "your-secure-password"
  }
}
```

**Prometheus Configuration**:

In `config/prometheus.yml`, add basic auth to the scrape config:

```yaml
scrape_configs:
  - job_name: 'file-sd'
    file_sd_configs:
      - files:
          - '/etc/prometheus/file-sd/*.json'
        refresh_interval: 30s

    # Add basic auth for APIs that require it
    basic_auth:
      username: '${FILE_SD_AUTH_USERNAME}'
      password: '${FILE_SD_AUTH_PASSWORD}'
```

**Note**: Configure Prometheus to use different auth credentials per API using relabeling.

### Bearer Token Authentication

Use when API requires token-based auth.

**Configuration**:

```json
{
  "targets": ["api.example.com:8080"],
  "labels": {
    "job": "api-with-token",
    "metrics_path": "/metrics",
    "env": "production",
    "auth_type": "bearer",
    "auth_token": "your-long-bearer-token-here"
  }
}
```

**Prometheus Configuration**:

```yaml
scrape_configs:
  - job_name: 'file-sd'
    file_sd_configs:
      - files:
          - '/etc/prometheus/file-sd/*.json'
        refresh_interval: 30s

    # Add bearer token support
    authorization:
      type: Bearer
      credentials: '${FILE_SD_AUTH_TOKEN}'
```

### TLS/HTTPS Configuration

For APIs using HTTPS, Prometheus handles TLS automatically.

```json
{
  "targets": ["api.example.com:443"],
  "labels": {
    "job": "https-api",
    "metrics_path": "/metrics",
    "scheme": "https",
    "env": "production"
  }
}
```

**For custom CA certificates**:

```yaml
scrape_configs:
  - job_name: 'file-sd'
    file_sd_configs:
      - files:
          - '/etc/prometheus/file-sd/*.json'
        refresh_interval: 30s

    tls_config:
      ca_file: /etc/prometheus/custom-ca.pem
      cert_file: /etc/prometheus/client-cert.pem
      key_file: /etc/prometheus/client-key.pem
```

---

## Examples

### Example 1: Simple REST API

```json
{
  "targets": ["api.example.com:8080"],
  "labels": {
    "job": "user-api",
    "metrics_path": "/metrics",
    "env": "production"
  }
}
```

### Example 2: Load-Balanced API

Multiple instances of the same API:

```json
{
  "targets": [
    "api1.example.com:8080",
    "api2.example.com:8080",
    "api3.example.com:8080"
  ],
  "labels": {
    "job": "load-balanced-api",
    "metrics_path": "/metrics",
    "env": "production",
    "service": "user-service"
  }
}
```

### Example 3: Spring Boot Actuator

Spring Boot apps expose metrics at `/actuator/prometheus`:

```json
{
  "targets": ["spring-app.example.com:8080"],
  "labels": {
    "job": "spring-boot-app",
    "metrics_path": "/actuator/prometheus",
    "env": "production",
    "framework": "spring-boot"
  }
}
```

### Example 4: Django Application

Django apps with django-prometheus:

```json
{
  "targets": ["django-app.example.com:8080"],
  "labels": {
    "job": "django-app",
    "metrics_path": "/metrics",
    "env": "production",
    "framework": "django",
    "language": "python",
    "auth_type": "basic",
    "auth_username": "prometheus",
    "auth_password": "django-password"
  }
}
```

### Example 5: Node.js Application

Node.js apps with prom-client:

```json
{
  "targets": ["nodejs-app.example.com:8080"],
  "labels": {
    "job": "nodejs-app",
    "metrics_path": "/metrics",
    "env": "production",
    "framework": "express",
    "language": "nodejs"
  }
}
```

### Example 6: Internal Docker Service

Monitoring services within Docker network:

```json
{
  "targets": ["api-service:8080"],
  "labels": {
    "job": "internal-api",
    "metrics_path": "/metrics",
    "env": "production",
    "network": "monitor-net"
  }
}
```

### Example 7: API with Custom Port

```json
{
  "targets": ["api.example.com:9000"],
  "labels": {
    "job": "api-port-9000",
    "metrics_path": "/api/v1/metrics",
    "env": "production"
  }
}
```

### Example 8: Multiple Environments

Separate configurations for different environments:

```json
{
  "targets": ["api-staging.example.com:8080"],
  "labels": {
    "job": "user-api",
    "metrics_path": "/metrics",
    "env": "staging"
  }
}
```

```json
{
  "targets": ["api-production.example.com:8080"],
  "labels": {
    "job": "user-api",
    "metrics_path": "/metrics",
    "env": "production"
  }
}
```

---

## Helper Script Usage

### Running the Script

```bash
./scripts/add-api-monitoring.sh
```

### Script Flow

1. **Prompts for API name**: Used for job name and filename
2. **Prompts for API target(s)**: host:port format
3. **Prompts for metrics path**: Default is `/metrics`
4. **Prompts for environment**: production, staging, etc.
5. **Prompts for authentication type**: None, Basic, Bearer
6. **Collects auth credentials**: If authentication selected
7. **Prompts for optional labels**: team, service, region
8. **Creates JSON file**: In `config/prometheus-file-sd/`
9. **Validates JSON**: Ensures proper format
10. **Prompts for reload**: Reloads Prometheus optionally

### Example Session

```bash
$ ./scripts/add-api-monitoring.sh

============================================
Add API Monitoring to Prometheus
============================================

This script will help you add a new API for monitoring

Enter API name (e.g., user-api, payment-api): user-service

Enter API target(s) (comma-separated for multiple instances):
Target(s): api.example.com:8080

Enter metrics path [default: /metrics]: /metrics

Enter environment label (e.g., production, staging, development): production

Select authentication type:
1) None (default)
2) Basic Authentication
3) Bearer Token
Enter choice [1-3]: 1

Optional labels (press Enter to skip):
Team (e.g., backend, platform): backend
Service (e.g., user-service, payment-service): user-service
Region (e.g., us-east-1, eu-west-1): us-east-1

Creating JSON configuration...
✓ JSON is valid
✓ Configuration file created: config/prometheus-file-sd/api-user-service.json

Configuration created:
{
  "targets": ["api.example.com:8080"],
  "labels": {
    "job": "user-service",
    "metrics_path": "/metrics",
    "env": "production",
    "team": "backend",
    "service": "user-service",
    "region": "us-east-1"
  }
}

Next steps:
1. The API will be monitored automatically (Prometheus uses file-based service discovery)
2. You can view the API in Prometheus UI: http://localhost:4102/targets
3. Create a dashboard in Grafana to visualize the metrics

Reload Prometheus now? (y/N): y
Attempting to reload Prometheus...
✓ Prometheus reloaded successfully

✓ API monitoring configuration completed!
```

### Viewing Examples

```bash
./scripts/add-api-monitoring.sh --examples
```

---

## Testing and Validation

### Test Metrics Endpoint

Before adding API, verify metrics endpoint works:

```bash
# Test HTTP
curl http://api.example.com:8080/metrics

# Test HTTPS with basic auth
curl -u username:password https://api.example.com:8080/metrics

# Test with bearer token
curl -H "Authorization: Bearer token" https://api.example.com:8080/metrics

# Check response time
time curl http://api.example.com:8080/metrics
```

### Verify in Prometheus

```bash
# Check all targets
curl http://localhost:4102/api/v1/targets | jq

# Check specific API target
curl 'http://localhost:4102/api/v1/targets?scrapePool=file-sd' | jq

# Check target is UP
curl 'http://localhost:4102/api/v1/query?query=up{job="user-service"}' | jq

# Query specific metric
curl 'http://localhost:4102/api/v1/query?query=up' | jq
```

### View in Prometheus UI

1. Access Prometheus: http://localhost:4102
2. Navigate to Status → Targets
3. Find your API in the list
4. Verify status is "UP"
5. Check last scrape time

### Create Grafana Dashboard

1. Access Grafana: http://localhost:4101
2. Create new dashboard
3. Add panels for:
   - Response time: `http_request_duration_seconds`
   - Error rate: `rate(http_requests_total{status=~"5.."}[5m])`
   - Request rate: `rate(http_requests_total[5m])`
   - Uptime: `up{job="user-service"}`

---

## Advanced Configuration

### Custom Scrape Interval

Override default scrape interval per API:

```json
{
  "targets": ["api.example.com:8080"],
  "labels": {
    "job": "user-api",
    "metrics_path": "/metrics",
    "env": "production",
    "scrape_interval": "30s",
    "scrape_timeout": "10s"
  }
}
```

**Prometheus Configuration**:

```yaml
scrape_configs:
  - job_name: 'file-sd'
    file_sd_configs:
      - files:
          - '/etc/prometheus/file-sd/*.json'
        refresh_interval: 30s

    # Use custom scrape interval from labels
    scrape_interval: 30s
    scrape_timeout: 10s

    relabel_configs:
      - source_labels: [__address__, __meta_sd_labels_scrape_interval]
        regex: '([^:]+):(\d+);(.+)'
        target_label: __param_scrape_interval
        replacement: '${3}'
```

### Metric Relabeling

Drop or modify metrics before storage:

```yaml
scrape_configs:
  - job_name: 'file-sd'
    file_sd_configs:
      - files:
          - '/etc/prometheus/file-sd/*.json'
        refresh_interval: 30s

    metric_relabel_configs:
      # Drop debug metrics
      - source_labels: [__name__]
        regex: 'debug_.*'
        action: drop

      # Rename metrics
      - source_labels: [__name__]
        regex: 'old_metric_name'
        replacement: 'new_metric_name'
        action: replace
```

### Custom Labels for Filtering

Add custom labels for better organization:

```json
{
  "targets": ["api.example.com:8080"],
  "labels": {
    "job": "user-api",
    "metrics_path": "/metrics",
    "env": "production",
    "team": "platform",
    "service": "user-service",
    "region": "us-east-1",
    "tier": "backend",
    "version": "v2.3.1",
    "datacenter": "dc1"
  }
}
```

### Multiple Metric Paths

Some APIs expose metrics at different paths:

```json
{
  "targets": ["api.example.com:8080"],
  "labels": {
    "job": "api-metrics-1",
    "metrics_path": "/metrics/app",
    "env": "production"
  }
}
```

```json
{
  "targets": ["api.example.com:8080"],
  "labels": {
    "job": "api-metrics-2",
    "metrics_path": "/metrics/db",
    "env": "production"
  }
}
```

---

## Troubleshooting

### Problem: API Not Showing in Prometheus Targets

**Symptoms**: API doesn't appear in Prometheus UI

**Solutions**:

```bash
# 1. Check file exists
ls -la config/prometheus-file-sd/

# 2. Verify JSON is valid
cat config/prometheus-file-sd/api-my-api.json | jq

# 3. Check Prometheus logs
docker compose logs prometheus | grep file-sd

# 4. Verify Prometheus is watching the directory
docker exec prometheus cat /etc/prometheus/prometheus.yml | grep file-sd

# 5. Wait for refresh interval (default: 30s)
# Or manually reload
docker kill -s HUP prometheus
```

### Problem: Target Shows as DOWN

**Symptoms**: API appears but status is DOWN

**Solutions**:

```bash
# 1. Test metrics endpoint from host
curl http://api.example.com:8080/metrics

# 2. Test from Prometheus container
docker exec prometheus wget -O- http://api.example.com:8080/metrics

# 3. Check network connectivity
docker exec prometheus ping api.example.com

# 4. Check firewall rules
sudo iptables -L -n | grep 8080

# 5. Verify authentication
curl -u user:pass http://api.example.com:8080/metrics
```

### Problem: Scrape Errors

**Symptoms**: Prometheus shows scrape errors

**Solutions**:

```bash
# 1. Check Prometheus logs for detailed errors
docker compose logs prometheus | tail -100

# 2. Verify API is responding correctly
curl -v http://api.example.com:8080/metrics

# 3. Check for rate limiting
# Add appropriate delays or rate limiting handling

# 4. Verify metrics format
# Ensure API returns Prometheus-compatible metrics
```

### Problem: High Scrape Latency

**Symptoms**: API takes too long to respond

**Solutions**:

```bash
# 1. Increase scrape timeout in configuration
"scrape_timeout": "30s"

# 2. Increase scrape interval
"scrape_interval": "60s"

# 3. Check API performance
# Optimize metrics endpoint on the API side

# 4. Reduce number of metrics
# Drop unnecessary metrics
```

### Problem: Authentication Fails

**Symptoms**: 401 Unauthorized errors

**Solutions**:

```bash
# 1. Test credentials manually
curl -u username:password http://api.example.com:8080/metrics

# 2. Check Prometheus configuration
docker exec prometheus cat /etc/prometheus/prometheus.yml | grep basic_auth

# 3. Verify token format
curl -H "Authorization: Bearer token" http://api.example.com:8080/metrics

# 4. Check for token expiration
# Update tokens regularly
```

### Problem: Metrics Not Appearing in Grafana

**Symptoms**: No data in Grafana dashboards

**Solutions**:

```bash
# 1. Verify Prometheus has metrics
curl 'http://localhost:4102/api/v1/query?query=up' | jq

# 2. Check Grafana datasource configuration
# Navigate to Configuration > Data Sources > Prometheus
# Test connection

# 3. Verify query syntax
# Test queries in Prometheus UI first

# 4. Check time range
# Ensure you're looking at the right time period
```

---

## Best Practices

### Naming Conventions

- Use descriptive job names: `user-service-api`, `payment-gateway`
- Avoid generic names: `api1`, `api2`
- Use kebab-case: `user-service` not `user_service`

### File Organization

- Group related APIs: `api-user.json`, `api-order.json`
- Use consistent naming: `api-[service].json`
- Separate environments: `api-production.json`, `api-staging.json`

### Label Strategy

- Always include `env` label
- Use `team` for ownership
- Use `service` for microservices
- Use `region` for multi-region setups

### Security

- Store secrets securely (use Docker secrets)
- Never commit passwords to git
- Rotate credentials regularly
- Use HTTPS for external APIs

### Performance

- Set appropriate scrape intervals (15s-60s)
- Reduce number of metrics exported
- Use metric relabeling to drop unnecessary metrics
- Monitor scrape latency

### Monitoring

- Monitor scrape errors
- Alert on high error rates
- Track scrape latency
- Monitor target uptime

---

## Additional Resources

- [Prometheus File-Based Service Discovery](https://prometheus.io/docs/guides/file-sd/)
- [Prometheus Scrape Configuration](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#scrape_config)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [Grafana Dashboard Creation](https://grafana.com/docs/grafana/latest/dashboards/)
- [Prometheus Exposition Format](https://prometheus.io/docs/instrumenting/exposition_formats/)

---

**Last Updated**: 2026-03-19
**Version**: 1.0.0
