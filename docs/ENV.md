# Variables d'Environnement

## Vue d'ensemble

Ce document décrit les variables d'environnement utilisées dans le projet YourMedia, leur objectif et leur configuration.

## Infrastructure AWS

### 1. Terraform

#### `terraform.tfvars`
```hcl
# AWS Configuration
aws_region = "eu-west-3"
aws_profile = "default"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"
public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]

# EC2 Configuration
instance_type = "t3.micro"
ami_id = "ami-0c55b159cbfafe1f0"
key_name = "yourmedia-key"

# RDS Configuration
db_instance_type = "db.t3.micro"
db_name = "yourmedia"
db_username = "admin"
db_password = "changeme"
```

### 2. GitHub Actions

#### `.github/workflows/1-infra-deploy-destroy.yml`
```yaml
env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  AWS_REGION: eu-west-3
  TF_VAR_db_password: ${{ secrets.DB_PASSWORD }}
```

## Applications

### 1. Java Spring Boot

#### `application.properties`
```properties
# Server Configuration
server.port=8080
server.servlet.context-path=/api

# Database Configuration
spring.datasource.url=jdbc:mysql://${DB_HOST}:3306/${DB_NAME}
spring.datasource.username=${DB_USERNAME}
spring.datasource.password=${DB_PASSWORD}
spring.jpa.hibernate.ddl-auto=update
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.MySQL8Dialect

# JWT Configuration
jwt.secret=${JWT_SECRET}
jwt.expiration=86400000

# Logging Configuration
logging.level.root=INFO
logging.level.com.yourmedia=DEBUG
logging.file.name=/var/log/tomcat/yourmedia.log
```

### 2. React

#### `.env`
```env
# API Configuration
REACT_APP_API_URL=http://localhost:8080/api
REACT_APP_API_TIMEOUT=30000

# Authentication
REACT_APP_AUTH_ENABLED=true
REACT_APP_AUTH_TOKEN_KEY=auth_token

# Feature Flags
REACT_APP_FEATURE_NEW_UI=true
REACT_APP_FEATURE_ANALYTICS=true
```

## Monitoring

### 1. Prometheus

#### `prometheus.yml`
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'java'
    static_configs:
      - targets: ['localhost:8080']
```

### 2. Grafana

#### `grafana.ini`
```ini
[server]
http_port = 3000
domain = localhost
root_url = http://localhost:3000/

[security]
admin_user = admin
admin_password = ${GRAFANA_ADMIN_PASSWORD}
secret_key = ${GRAFANA_SECRET_KEY}

[auth.anonymous]
enabled = true
org_name = Main Org.
org_role = Viewer
```

## Docker

### 1. Compose

#### `docker-compose.yml`
```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"
    environment:
      - PROMETHEUS_STORAGE_PATH=/prometheus

  grafana:
    image: grafana/grafana:latest
    volumes:
      - ./grafana.ini:/etc/grafana/grafana.ini
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
      - GF_SECURITY_SECRET_KEY=${GRAFANA_SECRET_KEY}

  loki:
    image: grafana/loki:latest
    volumes:
      - ./loki-config.yml:/etc/loki/local-config.yaml
    ports:
      - "3100:3100"
    environment:
      - LOKI_STORAGE_PATH=/loki
```

### 2. Environment Files

#### `.env.docker`
```env
# Prometheus
PROMETHEUS_STORAGE_PATH=/prometheus
PROMETHEUS_RETENTION_TIME=15d

# Grafana
GRAFANA_ADMIN_PASSWORD=changeme
GRAFANA_SECRET_KEY=your-secret-key

# Loki
LOKI_STORAGE_PATH=/loki
```

## Services Systemd

### 1. Docker Cleanup Service

#### `/etc/systemd/system/docker-cleanup.service`
```ini
[Unit]
Description=Docker Cleanup Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/docker-cleanup.sh
User=root

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=multi-user.target
```

### 2. Log Synchronization Service

#### `/etc/systemd/system/sync-tomcat-logs.service`
```ini
[Unit]
Description=Tomcat Logs Synchronization Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/sync-tomcat-logs.sh
User=root
Restart=always

[Install]
WantedBy=multi-user.target
```

## Scripts

### 1. Shell Scripts

#### `scripts/ec2-monitoring/setup-monitoring.sh`
```bash
# Monitoring Configuration
MONITORING_DIR="/opt/monitoring"
PROMETHEUS_VERSION="2.45.0"
GRAFANA_VERSION="10.0.0"
LOKI_VERSION="2.8.0"

# Database Configuration
DB_HOST="localhost"
DB_NAME="monitoring"
DB_USERNAME="monitoring"
DB_PASSWORD="changeme"

# Security Configuration
GRAFANA_ADMIN_PASSWORD="changeme"
GRAFANA_SECRET_KEY="your-secret-key"
```

### 2. Python Scripts

#### `scripts/utils/check-system.py`
```python
# System Configuration
LOG_DIR = "/var/log"
CHECK_INTERVAL = 300  # seconds
ALERT_THRESHOLD = 80  # percent

# Email Configuration
SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 587
SMTP_USERNAME = "your-email@gmail.com"
SMTP_PASSWORD = "your-app-password"

# Notification Configuration
ALERT_EMAILS = ["admin@yourmedia.com"]
SLACK_WEBHOOK = "https://hooks.slack.com/services/xxx/yyy/zzz"
```

## Sécurité

### 1. Secrets

#### `secrets.yml`
```yaml
# Database Secrets
db_password: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  636f6e74656e7473

# JWT Secrets
jwt_secret: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  736563726574

# API Keys
api_key: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  6b6579
```

### 2. Certificates

#### `certificates.yml`
```yaml
# SSL Configuration
ssl_cert: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  63657274

ssl_key: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  6b6579

# CA Configuration
ca_cert: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  6361
```

## Documentation

### 1. Configuration

#### `config.yml`
```yaml
# Application Configuration
app_name: "YourMedia"
app_version: "1.0.0"
app_environment: "production"

# Feature Flags
feature_new_ui: true
feature_analytics: true
feature_monitoring: true

# Logging Configuration
log_level: "INFO"
log_format: "json"
log_retention: "30d"
```

### 2. Deployment

#### `deploy.yml`
```yaml
# Deployment Configuration
deploy_environment: "production"
deploy_region: "eu-west-3"
deploy_version: "1.0.0"

# Scaling Configuration
min_instances: 1
max_instances: 3
target_cpu: 70

# Backup Configuration
backup_enabled: true
backup_interval: "24h"
backup_retention: "7d"
``` 