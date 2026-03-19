# Prometheus File-Based Service Discovery

This directory contains JSON configuration files for Prometheus file-based service discovery. These files define which targets Prometheus should scrape for metrics.

## How It Works

Prometheus watches for changes in these JSON files and automatically updates its scrape targets when files are modified. No Prometheus restart is required!

## File Format

Each JSON file should contain an array of target objects with the following structure:

```json
[
  {
    "targets": [
      "host:port"
    ],
    "labels": {
      "key": "value"
    },
    "scrape_interval": "15s",
    "scrape_timeout": "10s",
    "metrics_path": "/metrics"
  }
]
```

## Existing Configurations

### 1. Node Exporter (`node-exporter.json`)
Monitors system-level metrics (CPU, memory, disk, network).

**Target:** `node-exporter:9100`
**Labels:** job, instance, environment, cluster, os_family, exporter_version

### 2. MongoDB Exporter (`mongodb-exporter.json`)
Monitors MongoDB database metrics.

**Target:** `mongodb-exporter:9214`
**Labels:** job, instance, environment, cluster, database, exporter_version, mongodb_host, mongodb_port

## Adding New API Monitoring

### Step 1: Create a new JSON file

Create a new file in this directory, e.g., `my-api.json`:

```json
[
  {
    "targets": [
      "api-service:8080",
      "api-service-backup:8080"
    ],
    "labels": {
      "job": "my-api",
      "instance": "${HOSTNAME:-localhost}",
      "environment": "${ENVIRONMENT:-production}",
      "cluster": "${CLUSTER_NAME:-telemetry}",
      "service": "my-api-service",
      "api_type": "rest",
      "team": "backend"
    },
    "scrape_interval": "15s",
    "scrape_timeout": "10s",
    "metrics_path": "/metrics"
  }
]
```

### Step 2: Reference the file in prometheus.yml

Add a new scrape configuration in `../prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'my-api'
    file_sd_configs:
      - files:
          - '${PROMETHEUS_CONFIG_DIR:-./config}/prometheus-file-sd/my-api.json'
        refresh_interval: 30s
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
```

### Step 3: Reload Prometheus

Prometheus will automatically detect the new file within 30 seconds (the `refresh_interval`), or you can manually trigger a reload:

```bash
# Send SIGHUP to Prometheus
kill -HUP $(pidof prometheus)

# Or use the API
curl -X POST http://prometheus:9090/-/reload
```

## API Monitoring Examples

### REST API with Custom Metrics Path

```json
[
  {
    "targets": ["rest-api:3000"],
    "labels": {
      "job": "rest-api",
      "service": "user-service",
      "api_type": "rest",
      "version": "v2"
    },
    "metrics_path": "/api/v2/metrics"
  }
]
```

### gRPC API with Prometheus Bridge

```json
[
  {
    "targets": ["grpc-api:9095"],
    "labels": {
      "job": "grpc-api",
      "service": "order-service",
      "api_type": "grpc",
      "protocol": "http"
    },
    "metrics_path": "/metrics"
  }
]
```

### Multi-Environment API

```json
[
  {
    "targets": ["api-prod:8080"],
    "labels": {
      "job": "api",
      "environment": "production",
      "tier": "frontend"
    }
  },
  {
    "targets": ["api-staging:8080"],
    "labels": {
      "job": "api",
      "environment": "staging",
      "tier": "frontend"
    }
  }
]
```

### Database API (PostgreSQL Exporter)

```json
[
  {
    "targets": ["postgres-exporter:9187"],
    "labels": {
      "job": "postgres-exporter",
      "instance": "${HOSTNAME:-localhost}",
      "database": "postgresql",
      "cluster": "${CLUSTER_NAME:-telemetry}",
      "db_host": "${POSTGRES_HOST:-postgres}",
      "db_port": "${POSTGRES_PORT:-5432}",
      "exporter_version": "0.15.0"
    }
  }
]
```

### Redis Exporter

```json
[
  {
    "targets": ["redis-exporter:9121"],
    "labels": {
      "job": "redis-exporter",
      "instance": "${HOSTNAME:-localhost}",
      "database": "redis",
      "cluster": "${CLUSTER_NAME:-telemetry}",
      "redis_host": "${REDIS_HOST:-redis}",
      "redis_port": "${REDIS_PORT:-6379}",
      "exporter_version": "1.55.0"
    }
  }
]
```

## Best Practices

### 1. Use Descriptive Labels
Include labels that help identify the service, environment, and team:

```json
"labels": {
  "job": "service-name",
  "service": "service-name",
  "team": "team-responsible",
  "environment": "production",
  "version": "1.2.3"
}
```

### 2. Group Related Services
Create separate files for different types of services:
- `apis.json` - All API endpoints
- `databases.json` - Database exporters
- `infrastructure.json` - Node exporter, cAdvisor

### 3. Use Variable Substitution
Use environment variables for dynamic values:
- `${HOSTNAME}` - Current hostname
- `${ENVIRONMENT}` - Deployment environment
- `${CLUSTER_NAME}` - Cluster identifier

### 4. Set Appropriate Intervals
- **High-frequency metrics:** 5s (for critical systems)
- **Standard metrics:** 15s (default)
- **Low-frequency metrics:** 60s (for stable systems)

```json
"scrape_interval": "15s",
"scrape_timeout": "10s"
```

### 5. Multiple Targets
You can specify multiple targets in a single file:

```json
"targets": [
  "api-1:8080",
  "api-2:8080",
  "api-3:8080"
]
```

## Troubleshooting

### Targets Not Appearing

1. **Check file permissions:**
   ```bash
   ls -la prometheus-file-sd/
   ```

2. **Validate JSON syntax:**
   ```bash
   cat prometheus-file-sd/my-api.json | jq
   ```

3. **Check Prometheus logs:**
   ```bash
   docker logs prometheus | grep "file_sd"
   ```

4. **Verify Prometheus configuration:**
   ```bash
   curl http://prometheus:9090/api/v1/targets
   ```

### Invalid JSON Format

Common mistakes:
- Missing commas between array elements
- Trailing commas (not allowed in JSON)
- Single quotes instead of double quotes
- Unescaped special characters

### High Resource Usage

If Prometheus is using too many resources:

1. Increase scrape intervals
2. Reduce the number of targets
3. Adjust retention policy in `prometheus.yml`

### Metrics Not Updating

1. Check if the target is actually exposing metrics:
   ```bash
   curl http://target:port/metrics
   ```

2. Verify network connectivity
3. Check firewall rules
4. Review scrape timeout settings

## Advanced Features

### Dynamic Labels with Relabeling

You can use relabel configs in `prometheus.yml` to transform labels:

```yaml
relabel_configs:
  # Extract service name from address
  - source_labels: [__address__]
    regex: '([^:]+):.*'
    target_label: service
    replacement: '$1'

  # Add custom label based on existing label
  - source_labels: [environment]
    regex: 'production'
    target_label: tier
    replacement: 'critical'
```

### Multiple Scrape Configs

You can reference the same file in multiple scrape configs with different parameters:

```yaml
scrape_configs:
  - job_name: 'api-fast'
    file_sd_configs:
      - files: ['prometheus-file-sd/apis.json']
    scrape_interval: 5s

  - job_name: 'api-standard'
    file_sd_configs:
      - files: ['prometheus-file-sd/apis.json']
    scrape_interval: 30s
```

## Maintenance

### Regular Review
- Review target files monthly
- Remove deprecated services
- Update labels for accuracy
- Optimize scrape intervals

### Backup
```bash
# Backup current configuration
tar -czf prometheus-sd-backup-$(date +%Y%m%d).tar.gz prometheus-file-sd/
```

### Testing Changes
1. Create a test file: `my-api-test.json`
2. Validate JSON syntax
3. Monitor Prometheus targets endpoint
4. Verify metrics are being scraped
5. Rename to production file name

## Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/operating/configuration/)
- [File-Based Service Discovery](https://prometheus.io/docs/guides/file-sd/)
- [Best Practices](https://prometheus.io/docs/practices/naming/)
- [Label Best Practices](https://prometheus.io/docs/practices/labels/)
