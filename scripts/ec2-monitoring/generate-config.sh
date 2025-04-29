#!/bin/bash
#==============================================================================
# Nom du script : generate-config.sh
# Description   : Script pour générer les fichiers de configuration YAML pour les services de monitoring.
#                 Ce script génère tous les fichiers de configuration nécessaires à partir de modèles
#                 et de variables d'environnement.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2025-04-27
#==============================================================================
# Utilisation   : sudo ./generate-config.sh [options]
#
# Options       :
#   --output-dir=DIR : Répertoire de sortie pour les fichiers générés (par défaut: /opt/monitoring)
#   --config-only    : Générer uniquement les fichiers de configuration (pas docker-compose.yml)
#   --force          : Écraser les fichiers existants
#
# Exemples      :
#   sudo ./generate-config.sh
#   sudo ./generate-config.sh --output-dir=/tmp/monitoring
#   sudo ./generate-config.sh --config-only
#==============================================================================
# Dépendances   :
#   - envsubst   : Pour remplacer les variables d'environnement dans les modèles
#==============================================================================
# Droits requis : Ce script doit être exécuté avec des privilèges sudo ou en tant que root.
#==============================================================================

# Fonction de journalisation
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Fonction pour afficher les erreurs et quitter
error_exit() {
    log "ERREUR: $1"
    exit 1
}

# Vérifier si le script est exécuté avec les privilèges root
if [ "$(id -u)" -ne 0 ]; then
    error_exit "Ce script doit être exécuté avec les privilèges root (sudo)."
fi

# Variables par défaut
OUTPUT_DIR="/opt/monitoring"
CONFIG_ONLY=false
FORCE=false

# Traitement des arguments
for arg in "$@"; do
    case $arg in
        --output-dir=*)
            OUTPUT_DIR="${arg#*=}"
            shift
            ;;
        --config-only)
            CONFIG_ONLY=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        *)
            error_exit "Option inconnue: $arg"
            ;;
    esac
done

# Vérifier si envsubst est installé
if ! command -v envsubst &> /dev/null; then
    log "Installation de gettext pour envsubst..."
    apt-get update && apt-get install -y gettext-base || error_exit "Impossible d'installer gettext-base"
fi

# Créer le répertoire de sortie s'il n'existe pas
mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/prometheus-rules"

# Fonction pour générer un fichier à partir d'un modèle
generate_file() {
    local template="$1"
    local output_file="$2"

    # Vérifier si le fichier existe déjà et si --force n'est pas spécifié
    if [ -f "$output_file" ] && [ "$FORCE" = false ]; then
        log "Le fichier $output_file existe déjà. Utilisez --force pour l'écraser."
        return 0
    fi

    log "Génération du fichier $output_file..."
    echo "$template" | envsubst > "$output_file"

    # Vérifier si la génération a réussi
    if [ $? -ne 0 ]; then
        error_exit "Échec de la génération du fichier $output_file"
    fi

    log "Fichier $output_file généré avec succès."
}

# Modèle pour prometheus.yml
PROMETHEUS_TEMPLATE='global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "node-exporter"
    static_configs:
      - targets: ["node-exporter:9100"]

  - job_name: "mysql-exporter"
    static_configs:
      - targets: ["mysql-exporter:9104"]

  - job_name: "cloudwatch-exporter"
    static_configs:
      - targets: ["cloudwatch-exporter:9106"]

  - job_name: "app-backend"
    metrics_path: "/actuator/prometheus"
    static_configs:
      - targets: ["app-backend:8080"]

  # L'"application mobile ne fournit pas de métriques Prometheus directement
  # Utilisez node-exporter pour surveiller le système hôte
'

# Modèle pour cloudwatch-config.yml
CLOUDWATCH_TEMPLATE='# Configuration CloudWatch Exporter pour Prometheus
# Ce fichier définit les métriques AWS à collecter via l'"API CloudWatch

# Région AWS à surveiller
region: ${AWS_DEFAULT_REGION:-eu-west-3}

# Liste des métriques à collecter
metrics:
  #############################################################################
  # S3 Metrics - Surveillance du bucket S3 pour le stockage des médias
  #############################################################################

  # Taille totale du bucket en octets
  - aws_namespace: AWS/S3
    aws_metric_name: BucketSizeBytes
    aws_dimensions: [BucketName, StorageType]
    aws_statistics: [Average, Maximum]
    aws_dimension_select:
      BucketName: ["${S3_BUCKET_NAME:-yourmedia-ecf-studi}"]
      StorageType: [StandardStorage]
    period_seconds: 86400  # 24 heures (les métriques S3 sont mises à jour quotidiennement)

  # Nombre total d'"objets dans le bucket
  - aws_namespace: AWS/S3
    aws_metric_name: NumberOfObjects
    aws_dimensions: [BucketName, StorageType]
    aws_statistics: [Average, Maximum]
    aws_dimension_select:
      BucketName: ["${S3_BUCKET_NAME:-yourmedia-ecf-studi}"]
      StorageType: [AllStorageTypes]
    period_seconds: 86400  # 24 heures

  # Requêtes par type d'"opération
  - aws_namespace: AWS/S3
    aws_metric_name: AllRequests
    aws_dimensions: [BucketName, FilterId]
    aws_statistics: [Sum]
    aws_dimension_select:
      BucketName: ["${S3_BUCKET_NAME:-yourmedia-ecf-studi}"]
    period_seconds: 300  # 5 minutes

  #############################################################################
  # RDS Metrics - Surveillance de la base de données MySQL
  #############################################################################

  # Utilisation CPU de l'"instance RDS
  - aws_namespace: AWS/RDS
    aws_metric_name: CPUUtilization
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average, Maximum]
    period_seconds: 300  # 5 minutes

  # Nombre de connexions à la base de données
  - aws_namespace: AWS/RDS
    aws_metric_name: DatabaseConnections
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average, Maximum, Sum]
    period_seconds: 300  # 5 minutes

  # Espace de stockage disponible
  - aws_namespace: AWS/RDS
    aws_metric_name: FreeStorageSpace
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average, Minimum]
    period_seconds: 300  # 5 minutes

  # Latence des opérations de lecture
  - aws_namespace: AWS/RDS
    aws_metric_name: ReadLatency
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average, Maximum]
    period_seconds: 300  # 5 minutes

  # Latence des opérations d'"écriture
  - aws_namespace: AWS/RDS
    aws_metric_name: WriteLatency
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average, Maximum]
    period_seconds: 300  # 5 minutes

  #############################################################################
  # EC2 Metrics - Surveillance des instances EC2
  #############################################################################

  # Utilisation CPU
  - aws_namespace: AWS/EC2
    aws_metric_name: CPUUtilization
    aws_dimensions: [InstanceId]
    aws_statistics: [Average, Maximum]
    period_seconds: 300  # 5 minutes

  # Trafic réseau entrant
  - aws_namespace: AWS/EC2
    aws_metric_name: NetworkIn
    aws_dimensions: [InstanceId]
    aws_statistics: [Average, Sum]
    period_seconds: 300  # 5 minutes

  # Trafic réseau sortant
  - aws_namespace: AWS/EC2
    aws_metric_name: NetworkOut
    aws_dimensions: [InstanceId]
    aws_statistics: [Average, Sum]
    period_seconds: 300  # 5 minutes

  # Opérations disque
  - aws_namespace: AWS/EC2
    aws_metric_name: DiskReadOps
    aws_dimensions: [InstanceId]
    aws_statistics: [Average, Sum]
    period_seconds: 300  # 5 minutes

  - aws_namespace: AWS/EC2
    aws_metric_name: DiskWriteOps
    aws_dimensions: [InstanceId]
    aws_statistics: [Average, Sum]
    period_seconds: 300  # 5 minutes
'

# Modèle pour loki-config.yml
LOKI_TEMPLATE='auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /tmp/loki
  storage:
    filesystem:
      chunks_directory: /tmp/loki/chunks
      rules_directory: /tmp/loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://localhost:9093

limits_config:
  retention_period: 7d

analytics:
  reporting_enabled: false
'

# Modèle pour promtail-config.yml
PROMTAIL_TEMPLATE='server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: docker
    static_configs:
      - targets:
          - localhost
        labels:
          job: docker
          __path__: /var/lib/docker/containers/*/*-json.log
    pipeline_stages:
      - json:
          expressions:
            output: log
            stream: stream
            attrs: attrs
            time: time
            container_name: attrs.container_name
      - labels:
          container_name:
      - timestamp:
          source: time
          format: RFC3339Nano
      - output:
          source: output

  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: system
          __path__: /var/log/syslog
    pipeline_stages:
      - regex:
          expression: '\''^(?P<timestamp>\w+\s+\d+\s+\d+:\d+:\d+)\s+(?P<host>\S+)\s+(?P<app>\S+)(?:\[(?P<pid>\d+)\])?: (?P<message>.*)$'\''
      - labels:
          host:
          app:
          pid:
      - timestamp:
          source: timestamp
          format: Jan 2 15:04:05
      - output:
          source: message
'

# Modèle pour container-alerts.yml
CONTAINER_ALERTS_TEMPLATE='groups:
  - name: containers
    rules:
      - alert: ContainerDown
        expr: absent(container_last_seen{name=~"prometheus|grafana|cloudwatch-exporter|mysql-exporter"})
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Container {{ $labels.name }} is down"
          description: "Container {{ $labels.name }} has been down for more than 1 minute."

      - alert: ContainerHighCPU
        expr: sum(rate(container_cpu_usage_seconds_total{name=~"prometheus|grafana|cloudwatch-exporter|mysql-exporter"}[1m])) by (name) > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.name }} high CPU usage"
          description: "Container {{ $labels.name }} CPU usage is above 80% for more than 5 minutes."

      - alert: ContainerHighMemory
        expr: container_memory_usage_bytes{name=~"prometheus|grafana|cloudwatch-exporter|mysql-exporter"} / container_spec_memory_limit_bytes{name=~"prometheus|grafana|cloudwatch-exporter|mysql-exporter"} > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.name }} high memory usage"
          description: "Container {{ $labels.name }} memory usage is above 80% for more than 5 minutes."

      - alert: ContainerHighRestarts
        expr: changes(container_start_time_seconds{name=~"prometheus|grafana|cloudwatch-exporter|mysql-exporter"}[15m]) > 3
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.name }} high restart count"
          description: "Container {{ $labels.name }} has been restarted more than 3 times in the last 15 minutes."
'

# Modèle pour docker-compose.yml
DOCKER_COMPOSE_TEMPLATE='version: '\''3'\''

services:
  prometheus:
    image: ${DOCKER_USERNAME:-medsin}/${DOCKER_REPO:-yourmedia-ecf}:prometheus-latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - /opt/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - /opt/monitoring/prometheus-data:/prometheus
    command:
      - '\''--config.file=/etc/prometheus/prometheus.yml'\''
      - '\''--storage.tsdb.path=/prometheus'\''
      - '\''--storage.tsdb.retention.time=15d'\''
      - '\''--storage.tsdb.retention.size=1GB'\''
      - '\''--web.console.libraries=/usr/share/prometheus/console_libraries'\''
      - '\''--web.console.templates=/usr/share/prometheus/consoles'\''
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 512m
    cpu_shares: 512

  grafana:
    image: ${DOCKER_USERNAME:-medsin}/${DOCKER_REPO:-yourmedia-ecf}:grafana-latest
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - /opt/monitoring/grafana-data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-YourMedia2025!}
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer
    depends_on:
      - prometheus
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 512m
    cpu_shares: 512



  # Exportateur CloudWatch pour surveiller les services AWS (S3, RDS, EC2)
  cloudwatch-exporter:
    image: prom/cloudwatch-exporter:latest
    container_name: cloudwatch-exporter
    ports:
      - "9106:9106"
    volumes:
      - /opt/monitoring/cloudwatch-config.yml:/config/cloudwatch-config.yml
    environment:
      - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
      - AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
      - AWS_REGION=${AWS_DEFAULT_REGION:-eu-west-3}
    command:
      - --config.file=/config/cloudwatch-config.yml
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 256m
    cpu_shares: 256

  # Exportateur MySQL pour surveiller RDS
  mysql-exporter:
    image: prom/mysqld-exporter:v0.15.0
    container_name: mysql-exporter
    ports:
      - "9104:9104"
    environment:
      # Format correct pour la connexion MySQL: user:password@protocol(host:port)/
      - DATA_SOURCE_NAME=${RDS_USERNAME:-yourmedia}:${RDS_PASSWORD:-password}@tcp(${RDS_HOST:-localhost}:${RDS_PORT:-3306})/
      - RDS_HOST=${RDS_HOST:-localhost}
      - RDS_PORT=${RDS_PORT:-3306}
      - RDS_USERNAME=${RDS_USERNAME:-yourmedia}
      - RDS_PASSWORD=${RDS_PASSWORD:-password}
    entrypoint:
      - /bin/mysqld_exporter
    command:
      - --web.listen-address=:9104
      - --collect.info_schema.tables
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 256m
    cpu_shares: 256

  # Loki pour la centralisation des logs
  loki:
    image: grafana/loki:2.9.2
    container_name: loki
    ports:
      - "3100:3100"
    volumes:
      - /opt/monitoring/loki-config.yml:/etc/loki/local-config.yaml
      - /opt/monitoring/loki-data:/loki
    command: -config.file=/etc/loki/local-config.yaml
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 512m
    cpu_shares: 512

  # Promtail pour collecter les logs des conteneurs
  promtail:
    image: grafana/promtail:2.9.2
    container_name: promtail
    volumes:
      - /var/log:/var/log
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /opt/monitoring/promtail-config.yml:/etc/promtail/config.yml
    command: -config.file=/etc/promtail/config.yml
    depends_on:
      - loki
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 256m
    cpu_shares: 256
'

# Générer les fichiers de configuration
generate_file "$PROMETHEUS_TEMPLATE" "$OUTPUT_DIR/prometheus.yml"
generate_file "$CLOUDWATCH_TEMPLATE" "$OUTPUT_DIR/cloudwatch-config.yml"
generate_file "$LOKI_TEMPLATE" "$OUTPUT_DIR/loki-config.yml"
generate_file "$PROMTAIL_TEMPLATE" "$OUTPUT_DIR/promtail-config.yml"
generate_file "$CONTAINER_ALERTS_TEMPLATE" "$OUTPUT_DIR/prometheus-rules/container-alerts.yml"

# Générer le fichier docker-compose.yml si --config-only n'est pas spécifié
if [ "$CONFIG_ONLY" = false ]; then
    generate_file "$DOCKER_COMPOSE_TEMPLATE" "$OUTPUT_DIR/docker-compose.yml"
fi

# Créer les répertoires de données s'ils n'existent pas
mkdir -p "$OUTPUT_DIR/prometheus-data"
mkdir -p "$OUTPUT_DIR/grafana-data"

mkdir -p "$OUTPUT_DIR/loki-data"

# Définir les permissions
chmod 755 "$OUTPUT_DIR"
chmod 644 "$OUTPUT_DIR"/*.yml
chmod 644 "$OUTPUT_DIR/prometheus-rules"/*.yml

log "Génération des fichiers de configuration terminée."
log "Les fichiers ont été générés dans le répertoire $OUTPUT_DIR."
exit 0
