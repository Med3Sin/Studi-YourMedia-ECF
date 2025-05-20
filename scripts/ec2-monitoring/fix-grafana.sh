#!/bin/bash
#==============================================================================
# Nom du script : fix-grafana.sh
# Description   : Script pour corriger les problèmes de configuration de Grafana
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2025-05-20
#==============================================================================
# Utilisation   : sudo ./fix-grafana.sh
#==============================================================================
# Dépendances   :
#   - docker    : Pour gérer les conteneurs
#==============================================================================

# Journalisation
LOG_FILE="/var/log/fix-grafana.log"
exec > >(tee -a "$LOG_FILE") 2>&1

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

# Arrêter et supprimer le conteneur Grafana existant
log "Arrêt et suppression du conteneur Grafana existant"
docker stop grafana || log "Aucun conteneur Grafana en cours d'exécution"
docker rm grafana || log "Aucun conteneur Grafana à supprimer"

# Supprimer et recréer le volume Grafana
log "Suppression et recréation du volume Grafana"
docker volume rm grafana-storage || log "Aucun volume grafana-storage à supprimer"
docker volume create grafana-storage || error_exit "Impossible de créer le volume grafana-storage"

# Créer les répertoires nécessaires
log "Création des répertoires nécessaires"
mkdir -p /opt/monitoring/config/grafana/provisioning/datasources
mkdir -p /opt/monitoring/config/grafana/provisioning/dashboards
mkdir -p /opt/monitoring/config/grafana/dashboards

# Copier les fichiers de configuration
log "Copie des fichiers de configuration"

# Datasource Prometheus
cat > /opt/monitoring/config/grafana/provisioning/datasources/prometheus.yml << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
EOF

# Datasource Loki (si utilisé)
cat > /opt/monitoring/config/grafana/provisioning/datasources/loki.yml << EOF
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    isDefault: false
    editable: false
EOF

# Configuration des dashboards
cat > /opt/monitoring/config/grafana/provisioning/dashboards/default.yml << EOF
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

# Corriger les permissions
log "Correction des permissions"
docker run --rm -v grafana-storage:/var/lib/grafana alpine sh -c "chown -R 472:472 /var/lib/grafana"
chown -R 472:472 /opt/monitoring/config/grafana

# Démarrer le conteneur Grafana
log "Démarrage du conteneur Grafana"
docker run -d \
  --name=grafana \
  --restart=always \
  --network=monitoring_network \
  --user 472 \
  --memory=1g \
  --memory-swap=2g \
  -p 3000:3000 \
  -v /opt/monitoring/config/grafana/provisioning:/etc/grafana/provisioning \
  -v grafana-storage:/var/lib/grafana \
  -e "GF_SECURITY_ADMIN_PASSWORD=admin" \
  -e "GF_USERS_ALLOW_SIGN_UP=false" \
  -e "GF_SERVER_DOMAIN=localhost" \
  -e "GF_SERVER_ROOT_URL=http://localhost:3000/" \
  -e "GF_SERVER_SERVE_FROM_SUB_PATH=false" \
  grafana/grafana:9.5.2

# Vérifier que le conteneur est en cours d'exécution
log "Vérification que le conteneur est en cours d'exécution"
sleep 5
if docker ps | grep -q grafana; then
    log "Le conteneur Grafana a été démarré avec succès"
else
    error_exit "Le conteneur Grafana n'a pas pu être démarré"
fi

# Créer un script de surveillance pour Grafana
log "Création d'un script de surveillance pour Grafana"
cat > /tmp/check-grafana.sh << 'EOF'
#!/bin/bash
if ! docker ps | grep -q grafana; then
  echo "$(date) - Grafana container is not running. Attempting to restart..." >> /var/log/grafana-monitor.log
  docker start grafana
  sleep 10
  if docker ps | grep -q grafana; then
    echo "$(date) - Grafana container successfully restarted." >> /var/log/grafana-monitor.log
  else
    echo "$(date) - Failed to restart Grafana container." >> /var/log/grafana-monitor.log
  fi
fi
EOF

chmod +x /tmp/check-grafana.sh
mkdir -p /etc/cron.d
echo "*/5 * * * * /tmp/check-grafana.sh" > /etc/cron.d/check-grafana

log "Configuration terminée. Grafana devrait être accessible à l'adresse http://localhost:3000"
log "Identifiants par défaut : admin / admin"
