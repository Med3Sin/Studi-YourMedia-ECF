#!/bin/bash
#==============================================================================
# Nom du script : setup-monitoring-improvements.sh
# Description   : Script d'installation pour les améliorations de surveillance.
#                 Ce script configure des fonctionnalités avancées de surveillance
#                 comme la vérification de santé des conteneurs, la centralisation
#                 des logs et l'automatisation des tests.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2025-04-27
#==============================================================================
# Utilisation   : sudo ./setup-monitoring-improvements.sh
#
# Exemples      :
#   sudo ./setup-monitoring-improvements.sh
#==============================================================================
# Dépendances   :
#   - docker    : Pour gérer les conteneurs
#   - systemd   : Pour configurer les services et les timers
#   - sed       : Pour modifier les fichiers de configuration
#==============================================================================
# Fichiers requis :
#   - container-health-check.sh : Script de vérification de santé des conteneurs
#   - container-health-check.service : Service systemd pour la vérification de santé
#   - container-health-check.timer : Timer systemd pour la vérification de santé
#   - container-tests.sh : Script de tests des conteneurs
#   - container-tests.service : Service systemd pour les tests
#   - container-tests.timer : Timer systemd pour les tests
#   - loki-config.yml : Configuration pour Loki
#   - promtail-config.yml : Configuration pour Promtail
#   - prometheus-rules/container-alerts.yml : Règles d'alerte pour Prometheus
#==============================================================================

# Fonction de journalisation
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Vérifier si le script est exécuté avec les privilèges root
if [ "$(id -u)" -ne 0 ]; then
    log "Ce script doit être exécuté avec les privilèges root (sudo)."
    exit 1
fi

# Créer les répertoires nécessaires
log "Création des répertoires..."
sudo mkdir -p /opt/monitoring/prometheus-rules
sudo mkdir -p /opt/monitoring/loki-data
sudo mkdir -p /opt/monitoring/test-reports

# Télécharger les fichiers de configuration depuis GitHub
log "Téléchargement des fichiers de configuration..."
GITHUB_RAW_URL="https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main"

# 1. Surveillance des conteneurs
log "Téléchargement des fichiers de surveillance des conteneurs..."
sudo wget -q -O /opt/monitoring/container-health-check.sh "$GITHUB_RAW_URL/scripts/ec2-monitoring/container-health-check.sh"
sudo wget -q -O /etc/systemd/system/container-health-check.service "$GITHUB_RAW_URL/scripts/ec2-monitoring/container-health-check.service"
sudo wget -q -O /etc/systemd/system/container-health-check.timer "$GITHUB_RAW_URL/scripts/ec2-monitoring/container-health-check.timer"
sudo cp /opt/monitoring/config/prometheus/container-alerts.yml /opt/monitoring/prometheus-rules/

# 2. Logs centralisés
log "Configuration des logs centralisés..."
sudo cp /opt/monitoring/config/loki-config.yml /opt/monitoring/
sudo cp /opt/monitoring/config/promtail-config.yml /opt/monitoring/

# 3. Automatisation des tests
log "Téléchargement des fichiers d'automatisation des tests..."
sudo wget -q -O /opt/monitoring/container-tests.sh "$GITHUB_RAW_URL/scripts/ec2-monitoring/container-tests.sh"
sudo wget -q -O /etc/systemd/system/container-tests.service "$GITHUB_RAW_URL/scripts/ec2-monitoring/container-tests.service"
sudo wget -q -O /etc/systemd/system/container-tests.timer "$GITHUB_RAW_URL/scripts/ec2-monitoring/container-tests.timer"

# Rendre les scripts exécutables
log "Configuration des permissions..."
sudo chmod +x /opt/monitoring/container-health-check.sh
sudo chmod +x /opt/monitoring/container-tests.sh

# Mettre à jour la configuration de Prometheus pour inclure les règles d'alerte
log "Mise à jour de la configuration de Prometheus..."
if [ -f "/opt/monitoring/config/prometheus/prometheus.yml" ]; then
    # Vérifier si les règles sont déjà configurées
    if ! grep -q "rule_files:" /opt/monitoring/config/prometheus/prometheus.yml; then
        # Ajouter la section rule_files
        sudo sed -i '/scrape_configs:/i\rule_files:\n  - /etc/prometheus/rules/*.yml\n' /opt/monitoring/config/prometheus/prometheus.yml
    elif ! grep -q "/etc/prometheus/rules/\*.yml" /opt/monitoring/config/prometheus/prometheus.yml; then
        # Ajouter le fichier de règles
        sudo sed -i '/rule_files:/a\  - /etc/prometheus/rules/*.yml' /opt/monitoring/config/prometheus/prometheus.yml
    fi

    # Ajouter un volume pour les règles dans docker-compose.yml si nécessaire
    if ! grep -q "/opt/monitoring/prometheus-rules:/etc/prometheus/rules" /opt/monitoring/docker-compose.yml; then
        sudo sed -i '/\/opt\/monitoring\/config\/prometheus\/prometheus.yml:\/etc\/prometheus\/prometheus.yml/a\      - /opt/monitoring/prometheus-rules:/etc/prometheus/rules' /opt/monitoring/docker-compose.yml
    fi
fi

# Activer et démarrer les services systemd
log "Activation des services..."
sudo systemctl daemon-reload
sudo systemctl enable container-health-check.timer
sudo systemctl start container-health-check.timer
sudo systemctl enable container-tests.timer
sudo systemctl start container-tests.timer

# Redémarrer les conteneurs Docker
log "Redémarrage des conteneurs..."
cd /opt/monitoring
sudo docker-compose down
sudo docker-compose up -d

log "Installation des améliorations de surveillance terminée avec succès."
log "Vous pouvez maintenant accéder aux logs centralisés via Grafana à l'adresse http://localhost:3000"
log "Les tests automatisés seront exécutés toutes les heures et les rapports seront disponibles dans /opt/monitoring/test-reports"
log "La surveillance des conteneurs est active et vérifiera l'état des conteneurs toutes les 5 minutes"
