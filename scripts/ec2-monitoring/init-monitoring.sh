#!/bin/bash
#==============================================================================
# Nom du script : init-monitoring.sh
# Description   : Script unifié d'initialisation pour l'instance EC2 de monitoring.
#                 Ce script configure l'environnement de l'instance, télécharge les scripts
#                 nécessaires depuis S3, récupère les variables d'environnement et initialise
#                 les conteneurs Docker.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 2.1
# Date          : 2023-11-15
#==============================================================================
# Utilisation   : sudo ./init-monitoring.sh
#==============================================================================
# Dépendances   :
#   - aws-cli   : Pour télécharger les scripts depuis S3
#   - docker    : Pour gérer les conteneurs
#   - wget      : Pour télécharger les fichiers et récupérer les métadonnées de l'instance
#   - jq        : Pour traiter les fichiers JSON
#==============================================================================

# Journalisation
LOG_FILE="/var/log/init-monitoring.log"
exec > >(tee -a "$LOG_FILE") 2>&1

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

# Création des répertoires nécessaires
log "Création des répertoires nécessaires"
sudo mkdir -p /opt/monitoring/secure
sudo mkdir -p /opt/monitoring/data/prometheus
sudo mkdir -p /opt/monitoring/data/grafana
sudo mkdir -p /opt/monitoring/config
sudo mkdir -p /opt/monitoring/prometheus-rules

# Récupération du nom du bucket S3 depuis les métadonnées de l'instance
log "Récupération du nom du bucket S3 depuis les métadonnées de l'instance"

# Attendre que les métadonnées soient disponibles
MAX_RETRIES=10
RETRY_INTERVAL=5
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    TOKEN=$(sudo curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    INSTANCE_ID=$(sudo curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id || echo "")
    if [ ! -z "$INSTANCE_ID" ]; then
        log "ID de l'instance récupéré: $INSTANCE_ID"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT+1))
    log "Tentative $RETRY_COUNT: Métadonnées non disponibles, nouvelle tentative dans $RETRY_INTERVAL secondes..."
    sleep $RETRY_INTERVAL
done

# Récupérer la région
TOKEN=$(sudo curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
REGION=$(sudo curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region || echo "eu-west-3")
log "Région AWS: $REGION"

# Récupérer le nom du bucket S3 depuis les tags de l'instance
if [ ! -z "$INSTANCE_ID" ]; then
    S3_BUCKET_NAME=$(aws ec2 describe-tags --region "$REGION" --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=S3BucketName" --query "Tags[0].Value" --output text)
else
    S3_BUCKET_NAME="None"
fi

# Si le nom du bucket n'est pas trouvé, utiliser la valeur par défaut
if [ -z "$S3_BUCKET_NAME" ] || [ "$S3_BUCKET_NAME" == "None" ]; then
    log "Nom du bucket S3 non trouvé dans les tags, utilisation de la valeur par défaut"
    # Récupérer le nom du bucket depuis les variables d'environnement Terraform
    S3_BUCKET_NAME="yourmedia-dev-media-797748030261-e6ly5tku"
fi

log "Nom du bucket S3: $S3_BUCKET_NAME"

# Vérification des dépendances essentielles
log "Vérification des dépendances essentielles"
check_dependency() {
    local cmd=$1
    local pkg=$2

    if ! command -v $cmd &> /dev/null; then
        log "Dépendance manquante: $cmd. Installation de $pkg..."
        sudo dnf install -y $pkg || error_exit "Impossible d'installer $pkg"
    fi
}

check_dependency aws aws-cli
check_dependency curl curl
check_dependency jq jq
check_dependency docker docker

# Téléchargement des scripts depuis GitHub
log "Téléchargement des scripts depuis GitHub"
GITHUB_RAW_URL="https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main"

# Installation de wget si nécessaire
if ! command -v wget &> /dev/null; then
    log "Installation de wget"
    sudo dnf install -y wget
fi

# Téléchargement du script de configuration
log "Téléchargement du script setup-monitoring.sh"
sudo wget -q -O /opt/monitoring/setup-monitoring.sh "$GITHUB_RAW_URL/scripts/ec2-monitoring/setup-monitoring.sh"
sudo chmod +x /opt/monitoring/setup-monitoring.sh

# Création d'un fichier env.json avec les valeurs récupérées
log "Création d'un fichier env.json avec les valeurs récupérées"

# Définir des variables par défaut si elles ne sont pas déjà définies
RDS_USERNAME=${RDS_USERNAME:-""}
RDS_PASSWORD=${RDS_PASSWORD:-""}
RDS_ENDPOINT=${RDS_ENDPOINT:-""}
RDS_NAME=${RDS_NAME:-""}
GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-"admin"}
# Utiliser le S3_BUCKET_NAME récupéré précédemment
AWS_REGION=${AWS_REGION:-"eu-west-3"}

# Créer le fichier env.json avec les valeurs définies
cat > /tmp/env.json << EOF
{
  "RDS_USERNAME": "${RDS_USERNAME}",
  "RDS_PASSWORD": "${RDS_PASSWORD}",
  "RDS_ENDPOINT": "${RDS_ENDPOINT}",
  "RDS_NAME": "${RDS_NAME}",
  "GRAFANA_ADMIN_PASSWORD": "${GRAFANA_ADMIN_PASSWORD}",
  "S3_BUCKET_NAME": "${S3_BUCKET_NAME}",
  "AWS_REGION": "${AWS_REGION}"
}
EOF

# Extraction des variables (pour s'assurer qu'elles sont correctement définies)
RDS_USERNAME=$(jq -r '.RDS_USERNAME' /tmp/env.json)
RDS_PASSWORD=$(jq -r '.RDS_PASSWORD' /tmp/env.json)
RDS_ENDPOINT=$(jq -r '.RDS_ENDPOINT' /tmp/env.json)
RDS_NAME=$(jq -r '.RDS_NAME' /tmp/env.json)
GRAFANA_ADMIN_PASSWORD=$(jq -r '.GRAFANA_ADMIN_PASSWORD' /tmp/env.json)
S3_BUCKET_NAME=$(jq -r '.S3_BUCKET_NAME' /tmp/env.json)
AWS_REGION=$(jq -r '.AWS_REGION' /tmp/env.json)
TOKEN=$(sudo curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
MONITORING_EC2_PUBLIC_IP=$(sudo curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)
EC2_INSTANCE_PRIVATE_IP=$(sudo curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)

# Suppression du fichier temporaire
rm /tmp/env.json

# Création du fichier de variables d'environnement
log "Création du fichier de variables d'environnement"
sudo bash -c "cat > /opt/monitoring/secure/.env << EOF
RDS_USERNAME=$RDS_USERNAME
RDS_PASSWORD=$RDS_PASSWORD
RDS_ENDPOINT=$RDS_ENDPOINT
RDS_NAME=$RDS_NAME
GRAFANA_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD
S3_BUCKET_NAME=$S3_BUCKET_NAME
AWS_REGION=$AWS_REGION
MONITORING_EC2_PUBLIC_IP=$MONITORING_EC2_PUBLIC_IP
EC2_INSTANCE_PRIVATE_IP=$EC2_INSTANCE_PRIVATE_IP
EOF"

# Sécurisation du fichier
sudo chmod 600 /opt/monitoring/secure/.env
sudo chown root:root /opt/monitoring/secure/.env

# Création du fichier env.sh pour les scripts shell
log "Création du fichier env.sh pour les scripts shell"
sudo bash -c "cat > /opt/monitoring/env.sh << EOF
#!/bin/bash
# Variables d'environnement pour le monitoring
# Généré automatiquement par init-monitoring-unified.sh
# Date de génération: \$(date)

# Variables EC2
export EC2_INSTANCE_PRIVATE_IP=\"$EC2_INSTANCE_PRIVATE_IP\"
export EC2_INSTANCE_PUBLIC_IP=\"$MONITORING_EC2_PUBLIC_IP\"
export EC2_INSTANCE_ID=\"$INSTANCE_ID\"
export EC2_INSTANCE_REGION=\"$REGION\"

# Variables S3
export S3_BUCKET_NAME=\"$S3_BUCKET_NAME\"
export AWS_REGION=\"$AWS_REGION\"

# Variables RDS
export RDS_USERNAME=\"$RDS_USERNAME\"
export RDS_PASSWORD=\"$RDS_PASSWORD\"
export RDS_ENDPOINT=\"$RDS_ENDPOINT\"
export RDS_NAME=\"$RDS_NAME\"

# Variables Grafana
export GRAFANA_ADMIN_PASSWORD=\"$GRAFANA_ADMIN_PASSWORD\"
export GF_SECURITY_ADMIN_PASSWORD=\"$GRAFANA_ADMIN_PASSWORD\"

# Variables de compatibilité
export DB_USERNAME=\"$RDS_USERNAME\"
export DB_PASSWORD=\"$RDS_PASSWORD\"
export DB_ENDPOINT=\"$RDS_ENDPOINT\"
EOF"

sudo chmod +x /opt/monitoring/env.sh

# Installation de Docker si nécessaire
log "Vérification de l'installation de Docker"
if ! command -v docker &> /dev/null; then
    log "Installation de Docker..."
    sudo dnf install -y docker
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker ec2-user
else
    log "Docker est déjà installé"
    # S'assurer que Docker est démarré
    if ! sudo systemctl is-active --quiet docker; then
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
fi

# Installation de Docker Compose si nécessaire
log "Vérification de l'installation de Docker Compose"
if ! command -v docker-compose &> /dev/null; then
    log "Installation de Docker Compose..."
    sudo wget -q -O /usr/local/bin/docker-compose "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)"
    sudo chmod +x /usr/local/bin/docker-compose
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
else
    log "Docker Compose est déjà installé"
fi

# Téléchargement des fichiers de configuration supplémentaires depuis GitHub
log "Téléchargement des fichiers de configuration supplémentaires depuis GitHub"

# Téléchargement des fichiers de configuration Prometheus
log "Téléchargement des fichiers de configuration Prometheus"
sudo mkdir -p /opt/monitoring/config/prometheus
sudo mkdir -p /opt/monitoring/prometheus/rules

# Création du fichier prometheus.yml
log "Création du fichier prometheus.yml"
sudo bash -c 'cat > /opt/monitoring/prometheus.yml << EOF
global:
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
EOF'

# Création du fichier container-alerts.yml
log "Création du fichier container-alerts.yml"
sudo bash -c 'cat > /opt/monitoring/prometheus/rules/container-alerts.yml << EOF
groups:
  - name: containers
    rules:
      - alert: ContainerDown
        expr: absent(container_last_seen{name=~"prometheus|grafana|node-exporter|loki|promtail"})
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Container {{ \$labels.name }} is down"
          description: "Container {{ \$labels.name }} has been down for more than 1 minute."

      - alert: ContainerHighCPU
        expr: sum(rate(container_cpu_usage_seconds_total{name=~"prometheus|grafana|node-exporter|loki|promtail"}[1m])) by (name) > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ \$labels.name }} high CPU usage"
          description: "Container {{ \$labels.name }} CPU usage is above 80% for more than 5 minutes."

      - alert: ContainerHighMemory
        expr: container_memory_usage_bytes{name=~"prometheus|grafana|node-exporter|loki|promtail"} / container_spec_memory_limit_bytes{name=~"prometheus|grafana|node-exporter|loki|promtail"} > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ \$labels.name }} high memory usage"
          description: "Container {{ \$labels.name }} memory usage is above 80% for more than 5 minutes."

      - alert: ContainerHighRestarts
        expr: changes(container_start_time_seconds{name=~"prometheus|grafana|node-exporter|loki|promtail"}[15m]) > 3
        labels:
          severity: warning
        annotations:
          summary: "Container {{ \$labels.name }} high restart count"
          description: "Container {{ \$labels.name }} has been restarted more than 3 times in the last 15 minutes."
EOF'

# Téléchargement des fichiers de configuration Grafana
log "Configuration de Grafana"
sudo mkdir -p /opt/monitoring/config/grafana/datasources
sudo mkdir -p /opt/monitoring/config/grafana/dashboards

# Création du fichier datasource Prometheus
log "Création du fichier datasource Prometheus"
sudo bash -c 'cat > /opt/monitoring/config/grafana/datasources/prometheus.yml << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
EOF'

# Création du fichier datasource Loki
log "Création du fichier datasource Loki"
sudo bash -c 'cat > /opt/monitoring/config/grafana/datasources/loki.yml << EOF
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    editable: false
EOF'

# Création du fichier dashboard configuration
log "Création du fichier dashboard configuration"
sudo bash -c 'cat > /opt/monitoring/config/grafana/dashboards/default.yml << EOF
apiVersion: 1

providers:
  - name: "Default"
    orgId: 1
    folder: ""
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /var/lib/grafana/dashboards
EOF'

# Téléchargement des fichiers de configuration Loki et Promtail
log "Configuration de Loki et Promtail"

# Création du fichier loki-config.yml
log "Création du fichier loki-config.yml"
sudo mkdir -p /opt/monitoring/config
sudo bash -c 'cat > /opt/monitoring/config/loki-config.yml << EOF
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 5m
  chunk_retain_period: 30s

schema_config:
  configs:
    - from: 2020-05-15
      store: boltdb
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 168h

storage_config:
  boltdb:
    directory: /loki/index

  filesystem:
    directory: /loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
EOF'

# Création du fichier promtail-config.yml
log "Création du fichier promtail-config.yml"
sudo bash -c 'cat > /opt/monitoring/config/promtail-config.yml << EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*log
EOF'

# Téléchargement du fichier docker-compose.yml
log "Téléchargement du fichier docker-compose.yml"
sudo wget -q -O /opt/monitoring/docker-compose.yml "$GITHUB_RAW_URL/scripts/ec2-monitoring/docker-compose.yml"

# Téléchargement des services systemd
log "Téléchargement des services systemd"
sudo wget -q -O /opt/monitoring/container-health-check.service "$GITHUB_RAW_URL/scripts/ec2-monitoring/container-health-check.service"
sudo wget -q -O /opt/monitoring/container-health-check.timer "$GITHUB_RAW_URL/scripts/ec2-monitoring/container-health-check.timer"
sudo wget -q -O /opt/monitoring/container-tests.service "$GITHUB_RAW_URL/scripts/ec2-monitoring/container-tests.service"
sudo wget -q -O /opt/monitoring/container-tests.timer "$GITHUB_RAW_URL/scripts/ec2-monitoring/container-tests.timer"

# Créer des liens symboliques pour la compatibilité avec les anciens scripts
log "Création de liens symboliques pour la compatibilité"
sudo ln -sf /opt/monitoring/config/prometheus/prometheus.yml /opt/monitoring/prometheus.yml
sudo ln -sf /opt/monitoring/config/prometheus/container-alerts.yml /opt/monitoring/prometheus-rules/container-alerts.yml
sudo ln -sf /opt/monitoring/config/cloudwatch-config.yml /opt/monitoring/cloudwatch-config.yml
sudo ln -sf /opt/monitoring/config/loki-config.yml /opt/monitoring/loki-config.yml
sudo ln -sf /opt/monitoring/config/promtail-config.yml /opt/monitoring/promtail-config.yml

# Rendre les scripts exécutables
log "Rendre les scripts exécutables"
sudo find /opt/monitoring -name "*.sh" -exec chmod +x {} \;

# Configurer les limites de ressources système
log "Configuration des limites de ressources système"
if ! grep -q "ec2-user.*nofile" /etc/security/limits.conf; then
    echo "ec2-user soft nofile 4096" | sudo tee -a /etc/security/limits.conf
    echo "ec2-user hard nofile 4096" | sudo tee -a /etc/security/limits.conf
    echo "ec2-user soft nproc 2048" | sudo tee -a /etc/security/limits.conf
    echo "ec2-user hard nproc 2048" | sudo tee -a /etc/security/limits.conf
fi

# Exécution du script de configuration
log "Exécution du script de configuration"
cd /opt/monitoring
source /opt/monitoring/env.sh
sudo ./setup-monitoring.sh

# Installation des services systemd pour la surveillance des conteneurs
log "Installation des services systemd pour la surveillance des conteneurs"
if [ -f "/opt/monitoring/container-health-check.service" ]; then
    sudo cp /opt/monitoring/container-health-check.service /etc/systemd/system/
    sudo cp /opt/monitoring/container-health-check.timer /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable container-health-check.timer
    sudo systemctl start container-health-check.timer
    log "Service container-health-check installé et activé"
fi

if [ -f "/opt/monitoring/container-tests.service" ]; then
    sudo cp /opt/monitoring/container-tests.service /etc/systemd/system/
    sudo cp /opt/monitoring/container-tests.timer /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable container-tests.timer
    sudo systemctl start container-tests.timer
    log "Service container-tests installé et activé"
fi

# Installation du service de nettoyage Docker
log "Installation du service de nettoyage Docker"
sudo wget -q -O /opt/monitoring/docker-cleanup.sh "$GITHUB_RAW_URL/scripts/ec2-monitoring/docker-cleanup.sh"
sudo chmod +x /opt/monitoring/docker-cleanup.sh
sudo wget -q -O /etc/systemd/system/docker-cleanup.service "$GITHUB_RAW_URL/scripts/ec2-monitoring/docker-cleanup.service"
sudo wget -q -O /etc/systemd/system/docker-cleanup.timer "$GITHUB_RAW_URL/scripts/ec2-monitoring/docker-cleanup.timer"
sudo systemctl daemon-reload
sudo systemctl enable docker-cleanup.timer
sudo systemctl start docker-cleanup.timer
log "Service docker-cleanup installé et activé"

# Création du répertoire scripts
log "Création du répertoire scripts"
sudo mkdir -p /opt/monitoring/scripts

# Téléchargement et installation du script de synchronisation des logs Tomcat
log "Téléchargement et installation du script de synchronisation des logs Tomcat"
sudo wget -q -O /opt/monitoring/scripts/sync-tomcat-logs.sh "$GITHUB_RAW_URL/scripts/ec2-monitoring/sync-tomcat-logs.sh"
sudo chmod +x /opt/monitoring/scripts/sync-tomcat-logs.sh

# Installation du service de synchronisation des logs Tomcat
log "Installation du service de synchronisation des logs Tomcat"
sudo wget -q -O /etc/systemd/system/sync-tomcat-logs.service "$GITHUB_RAW_URL/scripts/ec2-monitoring/sync-tomcat-logs.service"
sudo wget -q -O /etc/systemd/system/sync-tomcat-logs.timer "$GITHUB_RAW_URL/scripts/ec2-monitoring/sync-tomcat-logs.timer"
sudo systemctl daemon-reload
sudo systemctl enable sync-tomcat-logs.timer
sudo systemctl start sync-tomcat-logs.timer
log "Service sync-tomcat-logs installé et activé"

# Exécuter le script de synchronisation des logs immédiatement
log "Exécution immédiate du script de synchronisation des logs"
sudo /opt/monitoring/scripts/sync-tomcat-logs.sh

# Téléchargement et installation du script d'initialisation de l'adresse IP de l'instance EC2 Java Tomcat
log "Téléchargement et installation du script d'initialisation de l'adresse IP de l'instance EC2 Java Tomcat"
sudo wget -q -O /opt/monitoring/scripts/init-java-tomcat-ip.sh "$GITHUB_RAW_URL/scripts/ec2-monitoring/init-java-tomcat-ip.sh"
sudo chmod +x /opt/monitoring/scripts/init-java-tomcat-ip.sh

# Téléchargement et installation du script de mise à jour des cibles Prometheus
log "Téléchargement et installation du script de mise à jour des cibles Prometheus"
sudo wget -q -O /opt/monitoring/scripts/update-prometheus-targets.sh "$GITHUB_RAW_URL/scripts/ec2-monitoring/update-prometheus-targets.sh"
sudo chmod +x /opt/monitoring/scripts/update-prometheus-targets.sh

# Téléchargement et installation du script de configuration des clés SSH
log "Téléchargement et installation du script de configuration des clés SSH"
sudo mkdir -p /opt/scripts/utils
sudo wget -q -O /opt/scripts/utils/setup-ssh-keys.sh "$GITHUB_RAW_URL/scripts/utils/setup-ssh-keys.sh"
sudo wget -q -O /opt/scripts/utils/fix-ssh-keys.sh "$GITHUB_RAW_URL/scripts/utils/fix-ssh-keys.sh"
sudo chmod +x /opt/scripts/utils/setup-ssh-keys.sh
sudo chmod +x /opt/scripts/utils/fix-ssh-keys.sh

# Création du répertoire pour les secrets
log "Création du répertoire pour les secrets"
sudo mkdir -p /opt/secrets

# Récupération des secrets GitHub depuis les variables d'environnement
log "Récupération des secrets GitHub depuis les variables d'environnement"
if [ -n "$EC2_SSH_PRIVATE_KEY" ]; then
    log "Stockage de la clé privée SSH"
    echo "$EC2_SSH_PRIVATE_KEY" > /opt/secrets/EC2_SSH_PRIVATE_KEY
    chmod 600 /opt/secrets/EC2_SSH_PRIVATE_KEY
fi

if [ -n "$EC2_SSH_PUBLIC_KEY" ]; then
    log "Stockage de la clé publique SSH"
    echo "$EC2_SSH_PUBLIC_KEY" > /opt/secrets/EC2_SSH_PUBLIC_KEY
    chmod 644 /opt/secrets/EC2_SSH_PUBLIC_KEY
fi

if [ -n "$EC2_KEY_PAIR_NAME" ]; then
    log "Stockage du nom de la paire de clés"
    echo "$EC2_KEY_PAIR_NAME" > /opt/secrets/EC2_KEY_PAIR_NAME
    chmod 644 /opt/secrets/EC2_KEY_PAIR_NAME
fi

# Configuration des clés SSH
log "Configuration des clés SSH"
sudo /opt/scripts/utils/setup-ssh-keys.sh

# Création du répertoire pour les logs Tomcat
log "Création du répertoire pour les logs Tomcat"
sudo mkdir -p /mnt/ec2-java-tomcat-logs

# Installation du service de synchronisation des logs Tomcat
log "Installation du service de synchronisation des logs Tomcat"
sudo wget -q -O /etc/systemd/system/sync-tomcat-logs.service "$GITHUB_RAW_URL/scripts/ec2-monitoring/sync-tomcat-logs.service"
sudo wget -q -O /etc/systemd/system/sync-tomcat-logs.timer "$GITHUB_RAW_URL/scripts/ec2-monitoring/sync-tomcat-logs.timer"

# Téléchargement et installation du script de génération de logs de test
log "Téléchargement et installation du script de génération de logs de test"
sudo wget -q -O /opt/monitoring/scripts/generate-test-logs.sh "$GITHUB_RAW_URL/scripts/ec2-monitoring/generate-test-logs.sh"
sudo chmod +x /opt/monitoring/scripts/generate-test-logs.sh

# Installation du service de génération de logs de test
log "Installation du service de génération de logs de test"
sudo wget -q -O /etc/systemd/system/generate-test-logs.service "$GITHUB_RAW_URL/scripts/ec2-monitoring/generate-test-logs.service"
sudo wget -q -O /etc/systemd/system/generate-test-logs.timer "$GITHUB_RAW_URL/scripts/ec2-monitoring/generate-test-logs.timer"

# Téléchargement et installation du script de copie des tableaux de bord
log "Téléchargement et installation du script de copie des tableaux de bord"
sudo wget -q -O /opt/monitoring/scripts/copy-dashboards.sh "$GITHUB_RAW_URL/scripts/ec2-monitoring/copy-dashboards.sh"
sudo chmod +x /opt/monitoring/scripts/copy-dashboards.sh
sudo systemctl daemon-reload
sudo systemctl enable sync-tomcat-logs.timer
sudo systemctl start sync-tomcat-logs.timer
log "Service sync-tomcat-logs installé et activé"

sudo systemctl enable generate-test-logs.timer
sudo systemctl start generate-test-logs.timer
log "Service generate-test-logs installé et activé"

# Exécution du script de copie des tableaux de bord
log "Exécution du script de copie des tableaux de bord"
sudo /opt/monitoring/scripts/copy-dashboards.sh

# Exécution du script d'initialisation de l'adresse IP de l'instance EC2 Java Tomcat
log "Exécution du script d'initialisation de l'adresse IP de l'instance EC2 Java Tomcat"
sudo /opt/monitoring/scripts/init-java-tomcat-ip.sh

# Téléchargement et installation du script de mise à jour des cibles Prometheus
log "Téléchargement et installation du script de mise à jour des cibles Prometheus"
sudo wget -q -O /opt/monitoring/scripts/update-prometheus-targets.sh "$GITHUB_RAW_URL/scripts/ec2-monitoring/update-prometheus-targets.sh"
sudo chmod +x /opt/monitoring/scripts/update-prometheus-targets.sh

# Copie des fichiers de configuration depuis le répertoire local
log "Copie des fichiers de configuration depuis le répertoire local"
if [ -d "/scripts/config" ]; then
    log "Utilisation des fichiers locaux pour la configuration"
    sudo mkdir -p /opt/monitoring/config
    sudo cp -r /scripts/config/* /opt/monitoring/config/

    # Copie des fichiers de configuration spécifiques
    if [ -f "/scripts/config/prometheus/prometheus.yml" ]; then
        sudo cp /scripts/config/prometheus/prometheus.yml /opt/monitoring/prometheus.yml
    fi

    if [ -f "/scripts/config/loki/loki-config.yml" ]; then
        sudo cp /scripts/config/loki/loki-config.yml /opt/monitoring/loki-config.yml
    fi

    if [ -f "/scripts/config/promtail/promtail-config.yml" ]; then
        sudo cp /scripts/config/promtail/promtail-config.yml /opt/monitoring/promtail-config.yml
    fi

    log "Fichiers de configuration copiés avec succès"
else
    log "Le répertoire local de configuration n'existe pas, utilisation des fichiers téléchargés"
fi

# Installation du service de mise à jour des cibles Prometheus
log "Installation du service de mise à jour des cibles Prometheus"
sudo wget -q -O /etc/systemd/system/update-prometheus-targets.service "$GITHUB_RAW_URL/scripts/ec2-monitoring/update-prometheus-targets.service"
sudo wget -q -O /etc/systemd/system/update-prometheus-targets.timer "$GITHUB_RAW_URL/scripts/ec2-monitoring/update-prometheus-targets.timer"
sudo systemctl daemon-reload
sudo systemctl enable update-prometheus-targets.timer
sudo systemctl start update-prometheus-targets.timer
log "Service update-prometheus-targets installé et activé"

# Authentification Docker Hub
log "Authentification à Docker Hub"

# Vérifier si les variables d'environnement Docker Hub sont définies
if [ -n "$DOCKERHUB_USERNAME" ] && [ -n "$DOCKERHUB_TOKEN" ]; then
    log "Utilisation des variables d'environnement pour l'authentification Docker Hub"

    # Créer le répertoire secure avec des permissions restrictives
    sudo mkdir -p /opt/monitoring/secure
    sudo chmod 700 /opt/monitoring/secure

    # Sauvegarder les variables dans des fichiers pour une utilisation ultérieure
    # Utiliser des permissions très restrictives
    echo "$DOCKERHUB_USERNAME" | sudo tee /opt/monitoring/secure/dockerhub-username.txt > /dev/null
    echo "$DOCKERHUB_TOKEN" | sudo tee /opt/monitoring/secure/dockerhub-token.txt > /dev/null
    sudo chmod 600 /opt/monitoring/secure/dockerhub-token.txt
    sudo chmod 600 /opt/monitoring/secure/dockerhub-username.txt
    sudo chown root:root /opt/monitoring/secure/dockerhub-token.txt
    sudo chown root:root /opt/monitoring/secure/dockerhub-username.txt

    # Authentification avec Docker Hub (sans afficher le token dans les logs)
    log "Tentative d'authentification Docker Hub..."
    # Utiliser un fichier temporaire pour éviter les problèmes de redirection avec sudo
    echo $DOCKERHUB_TOKEN > /tmp/docker_token.txt
    if sudo docker login --username $DOCKERHUB_USERNAME --password-stdin < /tmp/docker_token.txt > /dev/null 2>&1; then
        log "✅ Authentification Docker Hub réussie"
        # Exporter uniquement le nom d'utilisateur pour docker-compose
        export DOCKERHUB_USERNAME="$DOCKERHUB_USERNAME"
        export DOCKERHUB_REPO="${DOCKERHUB_REPO:-yourmedia-ecf}"
    else
        log "❌ Échec de l'authentification Docker Hub"
        log "Tentative d'utilisation des fichiers d'authentification"
    fi
    # Supprimer le fichier temporaire pour des raisons de sécurité
    sudo rm -f /tmp/docker_token.txt
# Vérifier si les fichiers d'authentification Docker Hub existent
elif [ -f "/opt/monitoring/secure/dockerhub-token.txt" ] && [ -f "/opt/monitoring/secure/dockerhub-username.txt" ]; then
    log "Utilisation des fichiers d'authentification pour l'authentification Docker Hub"
    # Utiliser sudo pour lire les fichiers protégés
    DOCKER_USERNAME=$(sudo cat /opt/monitoring/secure/dockerhub-username.txt)

    # Authentification avec Docker Hub (sans afficher le token dans les logs)
    log "Tentative d'authentification Docker Hub..."
    # Utiliser un fichier temporaire pour éviter les problèmes de redirection avec sudo
    sudo cat /opt/monitoring/secure/dockerhub-token.txt > /tmp/docker_token.txt
    if sudo docker login --username $DOCKER_USERNAME --password-stdin < /tmp/docker_token.txt > /dev/null 2>&1; then
        log "✅ Authentification Docker Hub réussie"
        # Exporter uniquement le nom d'utilisateur pour docker-compose
        export DOCKERHUB_USERNAME="$DOCKER_USERNAME"
        export DOCKERHUB_REPO="${DOCKERHUB_REPO:-yourmedia-ecf}"
    else
        log "❌ Échec de l'authentification Docker Hub"
        log "Tentative d'utilisation des images publiques"
    fi
    # Supprimer le fichier temporaire pour des raisons de sécurité
    sudo rm -f /tmp/docker_token.txt
else
    log "❌ Aucune information d'authentification Docker Hub trouvée"
    log "Tentative d'utilisation des images publiques"

    # Modifier le fichier docker-compose.yml pour utiliser des images publiques
    log "Modification du fichier docker-compose.yml pour utiliser des images publiques"
    sudo sed -i "s|image: \${DOCKERHUB_USERNAME:-medsin}/\${DOCKERHUB_REPO:-yourmedia-ecf}:grafana-latest|image: grafana/grafana:latest|g" /opt/monitoring/docker-compose.yml
    sudo sed -i "s|image: \${DOCKERHUB_USERNAME:-medsin}/\${DOCKERHUB_REPO:-yourmedia-ecf}:loki-latest|image: grafana/loki:latest|g" /opt/monitoring/docker-compose.yml
    sudo sed -i "s|image: \${DOCKERHUB_USERNAME:-medsin}/\${DOCKERHUB_REPO:-yourmedia-ecf}:promtail-latest|image: grafana/promtail:latest|g" /opt/monitoring/docker-compose.yml
fi

# Création des répertoires de données avec les bonnes permissions
log "Création des répertoires de données avec les bonnes permissions"
sudo mkdir -p /opt/monitoring/loki/chunks /opt/monitoring/loki/index
sudo mkdir -p /var/lib/grafana
sudo chown -R 472:472 /var/lib/grafana
sudo chmod -R 755 /var/lib/grafana
sudo chmod -R 777 /opt/monitoring/loki

# Démarrer les conteneurs Docker
log "Démarrage des conteneurs Docker"
# Exporter les variables d'environnement pour Docker Compose
# Vérifier si les variables d'environnement sont déjà définies
if [ -z "$DOCKERHUB_USERNAME" ]; then
    if [ -f "/opt/monitoring/secure/dockerhub-username.txt" ]; then
        export DOCKERHUB_USERNAME=$(cat /opt/monitoring/secure/dockerhub-username.txt)
    else
        export DOCKERHUB_USERNAME="medsin"
    fi
fi

if [ -z "$DOCKERHUB_REPO" ]; then
    if [ -f "/opt/monitoring/secure/dockerhub-repo.txt" ]; then
        export DOCKERHUB_REPO=$(cat /opt/monitoring/secure/dockerhub-repo.txt)
    else
        export DOCKERHUB_REPO="yourmedia-ecf"
    fi
fi

# Vérifier si le token Docker Hub est défini et si l'authentification est nécessaire
if [ -z "$DOCKERHUB_TOKEN" ] && [ -f "/opt/monitoring/secure/dockerhub-token.txt" ]; then
    # Réessayer l'authentification si elle n'a pas été faite précédemment
    if ! sudo docker info 2>/dev/null | grep -q "Username:"; then
        log "Tentative d'authentification Docker Hub avec le token stocké"
        DOCKER_USERNAME=$(sudo cat /opt/monitoring/secure/dockerhub-username.txt 2>/dev/null || echo "$DOCKERHUB_USERNAME")
        # Utiliser un fichier temporaire pour éviter les problèmes de redirection avec sudo
        sudo cat /opt/monitoring/secure/dockerhub-token.txt 2>/dev/null > /tmp/docker_token.txt
        if sudo docker login --username $DOCKER_USERNAME --password-stdin < /tmp/docker_token.txt > /dev/null 2>&1; then
            log "✅ Authentification Docker Hub réussie"
            export DOCKERHUB_USERNAME="$DOCKER_USERNAME"
        else
            log "❌ Échec de l'authentification Docker Hub"
        fi
        # Supprimer le fichier temporaire pour des raisons de sécurité
        sudo rm -f /tmp/docker_token.txt
    fi
fi

# Afficher uniquement les informations non sensibles
log "Configuration Docker Hub:"
log "DOCKERHUB_USERNAME: $DOCKERHUB_USERNAME"
log "DOCKERHUB_REPO: $DOCKERHUB_REPO"
log "Statut d'authentification: $(if sudo docker info 2>/dev/null | grep -q "Username:"; then echo "authentifié"; else echo "non authentifié"; fi)"

# Vérifier que Docker est en cours d'exécution
log "Vérification que Docker est en cours d'exécution"
if ! systemctl is-active --quiet docker; then
    log "Docker n'est pas en cours d'exécution, démarrage de Docker..."
    systemctl start docker
    sleep 5
    if ! systemctl is-active --quiet docker; then
        log "❌ Échec du démarrage de Docker"
        log "Vérification des logs Docker..."
        journalctl -u docker --no-pager -n 50
        exit 1
    fi
fi

# Vérifier que docker-compose est installé
log "Vérification que docker-compose est installé"
if ! command -v docker-compose &> /dev/null; then
    log "docker-compose n'est pas installé, installation de docker-compose..."
    wget -q -O /usr/local/bin/docker-compose "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)"
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    if ! command -v docker-compose &> /dev/null; then
        log "❌ Échec de l'installation de docker-compose"
        exit 1
    fi
fi

# Vérifier que le fichier docker-compose.yml existe
log "Vérification que le fichier docker-compose.yml existe"
if [ ! -f "/opt/monitoring/docker-compose.yml" ]; then
    log "Le fichier docker-compose.yml n'existe pas, téléchargement du fichier..."
    wget -q -O /opt/monitoring/docker-compose.yml "https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main/scripts/ec2-monitoring/docker-compose.yml"
    if [ ! -f "/opt/monitoring/docker-compose.yml" ]; then
        log "❌ Échec du téléchargement du fichier docker-compose.yml"
        exit 1
    fi
fi

# Démarrer les conteneurs Docker
cd /opt/monitoring
log "Préparation du démarrage des conteneurs Docker"

# Créer un fichier .env sécurisé pour Docker Compose (sans token)
sudo bash -c "cat > /opt/monitoring/.env << EOF
DOCKERHUB_USERNAME=$DOCKERHUB_USERNAME
DOCKERHUB_REPO=$DOCKERHUB_REPO
EOF"

# Sécuriser le fichier .env
sudo chmod 600 /opt/monitoring/.env
sudo chown root:root /opt/monitoring/.env

# Exécuter docker-compose avec les variables d'environnement
log "Démarrage des conteneurs Docker..."
sudo -E docker-compose up -d

# Vérifier que les conteneurs sont bien démarrés
log "Vérification du démarrage des conteneurs"
sleep 5
CONTAINER_COUNT=$(sudo docker ps -q | wc -l)
if [ "$CONTAINER_COUNT" -gt 0 ]; then
    log "✅ Les conteneurs Docker ont été démarrés avec succès"
else
    log "❌ Aucun conteneur Docker n'est en cours d'exécution. Tentative de démarrage..."
    log "Vérification des logs Docker..."
    sudo docker-compose logs

    log "Arrêt des conteneurs existants..."
    sudo docker-compose down
    sleep 5

    log "Vérification des images Docker..."
    sudo docker images

    log "Tentative de pull des images Docker..."
    sudo docker pull prom/prometheus:latest
    sudo docker pull prom/node-exporter:latest
    sudo docker pull gcr.io/cadvisor/cadvisor:latest

    # Vérifier si l'authentification Docker Hub a réussi
    if sudo docker info | grep -q "Username: $DOCKERHUB_USERNAME"; then
        log "Utilisation des images Docker Hub privées"
        sudo docker pull ${DOCKERHUB_USERNAME}/${DOCKERHUB_REPO}:grafana-latest
        sudo docker pull ${DOCKERHUB_USERNAME}/${DOCKERHUB_REPO}:loki-latest
        sudo docker pull ${DOCKERHUB_USERNAME}/${DOCKERHUB_REPO}:promtail-latest
    else
        log "Utilisation des images Docker Hub publiques"
        # Modifier le fichier docker-compose.yml pour utiliser des images publiques
        log "Modification du fichier docker-compose.yml pour utiliser des images publiques"
        sudo sed -i "s|image: \${DOCKERHUB_USERNAME:-medsin}/\${DOCKERHUB_REPO:-yourmedia-ecf}:grafana-latest|image: grafana/grafana:latest|g" /opt/monitoring/docker-compose.yml
        sudo sed -i "s|image: \${DOCKERHUB_USERNAME:-medsin}/\${DOCKERHUB_REPO:-yourmedia-ecf}:loki-latest|image: grafana/loki:latest|g" /opt/monitoring/docker-compose.yml
        sudo sed -i "s|image: \${DOCKERHUB_USERNAME:-medsin}/\${DOCKERHUB_REPO:-yourmedia-ecf}:promtail-latest|image: grafana/promtail:latest|g" /opt/monitoring/docker-compose.yml

        # Pull des images publiques
        sudo docker pull grafana/grafana:latest
        sudo docker pull grafana/loki:latest
        sudo docker pull grafana/promtail:latest
    fi

    log "Nouvelle tentative de démarrage des conteneurs..."
    sudo -E docker-compose up -d
    sleep 10
    CONTAINER_COUNT=$(sudo docker ps -q | wc -l)
    if [ "$CONTAINER_COUNT" -gt 0 ]; then
        log "✅ Les conteneurs Docker ont été démarrés avec succès après une nouvelle tentative"
    else
        log "❌ Échec du démarrage des conteneurs Docker"
        log "Vérification des logs Docker..."
        sudo docker-compose logs

        log "Tentative de démarrage des conteneurs un par un..."
        sudo -E docker-compose up -d prometheus
        sleep 5
        sudo -E docker-compose up -d node-exporter
        sleep 5
        sudo -E docker-compose up -d cadvisor
        sleep 5
        sudo -E docker-compose up -d loki
        sleep 5
        sudo -E docker-compose up -d promtail
        sleep 5
        sudo -E docker-compose up -d grafana
        sleep 5

        CONTAINER_COUNT=$(sudo docker ps -q | wc -l)
        if [ "$CONTAINER_COUNT" -gt 0 ]; then
            log "✅ Certains conteneurs Docker ont été démarrés avec succès"
        else
            log "❌ Échec du démarrage des conteneurs Docker"
            log "Vérification des logs Docker..."
            sudo docker-compose logs
        fi
    fi
fi

# Afficher les conteneurs en cours d'exécution
log "Liste des conteneurs en cours d'exécution"
sudo docker ps

log "Initialisation terminée avec succès"
