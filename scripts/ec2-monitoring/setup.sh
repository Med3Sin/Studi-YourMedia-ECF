#!/bin/bash
# Script d'installation et de configuration des conteneurs Docker pour le monitoring

# Variables (peuvent être remplacées par des variables d'environnement)
ec2_java_tomcat_ip="${EC2_JAVA_TOMCAT_IP:-PLACEHOLDER_IP}"
db_username="${DB_USERNAME:-PLACEHOLDER_USERNAME}"
db_password="${DB_PASSWORD:-PLACEHOLDER_PASSWORD}"
db_endpoint="${DB_ENDPOINT:-PLACEHOLDER_ENDPOINT}"
sonar_jdbc_username="${SONAR_JDBC_USERNAME:-sonar}"
sonar_jdbc_password="${SONAR_JDBC_PASSWORD:-sonar123}"
sonar_jdbc_url="${SONAR_JDBC_URL:-jdbc:postgresql://sonarqube-db:5432/sonar}"
grafana_admin_password="${GRAFANA_ADMIN_PASSWORD:-admin}"

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
if [ "$grafana_admin_password" = "admin" ]; then
    log "AVERTISSEMENT: Mot de passe Grafana par défaut détecté. Il est recommandé de le changer."
fi

if [ "$sonar_jdbc_password" = "sonar123" ]; then
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

if [ "$(id -u)" -ne 0 ] && ! sudo -n true 2>/dev/null; then
    error_exit "Ce script nécessite des privilèges sudo. Veuillez l'exécuter avec sudo ou en tant que root."
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
        log "Le script install-docker.sh n'est pas disponible. Tentative d'installation standard..."
        # Installation pour Amazon Linux 2023 avec le script get-docker.sh
        log "Système détecté: Amazon Linux 2023"
        log "Installation des paquets nécessaires"
        sudo dnf install -y tar gzip curl

        log "Téléchargement du script d'installation de Docker"
        curl -fsSL https://get.docker.com -o get-docker.sh

        log "Exécution du script d'installation de Docker"
        sudo sh get-docker.sh

        # Supprimer le script d'installation
        rm -f get-docker.sh

        log "Démarrage et activation du service Docker"
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -a -G docker ec2-user
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
for dir in prometheus-data grafana-data sonarqube-data sonarqube-db-data; do
    if [ ! -d "/opt/monitoring/$dir" ]; then
        log "Création du répertoire /opt/monitoring/$dir"
        sudo mkdir -p "/opt/monitoring/$dir"
    fi
done

# Ajuster les permissions
sudo chown -R ec2-user:ec2-user /opt/monitoring
sudo chmod -R 755 /opt/monitoring

# Création du fichier docker-compose.yml
log "Création du fichier docker-compose.yml..."
sudo bash -c 'cat > /opt/monitoring/docker-compose.yml << "EOL"'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
    ports:
      - "9090:9090"
    restart: unless-stopped
    networks:
      - monitoring-network

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    ports:
      - "9100:9100"
    restart: unless-stopped
    networks:
      - monitoring-network

  mysql-exporter:
    image: prom/mysqld-exporter:latest
    container_name: mysql-exporter
    environment:
      - DATA_SOURCE_NAME=MYSQL_USER:MYSQL_PASSWORD@(MYSQL_HOST:3306)/
    ports:
      - "9104:9104"
    restart: unless-stopped
    networks:
      - monitoring-network

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    volumes:
      - ./grafana-data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=GRAFANA_PASSWORD
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer
    ports:
      - "3001:3000"
    restart: unless-stopped
    networks:
      - monitoring-network
    depends_on:
      - prometheus

  sonarqube-db:
    image: postgres:13
    container_name: sonarqube-db
    environment:
      - POSTGRES_USER=SONAR_DB_USER
      - POSTGRES_PASSWORD=SONAR_DB_PASSWORD
      - POSTGRES_DB=sonar
    volumes:
      - ./sonarqube-db-data:/var/lib/postgresql/data
    networks:
      - monitoring-network
    restart: unless-stopped

  sonarqube:
    image: sonarqube:9.9-community
    container_name: sonarqube
    depends_on:
      - sonarqube-db
    environment:
      - SONAR_JDBC_URL=SONAR_JDBC_URL
      - SONAR_JDBC_USERNAME=SONAR_DB_USER
      - SONAR_JDBC_PASSWORD=SONAR_DB_PASSWORD
    volumes:
      - ./sonarqube-data/data:/opt/sonarqube/data
      - ./sonarqube-data/logs:/opt/sonarqube/logs
      - ./sonarqube-data/extensions:/opt/sonarqube/extensions
    ports:
      - "9000:9000"
    networks:
      - monitoring-network
    restart: unless-stopped

networks:
  monitoring-network:
    driver: bridge
EOL

# Création du fichier prometheus.yml
log "Création du fichier prometheus.yml..."
sudo bash -c 'cat > /opt/monitoring/prometheus.yml << "EOL"'
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
EOL

# Remplacement des variables dans le fichier docker-compose.yml
log "Remplacement des variables dans le fichier docker-compose.yml..."
sudo sed -i "s/MYSQL_USER/${db_username}/g" /opt/monitoring/docker-compose.yml
sudo sed -i "s/MYSQL_PASSWORD/${db_password}/g" /opt/monitoring/docker-compose.yml
sudo sed -i "s/MYSQL_HOST/${db_endpoint}/g" /opt/monitoring/docker-compose.yml
sudo sed -i "s/GRAFANA_PASSWORD/${grafana_admin_password}/g" /opt/monitoring/docker-compose.yml
sudo sed -i "s/SONAR_DB_USER/${sonar_jdbc_username}/g" /opt/monitoring/docker-compose.yml
sudo sed -i "s/SONAR_DB_PASSWORD/${sonar_jdbc_password}/g" /opt/monitoring/docker-compose.yml
sudo sed -i "s|SONAR_JDBC_URL|${sonar_jdbc_url}|g" /opt/monitoring/docker-compose.yml

# Démarrage des conteneurs
log "Démarrage des conteneurs..."

# Vérifier si des conteneurs sont déjà en cours d'exécution
RUNNING_CONTAINERS=$(sudo docker ps --filter "name=prometheus|grafana|sonarqube" --format "{{.Names}}" | wc -l)
if [ "$RUNNING_CONTAINERS" -gt 0 ]; then
    log "Des conteneurs sont déjà en cours d'exécution. Arrêt des conteneurs existants..."
    cd /opt/monitoring
    sudo docker-compose down || log "Erreur lors de l'arrêt des conteneurs. Tentative de continuer..."
fi

# Utiliser docker-manager.sh si disponible, sinon utiliser docker-compose directement
if [ -f "/usr/local/bin/docker-manager.sh" ]; then
    log "Utilisation de docker-manager.sh pour déployer les conteneurs..."
    sudo /usr/local/bin/docker-manager.sh deploy monitoring

    # Vérifier si le déploiement a réussi
    if [ $? -ne 0 ]; then
        log "Erreur lors du déploiement avec docker-manager.sh. Tentative avec docker-compose..."
        cd /opt/monitoring
        sudo docker-compose up -d
    fi
else
    log "Le script docker-manager.sh n'est pas disponible. Utilisation de docker-compose..."
    cd /opt/monitoring
    sudo docker-compose up -d
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

log "Installation et configuration terminées avec succès."
log "Grafana est accessible à l'adresse http://localhost:3001"
log "Prometheus est accessible à l'adresse http://localhost:9090"
log "SonarQube est accessible à l'adresse http://localhost:9000"

exit 0
