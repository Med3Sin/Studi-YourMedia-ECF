#!/bin/bash
#==============================================================================
# Nom du script : restart-monitoring.sh
# Description   : Script pour redémarrer les services de monitoring après des modifications
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2025-05-17
#==============================================================================
# Utilisation   : sudo ./restart-monitoring.sh
#==============================================================================
# Dépendances   :
#   - docker    : Pour redémarrer les conteneurs
#==============================================================================
# Droits requis : Ce script doit être exécuté avec des privilèges sudo ou en tant que root.
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

# Vérification des droits sudo
if [ "$(id -u)" -ne 0 ]; then
    log_error "Ce script doit être exécuté avec sudo ou en tant que root"
fi

# Vérifier que Docker est installé
if ! command -v docker &> /dev/null; then
    log_error "Docker n'est pas installé"
fi

# Vérifier que Docker Compose est installé
if ! command -v docker-compose &> /dev/null; then
    log_error "Docker Compose n'est pas installé"
fi

# Télécharger les fichiers de configuration depuis GitHub
log_info "Téléchargement des fichiers de configuration depuis GitHub"
GITHUB_RAW_URL="https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main"

# Télécharger la configuration de Promtail
log_info "Téléchargement de la configuration de Promtail"
mkdir -p /opt/monitoring/config/promtail
wget -q -O /opt/monitoring/config/promtail/promtail-config.yml "$GITHUB_RAW_URL/scripts/config/promtail/promtail-config.yml"

# Télécharger la configuration de Loki
log_info "Téléchargement de la configuration de Loki"
mkdir -p /opt/monitoring/config/loki
wget -q -O /opt/monitoring/config/loki/loki-config.yml "$GITHUB_RAW_URL/scripts/config/loki/loki-config.yml"

# Créer des liens symboliques pour la compatibilité
log_info "Création de liens symboliques pour la compatibilité"
ln -sf /opt/monitoring/config/promtail/promtail-config.yml /opt/monitoring/promtail-config.yml
ln -sf /opt/monitoring/config/loki/loki-config.yml /opt/monitoring/loki-config.yml

# Télécharger le tableau de bord cAdvisor
log_info "Téléchargement du tableau de bord cAdvisor"
mkdir -p /opt/monitoring/config/grafana/dashboards/dashboards
wget -q -O /opt/monitoring/config/grafana/dashboards/dashboards/cadvisor-dashboard.json "$GITHUB_RAW_URL/scripts/config/grafana/cadvisor-dashboard.json"

# Exécuter le script de copie des tableaux de bord
log_info "Exécution du script de copie des tableaux de bord"
if [ -f "/opt/monitoring/scripts/copy-dashboards.sh" ]; then
    /opt/monitoring/scripts/copy-dashboards.sh
else
    log_info "Téléchargement du script de copie des tableaux de bord"
    mkdir -p /opt/monitoring/scripts
    wget -q -O /opt/monitoring/scripts/copy-dashboards.sh "$GITHUB_RAW_URL/scripts/ec2-monitoring/copy-dashboards.sh"
    chmod +x /opt/monitoring/scripts/copy-dashboards.sh
    /opt/monitoring/scripts/copy-dashboards.sh
fi

# Redémarrer les conteneurs
log_info "Redémarrage des conteneurs"
cd /opt/monitoring

# Redémarrer Loki et Promtail
log_info "Redémarrage de Loki et Promtail"
docker restart loki
docker restart promtail

# Redémarrer Grafana
log_info "Redémarrage de Grafana"
docker restart grafana

# Vérifier que les conteneurs sont en cours d'exécution
log_info "Vérification que les conteneurs sont en cours d'exécution"
if docker ps | grep -q "loki" && docker ps | grep -q "promtail" && docker ps | grep -q "grafana"; then
    log_success "Les conteneurs ont été redémarrés avec succès"
else
    log_error "Certains conteneurs ne sont pas en cours d'exécution"
fi

log_success "Services de monitoring redémarrés avec succès"
exit 0
