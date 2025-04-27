#!/bin/bash
#==============================================================================
# Nom du script : setup-monitoring.sh
# Description   : Script unifié d'installation et de configuration pour l'instance EC2 Monitoring.
#                 Ce script combine les fonctionnalités de setup.sh, init-instance-env.sh,
#                 install-docker.sh, fix_permissions.sh, fix-containers.sh et fix-exporters.sh.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.1
# Date          : 2025-04-27
#==============================================================================
# Utilisation   : sudo ./setup-monitoring.sh
#
# Options       : Aucune
#
# Exemples      :
#   sudo ./setup-monitoring.sh
#==============================================================================
# Dépendances   :
#   - curl      : Pour télécharger des fichiers et récupérer les métadonnées de l'instance
#   - jq        : Pour le traitement JSON
#   - aws-cli   : Pour interagir avec les services AWS
#   - docker    : Sera installé par le script
#   - docker-compose : Sera installé par le script
#==============================================================================
# Variables d'environnement :
#   - S3_BUCKET_NAME : Nom du bucket S3 contenant les scripts
#   - RDS_USERNAME / DB_USERNAME : Nom d'utilisateur RDS
#   - RDS_PASSWORD / DB_PASSWORD : Mot de passe RDS
#   - RDS_ENDPOINT / DB_ENDPOINT : Point de terminaison RDS
#   - GRAFANA_ADMIN_PASSWORD / GF_SECURITY_ADMIN_PASSWORD : Mot de passe administrateur Grafana
#   - SONAR_JDBC_USERNAME : Nom d'utilisateur pour la base de données SonarQube
#   - SONAR_JDBC_PASSWORD : Mot de passe pour la base de données SonarQube
#   - SONAR_JDBC_URL : URL JDBC pour la base de données SonarQube
#   - DOCKER_USERNAME / DOCKERHUB_USERNAME : Nom d'utilisateur Docker Hub
#   - DOCKER_REPO / DOCKERHUB_REPO : Nom du dépôt Docker Hub
#==============================================================================
# Droits requis : Ce script doit être exécuté avec des privilèges sudo ou en tant que root.
#==============================================================================

set -e

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

# Variables SonarQube - Standardisation sur SONAR_*
export SONAR_JDBC_USERNAME="${SONAR_JDBC_USERNAME:-sonar}"
export SONAR_JDBC_PASSWORD="${SONAR_JDBC_PASSWORD:-sonar123}"
export SONAR_JDBC_URL="${SONAR_JDBC_URL:-jdbc:postgresql://sonarqube-db:5432/sonar}"

# Variables Docker - Standardisation sur DOCKERHUB_*
export DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME:-medsin}"
export DOCKERHUB_REPO="${DOCKERHUB_REPO:-yourmedia-ecf}"
export DOCKER_USERNAME="$DOCKERHUB_USERNAME"
export DOCKER_REPO="$DOCKERHUB_REPO"

# Variables de compatibilité
export DB_USERNAME="$RDS_USERNAME"
export DB_PASSWORD="$RDS_PASSWORD"
export DB_ENDPOINT="$RDS_ENDPOINT"

log "Variables d'environnement configurées avec succès"

# Création des répertoires nécessaires
log "Création des répertoires nécessaires"
mkdir -p /opt/monitoring/secure
chmod 755 /opt/monitoring
chmod 700 /opt/monitoring/secure

# Créer le fichier de variables d'environnement
log "Création du fichier de variables d'environnement"
cat > /opt/monitoring/env.sh << "EOL"
#!/bin/bash
# Variables d'environnement pour le monitoring
# Généré automatiquement par setup-monitoring.sh
# Date de génération: $(date)

# Variables EC2
export EC2_INSTANCE_PRIVATE_IP="$EC2_INSTANCE_PRIVATE_IP"
export EC2_INSTANCE_PUBLIC_IP="$EC2_INSTANCE_PUBLIC_IP"
export EC2_INSTANCE_ID="$EC2_INSTANCE_ID"
export EC2_INSTANCE_REGION="$EC2_INSTANCE_REGION"

# Variables S3
export S3_BUCKET_NAME="$S3_BUCKET_NAME"
export AWS_REGION="eu-west-3"

# Variables Docker
export DOCKER_USERNAME="${DOCKER_USERNAME:-medsin}"
export DOCKER_REPO="${DOCKER_REPO:-yourmedia-ecf}"
export DOCKERHUB_USERNAME="$DOCKER_USERNAME"
export DOCKERHUB_REPO="$DOCKER_REPO"

# Charger les variables sensibles
source /opt/monitoring/secure/sensitive-env.sh 2>/dev/null || true
EOL

# Créer le fichier de variables sensibles
log "Création du fichier de variables sensibles"
cat > /opt/monitoring/secure/sensitive-env.sh << "EOL"
#!/bin/bash
# Variables sensibles pour le monitoring
# Généré automatiquement par setup-monitoring.sh
# Date de génération: $(date)

# Variables Docker Hub
export DOCKERHUB_TOKEN="${DOCKERHUB_TOKEN:-}"

# Variables RDS
export RDS_USERNAME="$RDS_USERNAME"
export RDS_PASSWORD="$RDS_PASSWORD"
export RDS_ENDPOINT="$RDS_ENDPOINT"
export RDS_HOST="$RDS_HOST"
export RDS_PORT="$RDS_PORT"

# Variables de compatibilité
export DB_USERNAME="$RDS_USERNAME"
export DB_PASSWORD="$RDS_PASSWORD"
export DB_ENDPOINT="$RDS_ENDPOINT"

# Variables SonarQube
export SONAR_JDBC_USERNAME="$SONAR_JDBC_USERNAME"
export SONAR_JDBC_PASSWORD="$SONAR_JDBC_PASSWORD"
export SONAR_JDBC_URL="$SONAR_JDBC_URL"

# Variables Grafana
export GRAFANA_ADMIN_PASSWORD="$GRAFANA_ADMIN_PASSWORD"
export GF_SECURITY_ADMIN_PASSWORD="$GRAFANA_ADMIN_PASSWORD"
EOL

# Définir les permissions
chmod 755 /opt/monitoring/env.sh
chmod 600 /opt/monitoring/secure/sensitive-env.sh
chown -R ec2-user:ec2-user /opt/monitoring

# Mise à jour du système
log "Mise à jour du système"
dnf update -y

# Installation des dépendances nécessaires
log "Installation des dépendances"
dnf install -y aws-cli curl jq wget

# Installation de Docker pour Amazon Linux 2023
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

# Installation de Docker Compose
log "Installation de Docker Compose"
if ! command -v docker-compose &> /dev/null; then
    curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # Créer un lien symbolique
    if [ ! -f "/usr/bin/docker-compose" ] && [ ! -L "/usr/bin/docker-compose" ]; then
        ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
    fi
else
    log "Docker Compose est déjà installé"
fi

# Création des répertoires pour les données persistantes
log "Création des répertoires pour les données persistantes"
for dir in prometheus-data grafana-data sonarqube-data/data sonarqube-data/logs sonarqube-data/extensions sonarqube-data/db cloudwatch-config; do
    mkdir -p "/opt/monitoring/$dir"
done

# Ajuster les permissions
chown -R ec2-user:ec2-user /opt/monitoring
chmod -R 755 /opt/monitoring

# Appliquer les prérequis système pour SonarQube
log "Application des prérequis système pour SonarQube"

# Augmenter la limite de mmap count (nécessaire pour Elasticsearch)
if grep -q "vm.max_map_count" /etc/sysctl.conf; then
    sed -i 's/vm.max_map_count=.*/vm.max_map_count=262144/' /etc/sysctl.conf
else
    echo "vm.max_map_count=262144" | tee -a /etc/sysctl.conf
fi
sysctl -w vm.max_map_count=262144

# Augmenter la limite de fichiers ouverts
if grep -q "fs.file-max" /etc/sysctl.conf; then
    sed -i 's/fs.file-max=.*/fs.file-max=65536/' /etc/sysctl.conf
else
    echo "fs.file-max=65536" | tee -a /etc/sysctl.conf
fi
sysctl -w fs.file-max=65536

# Configurer les limites de ressources pour l'utilisateur ec2-user
if ! grep -q "ec2-user.*nofile" /etc/security/limits.conf; then
    echo "ec2-user soft nofile 65536" | tee -a /etc/security/limits.conf
    echo "ec2-user hard nofile 65536" | tee -a /etc/security/limits.conf
    echo "ec2-user soft nproc 4096" | tee -a /etc/security/limits.conf
    echo "ec2-user hard nproc 4096" | tee -a /etc/security/limits.conf
fi

# Définir les permissions appropriées pour SonarQube
chown -R 1000:1000 /opt/monitoring/sonarqube-data/data
chown -R 1000:1000 /opt/monitoring/sonarqube-data/logs
chown -R 1000:1000 /opt/monitoring/sonarqube-data/extensions
chown -R 999:999 /opt/monitoring/sonarqube-data/db

# Création du fichier docker-compose.yml
log "Création du fichier docker-compose.yml"
cat > /opt/monitoring/docker-compose.yml << 'EOF'
version: '3'

services:
  prometheus:
    image: prom/prometheus:v2.45.0
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - /opt/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - /opt/monitoring/prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=15d'
      - '--storage.tsdb.retention.size=1GB'
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

  # Base de données PostgreSQL pour SonarQube
  sonarqube-db:
    image: postgres:13
    container_name: sonarqube-db
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_USER=${SONAR_JDBC_USERNAME}
      - POSTGRES_PASSWORD=${SONAR_JDBC_PASSWORD}
      - POSTGRES_DB=sonar
    volumes:
      - /opt/monitoring/sonarqube-data/db:/var/lib/postgresql/data
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 512m

  # SonarQube pour l'analyse de code
  sonarqube:
    image: sonarqube:9.9-community
    container_name: sonarqube
    depends_on:
      - sonarqube-db
    ports:
      - "9000:9000"
    environment:
      - SONAR_JDBC_URL=${SONAR_JDBC_URL}
      - SONAR_JDBC_USERNAME=${SONAR_JDBC_USERNAME}
      - SONAR_JDBC_PASSWORD=${SONAR_JDBC_PASSWORD}
    volumes:
      - /opt/monitoring/sonarqube-data/data:/opt/sonarqube/data
      - /opt/monitoring/sonarqube-data/logs:/opt/sonarqube/logs
      - /opt/monitoring/sonarqube-data/extensions:/opt/sonarqube/extensions
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 1g
    ulimits:
      nofile:
        soft: 65536
        hard: 65536

  # Exportateur CloudWatch pour surveiller les services AWS
  cloudwatch-exporter:
    image: prom/cloudwatch-exporter:latest
    container_name: cloudwatch-exporter
    ports:
      - "9106:9106"
    volumes:
      - /opt/monitoring/cloudwatch-config:/config
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
      - '--collect.info_schema.tables'
      - '--collect.info_schema.innodb_metrics'
      - '--collect.global_status'
      - '--collect.global_variables'
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 256m
EOF

# Création du fichier de configuration CloudWatch Exporter
log "Création du fichier de configuration CloudWatch Exporter"
cat > /opt/monitoring/cloudwatch-config/cloudwatch-config.yml << EOF
---
region: ${AWS_REGION:-eu-west-3}
metrics:
  - aws_namespace: AWS/S3
    aws_metric_name: BucketSizeBytes
    aws_dimensions: [BucketName, StorageType]
    aws_dimension_select:
      BucketName: ["${S3_BUCKET_NAME}"]
    aws_statistics: [Average]

  - aws_namespace: AWS/S3
    aws_metric_name: NumberOfObjects
    aws_dimensions: [BucketName, StorageType]
    aws_dimension_select:
      BucketName: ["${S3_BUCKET_NAME}"]
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
EOF

# Création du fichier prometheus.yml
log "Création du fichier prometheus.yml"
cat > /opt/monitoring/prometheus.yml << "EOF"
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'mysql-exporter'
    static_configs:
      - targets: ['mysql-exporter:9104']

  - job_name: 'cloudwatch-exporter'
    static_configs:
      - targets: ['cloudwatch-exporter:9106']
EOF

# Télécharger le script docker-manager.sh depuis S3 si disponible
log "Téléchargement du script docker-manager.sh depuis S3"
if [ ! -z "$S3_BUCKET_NAME" ]; then
    aws s3 cp s3://$S3_BUCKET_NAME/scripts/docker/docker-manager.sh /opt/monitoring/docker-manager.sh || log "Échec du téléchargement du script docker-manager.sh depuis S3"
fi

# Si le téléchargement a échoué, créer une version simplifiée du script
if [ ! -f "/opt/monitoring/docker-manager.sh" ]; then
    log "Création d'une version simplifiée du script docker-manager.sh"
    cat > /opt/monitoring/docker-manager.sh << 'EOF'
#!/bin/bash
# Script simplifié de gestion des conteneurs Docker
# Usage: docker-manager.sh [start|stop|restart|status|deploy] [service_name]

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

# Connexion à Docker Hub si les identifiants sont disponibles
if [ ! -z "$DOCKERHUB_USERNAME" ] && [ ! -z "$DOCKERHUB_TOKEN" ]; then
    log "Connexion à Docker Hub avec l'utilisateur $DOCKERHUB_USERNAME"
    echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
fi

# Démarrage des conteneurs
log "Démarrage des conteneurs"
cd /opt/monitoring
docker-compose up -d

# Vérification du statut des conteneurs
log "Vérification du statut des conteneurs"
docker ps

log "Installation et configuration terminées avec succès"
log "Grafana est accessible à l'adresse http://$EC2_INSTANCE_PUBLIC_IP:3000"
log "Prometheus est accessible à l'adresse http://$EC2_INSTANCE_PUBLIC_IP:9090"
log "SonarQube est accessible à l'adresse http://$EC2_INSTANCE_PUBLIC_IP:9000"

exit 0
