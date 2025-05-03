#!/bin/bash
#==============================================================================
# Nom du script : setup-monitoring.sh
# Description   : Script unifié d'installation et de configuration pour l'instance EC2 Monitoring.
#                 Ce script combine les fonctionnalités d'installation, configuration,
#                 vérification et correction des problèmes pour les services de monitoring.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 2.1
# Date          : 2023-11-15
#==============================================================================
# Utilisation   : sudo ./setup-monitoring.sh [options]
#
# Options       :
#   --check     : Vérifie uniquement l'état de l'installation sans rien installer
#   --fix       : Corrige les problèmes détectés
#   --force     : Force la réinstallation même si déjà installé
#   --help      : Affiche l'aide
#
# Exemples      :
#   sudo ./setup-monitoring.sh
#   sudo ./setup-monitoring.sh --check
#   sudo ./setup-monitoring.sh --fix
#   sudo ./setup-monitoring.sh --force
#==============================================================================
# Dépendances   :
#   - wget      : Pour télécharger des fichiers et récupérer les métadonnées de l'instance
#   - jq        : Pour le traitement JSON
#   - aws-cli   : Pour interagir avec les services AWS
#   - docker    : Sera installé par le script
#   - docker-compose : Sera installé par le script
#   - netstat   : Pour vérifier les ports ouverts
#==============================================================================
# Variables d'environnement :
#   - S3_BUCKET_NAME : Nom du bucket S3 contenant les scripts
#   - RDS_USERNAME / DB_USERNAME : Nom d'utilisateur RDS
#   - RDS_PASSWORD / DB_PASSWORD : Mot de passe RDS
#   - RDS_ENDPOINT / DB_ENDPOINT : Point de terminaison RDS
#   - GRAFANA_ADMIN_PASSWORD / GF_SECURITY_ADMIN_PASSWORD : Mot de passe administrateur Grafana
#   - DOCKERHUB_USERNAME : Nom d'utilisateur Docker Hub (standard)
#   - DOCKERHUB_TOKEN : Token d'authentification Docker Hub (standard)
#   - DOCKERHUB_REPO : Nom du dépôt Docker Hub (standard)
#   - DOCKER_USERNAME : Alias pour DOCKERHUB_USERNAME (compatibilité)
#   - DOCKER_PASSWORD : Alias pour DOCKERHUB_TOKEN (compatibilité)
#   - DOCKER_REPO : Alias pour DOCKERHUB_REPO (compatibilité)
#==============================================================================
# Droits requis : Ce script doit être exécuté avec des privilèges sudo ou en tant que root.
#==============================================================================

set -e

# Rediriger stdout et stderr vers un fichier log pour le débogage
exec > >(tee /var/log/setup-monitoring.log|logger -t setup-monitoring -s 2>/dev/console) 2>&1

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Fonction pour afficher les erreurs et quitter
error_exit() {
    log "ERREUR: $1"
    exit 1
}

# Fonction pour installer Docker
install_docker() {
    log "Installation de Docker"
    if ! command -v docker &> /dev/null; then
        log "Installation de Docker natif pour Amazon Linux 2023"
        dnf install -y docker
        systemctl start docker
        systemctl enable docker

        # Créer le groupe docker s'il n'existe pas
        getent group docker &>/dev/null || groupadd docker

        # Ajouter l'utilisateur ec2-user au groupe docker
        usermod -aG docker ec2-user
        log "Utilisateur ec2-user ajouté au groupe docker"
    else
        log "Docker est déjà installé"
        # S'assurer que Docker est démarré
        if ! systemctl is-active --quiet docker; then
            systemctl start docker
            systemctl enable docker
        fi
        # S'assurer que l'utilisateur ec2-user est dans le groupe docker
        if ! groups ec2-user | grep -q docker; then
            usermod -a -G docker ec2-user
        fi
    fi

    log "Docker installé avec succès"
    return 0
}

# Fonction pour installer Docker Compose
install_docker_compose() {
    log "Installation de Docker Compose"
    if ! command -v docker-compose &> /dev/null; then
        sudo wget -q -O /usr/local/bin/docker-compose "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)"
        sudo chmod +x /usr/local/bin/docker-compose

        # Créer un lien symbolique
        if [ ! -f "/usr/bin/docker-compose" ] && [ ! -L "/usr/bin/docker-compose" ]; then
            sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
        fi
    else
        log "Docker Compose est déjà installé"
    fi

    log "Docker Compose installé avec succès"
    return 0
}

# Fonction pour configurer les limites de ressources système
configure_system_limits() {
    log "Configuration des limites de ressources système"

    # Configurer les limites de ressources pour l'utilisateur ec2-user
    if ! grep -q "ec2-user.*nofile" /etc/security/limits.conf; then
        echo "ec2-user soft nofile 4096" | tee -a /etc/security/limits.conf
        echo "ec2-user hard nofile 4096" | tee -a /etc/security/limits.conf
        echo "ec2-user soft nproc 2048" | tee -a /etc/security/limits.conf
        echo "ec2-user hard nproc 2048" | tee -a /etc/security/limits.conf
    fi

    log "Limites de ressources système configurées avec succès"
    return 0
}

# Fonction pour créer le fichier docker-compose.yml
create_docker_compose_file() {
    log "Création du fichier docker-compose.yml"
    # Vérifier si le fichier existe déjà
    if [ -f "/opt/monitoring/docker-compose.yml" ]; then
        log "Le fichier docker-compose.yml existe déjà, utilisation du fichier existant"
        return 0
    fi

    # Note: La création du fichier docker-compose.yml est maintenant gérée dans la partie principale du script
    # pour éviter les duplications et incohérences
    log "Le fichier docker-compose.yml sera créé dans la partie principale du script"
    return 0
}

# Fonction pour créer le fichier de configuration CloudWatch Exporter
create_cloudwatch_config() {
    log "Création du fichier de configuration CloudWatch Exporter"
    mkdir -p /opt/monitoring/config

    # Vérifier si le fichier existe déjà dans le répertoire config
    if [ -f "/opt/monitoring/config/cloudwatch-config.yml" ]; then
        log "Le fichier de configuration CloudWatch existe déjà"
        return 0
    fi

    # URL du fichier de configuration sur GitHub
    GITHUB_RAW_URL="https://raw.githubusercontent.com/${REPO_OWNER:-Med3Sin}/${REPO_NAME:-Studi-YourMedia-ECF}/main"
    CONFIG_URL="$GITHUB_RAW_URL/scripts/config/monitoring/cloudwatch-config.yml"

    # Télécharger le fichier de configuration avec wget
    log "Téléchargement du fichier de configuration depuis $CONFIG_URL"
    wget -q -O /opt/monitoring/config/cloudwatch-config.yml "$CONFIG_URL"

    # Vérifier si le téléchargement a réussi
    if [ ! -s /opt/monitoring/config/cloudwatch-config.yml ]; then
        log "ERREUR: Le téléchargement du fichier de configuration a échoué. Nouvelle tentative avec une URL alternative..."

        # Essayer une URL alternative
        GITHUB_RAW_URL_ALT="https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main"
        CONFIG_URL_ALT="$GITHUB_RAW_URL_ALT/scripts/config/monitoring/cloudwatch-config.yml"

        log "Téléchargement du fichier de configuration depuis $CONFIG_URL_ALT"
        sudo wget -q -O /opt/monitoring/config/cloudwatch-config.yml "$CONFIG_URL_ALT"

        # Si le téléchargement échoue toujours, créer un fichier de base
        if [ ! -s /opt/monitoring/config/cloudwatch-config.yml ]; then
            log "ERREUR: Le téléchargement du fichier de configuration a échoué à nouveau. Création d'un fichier de base..."

            # Créer un fichier temporaire avec le contenu de base
            sudo bash -c "cat > /tmp/cloudwatch-config.yml << EOF
---
region: ${AWS_REGION:-eu-west-3}
metrics:
  - aws_namespace: AWS/S3
    aws_metric_name: BucketSizeBytes
    aws_dimensions: [BucketName, StorageType]
    aws_dimension_select:
      BucketName: [\"${S3_BUCKET_NAME}\"]
    aws_statistics: [Average]

  - aws_namespace: AWS/S3
    aws_metric_name: NumberOfObjects
    aws_dimensions: [BucketName, StorageType]
    aws_dimension_select:
      BucketName: [\"${S3_BUCKET_NAME}\"]
    aws_statistics: [Average]

  - aws_namespace: AWS/RDS
    aws_metric_name: CPUUtilization
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average]

  - aws_namespace: AWS/RDS
    aws_metric_name: DatabaseConnections
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average]

  - aws_namespace: AWS/RDS
    aws_metric_name: FreeStorageSpace
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average]
EOF"
            # Copier le fichier temporaire vers l'emplacement final
            sudo cp /tmp/cloudwatch-config.yml /opt/monitoring/config/cloudwatch-config.yml
            sudo rm /tmp/cloudwatch-config.yml
        fi
    fi
    fi

    # Remplacer les variables dans le fichier téléchargé
    sed -i "s/\${AWS_REGION:-eu-west-3}/${AWS_REGION:-eu-west-3}/g" /opt/monitoring/config/cloudwatch-config.yml
    sed -i "s/\${S3_BUCKET_NAME}/${S3_BUCKET_NAME}/g" /opt/monitoring/config/cloudwatch-config.yml

    # Créer un lien symbolique pour la compatibilité avec les anciens scripts
    mkdir -p /opt/monitoring/cloudwatch-config
    ln -sf /opt/monitoring/config/cloudwatch-config.yml /opt/monitoring/cloudwatch-config/cloudwatch-config.yml

    log "Fichier de configuration CloudWatch Exporter créé avec succès"
    return 0
}

# Fonction pour créer le fichier prometheus.yml
create_prometheus_config() {
    log "Création du fichier prometheus.yml"
    sudo mkdir -p /opt/monitoring/config/prometheus

    # Vérifier si le fichier existe déjà dans le répertoire config
    if [ -f "/opt/monitoring/config/prometheus/prometheus.yml" ]; then
        log "Le fichier de configuration Prometheus existe déjà"
        return 0
    fi

    # URL du fichier de configuration sur GitHub
    GITHUB_RAW_URL="https://raw.githubusercontent.com/${REPO_OWNER:-Med3Sin}/${REPO_NAME:-Studi-YourMedia-ECF}/main"
    CONFIG_URL="$GITHUB_RAW_URL/scripts/config/prometheus/prometheus.yml"

    # Télécharger le fichier de configuration avec wget
    log "Téléchargement du fichier de configuration depuis $CONFIG_URL"
    sudo wget -q -O /opt/monitoring/config/prometheus/prometheus.yml "$CONFIG_URL"

    # Vérifier si le téléchargement a réussi
    if [ ! -s /opt/monitoring/config/prometheus/prometheus.yml ]; then
        log "ERREUR: Le téléchargement du fichier de configuration a échoué. Création d'un fichier de base..."

        # Créer un fichier temporaire avec le contenu de base
        sudo bash -c 'cat > /tmp/prometheus.yml << "EOF"
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: '\''prometheus'\''
    static_configs:
      - targets: ['\''localhost:9090'\'']

  - job_name: '\''node-exporter'\''
    static_configs:
      - targets: ['\''node-exporter:9100'\'']

  - job_name: '\''mysql-exporter'\''
    static_configs:
      - targets: ['\''mysql-exporter:9104'\'']

  - job_name: '\''cloudwatch-exporter'\''
    static_configs:
      - targets: ['\''cloudwatch-exporter:9106'\'']
EOF'
        # Copier le fichier temporaire vers l'emplacement final
        sudo cp /tmp/prometheus.yml /opt/monitoring/config/prometheus/prometheus.yml
        sudo rm /tmp/prometheus.yml
    fi

    # Créer un lien symbolique pour la compatibilité avec les anciens scripts
    sudo ln -sf /opt/monitoring/config/prometheus/prometheus.yml /opt/monitoring/prometheus.yml

    log "Fichier prometheus.yml créé avec succès"
    return 0
}

# Fonction pour créer le fichier loki-config.yml
create_loki_config() {
    log "Création du fichier loki-config.yml"
    sudo mkdir -p /opt/monitoring/config

    # Vérifier si le fichier existe déjà dans le répertoire config
    if [ -f "/opt/monitoring/config/loki-config.yml" ]; then
        log "Le fichier de configuration Loki existe déjà"
        return 0
    fi

    # URL du fichier de configuration sur GitHub
    GITHUB_RAW_URL="https://raw.githubusercontent.com/${REPO_OWNER:-Med3Sin}/${REPO_NAME:-Studi-YourMedia-ECF}/main"
    CONFIG_URL="$GITHUB_RAW_URL/scripts/config/loki-config.yml"

    # Télécharger le fichier de configuration avec wget
    log "Téléchargement du fichier de configuration depuis $CONFIG_URL"
    sudo wget -q -O /opt/monitoring/config/loki-config.yml "$CONFIG_URL"

    # Vérifier si le téléchargement a réussi
    if [ ! -s /opt/monitoring/config/loki-config.yml ]; then
        log "ERREUR: Le téléchargement du fichier de configuration a échoué. Création d'un fichier de base..."

        # Créer un fichier temporaire avec le contenu de base
        sudo bash -c 'cat > /tmp/loki-config.yml << "EOF"
auth_enabled: false

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
EOF'
        # Copier le fichier temporaire vers l'emplacement final
        sudo cp /tmp/loki-config.yml /opt/monitoring/config/loki-config.yml
        sudo rm /tmp/loki-config.yml
    fi

    # Créer un lien symbolique pour la compatibilité avec les anciens scripts
    sudo ln -sf /opt/monitoring/config/loki-config.yml /opt/monitoring/loki-config.yml

    log "Fichier loki-config.yml créé avec succès"
    return 0
}

# Fonction pour créer le fichier promtail-config.yml
create_promtail_config() {
    log "Création du fichier promtail-config.yml"
    sudo mkdir -p /opt/monitoring/config

    # Vérifier si le fichier existe déjà dans le répertoire config
    if [ -f "/opt/monitoring/config/promtail-config.yml" ]; then
        log "Le fichier de configuration Promtail existe déjà"
        return 0
    fi

    # URL du fichier de configuration sur GitHub
    GITHUB_RAW_URL="https://raw.githubusercontent.com/${REPO_OWNER:-Med3Sin}/${REPO_NAME:-Studi-YourMedia-ECF}/main"
    CONFIG_URL="$GITHUB_RAW_URL/scripts/config/promtail-config.yml"

    # Télécharger le fichier de configuration avec wget
    log "Téléchargement du fichier de configuration depuis $CONFIG_URL"
    sudo wget -q -O /opt/monitoring/config/promtail-config.yml "$CONFIG_URL"

    # Vérifier si le téléchargement a réussi
    if [ ! -s /opt/monitoring/config/promtail-config.yml ]; then
        log "ERREUR: Le téléchargement du fichier de configuration a échoué. Création d'un fichier de base..."

        # Créer un fichier temporaire avec le contenu de base
        sudo bash -c 'cat > /tmp/promtail-config.yml << "EOF"
server:
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
EOF'
        # Copier le fichier temporaire vers l'emplacement final
        sudo cp /tmp/promtail-config.yml /opt/monitoring/config/promtail-config.yml
        sudo rm /tmp/promtail-config.yml
    fi

    # Créer un lien symbolique pour la compatibilité avec les anciens scripts
    sudo ln -sf /opt/monitoring/config/promtail-config.yml /opt/monitoring/promtail-config.yml

    log "Fichier promtail-config.yml créé avec succès"
    return 0
}

# Fonction pour créer le fichier container-alerts.yml
create_container_alerts() {
    log "Création du fichier container-alerts.yml"
    sudo mkdir -p /opt/monitoring/prometheus-rules
    sudo mkdir -p /opt/monitoring/config/prometheus

    # Vérifier si le fichier existe déjà dans le répertoire config
    if [ -f "/opt/monitoring/config/prometheus/container-alerts.yml" ]; then
        log "Le fichier d'alertes existe déjà"
        # Créer un lien symbolique pour la compatibilité avec les anciens scripts
        sudo ln -sf /opt/monitoring/config/prometheus/container-alerts.yml /opt/monitoring/prometheus-rules/container-alerts.yml
        return 0
    fi

    # URL du fichier de configuration sur GitHub
    GITHUB_RAW_URL="https://raw.githubusercontent.com/${REPO_OWNER:-Med3Sin}/${REPO_NAME:-Studi-YourMedia-ECF}/main"
    CONFIG_URL="$GITHUB_RAW_URL/scripts/config/prometheus/container-alerts.yml"

    # Télécharger le fichier de configuration avec wget
    log "Téléchargement du fichier de configuration depuis $CONFIG_URL"
    sudo wget -q -O /opt/monitoring/config/prometheus/container-alerts.yml "$CONFIG_URL"

    # Vérifier si le téléchargement a réussi
    if [ ! -s /opt/monitoring/config/prometheus/container-alerts.yml ]; then
        log "ERREUR: Le téléchargement du fichier de configuration a échoué. Création d'un fichier de base..."

        # Créer un fichier temporaire avec le contenu de base
        sudo bash -c 'cat > /tmp/container-alerts.yml << "EOF"
groups:
  - name: containers
    rules:
      - alert: ContainerDown
        expr: absent(container_last_seen{name=~"prometheus|grafana|node-exporter|cloudwatch-exporter|mysql-exporter"})
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Container {{ $labels.name }} is down"
          description: "Container {{ $labels.name }} has been down for more than 1 minute."

      - alert: ContainerHighCPU
        expr: sum(rate(container_cpu_usage_seconds_total{name=~"prometheus|grafana|node-exporter|cloudwatch-exporter|mysql-exporter"}[1m])) by (name) > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.name }} high CPU usage"
          description: "Container {{ $labels.name }} CPU usage is above 80% for more than 5 minutes."

      - alert: ContainerHighMemory
        expr: container_memory_usage_bytes{name=~"prometheus|grafana|node-exporter|cloudwatch-exporter|mysql-exporter"} / container_spec_memory_limit_bytes{name=~"prometheus|grafana|node-exporter|cloudwatch-exporter|mysql-exporter"} > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.name }} high memory usage"
          description: "Container {{ $labels.name }} memory usage is above 80% for more than 5 minutes."

      - alert: ContainerHighRestarts
        expr: changes(container_start_time_seconds{name=~"prometheus|grafana|node-exporter|cloudwatch-exporter|mysql-exporter"}[15m]) > 3
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.name }} high restart count"
          description: "Container {{ $labels.name }} has been restarted more than 3 times in the last 15 minutes."
EOF'
        # Copier le fichier temporaire vers l'emplacement final
        sudo cp /tmp/container-alerts.yml /opt/monitoring/config/prometheus/container-alerts.yml
        sudo rm /tmp/container-alerts.yml
    fi

    # Créer un lien symbolique pour la compatibilité avec les anciens scripts
    sudo ln -sf /opt/monitoring/config/prometheus/container-alerts.yml /opt/monitoring/prometheus-rules/container-alerts.yml

    log "Fichier container-alerts.yml créé avec succès"
    return 0
}

# Fonction pour créer le script docker-manager.sh
create_docker_manager_script() {
    log "Création du script docker-manager.sh"

    # Télécharger le script docker-manager.sh depuis S3 si disponible
    if [ ! -z "$S3_BUCKET_NAME" ]; then
        aws s3 cp s3://$S3_BUCKET_NAME/scripts/utils/docker-manager.sh /opt/monitoring/docker-manager.sh || log "Échec du téléchargement du script docker-manager.sh depuis S3"
    fi

    # Si le téléchargement depuis S3 a échoué, essayer de télécharger depuis GitHub
    if [ ! -f "/opt/monitoring/docker-manager.sh" ]; then
        log "Téléchargement du script docker-manager.sh depuis GitHub"

        # URL du script sur GitHub
        GITHUB_RAW_URL="https://raw.githubusercontent.com/${REPO_OWNER:-Med3Sin}/${REPO_NAME:-Studi-YourMedia-ECF}/main"
        SCRIPT_URL="$GITHUB_RAW_URL/scripts/config/monitoring/docker-manager.sh"

        # Télécharger le script avec wget
        wget -q -O /opt/monitoring/docker-manager.sh "$SCRIPT_URL"
    fi

    # Si les deux téléchargements ont échoué, créer une version simplifiée du script
    if [ ! -s "/opt/monitoring/docker-manager.sh" ]; then
        log "Création d'une version simplifiée du script docker-manager.sh"
        cat > /opt/monitoring/docker-manager.sh << 'EOF'
#!/bin/bash
#==============================================================================
# Nom du script : docker-manager.sh
# Description   : Script simplifié de gestion des conteneurs Docker.
#                 Ce script permet de démarrer, arrêter, redémarrer et vérifier
#                 le statut des conteneurs Docker.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2025-05-02
#==============================================================================
# Utilisation   : sudo ./docker-manager.sh [start|stop|restart|status|deploy] [service_name]
#
# Options       :
#   start       : Démarrer les conteneurs
#   stop        : Arrêter les conteneurs
#   restart     : Redémarrer les conteneurs
#   status      : Afficher le statut des conteneurs
#   deploy      : Déployer les conteneurs (arrêter puis démarrer)
#
# Exemples      :
#   sudo ./docker-manager.sh start
#   sudo ./docker-manager.sh stop grafana
#   sudo ./docker-manager.sh restart prometheus
#==============================================================================
# Dépendances   :
#   - docker    : Pour gérer les conteneurs
#   - docker-compose : Pour gérer les services
#==============================================================================
# Droits requis : Ce script doit être exécuté avec des privilèges sudo ou en tant que root.
#==============================================================================

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Fonction pour afficher les erreurs et quitter
error_exit() {
    log "ERREUR: $1"
    exit 1
}

# Vérification des droits sudo
if [ "$(id -u)" -ne 0 ]; then
    error_exit "Ce script doit être exécuté avec sudo ou en tant que root"
fi

# Charger les variables d'environnement
if [ -f "/opt/monitoring/env.sh" ]; then
    source /opt/monitoring/env.sh
fi

if [ -f "/opt/monitoring/secure/sensitive-env.sh" ]; then
    source /opt/monitoring/secure/sensitive-env.sh
fi

# Vérifier si Docker est installé
if ! command -v docker &> /dev/null; then
    error_exit "Docker n'est pas installé"
fi

# Vérifier si Docker Compose est installé
if ! command -v docker-compose &> /dev/null; then
    error_exit "Docker Compose n'est pas installé"
fi

# Vérifier les arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 [start|stop|restart|status|deploy] [service_name]"
    exit 1
fi

ACTION=$1
SERVICE=${2:-all}

# Fonction pour démarrer les conteneurs
start_containers() {
    log "Démarrage des conteneurs..."
    cd /opt/monitoring
    docker-compose up -d $SERVICE
    if [ $? -eq 0 ]; then
        log "Conteneurs démarrés avec succès"
    else
        error_exit "Échec du démarrage des conteneurs"
    fi
}

# Fonction pour arrêter les conteneurs
stop_containers() {
    log "Arrêt des conteneurs..."
    cd /opt/monitoring
    docker-compose down $SERVICE
    if [ $? -eq 0 ]; then
        log "Conteneurs arrêtés avec succès"
    else
        error_exit "Échec de l'arrêt des conteneurs"
    fi
}

# Fonction pour redémarrer les conteneurs
restart_containers() {
    log "Redémarrage des conteneurs..."
    cd /opt/monitoring
    docker-compose restart $SERVICE
    if [ $? -eq 0 ]; then
        log "Conteneurs redémarrés avec succès"
    else
        error_exit "Échec du redémarrage des conteneurs"
    fi
}

# Fonction pour afficher le statut des conteneurs
status_containers() {
    log "Statut des conteneurs:"
    docker ps -a
}

# Fonction pour déployer les conteneurs
deploy_containers() {
    log "Déploiement des conteneurs..."
    cd /opt/monitoring

    # Arrêter les conteneurs existants
    docker-compose down

    # Démarrer les conteneurs
    docker-compose up -d

    if [ $? -eq 0 ]; then
        log "Conteneurs déployés avec succès"
    else
        error_exit "Échec du déploiement des conteneurs"
    fi
}

# Exécuter l'action demandée
case $ACTION in
    start)
        start_containers
        ;;
    stop)
        stop_containers
        ;;
    restart)
        restart_containers
        ;;
    status)
        status_containers
        ;;
    deploy)
        deploy_containers
        ;;
    *)
        echo "Action non reconnue: $ACTION"
        echo "Usage: $0 [start|stop|restart|status|deploy] [service_name]"
        exit 1
        ;;
esac

exit 0
EOF
    fi

    # Rendre le script exécutable
    chmod +x /opt/monitoring/docker-manager.sh

    # Créer un lien symbolique pour le script docker-manager.sh
    log "Création d'un lien symbolique pour le script docker-manager.sh"
    ln -sf /opt/monitoring/docker-manager.sh /usr/local/bin/docker-manager.sh
    chmod +x /usr/local/bin/docker-manager.sh

    log "Script docker-manager.sh créé avec succès"
    return 0
}

# Fonction pour démarrer les conteneurs
start_containers() {
    log "Démarrage des conteneurs"

    # Connexion à Docker Hub si les identifiants sont disponibles
    if [ ! -z "$DOCKERHUB_USERNAME" ] && [ ! -z "$DOCKERHUB_TOKEN" ]; then
        log "Connexion à Docker Hub avec l'utilisateur $DOCKERHUB_USERNAME"
        echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
    fi

    cd /opt/monitoring
    docker-compose up -d

    # Vérification du statut des conteneurs
    log "Vérification du statut des conteneurs"
    docker ps

    log "Conteneurs démarrés avec succès"
    return 0
}

# Fonction pour vérifier l'état des conteneurs
check_containers() {
    local fix_issues=$1
    local status=0

    log "Vérification de l'installation de Docker..."
    if command -v docker &> /dev/null; then
        log "✅ Docker est installé"
    else
        log "❌ Docker n'est pas installé"
        if [ "$fix_issues" = "true" ]; then
            log "Installation de Docker..."
            install_docker
            if [ $? -eq 0 ]; then
                log "✅ Docker a été installé avec succès"
            else
                log "❌ L'installation de Docker a échoué"
                return 1
            fi
        else
            status=1
        fi
    fi

    log "Vérification de l'installation de Docker Compose..."
    if command -v docker-compose &> /dev/null; then
        log "✅ Docker Compose est installé"
    else
        log "❌ Docker Compose n'est pas installé"
        if [ "$fix_issues" = "true" ]; then
            log "Installation de Docker Compose..."
            install_docker_compose
            if [ $? -eq 0 ]; then
                log "✅ Docker Compose a été installé avec succès"
            else
                log "❌ L'installation de Docker Compose a échoué"
                return 1
            fi
        else
            status=1
        fi
    fi

    log "Vérification des répertoires de données..."
    local missing_dirs=0
    for dir in prometheus-data grafana-data cloudwatch-config; do
        if [ ! -d "/opt/monitoring/$dir" ]; then
            log "❌ Le répertoire /opt/monitoring/$dir n'existe pas"
            missing_dirs=1
        fi
    done

    if [ $missing_dirs -eq 1 ]; then
        if [ "$fix_issues" = "true" ]; then
            log "Création des répertoires manquants..."
            for dir in prometheus-data grafana-data cloudwatch-config; do
                mkdir -p "/opt/monitoring/$dir"
            done
            log "✅ Répertoires créés avec succès"
        else
            status=1
        fi
    else
        log "✅ Tous les répertoires de données existent"
    fi

    log "Vérification des fichiers de configuration..."
    local config_files_missing=0

    # Vérifier si les fichiers de configuration existent
    if [ ! -f "/opt/monitoring/docker-compose.yml" ] ||
       [ ! -f "/opt/monitoring/cloudwatch-config/cloudwatch-config.yml" ] ||
       [ ! -f "/opt/monitoring/prometheus.yml" ] ||
       [ ! -f "/opt/monitoring/loki-config.yml" ] ||
       [ ! -f "/opt/monitoring/promtail-config.yml" ] ||
       [ ! -f "/opt/monitoring/prometheus-rules/container-alerts.yml" ]; then
        log "❌ Certains fichiers de configuration sont manquants"
        config_files_missing=1
    else
        log "✅ Tous les fichiers de configuration existent"
    fi

    # Si des fichiers sont manquants et que fix_issues est true, générer les fichiers
    if [ $config_files_missing -eq 1 ] && [ "$fix_issues" = "true" ]; then
        log "Génération des fichiers de configuration manquants..."

        # Vérifier si le script generate-config.sh existe
        if [ -f "$(dirname "$0")/generate-config.sh" ]; then
            # Copier le script dans /opt/monitoring
            cp "$(dirname "$0")/generate-config.sh" /opt/monitoring/
            chmod +x /opt/monitoring/generate-config.sh

            # Exécuter le script
            /opt/monitoring/generate-config.sh --force

            if [ $? -eq 0 ]; then
                log "✅ Fichiers de configuration générés avec succès"
            else
                log "❌ La génération des fichiers de configuration a échoué"

                # Utiliser les anciennes fonctions comme fallback
                log "Utilisation des fonctions intégrées comme fallback..."

                if [ ! -f "/opt/monitoring/docker-compose.yml" ]; then
                    create_docker_compose_file
                fi

                if [ ! -f "/opt/monitoring/cloudwatch-config/cloudwatch-config.yml" ]; then
                    create_cloudwatch_config
                fi

                if [ ! -f "/opt/monitoring/prometheus.yml" ]; then
                    create_prometheus_config
                fi

                if [ ! -f "/opt/monitoring/loki-config.yml" ]; then
                    create_loki_config
                fi

                if [ ! -f "/opt/monitoring/promtail-config.yml" ]; then
                    create_promtail_config
                fi

                if [ ! -f "/opt/monitoring/prometheus-rules/container-alerts.yml" ]; then
                    create_container_alerts
                fi

                # Vérifier si les fichiers ont été créés
                if [ ! -f "/opt/monitoring/docker-compose.yml" ] ||
                   [ ! -f "/opt/monitoring/cloudwatch-config/cloudwatch-config.yml" ] ||
                   [ ! -f "/opt/monitoring/prometheus.yml" ] ||
                   [ ! -f "/opt/monitoring/loki-config.yml" ] ||
                   [ ! -f "/opt/monitoring/promtail-config.yml" ] ||
                   [ ! -f "/opt/monitoring/prometheus-rules/container-alerts.yml" ]; then
                    log "❌ La création des fichiers de configuration a échoué"
                    return 1
                fi
            fi
        else
            # Si le script n'existe pas, utiliser les anciennes fonctions
            log "Script generate-config.sh non trouvé, utilisation des fonctions intégrées..."

            if [ ! -f "/opt/monitoring/docker-compose.yml" ]; then
                create_docker_compose_file
            fi

            if [ ! -f "/opt/monitoring/cloudwatch-config/cloudwatch-config.yml" ]; then
                create_cloudwatch_config
            fi

            if [ ! -f "/opt/monitoring/prometheus.yml" ]; then
                create_prometheus_config
            fi

            if [ ! -f "/opt/monitoring/loki-config.yml" ]; then
                create_loki_config
            fi

            if [ ! -f "/opt/monitoring/promtail-config.yml" ]; then
                create_promtail_config
            fi

            if [ ! -f "/opt/monitoring/prometheus-rules/container-alerts.yml" ]; then
                create_container_alerts
            fi

            # Vérifier si les fichiers ont été créés
            if [ ! -f "/opt/monitoring/docker-compose.yml" ] ||
               [ ! -f "/opt/monitoring/cloudwatch-config/cloudwatch-config.yml" ] ||
               [ ! -f "/opt/monitoring/prometheus.yml" ] ||
               [ ! -f "/opt/monitoring/loki-config.yml" ] ||
               [ ! -f "/opt/monitoring/promtail-config.yml" ] ||
               [ ! -f "/opt/monitoring/prometheus-rules/container-alerts.yml" ]; then
                log "❌ La création des fichiers de configuration a échoué"
                return 1
            fi
        fi
    elif [ $config_files_missing -eq 1 ]; then
        status=1
    fi

    log "Vérification des conteneurs Docker..."
    local running_containers=$(docker ps --format "{{.Names}}" | grep -E "prometheus|grafana|mysql-exporter|cloudwatch-exporter" | wc -l)
    if [ $running_containers -lt 4 ]; then
        log "❌ Certains conteneurs ne sont pas en cours d'exécution ($running_containers/4)"
        if [ "$fix_issues" = "true" ]; then
            log "Démarrage des conteneurs..."
            start_containers
            if [ $? -eq 0 ]; then
                log "✅ Conteneurs démarrés avec succès"
            else
                log "❌ Le démarrage des conteneurs a échoué"
                return 1
            fi
        else
            status=1
        fi
    else
        log "✅ Tous les conteneurs sont en cours d'exécution"
    fi

    log "Vérification des ports..."
    local missing_ports=0
    for port in 9090 3000 9104 9106; do
        if ! netstat -tuln | grep -q ":$port"; then
            log "❌ Le port $port n'est pas ouvert"
            missing_ports=1
        fi
    done

    if [ $missing_ports -eq 1 ]; then
        if [ "$fix_issues" = "true" ]; then
            log "Redémarrage des conteneurs pour ouvrir les ports manquants..."
            cd /opt/monitoring
            docker-compose restart
            sleep 10

            # Vérifier à nouveau les ports
            missing_ports=0
            for port in 9090 3000 9104 9106; do
                if ! netstat -tuln | grep -q ":$port"; then
                    log "❌ Le port $port n'est toujours pas ouvert"
                    missing_ports=1
                fi
            done

            if [ $missing_ports -eq 1 ]; then
                log "❌ Certains ports sont toujours fermés après redémarrage"
                return 1
            else
                log "✅ Tous les ports sont maintenant ouverts"
            fi
        else
            status=1
        fi
    else
        log "✅ Tous les ports sont ouverts"
    fi

    # Afficher un résumé
    log "Résumé de la vérification des conteneurs:"
    log "- Docker installé: $(command -v docker &> /dev/null && echo "Oui" || echo "Non")"
    log "- Docker Compose installé: $(command -v docker-compose &> /dev/null && echo "Oui" || echo "Non")"
    log "- Conteneurs en cours d'exécution: $running_containers/4"
    log "- Ports ouverts: $([ $missing_ports -eq 0 ] && echo "Tous" || echo "Certains manquants")"

    return $status
}

# Vérification des droits sudo
if [ "$(id -u)" -ne 0 ]; then
    error_exit "Ce script doit être exécuté avec sudo ou en tant que root"
fi

# Vérification du système d'exploitation
if [ ! -f "/etc/os-release" ] || ! grep -q "Amazon Linux" /etc/os-release; then
    error_exit "Ce script est conçu pour Amazon Linux. Veuillez l'adapter pour votre système d'exploitation."
fi

# Charger les variables d'environnement si elles existent
if [ -f "/opt/monitoring/env.sh" ]; then
    source /opt/monitoring/env.sh
fi

if [ -f "/opt/monitoring/secure/sensitive-env.sh" ]; then
    source /opt/monitoring/secure/sensitive-env.sh
fi

# Définir les variables d'environnement
log "Configuration des variables d'environnement"

# Variables EC2 - Standardisation sur EC2_*
EC2_INSTANCE_PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
EC2_INSTANCE_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
EC2_INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
EC2_INSTANCE_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

# Variables S3 - Standardisation sur S3_*
if [ -z "$S3_BUCKET_NAME" ]; then
    log "La variable S3_BUCKET_NAME n'est pas définie, utilisation de la valeur par défaut yourmedia-ecf-studi"
    S3_BUCKET_NAME="yourmedia-ecf-studi"
fi
export S3_BUCKET_NAME
export AWS_REGION="${AWS_REGION:-eu-west-3}"

# Variables RDS - Standardisation sur RDS_*
if [ -z "$RDS_USERNAME" ] && [ -n "$DB_USERNAME" ]; then
    RDS_USERNAME="$DB_USERNAME"
elif [ -z "$RDS_USERNAME" ]; then
    RDS_USERNAME="yourmedia"
    log "La variable RDS_USERNAME n'est pas définie, utilisation de la valeur par défaut $RDS_USERNAME"
fi
export RDS_USERNAME

if [ -z "$RDS_PASSWORD" ] && [ -n "$DB_PASSWORD" ]; then
    RDS_PASSWORD="$DB_PASSWORD"
elif [ -z "$RDS_PASSWORD" ]; then
    RDS_PASSWORD="password"
    log "La variable RDS_PASSWORD n'est pas définie, utilisation de la valeur par défaut (non sécurisée)"
fi
export RDS_PASSWORD

if [ -z "$RDS_ENDPOINT" ] && [ -n "$DB_ENDPOINT" ]; then
    RDS_ENDPOINT="$DB_ENDPOINT"
elif [ -z "$RDS_ENDPOINT" ]; then
    RDS_ENDPOINT="localhost:3306"
    log "La variable RDS_ENDPOINT n'est pas définie, utilisation de la valeur par défaut $RDS_ENDPOINT"
fi
export RDS_ENDPOINT

# Extraire l'hôte et le port de RDS_ENDPOINT
if [[ "$RDS_ENDPOINT" == *":"* ]]; then
    export RDS_HOST=$(echo "$RDS_ENDPOINT" | cut -d':' -f1)
    export RDS_PORT=$(echo "$RDS_ENDPOINT" | cut -d':' -f2)
else
    export RDS_HOST="$RDS_ENDPOINT"
    export RDS_PORT="3306"
fi

# Variables Grafana - Standardisation sur GRAFANA_*
if [ -z "$GRAFANA_ADMIN_PASSWORD" ] && [ -n "$GF_SECURITY_ADMIN_PASSWORD" ]; then
    GRAFANA_ADMIN_PASSWORD="$GF_SECURITY_ADMIN_PASSWORD"
elif [ -z "$GRAFANA_ADMIN_PASSWORD" ]; then
    GRAFANA_ADMIN_PASSWORD="YourMedia2025!"
    log "La variable GRAFANA_ADMIN_PASSWORD n'est pas définie, utilisation de la valeur par défaut"
fi
export GRAFANA_ADMIN_PASSWORD
export GF_SECURITY_ADMIN_PASSWORD="$GRAFANA_ADMIN_PASSWORD"



# Variables Docker - Standardisation sur DOCKERHUB_*
export DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME:-medsin}"
export DOCKERHUB_REPO="${DOCKERHUB_REPO:-yourmedia-ecf}"
export DOCKER_USERNAME="$DOCKERHUB_USERNAME"
export DOCKER_REPO="$DOCKERHUB_REPO"

# Authentification Docker Hub si les identifiants sont disponibles
if [ ! -z "${DOCKERHUB_USERNAME}" ] && [ ! -z "${DOCKERHUB_TOKEN}" ]; then
    log "Authentification à Docker Hub avec l'utilisateur ${DOCKERHUB_USERNAME}"
    echo "${DOCKERHUB_TOKEN}" | docker login -u "${DOCKERHUB_USERNAME}" --password-stdin
    if [ $? -eq 0 ]; then
        log "✅ Authentification Docker Hub réussie"
    else
        log "❌ Échec de l'authentification Docker Hub"
    fi
else
    log "Aucun identifiant Docker Hub trouvé, les images publiques seront utilisées"
fi

# Variables de compatibilité
export DB_USERNAME="$RDS_USERNAME"
export DB_PASSWORD="$RDS_PASSWORD"
export DB_ENDPOINT="$RDS_ENDPOINT"

log "Variables d'environnement configurées avec succès"

# Création des répertoires nécessaires
log "Création des répertoires nécessaires"
sudo mkdir -p /opt/monitoring/secure
sudo chmod 755 /opt/monitoring
sudo chmod 700 /opt/monitoring/secure

# Créer le fichier de variables d'environnement
log "Création du fichier de variables d'environnement"
sudo bash -c "cat > /opt/monitoring/env.sh << EOL
#!/bin/bash
# Variables d'environnement pour le monitoring
# Généré automatiquement par setup-monitoring.sh
# Date de génération: \$(date)

# Variables EC2
export EC2_INSTANCE_PRIVATE_IP=\"$EC2_INSTANCE_PRIVATE_IP\"
export EC2_INSTANCE_PUBLIC_IP=\"$EC2_INSTANCE_PUBLIC_IP\"
export EC2_INSTANCE_ID=\"$EC2_INSTANCE_ID\"
export EC2_INSTANCE_REGION=\"$EC2_INSTANCE_REGION\"

# Variables S3
export S3_BUCKET_NAME=\"$S3_BUCKET_NAME\"
export AWS_REGION=\"eu-west-3\"

# Variables Docker
export DOCKER_USERNAME=\"${DOCKER_USERNAME:-medsin}\"
export DOCKER_REPO=\"${DOCKER_REPO:-yourmedia-ecf}\"
export DOCKER_PASSWORD=\"${DOCKERHUB_TOKEN:-$DOCKER_PASSWORD}\"
# Variables de compatibilité (pour les scripts existants)
export DOCKERHUB_USERNAME=\"\$DOCKER_USERNAME\"
export DOCKERHUB_REPO=\"\$DOCKER_REPO\"

# Charger les variables sensibles
source /opt/monitoring/secure/sensitive-env.sh 2>/dev/null || true
EOL"

# Créer le fichier de variables sensibles
log "Création du fichier de variables sensibles"
sudo bash -c "cat > /opt/monitoring/secure/sensitive-env.sh << EOL
#!/bin/bash
# Variables sensibles pour le monitoring
# Généré automatiquement par setup-monitoring.sh
# Date de génération: \$(date)

# Variables Docker Hub
export DOCKERHUB_TOKEN=\"${DOCKERHUB_TOKEN:-}\"

# Variables RDS
export RDS_USERNAME=\"$RDS_USERNAME\"
export RDS_PASSWORD=\"$RDS_PASSWORD\"
export RDS_ENDPOINT=\"$RDS_ENDPOINT\"
export RDS_HOST=\"$RDS_HOST\"
export RDS_PORT=\"$RDS_PORT\"

# Variables de compatibilité
export DB_USERNAME=\"$RDS_USERNAME\"
export DB_PASSWORD=\"$RDS_PASSWORD\"
export DB_ENDPOINT=\"$RDS_ENDPOINT\"

# Variables Grafana
export GRAFANA_ADMIN_PASSWORD=\"$GRAFANA_ADMIN_PASSWORD\"
export GF_SECURITY_ADMIN_PASSWORD=\"$GRAFANA_ADMIN_PASSWORD\"
EOL"

# Définir les permissions
sudo chmod 755 /opt/monitoring/env.sh
sudo chmod 600 /opt/monitoring/secure/sensitive-env.sh
sudo chown -R ec2-user:ec2-user /opt/monitoring

# Mise à jour du système
log "Mise à jour du système"
dnf update -y

# Installation des dépendances nécessaires
log "Installation des dépendances"
# Installer jq et wget
dnf install -y jq wget

# Vérifier si aws-cli est installé
log "Installation d'AWS CLI"
if ! command -v aws &> /dev/null; then
    dnf install -y aws-cli || {
        log "Installation d'AWS CLI via le package aws-cli a échoué, tentative avec awscli..."
        dnf install -y awscli
    }
else
    log "AWS CLI est déjà installé, version: $(aws --version)"
fi

# Gérer l'installation de curl séparément pour éviter les conflits avec curl-minimal
log "Installation de curl"
if ! command -v curl &> /dev/null; then
    # Si curl n'est pas installé, l'installer avec --allowerasing pour résoudre les conflits
    dnf install -y --allowerasing curl
else
    log "curl est déjà installé, version: $(curl --version | head -n 1)"
fi

# S'assurer que netstat est installé
log "Installation de net-tools"
if ! command -v netstat &> /dev/null; then
    dnf install -y net-tools
else
    log "net-tools est déjà installé"
fi

# Installation de Docker pour Amazon Linux 2023
log "Installation de Docker"
# Utiliser la fonction install_docker définie plus haut
install_docker

# Installation de Docker Compose
log "Installation de Docker Compose"
# Utiliser la fonction install_docker_compose définie plus haut
install_docker_compose

# Création des répertoires pour les données persistantes
log "Création des répertoires pour les données persistantes"
for dir in prometheus-data grafana-data cloudwatch-config prometheus-rules; do
    mkdir -p "/opt/monitoring/$dir"
done

# Ajuster les permissions
chown -R ec2-user:ec2-user /opt/monitoring
chmod -R 755 /opt/monitoring

# Configurer les limites de ressources système
log "Configuration des limites de ressources système"

# Configurer les limites de ressources pour l'utilisateur ec2-user
if ! grep -q "ec2-user.*nofile" /etc/security/limits.conf; then
    echo "ec2-user soft nofile 4096" | tee -a /etc/security/limits.conf
    echo "ec2-user hard nofile 4096" | tee -a /etc/security/limits.conf
    echo "ec2-user soft nproc 2048" | tee -a /etc/security/limits.conf
    echo "ec2-user hard nproc 2048" | tee -a /etc/security/limits.conf
fi

# Création du fichier docker-compose.yml
log "Création du fichier docker-compose.yml"

# URL du fichier de configuration sur GitHub
GITHUB_RAW_URL="https://raw.githubusercontent.com/${REPO_OWNER:-Med3Sin}/${REPO_NAME:-Studi-YourMedia-ECF}/main"
CONFIG_URL="$GITHUB_RAW_URL/scripts/ec2-monitoring/docker-compose.yml"

# Télécharger le fichier de configuration avec wget
log "Téléchargement du fichier docker-compose.yml depuis $CONFIG_URL"
sudo wget -q -O /opt/monitoring/docker-compose.yml "$CONFIG_URL"

# Vérifier si le téléchargement a réussi
if [ ! -s /opt/monitoring/docker-compose.yml ]; then
    log "ERREUR: Le téléchargement du fichier docker-compose.yml a échoué. Création d'un fichier de base..."

    # Créer un fichier temporaire avec le contenu de base
    sudo bash -c 'cat > /tmp/docker-compose.yml << '\''EOF'\''
version: '\''3'\''

services:
  prometheus:
    image: prom/prometheus:v2.45.0
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - /opt/monitoring/config/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - /opt/monitoring/prometheus-data:/prometheus
      - /opt/monitoring/config/prometheus:/etc/prometheus/rules
    command:
      - '\''--config.file=/etc/prometheus/prometheus.yml'\''
      - '\''--storage.tsdb.path=/prometheus'\''
      - '\''--storage.tsdb.retention.time=15d'\''
      - '\''--storage.tsdb.retention.size=1GB'\''
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 512m

  grafana:
    image: grafana/grafana:10.0.3
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - /opt/monitoring/grafana-data:/var/lib/grafana
      - /opt/monitoring/config/grafana/dashboards:/etc/grafana/provisioning/dashboards
      - /opt/monitoring/config/grafana/datasources:/etc/grafana/provisioning/datasources
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD:-YourMedia2025!}
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

  # Exportateur CloudWatch pour surveiller les services AWS
  cloudwatch-exporter:
    image: prom/cloudwatch-exporter:latest
    container_name: cloudwatch-exporter
    ports:
      - "9106:9106"
    volumes:
      - /opt/monitoring/config/cloudwatch-config.yml:/config/cloudwatch-config.yml
    command: "--config.file=/config/cloudwatch-config.yml"
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 256m

  # Exportateur MySQL pour surveiller RDS
  mysql-exporter:
    image: prom/mysqld-exporter:v0.15.0
    container_name: mysql-exporter
    ports:
      - "9104:9104"
    environment:
      - DATA_SOURCE_NAME=${RDS_USERNAME}:${RDS_PASSWORD}@(${RDS_HOST}:${RDS_PORT})/
    command:
      - '\''--collect.info_schema.tables'\''
      - '\''--collect.info_schema.innodb_metrics'\''
      - '\''--collect.global_status'\''
      - '\''--collect.global_variables'\''
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 256m

  # Node Exporter pour surveiller l'\''instance EC2
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '\''--path.procfs=/host/proc'\''
      - '\''--path.sysfs=/host/sys'\''
      - '\''--path.rootfs=/rootfs'\''
      - '\''--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)($$|/)'\''
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 256m
EOF'
    # Copier le fichier temporaire vers l'emplacement final
    sudo cp /tmp/docker-compose.yml /opt/monitoring/docker-compose.yml
    sudo rm /tmp/docker-compose.yml
fi

# Création du fichier de configuration CloudWatch Exporter
log "Création du fichier de configuration CloudWatch Exporter"
sudo mkdir -p /opt/monitoring/config

# URL du fichier de configuration sur GitHub
GITHUB_RAW_URL="https://raw.githubusercontent.com/${REPO_OWNER:-Med3Sin}/${REPO_NAME:-Studi-YourMedia-ECF}/main"
CONFIG_URL="$GITHUB_RAW_URL/scripts/config/monitoring/cloudwatch-config.yml"

# Télécharger le fichier de configuration avec wget
log "Téléchargement du fichier de configuration CloudWatch depuis $CONFIG_URL"
sudo wget -q -O /opt/monitoring/config/cloudwatch-config.yml "$CONFIG_URL"

# Vérifier si le téléchargement a réussi
if [ ! -s /opt/monitoring/config/cloudwatch-config.yml ]; then
    log "ERREUR: Le téléchargement du fichier de configuration CloudWatch a échoué. Création d'un fichier de base..."

    # Créer un fichier temporaire avec le contenu de base
    sudo bash -c "cat > /tmp/cloudwatch-config.yml << EOF
---
region: ${AWS_REGION:-eu-west-3}
metrics:
  - aws_namespace: AWS/S3
    aws_metric_name: BucketSizeBytes
    aws_dimensions: [BucketName, StorageType]
    aws_dimension_select:
      BucketName: [\"${S3_BUCKET_NAME}\"]
    aws_statistics: [Average]

  - aws_namespace: AWS/S3
    aws_metric_name: NumberOfObjects
    aws_dimensions: [BucketName, StorageType]
    aws_dimension_select:
      BucketName: [\"${S3_BUCKET_NAME}\"]
    aws_statistics: [Average]

  - aws_namespace: AWS/RDS
    aws_metric_name: CPUUtilization
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average]

  - aws_namespace: AWS/RDS
    aws_metric_name: DatabaseConnections
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average]

  - aws_namespace: AWS/RDS
    aws_metric_name: FreeStorageSpace
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average]
EOF"
    # Copier le fichier temporaire vers l'emplacement final
    sudo cp /tmp/cloudwatch-config.yml /opt/monitoring/config/cloudwatch-config.yml
    sudo rm /tmp/cloudwatch-config.yml
fi

# Créer un lien symbolique pour la compatibilité avec les anciens scripts
sudo mkdir -p /opt/monitoring/cloudwatch-config
sudo ln -sf /opt/monitoring/config/cloudwatch-config.yml /opt/monitoring/cloudwatch-config/cloudwatch-config.yml

# Création du fichier prometheus.yml
log "Création du fichier prometheus.yml"
sudo mkdir -p /opt/monitoring/config/prometheus

# URL du fichier de configuration sur GitHub
GITHUB_RAW_URL="https://raw.githubusercontent.com/${REPO_OWNER:-Med3Sin}/${REPO_NAME:-Studi-YourMedia-ECF}/main"
CONFIG_URL="$GITHUB_RAW_URL/scripts/config/prometheus/prometheus.yml"

# Télécharger le fichier de configuration avec wget
log "Téléchargement du fichier prometheus.yml depuis $CONFIG_URL"
sudo wget -q -O /opt/monitoring/config/prometheus/prometheus.yml "$CONFIG_URL"

# Vérifier si le téléchargement a réussi
if [ ! -s /opt/monitoring/config/prometheus/prometheus.yml ]; then
    log "ERREUR: Le téléchargement du fichier prometheus.yml a échoué. Création d'un fichier de base..."

    # Créer un fichier temporaire avec le contenu de base
    sudo bash -c 'cat > /tmp/prometheus.yml << "EOF"
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "/etc/prometheus/rules/*.yml"

scrape_configs:
  - job_name: '\''prometheus'\''
    static_configs:
      - targets: ['\''localhost:9090'\'']

  - job_name: '\''node-exporter'\''
    static_configs:
      - targets: ['\''node-exporter:9100'\'']

  - job_name: '\''mysql-exporter'\''
    static_configs:
      - targets: ['\''mysql-exporter:9104'\'']

  - job_name: '\''cloudwatch-exporter'\''
    static_configs:
      - targets: ['\''cloudwatch-exporter:9106'\'']
EOF'
    # Copier le fichier temporaire vers l'emplacement final
    sudo cp /tmp/prometheus.yml /opt/monitoring/config/prometheus/prometheus.yml
    sudo rm /tmp/prometheus.yml
fi

# Créer un lien symbolique pour la compatibilité avec les anciens scripts
sudo ln -sf /opt/monitoring/config/prometheus/prometheus.yml /opt/monitoring/prometheus.yml

# Création du fichier loki-config.yml
log "Création du fichier loki-config.yml"
sudo mkdir -p /opt/monitoring/config

# URL du fichier de configuration sur GitHub
GITHUB_RAW_URL="https://raw.githubusercontent.com/${REPO_OWNER:-Med3Sin}/${REPO_NAME:-Studi-YourMedia-ECF}/main"
CONFIG_URL="$GITHUB_RAW_URL/scripts/config/loki-config.yml"

# Télécharger le fichier de configuration avec wget
log "Téléchargement du fichier loki-config.yml depuis $CONFIG_URL"
sudo wget -q -O /opt/monitoring/config/loki-config.yml "$CONFIG_URL"

# Vérifier si le téléchargement a réussi
if [ ! -s /opt/monitoring/config/loki-config.yml ]; then
    log "ERREUR: Le téléchargement du fichier loki-config.yml a échoué. Création d'un fichier de base..."

    # Créer un fichier temporaire avec le contenu de base
    sudo bash -c 'cat > /tmp/loki-config.yml << "EOF"
auth_enabled: false

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
EOF'
    # Copier le fichier temporaire vers l'emplacement final
    sudo cp /tmp/loki-config.yml /opt/monitoring/config/loki-config.yml
    sudo rm /tmp/loki-config.yml
fi

# Créer un lien symbolique pour la compatibilité avec les anciens scripts
sudo ln -sf /opt/monitoring/config/loki-config.yml /opt/monitoring/loki-config.yml

# Création du fichier promtail-config.yml
log "Création du fichier promtail-config.yml"
sudo mkdir -p /opt/monitoring/config

# URL du fichier de configuration sur GitHub
GITHUB_RAW_URL="https://raw.githubusercontent.com/${REPO_OWNER:-Med3Sin}/${REPO_NAME:-Studi-YourMedia-ECF}/main"
CONFIG_URL="$GITHUB_RAW_URL/scripts/config/promtail-config.yml"

# Télécharger le fichier de configuration avec wget
log "Téléchargement du fichier promtail-config.yml depuis $CONFIG_URL"
sudo wget -q -O /opt/monitoring/config/promtail-config.yml "$CONFIG_URL"

# Vérifier si le téléchargement a réussi
if [ ! -s /opt/monitoring/config/promtail-config.yml ]; then
    log "ERREUR: Le téléchargement du fichier promtail-config.yml a échoué. Création d'un fichier de base..."

    # Créer un fichier temporaire avec le contenu de base
    sudo bash -c 'cat > /tmp/promtail-config.yml << "EOF"
server:
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
EOF'
    # Copier le fichier temporaire vers l'emplacement final
    sudo cp /tmp/promtail-config.yml /opt/monitoring/config/promtail-config.yml
    sudo rm /tmp/promtail-config.yml
fi

# Créer un lien symbolique pour la compatibilité avec les anciens scripts
sudo ln -sf /opt/monitoring/config/promtail-config.yml /opt/monitoring/promtail-config.yml

# Création du fichier container-alerts.yml
log "Création du fichier container-alerts.yml"
sudo mkdir -p /opt/monitoring/config/prometheus

# URL du fichier de configuration sur GitHub
GITHUB_RAW_URL="https://raw.githubusercontent.com/${REPO_OWNER:-Med3Sin}/${REPO_NAME:-Studi-YourMedia-ECF}/main"
CONFIG_URL="$GITHUB_RAW_URL/scripts/config/prometheus/container-alerts.yml"

# Télécharger le fichier de configuration avec wget
log "Téléchargement du fichier container-alerts.yml depuis $CONFIG_URL"
sudo wget -q -O /opt/monitoring/config/prometheus/container-alerts.yml "$CONFIG_URL"

# Vérifier si le téléchargement a réussi
if [ ! -s /opt/monitoring/config/prometheus/container-alerts.yml ]; then
    log "ERREUR: Le téléchargement du fichier container-alerts.yml a échoué. Création d'un fichier de base..."

    # Créer un fichier temporaire avec le contenu de base
    sudo bash -c 'cat > /tmp/container-alerts.yml << "EOF"
groups:
  - name: containers
    rules:
      - alert: ContainerDown
        expr: absent(container_last_seen{name=~"prometheus|grafana|cloudwatch-exporter|mysql-exporter|node-exporter|loki|promtail"})
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Container {{ $labels.name }} is down"
          description: "Container {{ $labels.name }} has been down for more than 1 minute."

      - alert: ContainerHighCPU
        expr: sum(rate(container_cpu_usage_seconds_total{name=~"prometheus|grafana|cloudwatch-exporter|mysql-exporter|node-exporter|loki|promtail"}[1m])) by (name) > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.name }} high CPU usage"
          description: "Container {{ $labels.name }} CPU usage is above 80% for more than 5 minutes."

      - alert: ContainerHighMemory
        expr: container_memory_usage_bytes{name=~"prometheus|grafana|cloudwatch-exporter|mysql-exporter|node-exporter|loki|promtail"} / container_spec_memory_limit_bytes{name=~"prometheus|grafana|cloudwatch-exporter|mysql-exporter|node-exporter|loki|promtail"} > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.name }} high memory usage"
          description: "Container {{ $labels.name }} memory usage is above 80% for more than 5 minutes."

      - alert: ContainerHighRestarts
        expr: changes(container_start_time_seconds{name=~"prometheus|grafana|cloudwatch-exporter|mysql-exporter|node-exporter|loki|promtail"}[15m]) > 3
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.name }} high restart count"
          description: "Container {{ $labels.name }} has been restarted more than 3 times in the last 15 minutes."
EOF'
    # Copier le fichier temporaire vers l'emplacement final
    sudo cp /tmp/container-alerts.yml /opt/monitoring/config/prometheus/container-alerts.yml
    sudo rm /tmp/container-alerts.yml
fi

# Créer un lien symbolique pour la compatibilité avec les anciens scripts
sudo mkdir -p /opt/monitoring/prometheus-rules
sudo ln -sf /opt/monitoring/config/prometheus/container-alerts.yml /opt/monitoring/prometheus-rules/container-alerts.yml

# Télécharger le script docker-manager.sh depuis S3 si disponible
log "Téléchargement du script docker-manager.sh depuis S3"
if [ ! -z "$S3_BUCKET_NAME" ]; then
    sudo aws s3 cp s3://$S3_BUCKET_NAME/scripts/utils/docker-manager.sh /opt/monitoring/docker-manager.sh || log "Échec du téléchargement du script docker-manager.sh depuis S3"
fi

# Si le téléchargement depuis S3 a échoué, essayer de télécharger depuis GitHub
if [ ! -f "/opt/monitoring/docker-manager.sh" ]; then
    log "Téléchargement du script docker-manager.sh depuis GitHub"

    # URL du script sur GitHub
    GITHUB_RAW_URL="https://raw.githubusercontent.com/${REPO_OWNER:-Med3Sin}/${REPO_NAME:-Studi-YourMedia-ECF}/main"
    SCRIPT_URL="$GITHUB_RAW_URL/scripts/config/monitoring/docker-manager.sh"

    # Télécharger le script avec wget
    log "Téléchargement du script depuis $SCRIPT_URL"
    sudo wget -q -O /opt/monitoring/docker-manager.sh "$SCRIPT_URL"
fi

# Si les deux téléchargements ont échoué, créer une version simplifiée du script
if [ ! -s "/opt/monitoring/docker-manager.sh" ]; then
    log "Création d'une version simplifiée du script docker-manager.sh"
    sudo bash -c 'cat > /tmp/docker-manager.sh << '\''EOF'\''
#!/bin/bash
# Script simplifié de gestion des conteneurs Docker
# Usage: docker-manager.sh [start|stop|restart|status|deploy] [service_name]

# Fonction pour afficher les messages
log() {
    echo "$(date '\''+'\''+%Y-%m-%d %H:%M:%S'\'') - $1"
}

# Fonction pour afficher les erreurs et quitter
error_exit() {
    log "ERREUR: $1"
    exit 1
}

# Vérification des droits sudo
if [ "$(id -u)" -ne 0 ]; then
    error_exit "Ce script doit être exécuté avec sudo ou en tant que root"
fi

# Charger les variables d'\''environnement
if [ -f "/opt/monitoring/env.sh" ]; then
    source /opt/monitoring/env.sh
fi

if [ -f "/opt/monitoring/secure/sensitive-env.sh" ]; then
    source /opt/monitoring/secure/sensitive-env.sh
fi

# Vérifier si Docker est installé
if ! command -v docker &> /dev/null; then
    error_exit "Docker n'\''est pas installé"
fi

# Vérifier si Docker Compose est installé
if ! command -v docker-compose &> /dev/null; then
    error_exit "Docker Compose n'\''est pas installé"
fi

# Vérifier les arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 [start|stop|restart|status|deploy] [service_name]"
    exit 1
fi

ACTION=$1
SERVICE=${2:-all}

# Fonction pour démarrer les conteneurs
start_containers() {
    log "Démarrage des conteneurs..."
    cd /opt/monitoring
    docker-compose up -d $SERVICE
    if [ $? -eq 0 ]; then
        log "Conteneurs démarrés avec succès"
    else
        error_exit "Échec du démarrage des conteneurs"
    fi
}

# Fonction pour arrêter les conteneurs
stop_containers() {
    log "Arrêt des conteneurs..."
    cd /opt/monitoring
    docker-compose down $SERVICE
    if [ $? -eq 0 ]; then
        log "Conteneurs arrêtés avec succès"
    else
        error_exit "Échec de l'\''arrêt des conteneurs"
    fi
}

# Fonction pour redémarrer les conteneurs
restart_containers() {
    log "Redémarrage des conteneurs..."
    cd /opt/monitoring
    docker-compose restart $SERVICE
    if [ $? -eq 0 ]; then
        log "Conteneurs redémarrés avec succès"
    else
        error_exit "Échec du redémarrage des conteneurs"
    fi
}

# Fonction pour afficher le statut des conteneurs
status_containers() {
    log "Statut des conteneurs:"
    docker ps -a
}

# Fonction pour déployer les conteneurs
deploy_containers() {
    log "Déploiement des conteneurs..."
    cd /opt/monitoring

    # Arrêter les conteneurs existants
    docker-compose down

    # Démarrer les conteneurs
    docker-compose up -d

    if [ $? -eq 0 ]; then
        log "Conteneurs déployés avec succès"
    else
        error_exit "Échec du déploiement des conteneurs"
    fi
}

# Exécuter l'\''action demandée
case $ACTION in
    start)
        start_containers
        ;;
    stop)
        stop_containers
        ;;
    restart)
        restart_containers
        ;;
    status)
        status_containers
        ;;
    deploy)
        deploy_containers
        ;;
    *)
        echo "Action non reconnue: $ACTION"
        echo "Usage: $0 [start|stop|restart|status|deploy] [service_name]"
        exit 1
        ;;
esac

exit 0
EOF'
    # Copier le fichier temporaire vers l'emplacement final
    sudo cp /tmp/docker-manager.sh /opt/monitoring/docker-manager.sh
    sudo rm /tmp/docker-manager.sh
fi

# Rendre le script exécutable
sudo chmod +x /opt/monitoring/docker-manager.sh

# Créer un lien symbolique pour le script docker-manager.sh
log "Création d'un lien symbolique pour le script docker-manager.sh"
sudo ln -sf /opt/monitoring/docker-manager.sh /usr/local/bin/docker-manager.sh
sudo chmod +x /usr/local/bin/docker-manager.sh

# Traitement des arguments de ligne de commande
MODE="install"
FORCE=false

# Analyser les arguments
for arg in "$@"; do
    case $arg in
        --check)
            MODE="check"
            shift
            ;;
        --fix)
            MODE="fix"
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [--check] [--fix] [--force]"
            echo ""
            echo "Options:"
            echo "  --check    Vérifie uniquement l'état de l'installation sans rien installer"
            echo "  --fix      Corrige les problèmes détectés"
            echo "  --force    Force la réinstallation même si déjà installé"
            echo "  --help     Affiche cette aide"
            exit 0
            ;;
        *)
            # Argument inconnu
            log "Argument inconnu: $arg"
            echo "Utilisez --help pour afficher l'aide"
            exit 1
            ;;
    esac
done

# Exécuter le mode approprié
case $MODE in
    check)
        log "Mode vérification uniquement"
        check_containers false
        if [ $? -eq 0 ]; then
            log "✅ Vérification terminée avec succès. Tout est correctement configuré."
            exit 0
        else
            log "❌ Vérification terminée avec des erreurs. Utilisez --fix pour corriger les problèmes."
            exit 1
        fi
        ;;
    fix)
        log "Mode correction des problèmes"
        check_containers true
        if [ $? -eq 0 ]; then
            log "✅ Correction terminée avec succès. Tout est correctement configuré."
            exit 0
        else
            log "❌ Correction terminée avec des erreurs. Veuillez vérifier les journaux."
            exit 1
        fi
        ;;
    install)
        # Si les conteneurs sont déjà installés et que --force n'est pas spécifié, vérifier seulement
        if [ -d "/opt/monitoring" ] && [ -f "/opt/monitoring/docker-compose.yml" ] && [ "$FORCE" = "false" ]; then
            log "Les conteneurs semblent déjà installés. Vérification de l'installation..."
            check_containers true
            if [ $? -eq 0 ]; then
                log "✅ Installation et configuration terminées avec succès."
                log "Grafana est accessible à l'adresse http://$EC2_INSTANCE_PUBLIC_IP:3000"
                log "Prometheus est accessible à l'adresse http://$EC2_INSTANCE_PUBLIC_IP:9090"

                exit 0
            else
                log "❌ Des problèmes ont été détectés et n'ont pas pu être corrigés automatiquement."
                exit 1
            fi
        else
            # Installation complète
            log "Mode installation complète"
            if [ "$FORCE" = "true" ]; then
                log "Mode force activé. Réinstallation complète."
                # Arrêter les conteneurs s'ils sont déjà installés
                if [ -f "/opt/monitoring/docker-compose.yml" ]; then
                    log "Arrêt des conteneurs existants..."
                    cd /opt/monitoring
                    docker-compose down
                fi
            fi

            # Connexion à Docker Hub si les identifiants sont disponibles
            if [ ! -z "$DOCKERHUB_USERNAME" ] && [ ! -z "$DOCKERHUB_TOKEN" ]; then
                log "Connexion à Docker Hub avec l'utilisateur $DOCKERHUB_USERNAME"
                echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
            fi

            # Démarrage des conteneurs
            log "Démarrage des conteneurs"
            cd /opt/monitoring

            # Vérifier si docker-compose est installé
            if ! command -v docker-compose &> /dev/null; then
                log "Installation de Docker Compose..."
                sudo wget -q -O /usr/local/bin/docker-compose "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)"
                sudo chmod +x /usr/local/bin/docker-compose
                sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
            fi

            # Vérifier si Docker est en cours d'exécution
            if ! systemctl is-active --quiet docker; then
                log "Démarrage du service Docker..."
                sudo systemctl start docker
                sudo systemctl enable docker
                sleep 5
            fi

            # Démarrer les conteneurs
            log "Exécution de docker-compose up -d"
            docker-compose up -d

            # Vérifier que les conteneurs sont bien démarrés
            sleep 10
            CONTAINER_COUNT=$(docker ps -q | wc -l)
            if [ "$CONTAINER_COUNT" -gt 0 ]; then
                log "✅ Les conteneurs Docker ont été démarrés avec succès"
            else
                log "❌ Aucun conteneur Docker n'est en cours d'exécution. Tentative de redémarrage..."
                docker-compose down
                sleep 5
                docker-compose up -d
                sleep 10
                CONTAINER_COUNT=$(docker ps -q | wc -l)
                if [ "$CONTAINER_COUNT" -gt 0 ]; then
                    log "✅ Les conteneurs Docker ont été démarrés avec succès après une nouvelle tentative"
                else
                    log "❌ Échec du démarrage des conteneurs Docker"
                    log "Vérification des logs Docker..."
                    docker-compose logs
                fi
            fi

            # Vérification du statut des conteneurs
            log "Vérification du statut des conteneurs"
            docker ps

            # Vérifier l'installation
            check_containers true
            if [ $? -eq 0 ]; then
                log "✅ Installation et configuration terminées avec succès."
                log "Grafana est accessible à l'adresse http://$EC2_INSTANCE_PUBLIC_IP:3000"
                log "Prometheus est accessible à l'adresse http://$EC2_INSTANCE_PUBLIC_IP:9090"

                exit 0
            else
                log "❌ L'installation a échoué. Veuillez vérifier les journaux."
                exit 1
            fi
        fi
        ;;
esac

exit 0
