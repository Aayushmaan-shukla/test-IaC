# Monitoring & Observability Stack - Detailed Analysis

## Executive Summary

This document provides a comprehensive analysis for setting up a production-grade LGTM (Loki, Grafana, Tempo, Mimir) + MongoDB monitoring stack on a single Linux server using Docker Compose.

---

## 1. Architecture Overview

### 1.1 Components Breakdown

| Component | Purpose | Internal Port | External Port |
|-----------|---------|---------------|---------------|
| Grafana | Visualization & Dashboards | 3000 | 4101 |
| Prometheus | Metrics Collection & Storage | 9090 | 4102 |
| Loki | Log Aggregation & Storage | 3100 | 4103 |
| Promtail | Log Collection Agent | - | - |
| Node Exporter | System Metrics Exporter | 9100 | - |
| MongoDB | Database | 27017 | 27017 |
| MongoDB Exporter | MongoDB Metrics Exporter | 9214 | - |

### 1.2 Network Architecture

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

---

## 2. Detailed Task Breakdown

### Phase 1: Infrastructure Preparation

#### 2.1 Directory Structure Setup
**Tasks:**
- Create project root directory: `/opt/monitoring-stack`
- Create subdirectories:
  - `./config` - Store all configuration files
  - `./data` - Persistent data storage
    - `./data/grafana`
    - `./data/prometheus`
    - `./data/loki`
    - `./data/mongodb`
  - `./logs` - Symlink or mount point for host logs
  - `./scripts` - Custom scripts and utilities

**Potential Issues:**
- **Permission issues**: Non-root users may not have write access to `/opt/`
- **SELinux/AppArmor**: May block volume mounts and network access
- **Disk space**: Ensure sufficient space for logs and metrics (monitor growth)

#### 2.2 Network Configuration
**Tasks:**
- Create Docker bridge network `monitor-net`
- Configure DNS resolution within network
- Set up firewall rules for exposed ports

**Potential Issues:**
- **Port conflicts**: Ports 4101-4103 or 27017 may be in use
- **Firewall rules**: UFW/firewalld may block inter-container communication
- **DNS resolution**: Service names may not resolve if network not properly configured

---

### Phase 2: Component Configuration

#### 2.3 Prometheus Configuration
**Configuration File:** `config/prometheus.yml`

**Required Scrape Jobs:**
1. **Prometheus self-scrape**: `http://prometheus:9090/metrics`
2. **Node Exporter**: `http://node-exporter:9100/metrics`
3. **MongoDB Exporter**: `http://mongodb-exporter:9214/metrics`
4. **Grafana**: `http://grafana:3000/metrics` (optional)

**Key Considerations:**
- **Scrape intervals**: Balance between granularity and storage
- **Retention period**: Default 15d may need adjustment
- **Metric relabeling**: Drop unnecessary metrics to save space

**Potential Issues:**
- **Metric explosion**: Too many metrics can overwhelm Prometheus
- **Storage pressure**: High-frequency metrics consume disk rapidly
- **Service discovery**: Static targets in docker-compose may fail if container names change

#### 2.4 Loki Configuration
**Configuration File:** `config/loki-config.yml`

**Key Sections:**
- **Limits**: Max streams, rate limits
- **Schema**: Index and chunk configuration
- **Storage**: Local file system configuration
- **Ingester**: Replication factor, lifecycler

**Potential Issues:**
- **Index size**: Can grow uncontrollably with high cardinality labels
- **Query performance**: Degraded with millions of streams
- **Log retention**: Requires manual cleanup if not configured properly

#### 2.5 Promtail Configuration
**Configuration File:** `config/promtail-config.yml`

**Required Log Targets:**

**1. SSH Authentication Logs (auth.log)**
```yaml
- job_name: auth-logs
  static_configs:
    - targets:
        - localhost
      labels:
        job: ssh-auth
        __path__: /var/log/auth.log
        stream: ssh
```

**2. System Logs (syslog)**
```yaml
- job_name: syslog
  static_configs:
    - targets:
        - localhost
      labels:
        job: system-logs
        __path__: /var/log/syslog
        stream: syslog
```

**Pipeline Stages:**
- Extract SSH IP addresses
- Parse timestamps
- Extract usernames
- Extract command patterns

**Potential Issues:**
- **Log rotation**: Promtail may miss logs during rotation
- **Permission denied**: `/var/log/*` files often restricted to root
- **Journalctl vs files**: Modern systems use systemd journal, not syslog files
- **Log format variations**: Different distributions format logs differently
- **Circular dependencies**: Promtail needs to start after log files are mounted

#### 2.6 Grafana Configuration
**Environment Variables:**
```yaml
GF_SECURITY_ADMIN_USER: admin
GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD}
GF_USERS_ALLOW_SIGN_UP: false
GF_SERVER_ROOT_URL: http://localhost:4101
GF_INSTALL_PLUGINS: grafana-piechart-panel
```

**Provisioning:**
- **Datasources**: Auto-provision Prometheus and Loki
- **Dashboards**: Auto-import community dashboards

**Potential Issues:**
- **Password security**: Plain-text passwords in env files
- **Plugin compatibility**: Plugins may not be compatible with Grafana version
- **Dashboard drift**: Auto-imported dashboards may not match requirements

#### 2.7 MongoDB Configuration
**Environment Variables:**
```yaml
MONGO_INITDB_ROOT_USERNAME: admin
MONGO_INITDB_ROOT_PASSWORD: ${MONGO_PASSWORD}
MONGO_INITDB_ROOT_DATABASE: admin
```

**Replica Set Configuration:**
- May need replica set for backup purposes
- Oplog for change streams

**Potential Issues:**
- **Exporter authentication**: Exporter needs credentials to access metrics
- **Connection failures**: Network issues between MongoDB and exporter
- **Metric collection**: Exporter may overwhelm small MongoDB instances

---

### Phase 3: Real-time Shell History Logging

#### 2.8 Shell Integration
**Challenge:** Linux shell history is per-session and not logged in real-time to syslog

**Solutions to Evaluate:**

**Option 1: PAM Module Integration**
- Configure `pam_exec.so` to log commands
- Pros: System-wide, captures all sessions
- Cons: Requires root, complex to set up

**Option 2: Rsyslog Integration**
- Configure rsyslog to forward shell history
- Pros: Native syslog integration
- Cons: Requires shell configuration changes

**Option 3: Custom Wrapper Script**
- Wrap shell commands with logging function
- Pros: Simple, flexible
- Cons: Users can bypass, needs per-user setup

**Option 4: Auditd Integration**
- Use Linux audit subsystem
- Pros: Built-in, secure
- Cons: Verbose, requires parsing

**Recommended Implementation:**
```bash
# Add to /etc/bash.bashrc or /etc/profile.d/audit-commands.sh
log_command() {
    local cmd=$(history 1 | sed -e "s/^[ ]*[0-9]*[ ]*//")
    logger -t "bash-audit" "User: $USER, PID: $$, Command: $cmd"
}

trap 'log_command' DEBUG
```

**Potential Issues:**
- **Performance impact**: Every command triggers logging
- **Noise**: Background processes generate many events
- **Bypass methods**: Users can disable traps
- **Multiple shells**: Different shells (zsh, fish) need different configs

---

### Phase 4: Security Considerations

#### 2.9 Authentication & Access Control
**Issues:**
- Default credentials in configuration files
- Unencrypted communication between containers
- No TLS/SSL for external access
- Password rotation not automated

**Mitigations:**
- Use Docker secrets for sensitive data
- Enable HTTPS reverse proxy (nginx/traefik)
- Implement OAuth/SSO for Grafana
- Regular password rotation policies

#### 2.10 Data Protection
**Issues:**
- Logs may contain sensitive information
- Commands may expose credentials
- SSH IPs could be privacy concerns
- No data-at-rest encryption

**Mitigations:**
- Implement log redaction in Promtail
- Exclude sensitive patterns from logs
- Encrypt data volumes
- Implement retention policies

---

### Phase 5: Operational Readiness

#### 2.11 Monitoring the Monitoring Stack
**Self-Monitoring:**
- Container health checks
- Disk space alerts
- Service availability
- Log pipeline health

**Alerting:**
- Configure Alertmanager
- Set up notification channels (email, Slack)
- Create alert rules for critical metrics

#### 2.12 Backup & Disaster Recovery
**Backup Strategy:**
- Daily snapshots of data volumes
- Export Grafana dashboards and datasources
- Backup configuration files
- Document restore procedures

**Potential Issues:**
- **Backup window**: Large datasets may take hours
- **Storage costs**: Backups multiply storage needs
- **Restore testing**: Often overlooked until needed
- **Version compatibility**: Restoring to different versions may fail

#### 2.13 Resource Planning
**Resource Requirements:**

| Component | CPU | RAM | Disk | Growth |
|-----------|-----|-----|------|--------|
| Grafana | 1 core | 512 MB | 1 GB | Low |
| Prometheus | 2 cores | 2 GB | 50 GB/15d | High |
| Loki | 1 core | 1 GB | 20 GB/7d | Medium |
| Promtail | 0.5 cores | 256 MB | N/A | N/A |
| MongoDB | 2 cores | 2 GB | Depends on app | Medium |
| Exporters | 0.5 cores each | 256 MB each | N/A | N/A |
| **Total** | ~7 cores | ~6 GB | ~70 GB | Variable |

**Potential Issues:**
- **Resource contention**: Monitoring stack consumes resources it's supposed to monitor
- **Oversubscription**: Limited server resources may cause instability
- **Disk I/O**: High write rates from logs/metrics

---

## 3. Pre-Implementation Checklist

### 3.1 System Prerequisites
- [ ] Docker Engine 20.10+ installed
- [ ] Docker Compose v2.x installed
- [ ] Minimum 8 CPU cores available
- [ ] Minimum 8 GB RAM available
- [ ] Minimum 100 GB free disk space
- [ ] Root or sudo access

### 3.2 Network Requirements
- [ ] Ports 4101, 4102, 4103, 27017 available
- [ ] Firewall rules configured
- [ ] DNS resolution working
- [ ] Internet access (for base images, plugins)

### 3.3 Security Requirements
- [ ] Secrets management plan established
- [ ] SSL/TLS certificates obtained (if needed)
- [ ] Access control policy defined
- [ ] Data retention policy defined
- [ ] Compliance requirements identified

### 3.4 Backup Requirements
- [ ] Backup schedule defined
- [ ] Backup storage location secured
- [ ] Restore procedures documented
- [ ] Backup verification process established

---

## 4. Known Challenges & Workarounds

### 4.1 Log Collection Issues

**Challenge**: System logs on modern Linux distributions use systemd journal, not syslog files

**Workaround**:
1. Configure Promtail to read from journal
2. OR configure rsyslog to write to files
3. OR use journald export to files

**Impact**: Additional configuration complexity

### 4.2 Real-time Command Logging

**Challenge**: Native shell history is not real-time and per-session

**Workaround**:
1. Implement DEBUG trap in shell startup
2. OR use auditd for comprehensive auditing
3. OR implement PAM modules

**Impact**: Performance overhead, user experience impact

### 4.3 Container Permissions

**Challenge**: Containers need access to `/var/log` which is root-owned

**Workaround**:
1. Add containers to `adm` or `systemd-journal` group
2. OR create log forwarding with proper permissions
3. OR use elevated privileges (not recommended)

**Impact**: Security considerations

### 4.4 Service Discovery

**Challenge**: Static service names in docker-compose may fail if containers renamed

**Workaround**:
1. Use Docker DNS with service names
2. OR implement Docker labels and auto-discovery
3. OR use Docker API for service discovery

**Impact**: Configuration complexity

### 4.5 Data Volume Persistence

**Challenge**: Volume permissions reset on container recreation

**Workaround**:
1. Create volumes with correct UID/GID
2. OR use named volumes with proper configuration
3. OR run containers as specific users

**Impact**: Operational overhead

---

## 5. Testing Strategy

### 5.1 Component-Level Testing
- [ ] Verify each container starts successfully
- [ ] Test inter-container communication
- [ ] Verify data persistence after restart
- [ ] Test health checks and restart policies

### 5.2 Integration Testing
- [ ] Verify Prometheus scrapes all exporters
- [ ] Verify Promtail sends logs to Loki
- [ ] Verify Grafana connects to both datasources
- [ ] Test end-to-end metrics flow
- [ ] Test end-to-end logs flow

### 5.3 Scenario Testing
- [ ] Simulate high CPU and verify metrics
- [ ] Generate test SSH sessions and verify logs
- [ ] Execute test commands and verify audit trail
- [ ] Fill disk and verify alerts
- [ ] Kill containers and verify restart

### 5.4 Security Testing
- [ ] Verify default credentials changed
- [ ] Test unauthorized access attempts
- [ ] Verify log redaction works
- [ ] Test data at rest encryption (if implemented)

### 5.5 Performance Testing
- [ ] Test under normal load
- [ ] Test under high load
- [ ] Monitor resource consumption
- [ ] Measure query latency
- [ ] Test data ingestion rate

---

## 6. Implementation Roadmap

### Week 1: Infrastructure Setup
- **Day 1-2**: Directory structure, network configuration, prerequisites
- **Day 3-4**: Docker Compose skeleton, base container definitions
- **Day 5**: Initial deployment testing, health checks

### Week 2: Core Components
- **Day 1-2**: Prometheus configuration, scrape targets
- **Day 3-4**: Loki and Promtail configuration, log pipelines
- **Day 5**: Grafana setup, datasource provisioning

### Week 3: Advanced Features
- **Day 1-2**: MongoDB and exporter integration
- **Day 3-4**: Shell history logging implementation
- **Day 5**: Security hardening

### Week 4: Operations
- **Day 1-2**: Dashboard creation, alerting setup
- **Day 3-4**: Backup implementation, documentation
- **Day 5**: Full stack testing, handover

---

## 7. Maintenance & Operations

### 7.1 Daily Tasks
- Check disk space usage
- Review system health dashboards
- Verify data ingestion

### 7.2 Weekly Tasks
- Review alert notifications
- Check log retention policies
- Backup verification

### 7.3 Monthly Tasks
- Update container images
- Review and rotate credentials
- Performance tuning
- Capacity planning

### 7.4 Quarterly Tasks
- Disaster recovery testing
- Security audit
- Architecture review
- Cost optimization

---

## 8. Success Criteria

### 8.1 Functional Requirements
- [ ] All containers start and communicate properly
- [ ] System metrics collected with < 5% latency
- [ ] Logs ingested with < 10s delay
- [ ] Dashboards display accurate data
- [ ] SSH IP tracking works in real-time
- [ ] Shell commands logged immediately

### 8.2 Non-Functional Requirements
- [ ] System uptime > 99%
- [ ] Query response time < 2s
- [ ] Data retention policy enforced
- [ ] Backup RTO < 1 hour
- [ ] RPO < 15 minutes
- [ ] Security compliance met

### 8.3 Operational Requirements
- [ ] Alert coverage for all critical components
- [ ] Documentation complete and accurate
- [ ] Team trained on operations
- [ ] Monitoring stack self-monitored

---

## 9. Recommendations & Best Practices

### 9.1 Immediate Recommendations
1. **Start small**: Deploy basic stack first, add features incrementally
2. **Use official images**: Avoid custom builds unless necessary
3. **Version pinning**: Specify exact image versions in compose file
4. **Environment separation**: Use separate configs for dev/stage/prod
5. **Secrets management**: Never commit credentials to version control

### 9.2 Long-term Recommendations
1. **External log aggregation**: Consider ELK or Splunk for production
2. **Distributed tracing**: Add Jaeger or Tempo for microservices
3. **Automated scaling**: Consider Kubernetes for large deployments
4. **SLI/SLO framework**: Define service level objectives
5. **Chaos engineering**: Test resilience proactively

### 9.3 Security Recommendations
1. **Principle of least privilege**: Run containers with minimal permissions
2. **Network segmentation**: Isolate monitoring network
3. **Regular audits**: Review access logs weekly
4. **Vulnerability scanning**: Scan images regularly
5. **Compliance alignment**: Follow SOC2, PCI-DSS, etc. if applicable

---

## 10. Appendices

### Appendix A: Technology Versions
- Docker: 24.0+
- Docker Compose: 2.20+
- Grafana: 10.x
- Prometheus: 2.48+
- Loki: 2.9+
- Promtail: 2.9+
- MongoDB: 7.0+
- MongoDB Exporter: 0.40+

### Appendix B: Reference Documentation
- Grafana: https://grafana.com/docs/
- Prometheus: https://prometheus.io/docs/
- Loki: https://grafana.com/docs/loki/latest/
- MongoDB: https://docs.mongodb.com/

### Appendix C: Common Commands
```bash
# View container logs
docker-compose logs -f [service]

# Restart services
docker-compose restart [service]

# Execute in container
docker-compose exec [service] /bin/bash

# Check volume usage
docker system df -v

# Monitor resource usage
docker stats
```

---

**Document Version**: 2.0
**Last Updated**: 2026-03-19
**Author**: DevOps Engineering Team
**Status**: Analysis Complete - Critical Requirements Review

---

## 11. CRITICAL REQUIREMENTS ANALYSIS - UPDATED

### 11.1 Case 1: Multi-User Deployment (/root vs /home/user)

**REQUIREMENT**: Stack must deploy correctly in both `/root/` and `/home/user/` contexts

**CRITICAL ANALYSIS:**

**Real Problems You Face:**

1. **Directory Structure Collision**
   - `/opt/monitoring-stack` hardcoded - will fail for non-root users
   - User cannot write to `/opt/` without sudo
   - Dynamic path resolution required for config/data directories

2. **Permission Management Nightmare**
   - Root user: No permission issues but security risk
   - Non-root user: Cannot access `/var/log` without sudo
   - Docker volumes created with wrong ownership
   - Container processes may not have write permissions to mounted volumes

3. **System Log Access**
   - Promtail needs access to `/var/log/auth.log`, `/var/log/syslog`
   - Only root or members of `adm`/`systemd-journal` groups can read
   - Non-root deployment requires sudo for permission setup
   - Running docker-compose as sudo breaks user permissions

4. **UID/GID Mismatch**
   - Containers run as non-root (best practice) but with random UIDs
   - Host-mounted files owned by root:root
   - Permission denied errors in containers
   - Need to sync container UID with host user UID

**ARCHITECTURAL DECISION NEEDED:**

**Option A: Root Deployment Only**
- Simplest approach
- No permission issues
- Security risk - everything runs as root
- Violates principle of least privilege

**Option B: User Deployment with Sudo Helper**
- Stack runs as normal user
- Setup script handles permissions with sudo
- Need sudo access for initial setup only
- More secure, more complex

**Option C: Dynamic Context Detection**
- Script detects deployment context (root vs user)
- Adjusts paths and permissions automatically
- Most flexible, most complex
- Two completely different deployment paths

**RECOMMENDED APPROACH:**
- Detect user context at runtime
- Use `$HOME` for non-root, `/opt` for root
- Separate permission setup script (your Case 4)
- Document sudo requirements clearly

---

### 11.2 Case 2: Modular API Health Metrics

**REQUIREMENT**: Add future API health metrics by editing single config file

**CRITICAL ANALYSIS:**

**Real Problems You Face:**

1. **Prometheus Scrape Configuration Bottleneck**
   - Every new API = new job in prometheus.yml
   - Static config means restart Prometheus for every change
   - No dynamic service discovery
   - Config validation errors break entire scraping

2. **Exporter vs Direct Metrics**
   - APIs need exporters or /metrics endpoints
   - Different APIs have different metric formats
   - Authentication varies per API
   - Rate limiting/throttling not configured

3. **Configuration Management**
   - Single config file = single point of failure
   - Merge conflicts in team scenarios
   - No version control per API configuration
   - Difficult to rollback single API changes

4. **Naming and Discovery**
   - API URLs change
   - Load balancing complicates static IPs
   - Container orchestration (k8s) requires different approach
   - Service names not consistent across environments

**ARCHITECTURAL DECISION NEEDED:**

**Option A: Single prometheus.yml with File-Based Service Discovery**
- Prometheus watches directory for changes
- Drop JSON/YAML files for each API
- Automatic reloading
- Cleaner separation

**Option B: Docker Compose File with Environment Variable**
- Add API exporters as services
- Use `--scale` for multiple instances
- Restart entire stack for changes
- Simpler but less flexible

**Option C: Custom Script that Generates prometheus.yml**
- Separate config file for API definitions
- Script generates final prometheus.yml
- More control, more moving parts
- Can add validation

**Option D: Prometheus Operator (Kubernetes)**
- CRDs for API monitoring
- Too complex for single server
- Overkill for your use case

**RECOMMENDED APPROACH:**
- `api-monitoring.yml` - single file for API definitions
- Prometheus uses file-based service discovery
- No restart needed for API additions
- Each API defined as separate file in directory
- `scrape_configs` section generated dynamically

**Structure:**
```
config/
  ├── prometheus.yml (base config)
  ├── prometheus-file-sd/
  │   ├── node-exporter.json
  │   ├── mongodb-exporter.json
  │   ├── api-auth.json  (new APIs added here)
  │   ├── api-user.json
  └── api-monitoring-config.yml (your single config file)
```

---

### 11.3 Case 3: Dynamic Docker Configuration via Env Variables

**REQUIREMENT**: No hardcoded values in docker-compose, use env variables

**CRITICAL ANALYSIS:**

**Real Problems You Face:**

1. **Docker Compose Environment Variable Limitations**
   - Environment variables only supported in certain fields
   - Cannot use env variables in service names
   - Cannot use env variables in volume paths (sometimes)
   - Network names cannot be dynamic
   - Command arrays don't support env substitution in all versions

2. **Configuration Validation**
   - No validation until runtime
   - Missing env variables = silent failures
   - Wrong value types cause cryptic errors
   - Debugging is painful

3. **Secret Management vs Configuration**
   - Not everything should be env variable (passwords)
   - Config vs secret distinction blurs
   - .env files in git = security risk
   - No encryption

4. **Default Values**
   - Docker Compose doesn't support default values
   - Need bash scripts or external tools
   - More complex setup
   - Harder to understand for new users

5. **Backward Compatibility**
   - Changing env variable names breaks existing deployments
   - Need migration strategy
   - Documentation drift

**ARCHITECTURAL DECISION NEEDED:**

**Option A: Pure Docker Compose with .env Files**
- Use `${VARIABLE_NAME:-default}` syntax
- .env.example for documentation
- Simple, but limited validation
- No secrets management

**Option B: Docker Compose + Bash Pre-Processing**
- Script reads config files
- Generates docker-compose.yml on the fly
- Full control over defaults
- More complex, more powerful

**Option C: Docker Compose + External Config Management**
- Use consul, etcd, etc.
- Overkill for single server
- Adds dependencies

**Option D: Hybrid Approach**
- Static structure in docker-compose
- Dynamic values via .env
- Separate .env.secrets for passwords
- Balance of simplicity and flexibility

**RECOMMENDED APPROACH:**
- `.env` file with all configurable values
- `.env.example` with documentation and defaults
- `.env.secrets` (git-ignored) for sensitive data
- Config validation script before docker-compose up
- Separate file for API monitoring config (Case 2)

**Critical Fields That Can't Be Dynamic:**
- Service names (prometheus, grafana, loki)
- Volume names (monitor-net)
- Network names
- Container restart policies

---

### 11.4 Case 4: Permission Setup Script

**REQUIREMENT**: Bash script to provide necessary permissions

**CRITICAL ANALYSIS:**

**Real Problems You Face:**

1. **Security Nightmare**
   - Script runs with sudo = attack surface
   - If script is compromised, entire system is compromised
   - Need to validate every command
   - No undo capability

2. **Permission Granularity**
   - Too many permissions = security risk
   - Too few permissions = deployment fails
   - Finding balance is hard
   - Different distros (Ubuntu, CentOS, Debian) have different requirements

3. **Idempotency**
   - Script must be runnable multiple times
   - Must handle existing permissions
   - Must not break existing setup
   - Must detect what's already done

4. **Rollback**
   - How to undo permission changes?
   - Script needs `--undo` flag
   - Difficult to track original permissions
   - System may be in inconsistent state

5. **Environment Detection**
   - Detect systemd vs syslog
   - Detect user vs root deployment
   - Detect existing Docker setup
   - Detect SELinux/AppArmor status

**ARCHITECTURAL DECISION NEEDED:**

**Option A: All-in-One Script**
- Does everything: permissions, setup, validation
- Easy to run
- Hard to debug
- Security risk

**Option B: Modular Scripts**
- `setup-permissions.sh` - just permissions
- `validate-environment.sh` - checks
- `deploy.sh` - actual deployment
- Separation of concerns
- Better security

**Option C: Ansible/Chef/etc.**
- Declarative approach
- Idempotent by design
- Overkill for this use case
- Additional dependency

**Option D: Docker Compose Hooks**
- Use container init scripts
- Less invasive
- Limited capabilities
- Cannot modify host system

**RECOMMENDED APPROACH:**
```
scripts/
  ├── setup-permissions.sh        # Your Case 4
  ├── validate-environment.sh    # Pre-flight checks
  ├── setup-env.sh                # Generate .env files
  ├── deploy.sh                   # Main deployment script
  └── rollback-permissions.sh     # Undo changes
```

**What setup-permissions.sh MUST do:**
1. Detect user context (root vs non-root)
2. Create directory structure with correct ownership
3. Grant log access: add user to adm/systemd-journal groups
4. Set correct permissions on Docker volumes
5. Validate permissions before proceeding
6. Log all changes for rollback

**What setup-permissions.sh MUST NOT do:**
1. Run docker-compose
2. Modify system-wide config files (/etc/*)
3. Install system packages
4. Modify Docker daemon configuration

---

### 11.5 INTEGRATED ARCHITECTURE ANALYSIS

**Your Requirements Together Create These Conflicts:**

1. **Case 1 + Case 4 Conflict**
   - Root deployment needs minimal permission setup
   - User deployment needs extensive permission setup
   - Single permission script must handle both
   - Increases complexity significantly

2. **Case 2 + Case 3 Conflict**
   - Modular API monitoring needs file-based service discovery
   - Environment variable approach limits dynamic config
   - Must reconcile static service names with dynamic API endpoints
   - Prometheus config generation becomes complex

3. **All Cases Combined = Explosion of Complexity**
   - Dynamic paths + modular APIs + env variables + permissions
   - Validation becomes nightmare
   - Documentation requirements huge
   - Testing matrix massive

---

### 12. REVISED ARCHITECTURE PROPOSAL

**New Directory Structure:**

```
telemetry/
├── .env.example                    # Template for environment variables
├── .env                            # Actual configuration (git-ignored)
├── .env.secrets                    # Sensitive data (git-ignored)
├── docker-compose.yml              # Dynamic via env variables
├── config/
│   ├── prometheus.yml              # Base Prometheus config
│   ├── prometheus-file-sd/         # File-based service discovery
│   │   ├── node-exporter.json
│   │   ├── mongodb-exporter.json
│   │   └── README.md               # How to add new APIs (Case 2)
│   ├── api-monitoring.yml          # Single file for API configs (Case 2)
│   ├── loki-config.yml
│   ├── promtail-config.yml
│   └── grafana-provisioning/
│       ├── datasources.yml
│       └── dashboards.yml
├── scripts/
│   ├── setup-permissions.sh        # Your Case 4
│   ├── validate-environment.sh    # Pre-flight checks
│   ├── setup-env.sh                # Generate .env from example
│   ├── deploy.sh                   # Main deployment orchestration
│   ├── rollback-permissions.sh     # Undo permission changes
│   └── add-api-monitoring.sh       # Helper for Case 2
├── data/                           # Auto-created, correct permissions
├── logs/                           # Log symlinks
└── README.md                       # Updated documentation
```

**Deployment Flow:**

```
1. User clones repo to /root/telemetry or /home/user/telemetry
2. User runs: ./scripts/setup-permissions.sh
   - Detects context
   - Creates directories
   - Sets permissions
   - Validates access to /var/log
3. User runs: ./scripts/setup-env.sh
   - Copies .env.example to .env
   - Prompts for secrets
   - Validates values
4. User runs: ./scripts/deploy.sh
   - Validates environment
   - Starts stack
   - Runs health checks
5. To add API: ./scripts/add-api-monitoring.sh
   - Prompts for API details
   - Creates config file
   - Reloads Prometheus
```

---

### 13. CRITICAL RISKS & MITIGATIONS

**Risk 1: Permission Script Compromise**
- **Issue**: Running setup-permissions.sh with sudo is dangerous
- **Mitigation**: Hash script contents, validate before execution
- **Mitigation**: Run in containerized environment if possible
- **Mitigation**: Separate sudo operations from non-sudo operations

**Risk 2: Environment Variable Hell**
- **Issue**: 20+ env variables, all required, no validation
- **Mitigation**: setup-env.sh validates each variable
- **Mitigation**: .env.example documents each variable with examples
- **Mitigation**: Type checking in validate-environment.sh

**Risk 3: Dynamic Path Failures**
- **Issue**: Paths resolve differently in different contexts
- **Mitigation**: Always use absolute paths
- **Mitigation**: Script validates path resolution
- **Mitigation**: Document absolute path requirements

**Risk 4: API Monitoring Complexity**
- **Issue**: Adding APIs requires understanding Prometheus file SD
- **Mitigation**: add-api-monitoring.sh helper script
- **Mitigation**: Detailed README in prometheus-file-sd/
- **Mitigation**: Template files for common API types

**Risk 5: Container Permission Drift**
- **Issue**: Containers create files with wrong permissions
- **Mitigation**: Run containers with explicit UID/GID
- **Mitigation**: Post-start permission fix script
- **Mitigation**: Monitor permission issues in logs

---

### 14. PRE-IMPLEMENTATION VALIDATION CHECKLIST

**Before ANY Code is Written:**

**Design Questions:**
- [ ] Are you okay with requiring sudo for setup?
- [ ] Do you want root deployment or user deployment as primary target?
- [ ] How many APIs do you expect to monitor in 6 months?
- [ ] What's your risk tolerance for security vs complexity?
- [ ] Who will maintain this stack? DevOps? SRE? Developer?

**Technical Decisions:**
- [ ] Prometheus file-based service discovery OR dynamic config?
- [ ] Single permission script OR modular scripts?
- [ ] .env validation via shell script OR external tool?
- [ ] How to handle secrets? Env file? Vault? Docker secrets?

**Documentation Requirements:**
- [ ] Quick start guide for root deployment
- [ ] Quick start guide for non-root deployment
- [ ] Troubleshooting guide
- [ ] API monitoring guide
- [ ] Permission troubleshooting guide

---

### 15. REFINED IMPLEMENTATION SEQUENCE

**Phase 1: Core Infrastructure (Week 1)**
1. Define directory structure
2. Create setup-permissions.sh with validation
3. Create validate-environment.sh
4. Create setup-env.sh
5. Test on both root and user contexts

**Phase 2: Base Stack (Week 2)**
1. Create docker-compose.yml with env variables
2. Create .env.example with all values
3. Configure Prometheus with file SD structure
4. Configure Loki and Promtail
5. Configure Grafana provisioning
6. Test dynamic path resolution

**Phase 3: Monitoring Features (Week 3)**
1. Configure node-exporter
2. Configure mongodb-exporter
3. Create API monitoring structure
4. Create add-api-monitoring.sh helper
5. Test modular API addition
6. Validate log collection

**Phase 4: Operations (Week 4)**
1. Create deploy.sh orchestration script
2. Create rollback-permissions.sh
3. Add health checks
4. Create backup/restore procedures
5. Write comprehensive documentation
6. Security audit

---

### 16. SUCCESS CRITERIA - UPDATED

**Functional Requirements:**
- [ ] Deploy works in `/root/telemetry` and `/home/user/telemetry`
- [ ] No hardcoded values in docker-compose.yml (except service names)
- [ ] New API added by editing single config file OR running helper script
- [ ] Permission script runs idempotently
- [ ] Permission script validates all changes
- [ ] Permission script can be rolled back
- [ ] Environment validation prevents invalid deployments
- [ ] All configuration is documented in .env.example

**Non-Functional Requirements:**
- [ ] Deployment time < 5 minutes on first run
- [ ] Deployment time < 1 minute on subsequent runs
- [ ] Permission setup < 30 seconds
- [ ] API addition < 2 minutes
- [ ] Zero manual configuration after initial setup
- [ ] Works offline after first image pull

**Security Requirements:**
- [ ] No passwords in git
- [ ] No hardcoded credentials
- [ ] Permission script validates input
- [ ] Permission script logs all changes
- [ ] Audit trail of permission changes
- [ ] Root user can run without sudo
- [ ] Non-root user needs sudo only for setup

---

## 17. DOCUMENTATION REQUIREMENTS

**Required Documentation:**

1. **README.md** - Main entry point
   - Quick start (root)
   - Quick start (non-root)
   - Architecture overview
   - Troubleshooting

2. **SETUP.md** - Detailed setup guide
   - Prerequisites
   - Permission requirements
   - Environment configuration
   - Common issues

3. **API_MONITORING.md** - How to add APIs
   - File-based service discovery
   - Config file format
   - Helper script usage
   - Examples

4. **PERMISSIONS.md** - Permission script guide
   - What the script does
   - Security considerations
   - Rollback procedures
   - Troubleshooting

5. **ENV_REFERENCE.md** - Environment variable reference
   - All variables documented
   - Required vs optional
   - Default values
   - Security notes

---

## 18. CONCLUSION

**Your Requirements Are Valid But Complex**

The combination of:
- Multi-user deployment
- Modular API monitoring
- Dynamic configuration
- Permission management

Creates a system that is:
- More complex than a basic LGTM stack
- More secure than hardcoded configs
- More flexible than static configs
- More maintainable than monolithic configs

**Critical Success Factors:**

1. **Accept complexity**: This will be more complex than basic tutorial
2. **Invest in scripts**: The bash scripts are the backbone of usability
3. **Document everything**: Future you will thank present you
4. **Test early, test often**: Test both root and user contexts
5. **Iterate**: Start with basic functionality, add complexity

**Recommended Next Steps:**

1. **Decision Matrix**: Explicitly choose options for each architectural decision
2. **Prototype**: Build minimal viable version of each case
3. **Integration**: Combine into single coherent system
4. **Testing**: Test in both root and user contexts
5. **Documentation**: Write docs as you build

**No Sugarcoating:**

This will be harder than a basic docker-compose up. You're building a production-grade, multi-context, modular monitoring system. It will take 3-4 weeks of solid work. There will be permission issues. There will be path resolution issues. There will be env variable conflicts. The scripts will need debugging. The documentation will need updating.

But if done correctly, you'll have a monitoring stack that:
- Deploys anywhere
- Scales to many APIs
- Uses industry best practices
- Is maintainable by others
- Is secure by design

**Are you ready for this level of complexity?**
