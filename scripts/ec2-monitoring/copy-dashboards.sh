#!/bin/bash
#==============================================================================
# Nom du script : copy-dashboards.sh
# Description   : Script pour copier les tableaux de bord Grafana dans le répertoire de configuration.
#                 Ce script copie les tableaux de bord depuis le répertoire de configuration
#                 vers le répertoire des tableaux de bord de Grafana.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2025-05-15
#==============================================================================
# Utilisation   : sudo ./copy-dashboards.sh
#==============================================================================
# Dépendances   :
#   - docker    : Pour redémarrer le conteneur Grafana
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

# Créer les répertoires nécessaires
log_info "Création des répertoires nécessaires"
mkdir -p /opt/monitoring/config/grafana/dashboards/dashboards

# Télécharger les tableaux de bord depuis GitHub
log_info "Téléchargement des tableaux de bord depuis GitHub"
GITHUB_RAW_URL="https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main"

# Télécharger le tableau de bord des logs de l'application Java
log_info "Téléchargement du tableau de bord des logs de l'application Java"
wget -q -O /opt/monitoring/config/grafana/dashboards/dashboards/java-app-logs.json "$GITHUB_RAW_URL/scripts/config/grafana/java-app-logs-dashboard.json"

# Télécharger le tableau de bord des logs des conteneurs
log_info "Téléchargement du tableau de bord des logs des conteneurs"
wget -q -O /opt/monitoring/config/grafana/dashboards/dashboards/container-logs.json "$GITHUB_RAW_URL/scripts/config/grafana/logs-dashboard.json"

# Télécharger le tableau de bord de l'aperçu du système
log_info "Téléchargement du tableau de bord de l'aperçu du système"
wget -q -O /opt/monitoring/config/grafana/dashboards/dashboards/system-overview.json "$GITHUB_RAW_URL/scripts/config/grafana/system-overview.json"

# Télécharger le tableau de bord de l'application React
log_info "Téléchargement du tableau de bord de l'application React"
wget -q -O /opt/monitoring/config/grafana/dashboards/dashboards/react-app-dashboard.json "$GITHUB_RAW_URL/scripts/config/grafana/react-app-dashboard.json"

# Télécharger le tableau de bord cAdvisor
log_info "Téléchargement du tableau de bord cAdvisor"
wget -q -O /opt/monitoring/config/grafana/dashboards/dashboards/cadvisor-dashboard.json "$GITHUB_RAW_URL/scripts/config/grafana/cadvisor-dashboard.json"

# Définir les permissions appropriées
log_info "Définition des permissions appropriées"
chmod -R 755 /opt/monitoring/config/grafana/dashboards/dashboards

# Créer le fichier de configuration des dashboards
log_info "Création du fichier de configuration des dashboards"
cat > /opt/monitoring/config/grafana/dashboards/default.yml << EOF
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
EOF

# Redémarrer le conteneur Grafana
log_info "Redémarrage du conteneur Grafana"
docker restart grafana

log_success "Tableaux de bord copiés avec succès"
exit 0
