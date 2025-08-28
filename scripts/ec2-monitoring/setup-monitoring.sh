#!/bin/bash
#==============================================================================
# Nom du script : setup-monitoring.sh
# Description   : Script unifié d'installation et de configuration pour l'instance EC2 Monitoring.
#                 Ce script combine les fonctionnalités d'installation, configuration,
#                 vérification et correction des problèmes pour les services de monitoring.
# Auteur        : Med3Sin
# Version       : 2.2
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

# Fonction pour configurer Promtail
configure_promtail() {
    log "Configuration de Promtail"
    
    # Créer les répertoires nécessaires
    mkdir -p /opt/monitoring/promtail/config
    mkdir -p /mnt/ec2-java-tomcat-logs

    # Créer le fichier de configuration Promtail
    cat > /opt/monitoring/promtail/config/config.yml << EOF
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

  - job_name: tomcat
    static_configs:
      - targets:
          - localhost
        labels:
          job: tomcat
          __path__: /mnt/ec2-java-tomcat-logs/*.log
          __path__: /mnt/ec2-java-tomcat-logs/catalina.out

  - job_name: promtail
    static_configs:
      - targets:
          - localhost
        labels:
          job: promtail
          __path__: /var/log/promtail.log
EOF

    # Définir les permissions appropriées
    chown -R ec2-user:ec2-user /opt/monitoring/promtail
    chmod -R 755 /opt/monitoring/promtail
    chmod 644 /opt/monitoring/promtail/config/config.yml

    log "Configuration de Promtail terminée avec succès"
    return 0
}

# Fonction pour configurer Node Exporter
configure_node_exporter() {
    log "Configuration de Node Exporter"
    
    # Créer le répertoire de configuration
    mkdir -p /opt/monitoring/node-exporter/config
    
    # Créer le fichier de configuration Node Exporter
    cat > /opt/monitoring/node-exporter/config/config.yml << EOF
collectors:
  enabled:
    - cpu
    - diskstats
    - filesystem
    - loadavg
    - meminfo
    - netdev
    - netstat
    - textfile
    - time
    - vmstat
    - systemd
    - logind
    - interrupts
    - ksmd
    - logind
    - meminfo_numa
    - mountstats
    - ntp
    - qdisc
    - runit
    - sockstat
    - stat
    - tcpstat
    - textfile
    - time
    - uname
    - vmstat
    - xfs
    - zfs

collector:
  filesystem:
    ignored_mount_points: "^/(sys|proc|dev|host|etc)($$|/)"
    ignored_fs_types: "^(sys|proc|auto)fs$"
  diskstats:
    ignored_devices: "^(ram|loop|fd|(h|s|v|xv)d[a-z]|nvme\\d+n\\d+p)\\d+$"
  netdev:
    ignored_devices: "^$"
  netstat:
    fields: "^(.*_(InErrors|InErrs)|Ip_Forwarding|Ip(6|Ext)_(InReceives|OutRequests|InDelivers|OutForwDatagrams|InUnknownProtos|InDiscards|OutDiscards|InNoRoutes))$"
  textfile:
    directory: /var/lib/node_exporter/textfile_collector
EOF

    # Créer le répertoire pour les métriques personnalisées
    mkdir -p /var/lib/node_exporter/textfile_collector
    
    # Créer un script pour les métriques personnalisées
    cat > /opt/monitoring/node-exporter/scripts/custom_metrics.sh << EOF
#!/bin/bash
# Script pour générer des métriques personnalisées pour Node Exporter

# Répertoire de sortie
OUTPUT_DIR="/var/lib/node_exporter/textfile_collector"

# Nombre de processus en cours
echo "# HELP node_processes_running Number of running processes" > \${OUTPUT_DIR}/processes.prom
echo "# TYPE node_processes_running gauge" >> \${OUTPUT_DIR}/processes.prom
echo "node_processes_running \$(ps aux | wc -l)" >> \${OUTPUT_DIR}/processes.prom

# Utilisation du swap
echo "# HELP node_swap_used_bytes Swap usage in bytes" > \${OUTPUT_DIR}/swap.prom
echo "# TYPE node_swap_used_bytes gauge" >> \${OUTPUT_DIR}/swap.prom
echo "node_swap_used_bytes \$(free -b | grep Swap | awk '{print \$3}')" >> \${OUTPUT_DIR}/swap.prom

# Nombre de connexions TCP établies
echo "# HELP node_tcp_connections_established Number of established TCP connections" > \${OUTPUT_DIR}/tcp.prom
echo "# TYPE node_tcp_connections_established gauge" >> \${OUTPUT_DIR}/tcp.prom
echo "node_tcp_connections_established \$(netstat -tn | grep ESTABLISHED | wc -l)" >> \${OUTPUT_DIR}/tcp.prom
EOF

    # Rendre le script exécutable
    chmod +x /opt/monitoring/node-exporter/scripts/custom_metrics.sh
    
    # Créer un service systemd pour les métriques personnalisées
    cat > /etc/systemd/system/node-exporter-custom-metrics.service << EOF
[Unit]
Description=Node Exporter Custom Metrics Generator
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/monitoring/node-exporter/scripts/custom_metrics.sh
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

    # Activer et démarrer le service
    systemctl daemon-reload
    systemctl enable node-exporter-custom-metrics
    systemctl start node-exporter-custom-metrics

    # Définir les permissions appropriées
    chown -R ec2-user:ec2-user /opt/monitoring/node-exporter
    chmod -R 755 /opt/monitoring/node-exporter
    chmod 644 /opt/monitoring/node-exporter/config/config.yml

    log "Configuration de Node Exporter terminée avec succès"
    return 0
}

# Fonction pour configurer les services de monitoring
configure_monitoring_services() {
    log "Configuration des services de monitoring"
    
    # Créer le fichier docker-compose.yml
    cat > /opt/monitoring/docker-compose.yml << EOF
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    volumes:
      - ./prometheus:/etc/prometheus
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
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/dashboards:/var/lib/grafana/dashboards
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=\${GRAFANA_ADMIN_PASSWORD}
      - GF_USERS_ALLOW_SIGN_UP=false
    ports:
      - "3000:3000"
    restart: unless-stopped
    networks:
      - monitoring

  loki:
    image: grafana/loki:latest
    container_name: loki
    volumes:
      - ./loki:/etc/loki
      - loki_data:/loki
    command: -config.file=/etc/loki/loki-config.yml
    ports:
      - "3100:3100"
    restart: unless-stopped
    networks:
      - monitoring

  promtail:
    image: grafana/promtail:latest
    container_name: promtail
    volumes:
      - ./promtail/config:/etc/promtail
      - /var/log:/var/log
      - /mnt/ec2-java-tomcat-logs:/mnt/ec2-java-tomcat-logs
    command: -config.file=/etc/promtail/config.yml
    restart: unless-stopped
    networks:
      - monitoring

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
      - /opt/monitoring/node-exporter/config:/etc/node-exporter
      - /var/lib/node_exporter/textfile_collector:/var/lib/node_exporter/textfile_collector
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--path.rootfs=/rootfs'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
      - '--collector.textfile.directory=/var/lib/node_exporter/textfile_collector'
      - '--web.listen-address=:9100'
      - '--web.telemetry-path=/metrics'
      - '--log.level=info'
    ports:
      - "9100:9100"
    restart: unless-stopped
    networks:
      - monitoring

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
      - "8080:8080"
      - "8081:8081"
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
    chmod -R 755 /opt/monitoring
    chmod 644 /opt/monitoring/docker-compose.yml

    log "Configuration des services de monitoring terminée avec succès"
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
    configure_promtail
    configure_node_exporter
    configure_monitoring_services
    
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
