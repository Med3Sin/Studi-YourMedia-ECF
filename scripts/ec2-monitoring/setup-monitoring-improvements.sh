#!/bin/bash
# Script d'installation pour les améliorations de surveillance
# Auteur: Med3Sin
# Date: $(date +%Y-%m-%d)

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
mkdir -p /opt/monitoring/prometheus-rules
mkdir -p /opt/monitoring/loki-data
mkdir -p /opt/monitoring/test-reports

# Copier les fichiers de configuration
log "Copie des fichiers de configuration..."

# 1. Surveillance des conteneurs
cp container-health-check.sh /opt/monitoring/
cp container-health-check.service /etc/systemd/system/
cp container-health-check.timer /etc/systemd/system/
cp prometheus-rules/container-alerts.yml /opt/monitoring/prometheus-rules/

# 2. Logs centralisés
cp loki-config.yml /opt/monitoring/
cp promtail-config.yml /opt/monitoring/

# 3. Automatisation des tests
cp container-tests.sh /opt/monitoring/
cp container-tests.service /etc/systemd/system/
cp container-tests.timer /etc/systemd/system/

# Rendre les scripts exécutables
log "Configuration des permissions..."
chmod +x /opt/monitoring/container-health-check.sh
chmod +x /opt/monitoring/container-tests.sh

# Mettre à jour la configuration de Prometheus pour inclure les règles d'alerte
log "Mise à jour de la configuration de Prometheus..."
if [ -f "/opt/monitoring/prometheus.yml" ]; then
    # Vérifier si les règles sont déjà configurées
    if ! grep -q "rule_files:" /opt/monitoring/prometheus.yml; then
        # Ajouter la section rule_files
        sed -i '/scrape_configs:/i\rule_files:\n  - /etc/prometheus/rules/*.yml\n' /opt/monitoring/prometheus.yml
    elif ! grep -q "/etc/prometheus/rules/\*.yml" /opt/monitoring/prometheus.yml; then
        # Ajouter le fichier de règles
        sed -i '/rule_files:/a\  - /etc/prometheus/rules/*.yml' /opt/monitoring/prometheus.yml
    fi
    
    # Ajouter un volume pour les règles dans docker-compose.yml
    if ! grep -q "/opt/monitoring/prometheus-rules:/etc/prometheus/rules" /opt/monitoring/docker-compose.yml; then
        sed -i '/\/opt\/monitoring\/prometheus.yml:\/etc\/prometheus\/prometheus.yml/a\      - /opt/monitoring/prometheus-rules:/etc/prometheus/rules' /opt/monitoring/docker-compose.yml
    fi
fi

# Activer et démarrer les services systemd
log "Activation des services..."
systemctl daemon-reload
systemctl enable container-health-check.timer
systemctl start container-health-check.timer
systemctl enable container-tests.timer
systemctl start container-tests.timer

# Redémarrer les conteneurs Docker
log "Redémarrage des conteneurs..."
cd /opt/monitoring
docker-compose down
docker-compose up -d

log "Installation des améliorations de surveillance terminée avec succès."
log "Vous pouvez maintenant accéder aux logs centralisés via Grafana à l'adresse http://localhost:3000"
log "Les tests automatisés seront exécutés toutes les heures et les rapports seront disponibles dans /opt/monitoring/test-reports"
log "La surveillance des conteneurs est active et vérifiera l'état des conteneurs toutes les 5 minutes"
