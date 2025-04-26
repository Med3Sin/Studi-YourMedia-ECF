#!/bin/bash
# Script d'installation et de configuration des conteneurs Docker pour le monitoring
#
# EXIGENCES EN MATIÈRE DE DROITS :
# Ce script doit être exécuté avec des privilèges sudo ou en tant que root.
# Exemple d'utilisation : sudo ./setup.sh
#
# Le script vérifie automatiquement les droits et demandera sudo si nécessaire.

# Charger les variables d'environnement si elles existent
if [ -f "/opt/monitoring/env.sh" ]; then
    echo "Chargement des variables d'environnement depuis /opt/monitoring/env.sh"
    source /opt/monitoring/env.sh
fi

# Charger les variables sensibles si elles existent
if [ -f "/opt/monitoring/secure/sensitive-env.sh" ]; then
    echo "Chargement des variables sensibles depuis /opt/monitoring/secure/sensitive-env.sh"
    source /opt/monitoring/secure/sensitive-env.sh
fi

# Variables standardisées (peuvent être remplacées par des variables d'environnement)
# Variables EC2
export EC2_JAVA_TOMCAT_IP="${EC2_JAVA_TOMCAT_IP:-PLACEHOLDER_IP}"

# Variables RDS standardisées
export RDS_USERNAME="${RDS_USERNAME:-PLACEHOLDER_USERNAME}"
export RDS_PASSWORD="${RDS_PASSWORD:-PLACEHOLDER_PASSWORD}"
export RDS_ENDPOINT="${RDS_ENDPOINT:-PLACEHOLDER_ENDPOINT}"

# Extraire l'hôte et le port de RDS_ENDPOINT
if [[ "$RDS_ENDPOINT" == *":"* ]]; then
    export RDS_HOST=$(echo "$RDS_ENDPOINT" | cut -d':' -f1)
    export RDS_PORT=$(echo "$RDS_ENDPOINT" | cut -d':' -f2)
else
    export RDS_HOST="$RDS_ENDPOINT"
    export RDS_PORT="3306"
fi

# Variables de compatibilité (pour les scripts existants)
export DB_USERNAME="$RDS_USERNAME"
export DB_PASSWORD="$RDS_PASSWORD"
export DB_ENDPOINT="$RDS_ENDPOINT"
# Variables SonarQube
export SONAR_JDBC_USERNAME="${SONAR_JDBC_USERNAME:-sonar}"
export SONAR_JDBC_PASSWORD="${SONAR_JDBC_PASSWORD:-sonar123}"
export SONAR_JDBC_URL="${SONAR_JDBC_URL:-jdbc:postgresql://sonarqube-db:5432/sonar}"
# Variables Grafana
export GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-YourMedia2025!}"
export GF_SECURITY_ADMIN_PASSWORD="$GRAFANA_ADMIN_PASSWORD"

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Fonction pour afficher les erreurs et quitter
error_exit() {
    log "ERREUR: $1"
    exit 1
}

# Vérification de sécurité pour les mots de passe par défaut
if [ "$GRAFANA_ADMIN_PASSWORD" = "admin" ]; then
    log "AVERTISSEMENT: Mot de passe Grafana par défaut détecté. Il est recommandé de le changer."
    # Définir un mot de passe plus sécurisé
    export GRAFANA_ADMIN_PASSWORD="YourMedia2025!"
    export GF_SECURITY_ADMIN_PASSWORD="$GRAFANA_ADMIN_PASSWORD"
    log "Mot de passe Grafana défini sur une valeur plus sécurisée."
fi

if [ "$SONAR_JDBC_PASSWORD" = "sonar123" ]; then
    log "AVERTISSEMENT: Mot de passe SonarQube par défaut détecté. Il est recommandé de le changer."
fi

# Vérification des dépendances
check_dependency() {
    local cmd=$1
    local pkg=$2

    if ! command -v $cmd &> /dev/null; then
        log "Dépendance manquante: $cmd. Installation de $pkg..."
        sudo dnf install -y $pkg || error_exit "Impossible d'installer $pkg"
    fi
}

# Vérification des prérequis
log "Vérification des prérequis..."
if [ ! -f "/etc/os-release" ] || ! grep -q "Amazon Linux" /etc/os-release; then
    error_exit "Ce script est conçu pour Amazon Linux. Veuillez l'adapter pour votre système d'exploitation."
fi

# Vérification des droits sudo
if [ "$(id -u)" -ne 0 ]; then
    log "Ce script nécessite des privilèges sudo."
    if sudo -n true 2>/dev/null; then
        log "Privilèges sudo disponibles sans mot de passe."
    else
        log "Tentative d'obtention des privilèges sudo..."
        if ! sudo -v; then
            error_exit "Impossible d'obtenir les privilèges sudo. Veuillez exécuter ce script avec sudo ou en tant que root."
        fi
        log "Privilèges sudo obtenus avec succès."
    fi
fi

# Vérification des dépendances essentielles
log "Vérification des dépendances essentielles"
check_dependency curl curl
check_dependency sed sed

# Installation des dépendances
log "Installation des dépendances..."
sudo dnf update -y

# Vérification si Docker est déjà installé
if ! command -v docker &> /dev/null; then
    log "Installation de Docker..."
    # Utiliser le script d'installation de Docker amélioré
    if [ -f "/opt/monitoring/install-docker.sh" ]; then
        log "Utilisation du script install-docker.sh..."
        sudo /opt/monitoring/install-docker.sh
    else
        log "Le script install-docker.sh n'est pas disponible. Installation native pour Amazon Linux 2023..."
        # Installation native pour Amazon Linux 2023
        log "Système détecté: Amazon Linux 2023"
        log "Installation des paquets nécessaires"
        sudo dnf update -y

        log "Installation de Docker natif pour Amazon Linux 2023"
        sudo dnf install -y docker

        log "Démarrage et activation du service Docker"
        sudo systemctl start docker
        sudo systemctl enable docker

        # Créer le groupe docker s'il n'existe pas
        getent group docker &>/dev/null || sudo groupadd docker

        # Ajouter l'utilisateur ec2-user au groupe docker
        sudo usermod -aG docker ec2-user
        log "Utilisateur ec2-user ajouté au groupe docker"
    fi
else
    log "Docker est déjà installé."
    # S'assurer que Docker est démarré
    if ! sudo systemctl is-active --quiet docker; then
        log "Démarrage de Docker..."
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
    # S'assurer que l'utilisateur ec2-user est dans le groupe docker
    if ! groups ec2-user | grep -q docker; then
        log "Ajout de l'utilisateur ec2-user au groupe docker..."
        sudo usermod -a -G docker ec2-user
    fi
fi

# Vérification si Docker Compose est déjà installé
if ! command -v docker-compose &> /dev/null; then
    log "Installation de Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    # Créer un lien symbolique si /usr/bin/docker-compose n'existe pas
    if [ ! -f "/usr/bin/docker-compose" ] && [ ! -L "/usr/bin/docker-compose" ]; then
        sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
    fi

    # Vérifier l'installation
    if ! command -v docker-compose &> /dev/null; then
        error_exit "L'installation de Docker Compose a échoué."
    fi
else
    log "Docker Compose est déjà installé."
    docker-compose --version
fi

# Création des répertoires pour les données persistantes
log "Création des répertoires pour les données persistantes..."

# Vérifier si le répertoire principal existe déjà
if [ ! -d "/opt/monitoring" ]; then
    sudo mkdir -p /opt/monitoring
fi

# Créer les sous-répertoires nécessaires
for dir in prometheus-data grafana-data sonarqube-data/data sonarqube-data/logs sonarqube-data/extensions sonarqube-data/db; do
    if [ ! -d "/opt/monitoring/$dir" ]; then
        log "Création du répertoire /opt/monitoring/$dir"
        sudo mkdir -p "/opt/monitoring/$dir"
    fi
done

# Ajuster les permissions
sudo chown -R ec2-user:ec2-user /opt/monitoring
sudo chmod -R 755 /opt/monitoring

# Appliquer les prérequis système pour SonarQube
log "Application des prérequis système pour SonarQube..."

# Augmenter la limite de mmap count (nécessaire pour Elasticsearch)
if grep -q "vm.max_map_count" /etc/sysctl.conf; then
    log "La configuration vm.max_map_count existe déjà, mise à jour..."
    sudo sed -i 's/vm.max_map_count=.*/vm.max_map_count=262144/' /etc/sysctl.conf
else
    log "Ajout de vm.max_map_count=262144 à /etc/sysctl.conf"
    echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
fi
sudo sysctl -w vm.max_map_count=262144

# Augmenter la limite de fichiers ouverts
if grep -q "fs.file-max" /etc/sysctl.conf; then
    log "La configuration fs.file-max existe déjà, mise à jour..."
    sudo sed -i 's/fs.file-max=.*/fs.file-max=65536/' /etc/sysctl.conf
else
    log "Ajout de fs.file-max=65536 à /etc/sysctl.conf"
    echo "fs.file-max=65536" | sudo tee -a /etc/sysctl.conf
fi
sudo sysctl -w fs.file-max=65536

# Configurer les limites de ressources pour l'utilisateur ec2-user
if ! grep -q "ec2-user.*nofile" /etc/security/limits.conf; then
    log "Ajout des limites de ressources pour l'utilisateur ec2-user"
    echo "ec2-user soft nofile 65536" | sudo tee -a /etc/security/limits.conf
    echo "ec2-user hard nofile 65536" | sudo tee -a /etc/security/limits.conf
    echo "ec2-user soft nproc 4096" | sudo tee -a /etc/security/limits.conf
    echo "ec2-user hard nproc 4096" | sudo tee -a /etc/security/limits.conf
fi

# Définir les permissions appropriées pour SonarQube
sudo chown -R 1000:1000 /opt/monitoring/sonarqube-data/data
sudo chown -R 1000:1000 /opt/monitoring/sonarqube-data/logs
sudo chown -R 1000:1000 /opt/monitoring/sonarqube-data/extensions
sudo chown -R 999:999 /opt/monitoring/sonarqube-data/db

# Exécution du script pour récupérer les informations RDS et S3
log "Exécution du script pour récupérer les informations RDS et S3..."
if [ -f "/opt/monitoring/get-aws-resources-info.sh" ]; then
    log "Utilisation du script get-aws-resources-info.sh..."
    sudo chmod +x /opt/monitoring/get-aws-resources-info.sh
    sudo /opt/monitoring/get-aws-resources-info.sh

    # Charger les variables d'environnement
    if [ -f "/opt/monitoring/aws-resources.env" ]; then
        log "Chargement des variables d'environnement depuis aws-resources.env..."
        source /opt/monitoring/aws-resources.env
    else
        log "AVERTISSEMENT: Le fichier aws-resources.env n'a pas été créé."
    fi
else
    log "AVERTISSEMENT: Le script get-aws-resources-info.sh n'est pas disponible."
    log "Création manuelle du fichier aws-resources.env..."

    # Créer un fichier de variables d'environnement minimal
    cat > /opt/monitoring/aws-resources.env << EOF
# Fichier généré manuellement par setup.sh
# Date de génération: $(date)

# Informations RDS
export RDS_ENDPOINT="${rds_endpoint}"
export RDS_USERNAME="${rds_username}"
export RDS_PASSWORD="${rds_password}"
# Variables de compatibilité (pour les scripts existants)
export DB_USERNAME="${rds_username}"
export DB_PASSWORD="${rds_password}"
export DB_ENDPOINT="${rds_endpoint}"

# Informations pour SonarQube
export SONAR_JDBC_URL="${sonar_jdbc_url}"
export SONAR_JDBC_USERNAME="${sonar_jdbc_username}"
export SONAR_JDBC_PASSWORD="${sonar_jdbc_password}"

# Informations pour Grafana
export GRAFANA_ADMIN_PASSWORD="${grafana_admin_password}"
EOF

    # Charger les variables d'environnement
    source /opt/monitoring/aws-resources.env
fi

# Utiliser le docker-compose.yml du répertoire scripts/ec2-monitoring
log "Copie du fichier docker-compose.yml depuis le répertoire scripts/ec2-monitoring..."
if [ -f "/opt/monitoring/docker-compose.yml.template" ]; then
    log "Utilisation du fichier docker-compose.yml.template..."
    cp /opt/monitoring/docker-compose.yml.template /opt/monitoring/docker-compose.yml
else
    log "Création du fichier docker-compose.yml..."
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
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 512m
    cpu_shares: 512

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
    cpu_shares: 512

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
    cpu_shares: 512

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
    cpu_shares: 1024
    ulimits:
      nofile:
        soft: 65536
        hard: 65536

  # Exportateur CloudWatch pour surveiller les services AWS (S3, RDS, EC2)
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
    cpu_shares: 256

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
    cpu_shares: 256
EOF
fi

# Création du répertoire pour CloudWatch Exporter
log "Création du répertoire pour CloudWatch Exporter..."
mkdir -p /opt/monitoring/cloudwatch-config

# Création du fichier de configuration CloudWatch Exporter
log "Création du fichier de configuration CloudWatch Exporter..."
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
log "Création du fichier prometheus.yml..."
cat > /opt/monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          # - alertmanager:9093

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

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

  - job_name: 'tomcat'
    metrics_path: '/metrics'
    static_configs:
      - targets: ['${ec2_java_tomcat_ip}:8080']
EOF

# Remplacement des variables dans le fichier prometheus.yml
log "Remplacement des variables dans le fichier prometheus.yml..."
sudo sed -i "s/\${ec2_java_tomcat_ip}/${ec2_java_tomcat_ip}/g" /opt/monitoring/prometheus.yml

# Démarrage des conteneurs
log "Démarrage des conteneurs..."

# Vérifier si des conteneurs sont déjà en cours d'exécution
RUNNING_CONTAINERS=$(sudo docker ps --filter "name=prometheus|grafana|sonarqube" --format "{{.Names}}" | wc -l)
if [ "$RUNNING_CONTAINERS" -gt 0 ]; then
    log "Des conteneurs sont déjà en cours d'exécution. Arrêt des conteneurs existants..."
    cd /opt/monitoring
    sudo docker-compose down || log "Erreur lors de l'arrêt des conteneurs. Tentative de continuer..."
fi

# Exécuter le script de correction des permissions avant de démarrer les conteneurs
if [ -f "/opt/monitoring/fix_permissions.sh" ]; then
    log "Exécution du script de correction des permissions avant le démarrage..."
    sudo /opt/monitoring/fix_permissions.sh
fi

# Connexion à Docker Hub si les identifiants sont disponibles
if [ ! -z "$DOCKERHUB_USERNAME" ] && [ ! -z "$DOCKERHUB_TOKEN" ]; then
    log "Connexion à Docker Hub..."
    echo "$DOCKERHUB_TOKEN" | sudo docker login -u "$DOCKERHUB_USERNAME" --password-stdin
fi

# Utiliser docker-manager.sh si disponible, sinon utiliser docker-compose directement
if [ -f "/usr/local/bin/docker-manager.sh" ]; then
    log "Utilisation de docker-manager.sh pour déployer les conteneurs..."
    # Définir explicitement le mot de passe Grafana pour docker-manager.sh
    export GF_SECURITY_ADMIN_PASSWORD="$grafana_admin_password"
    sudo -E /usr/local/bin/docker-manager.sh deploy monitoring

    # Vérifier si le déploiement a réussi
    if [ $? -ne 0 ]; then
        log "Erreur lors du déploiement avec docker-manager.sh. Tentative avec docker-compose..."
        cd /opt/monitoring
        sudo -E docker-compose up -d
    fi
else
    log "Le script docker-manager.sh n'est pas disponible. Utilisation de docker-compose..."
    cd /opt/monitoring
    # Définir explicitement le mot de passe Grafana pour docker-compose
    export GF_SECURITY_ADMIN_PASSWORD="$grafana_admin_password"
    sudo -E docker-compose up -d
fi

# Vérification du statut des conteneurs
log "Vérification du statut des conteneurs..."
sudo docker ps

# Vérifier si tous les conteneurs sont en cours d'exécution
EXPECTED_CONTAINERS=6  # prometheus, node-exporter, mysql-exporter, grafana, sonarqube-db, sonarqube
RUNNING_CONTAINERS=$(sudo docker ps --filter "name=prometheus|grafana|sonarqube|node-exporter|mysql-exporter" --format "{{.Names}}" | wc -l)

if [ "$RUNNING_CONTAINERS" -lt "$EXPECTED_CONTAINERS" ]; then
    log "AVERTISSEMENT: Certains conteneurs ne sont pas en cours d'exécution. Vérifiez les logs pour plus d'informations."
    sudo docker ps -a
    log "Logs des conteneurs qui ont échoué:"
    for container in prometheus grafana sonarqube sonarqube-db node-exporter mysql-exporter; do
        if ! sudo docker ps --filter "name=$container" --format "{{.Names}}" | grep -q "$container"; then
            log "Logs du conteneur $container:"
            sudo docker logs $container 2>&1 | tail -n 20
        fi
    done
else
    log "Tous les conteneurs sont en cours d'exécution."
fi

# Exécution du script de correction des permissions
log "Exécution du script de correction des permissions..."
if [ -f "/opt/monitoring/fix_permissions.sh" ]; then
    sudo /opt/monitoring/fix_permissions.sh
else
    log "AVERTISSEMENT: Le script fix_permissions.sh n'est pas disponible."
    # Correction manuelle des permissions
    sudo chown -R ec2-user:ec2-user /opt/monitoring
    sudo chmod -R 755 /opt/monitoring
fi

# Configuration d'une tâche cron pour vérifier périodiquement l'état des conteneurs
log "Configuration d'une tâche cron pour vérifier périodiquement l'état des conteneurs..."
if [ -f "/opt/monitoring/check-containers.sh" ]; then
    # Rendre le script exécutable
    sudo chmod +x /opt/monitoring/check-containers.sh

    # Créer un fichier crontab temporaire
    cat > /tmp/monitoring-crontab << EOF
# Vérifier l'état des conteneurs toutes les 15 minutes
*/15 * * * * /usr/bin/sudo /opt/monitoring/check-containers.sh >> /var/log/container-check.log 2>&1
EOF

    # Installer la tâche cron pour l'utilisateur root
    sudo crontab -u root /tmp/monitoring-crontab

    # Supprimer le fichier temporaire
    rm -f /tmp/monitoring-crontab

    log "Tâche cron configurée avec succès."
else
    log "AVERTISSEMENT: Le script check-containers.sh n'existe pas. La tâche cron n'a pas été configurée."
fi

log "Installation et configuration terminées avec succès."
log "Grafana est accessible à l'adresse http://localhost:3000"
log "Prometheus est accessible à l'adresse http://localhost:9090"
log "SonarQube est accessible à l'adresse http://localhost:9000"

exit 0
