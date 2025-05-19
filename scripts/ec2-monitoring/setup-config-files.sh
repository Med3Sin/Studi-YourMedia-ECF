#!/bin/bash
#==============================================================================
# Nom du script : setup-config-files.sh
# Description   : Script pour copier tous les fichiers de configuration au bon endroit
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
#==============================================================================
# Utilisation   : sudo ./setup-config-files.sh
#==============================================================================

# Fonction pour afficher les messages d'information
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] $1"
}

# Fonction pour afficher les messages d'erreur et quitter
log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [ERROR] $1" >&2
    exit 1
}

# Fonction pour afficher les messages de succès
log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [SUCCESS] $1"
}

# Vérifier si le script est exécuté en tant que root
if [ "$(id -u)" -ne 0 ]; then
    log_error "Ce script doit être exécuté en tant que root ou avec sudo"
fi

# Créer les répertoires nécessaires
log_info "Création des répertoires nécessaires"
mkdir -p /opt/monitoring/config/grafana/dashboards/dashboards
mkdir -p /opt/monitoring/config/grafana/datasources
mkdir -p /opt/monitoring/prometheus/rules
mkdir -p /opt/monitoring/loki
mkdir -p /mnt/ec2-java-tomcat-logs

# Copier les fichiers de configuration Prometheus
log_info "Copie des fichiers de configuration Prometheus"
cp -f /home/ec2-user/scripts/config/prometheus/prometheus.yml /opt/monitoring/prometheus.yml
cp -f /home/ec2-user/scripts/config/prometheus/alerts.yml /opt/monitoring/prometheus/rules/alerts.yml
cp -f /home/ec2-user/scripts/config/prometheus/container-alerts.yml /opt/monitoring/prometheus/rules/container-alerts.yml

# Copier les fichiers de configuration Grafana
log_info "Copie des fichiers de configuration Grafana"
cp -f /home/ec2-user/scripts/config/grafana/dashboards/default.yml /opt/monitoring/config/grafana/dashboards/default.yml
cp -f /home/ec2-user/scripts/config/grafana/datasources/prometheus.yml /opt/monitoring/config/grafana/datasources/prometheus.yml
cp -f /home/ec2-user/scripts/config/grafana/datasources/loki.yml /opt/monitoring/config/grafana/datasources/loki.yml

# Copier les dashboards Grafana
log_info "Copie des dashboards Grafana"
cp -f /home/ec2-user/scripts/config/grafana/cadvisor-dashboard.json /opt/monitoring/config/grafana/dashboards/dashboards/
cp -f /home/ec2-user/scripts/config/grafana/java-app-logs-dashboard.json /opt/monitoring/config/grafana/dashboards/dashboards/
cp -f /home/ec2-user/scripts/config/grafana/logs-dashboard.json /opt/monitoring/config/grafana/dashboards/dashboards/
cp -f /home/ec2-user/scripts/config/grafana/react-app-dashboard.json /opt/monitoring/config/grafana/dashboards/dashboards/
cp -f /home/ec2-user/scripts/config/grafana/system-overview.json /opt/monitoring/config/grafana/dashboards/dashboards/

# Copier le fichier docker-compose.yml
log_info "Copie du fichier docker-compose.yml"
cp -f /home/ec2-user/scripts/ec2-monitoring/docker-compose.yml /opt/monitoring/docker-compose.yml

# Définir les permissions appropriées
log_info "Définition des permissions appropriées"
chown -R ec2-user:ec2-user /opt/monitoring
chown -R ec2-user:ec2-user /mnt/ec2-java-tomcat-logs
chmod -R 755 /opt/monitoring
chmod -R 755 /mnt/ec2-java-tomcat-logs

log_success "Configuration terminée avec succès"
exit 0
