#!/bin/bash
#==============================================================================
# Nom du script : setup-monitoring-complete.sh
# Description   : Script complet pour installer et configurer Prometheus et Grafana
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2025-05-20
#==============================================================================
# Utilisation   : sudo ./setup-monitoring-complete.sh
#==============================================================================
# Dépendances   :
#   - docker    : Pour gérer les conteneurs
#   - wget      : Pour télécharger les fichiers
#==============================================================================

# Journalisation
LOG_FILE="/var/log/setup-monitoring-complete.log"
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

# Vérification de Docker
if ! command -v docker &> /dev/null; then
    log "Installation de Docker..."
    amazon-linux-extras install docker -y || error_exit "Impossible d'installer Docker"
    systemctl start docker
    systemctl enable docker
else
    log "Docker est déjà installé"
fi

# Arrêter et supprimer les conteneurs existants
log "Arrêt et suppression des conteneurs existants"
docker stop grafana prometheus loki promtail cadvisor node-exporter 2>/dev/null || log "Aucun conteneur à arrêter"
docker rm grafana prometheus loki promtail cadvisor node-exporter 2>/dev/null || log "Aucun conteneur à supprimer"

# Supprimer et recréer les volumes
log "Suppression et recréation des volumes"
docker volume rm grafana-storage prometheus_data loki_data 2>/dev/null || log "Aucun volume à supprimer"
docker volume create grafana-storage || error_exit "Impossible de créer le volume grafana-storage"
docker volume create prometheus_data || error_exit "Impossible de créer le volume prometheus_data"
docker volume create loki_data || error_exit "Impossible de créer le volume loki_data"

# Créer ou vérifier le réseau Docker
if ! docker network inspect monitoring_network &>/dev/null; then
    log "Création du réseau Docker monitoring_network"
    docker network create monitoring_network || error_exit "Impossible de créer le réseau monitoring_network"
else
    log "Le réseau Docker monitoring_network existe déjà"
fi

# Créer les répertoires nécessaires
log "Création des répertoires nécessaires"
mkdir -p /opt/monitoring/config/grafana/provisioning/datasources
mkdir -p /opt/monitoring/config/grafana/provisioning/dashboards
mkdir -p /opt/monitoring/config/grafana/dashboards
mkdir -p /opt/monitoring/config/prometheus/rules

# Copier les fichiers de configuration
log "Création des fichiers de configuration"

# Configuration Prometheus
cat > /opt/monitoring/prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "node_exporter_monitoring"
    static_configs:
      - targets: ["localhost:9100"]

  - job_name: "node_exporter_java_tomcat"
    static_configs:
      - targets: ["JAVA_TOMCAT_IP:9100"]

  - job_name: "tomcat_jvm"
    static_configs:
      - targets: ["JAVA_TOMCAT_IP:9404"]

  - job_name: "cadvisor"
    static_configs:
      - targets: ["cadvisor:8080"]
EOF

# Remplacer JAVA_TOMCAT_IP par l'adresse IP réelle
# Essayer de récupérer l'adresse IP de l'instance Java/Tomcat depuis les métadonnées EC2
JAVA_TOMCAT_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=*java*" --query "Reservations[].Instances[].PrivateIpAddress" --output text 2>/dev/null)
if [ -z "$JAVA_TOMCAT_IP" ]; then
    log "Impossible de récupérer automatiquement l'adresse IP de l'instance Java/Tomcat"
    log "Veuillez entrer l'adresse IP privée de l'instance Java/Tomcat :"
    read -p "IP privée : " JAVA_TOMCAT_IP
fi

log "Utilisation de l'adresse IP $JAVA_TOMCAT_IP pour l'instance Java/Tomcat"
sed -i "s/JAVA_TOMCAT_IP/$JAVA_TOMCAT_IP/g" /opt/monitoring/prometheus.yml

# Règles d'alerte Prometheus
cat > /opt/monitoring/config/prometheus/rules/alerts.yml << EOF
groups:
  - name: targets
    rules:
      - alert: TargetDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Target {{ \$labels.instance }} is down"
          description: "{{ \$labels.instance }} of job {{ \$labels.job }} has been down for more than 1 minute."

  - name: host
    rules:
      - alert: HostHighCpuLoad
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Host high CPU load (instance {{ \$labels.instance }})"
          description: "CPU load is > 80%\\n  VALUE = {{ \$value }}\\n  LABELS: {{ \$labels }}"
EOF

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

# Datasource Loki
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

# Démarrer les conteneurs
log "Démarrage des conteneurs"

# Prometheus
log "Démarrage de Prometheus"
docker run -d \
  --name=prometheus \
  --restart=always \
  --network=monitoring_network \
  -p 9090:9090 \
  -v prometheus_data:/prometheus \
  -v /opt/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml \
  -v /opt/monitoring/config/prometheus/rules:/etc/prometheus/rules \
  prom/prometheus:latest

# Node Exporter
log "Démarrage de Node Exporter"
docker run -d \
  --name=node-exporter \
  --restart=always \
  --network=monitoring_network \
  -p 9100:9100 \
  -v /:/rootfs:ro \
  -v /var/run:/var/run:ro \
  -v /sys:/sys:ro \
  -v /var/lib/docker/:/var/lib/docker:ro \
  prom/node-exporter:latest

# cAdvisor
log "Démarrage de cAdvisor"
docker run -d \
  --name=cadvisor \
  --restart=always \
  --network=monitoring_network \
  -p 8081:8080 \
  -v /:/rootfs:ro \
  -v /var/run:/var/run:ro \
  -v /sys:/sys:ro \
  -v /var/lib/docker/:/var/lib/docker:ro \
  -v /dev/disk/:/dev/disk:ro \
  --privileged \
  --device=/dev/kmsg \
  gcr.io/cadvisor/cadvisor:latest

# Grafana
log "Démarrage de Grafana"
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

log "Installation terminée"
log "Prometheus est accessible à l'adresse http://localhost:9090"
log "Grafana est accessible à l'adresse http://localhost:3000"
log "Identifiants Grafana par défaut : admin / admin"
