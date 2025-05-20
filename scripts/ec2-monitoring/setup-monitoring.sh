#!/bin/bash
#==============================================================================
# Nom du script : setup-monitoring.sh
# Description   : Script unifié d'installation et de configuration pour l'instance EC2 Monitoring.
#                 Ce script combine les fonctionnalités d'installation, configuration,
#                 vérification et correction des problèmes pour les services de monitoring.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 2.2
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

# Vérifier si le script est exécuté en tant que root
if [ "$EUID" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root ou avec sudo"
    exit 1
fi

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
        wget -q -O /usr/local/bin/docker-compose "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)"
        chmod +x /usr/local/bin/docker-compose

        # Créer un lien symbolique
        if [ ! -f "/usr/bin/docker-compose" ] && [ ! -L "/usr/bin/docker-compose" ]; then
            ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
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

# Fonction pour configurer Grafana
configure_grafana() {
    log "Configuration de Grafana"
    
    # Créer les répertoires nécessaires
    mkdir -p /opt/monitoring/grafana/provisioning/datasources
    mkdir -p /opt/monitoring/grafana/provisioning/dashboards
    mkdir -p /opt/monitoring/grafana/dashboards

    # Créer le fichier de configuration de la source de données Prometheus
    cat > /opt/monitoring/grafana/provisioning/datasources/prometheus.yml << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    editable: false
EOF

    # Créer le fichier de configuration des dashboards
    cat > /opt/monitoring/grafana/provisioning/dashboards/dashboards.yml << EOF
apiVersion: 1

providers:
  - name: 'Default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /var/lib/grafana/dashboards
EOF

    # Copier tous les dashboards depuis le répertoire de configuration
    cp /opt/monitoring/scripts/config/grafana/dashboards/*.json /opt/monitoring/grafana/dashboards/
    
    # Vérifier que les fichiers ont été copiés
    if [ ! -f "/opt/monitoring/grafana/dashboards/system-overview.json" ] || \
       [ ! -f "/opt/monitoring/grafana/dashboards/java-app-logs-dashboard.json" ] || \
       [ ! -f "/opt/monitoring/grafana/dashboards/cadvisor-dashboard.json" ] || \
       [ ! -f "/opt/monitoring/grafana/dashboards/logs-dashboard.json" ] || \
       [ ! -f "/opt/monitoring/grafana/dashboards/react-app-dashboard.json" ]; then
        log "ERREUR: Certains fichiers de dashboard n'ont pas été copiés correctement"
        return 1
    fi

    # Définir les permissions appropriées
    chown -R ec2-user:ec2-user /opt/monitoring/grafana
    chmod -R 755 /opt/monitoring/grafana
    chmod 644 /opt/monitoring/grafana/provisioning/datasources/prometheus.yml
    chmod 644 /opt/monitoring/grafana/provisioning/dashboards/dashboards.yml
    chmod 644 /opt/monitoring/grafana/dashboards/*.json

    log "Configuration de Grafana terminée avec succès"
    return 0
}

# Fonction pour créer la configuration de Prometheus
create_prometheus_config() {
    log "Création de la configuration Prometheus"
    
    # Vérifier si le fichier existe déjà
    if [ -f "/opt/monitoring/prometheus.yml" ]; then
        log "Le fichier prometheus.yml existe déjà"
        return 0
    fi

    # Créer le fichier de configuration Prometheus
    cat > /opt/monitoring/prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert.rules"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'java_tomcat'
    static_configs:
      - targets: ['ec2-java-tomcat:9404']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'loki'
    static_configs:
      - targets: ['loki:3100']

  - job_name: 'promtail'
    static_configs:
      - targets: ['promtail:9080']
EOF

    # Définir les permissions appropriées
    chown ec2-user:ec2-user /opt/monitoring/prometheus.yml
    chmod 644 /opt/monitoring/prometheus.yml

    log "Configuration Prometheus créée avec succès"
    return 0
}

# Fonction pour créer le fichier docker-compose.yml
create_docker_compose_file() {
    log "Création du fichier docker-compose.yml"
    
    # Créer le répertoire s'il n'existe pas
    mkdir -p /opt/monitoring
    
    # Vérifier si le fichier existe déjà
    if [ -f "/opt/monitoring/docker-compose.yml" ]; then
        log "Le fichier docker-compose.yml existe déjà"
        return 0
    fi

    # Créer le fichier docker-compose.yml
    cat > /opt/monitoring/docker-compose.yml << EOF
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    ports:
      - "9090:9090"
    restart: unless-stopped
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/dashboards:/var/lib/grafana/dashboards
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=\${GRAFANA_ADMIN_PASSWORD:-admin}
      - GF_USERS_ALLOW_SIGN_UP=false
    ports:
      - "3000:3000"
    restart: unless-stopped
    networks:
      - monitoring
    depends_on:
      - prometheus

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    ports:
      - "8081:8080"
    restart: unless-stopped
    networks:
      - monitoring

  loki:
    image: grafana/loki:latest
    container_name: loki
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml
    volumes:
      - loki_data:/loki
    restart: unless-stopped
    networks:
      - monitoring

  promtail:
    image: grafana/promtail:latest
    container_name: promtail
    volumes:
      - /var/log:/var/log
      - ./promtail-config.yml:/etc/promtail/config.yml
    command: -config.file=/etc/promtail/config.yml
    restart: unless-stopped
    networks:
      - monitoring

volumes:
  prometheus_data:
  grafana_data:
  loki_data:

networks:
  monitoring:
    driver: bridge
EOF

    # Définir les permissions appropriées
    chown -R ec2-user:ec2-user /opt/monitoring
    chmod 755 /opt/monitoring
    chmod 644 /opt/monitoring/docker-compose.yml

    log "Fichier docker-compose.yml créé avec succès"
    return 0
}

# Fonction pour télécharger les fichiers depuis GitHub
download_github_files() {
    log "Téléchargement des fichiers depuis GitHub"
    
    # Créer le répertoire temporaire
    TEMP_DIR="/tmp/monitoring-files"
    mkdir -p $TEMP_DIR
    
    # Cloner le dépôt GitHub
    git clone https://github.com/Med3Sin/Studi-YourMedia-ECF.git $TEMP_DIR
    
    # Copier les fichiers de configuration
    cp -r $TEMP_DIR/scripts/config/grafana/dashboards/* /opt/monitoring/grafana/dashboards/
    cp $TEMP_DIR/scripts/config/promtail/promtail-config.yml /opt/monitoring/promtail-config.yml
    
    # Nettoyer le répertoire temporaire
    rm -rf $TEMP_DIR
    
    # Vérifier que les fichiers ont été copiés
    if [ ! -f "/opt/monitoring/grafana/dashboards/system-overview.json" ] || \
       [ ! -f "/opt/monitoring/grafana/dashboards/java-app-logs-dashboard.json" ] || \
       [ ! -f "/opt/monitoring/grafana/dashboards/cadvisor-dashboard.json" ] || \
       [ ! -f "/opt/monitoring/grafana/dashboards/logs-dashboard.json" ] || \
       [ ! -f "/opt/monitoring/grafana/dashboards/react-app-dashboard.json" ]; then
        log "ERREUR: Certains fichiers de dashboard n'ont pas été copiés correctement"
        return 1
    fi
    
    log "Fichiers téléchargés avec succès"
    return 0
}

# Fonction pour configurer les permissions
configure_permissions() {
    log "Configuration des permissions"
    
    # Définir les permissions pour les répertoires
    chown -R ec2-user:ec2-user /opt/monitoring
    chmod -R 755 /opt/monitoring
    
    # Permissions spécifiques pour les fichiers de configuration
    chmod 644 /opt/monitoring/grafana/provisioning/datasources/prometheus.yml
    chmod 644 /opt/monitoring/grafana/provisioning/dashboards/dashboards.yml
    chmod 644 /opt/monitoring/grafana/dashboards/*.json
    chmod 644 /opt/monitoring/prometheus.yml
    chmod 644 /opt/monitoring/promtail-config.yml
    chmod 644 /opt/monitoring/docker-compose.yml
    
    # Permissions pour les volumes Docker
    mkdir -p /opt/monitoring/volumes/{prometheus,grafana,loki}
    chown -R ec2-user:ec2-user /opt/monitoring/volumes
    chmod -R 755 /opt/monitoring/volumes
    
    log "Permissions configurées avec succès"
    return 0
}

# Fonction principale d'installation
main() {
    log "Démarrage de l'installation du monitoring"
    
    # Installation des dépendances
    install_docker
    install_docker_compose
    configure_system_limits
    
    # Création des configurations
    create_prometheus_config
    create_docker_compose_file
    configure_grafana
    
    # Téléchargement des fichiers depuis GitHub
    download_github_files
    
    # Configuration des permissions
    configure_permissions
    
    # Démarrage des services
    cd /opt/monitoring
    docker-compose up -d
    
    log "Installation du monitoring terminée avec succès"
    log "Prometheus est accessible à l'adresse http://localhost:9090"
    log "Grafana est accessible à l'adresse http://localhost:3000"
    log "Utilisez les identifiants par défaut (admin/admin) pour Grafana"
}

# Exécution du script
main
