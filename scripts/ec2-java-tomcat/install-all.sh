#!/bin/bash
#==============================================================================
# Nom du script : install-all.sh
# Description   : Script d'installation complet pour une instance EC2 Java/Tomcat.
#                 Ce script installe et configure :
#                 - Java et Tomcat avec détection automatique de la dernière version
#                 - JMX Exporter pour la collecte des métriques JVM
#                 - Promtail pour la collecte des logs
#                 - Configuration des services systemd
#                 - Vérification de l'installation
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2025-05-30
#==============================================================================
# Utilisation   : sudo ./install-all.sh
#
# Exemples      :
#   sudo ./install-all.sh
#==============================================================================
# Dépendances   :
#   - Amazon Linux 2023
#   - wget
#   - curl
#   - unzip
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

# Mise à jour du système
log_info "Mise à jour du système"
sudo dnf update -y

# Installation des dépendances
log_info "Installation des dépendances"
sudo dnf install -y wget curl unzip

# Détection automatique de la dernière version de Tomcat 9
log_info "Détection de la dernière version de Tomcat 9"
TOMCAT_VERSION_PAGE=$(curl -s https://dlcdn.apache.org/tomcat/tomcat-9/)
LATEST_VERSION=$(echo "$TOMCAT_VERSION_PAGE" | grep -o 'v9\.[0-9]\+\.[0-9]\+' | sort -V | tail -n 1 | sed 's/v//')

if [ -n "$LATEST_VERSION" ]; then
  log_info "Dernière version de Tomcat 9 détectée: $LATEST_VERSION"
  TOMCAT_VERSION=$LATEST_VERSION
else
  log_info "Impossible de détecter la dernière version, utilisation de la version par défaut"
  TOMCAT_VERSION=9.0.105  # Version par défaut en cas d'échec de la détection
fi

cd /tmp

# Télécharger Tomcat
log_info "Téléchargement de Tomcat $TOMCAT_VERSION"
DOWNLOAD_SUCCESS=false
TOMCAT_URLS=(
  "https://dlcdn.apache.org/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz"
  "https://archive.apache.org/dist/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz"
  "https://downloads.apache.org/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz"
)

for URL in "${TOMCAT_URLS[@]}"; do
  log_info "Tentative de téléchargement depuis: $URL"
  wget -q -O /tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz "$URL"

  if [ -s /tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz ]; then
    log_success "Téléchargement réussi depuis: $URL"
    DOWNLOAD_SUCCESS=true
    break
  else
    log_info "Échec du téléchargement depuis: $URL"
  fi
done

# Si le téléchargement a échoué, essayer avec une version alternative
if [ "$DOWNLOAD_SUCCESS" = false ]; then
  log_info "Échec du téléchargement de Tomcat $TOMCAT_VERSION, tentative avec une version alternative"
  TOMCAT_VERSION=9.0.78
  URL="https://archive.apache.org/dist/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz"

  log_info "Tentative de téléchargement depuis: $URL"
  wget -q -O /tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz "$URL"

  if [ -s /tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz ]; then
    log_success "Téléchargement réussi depuis: $URL"
    DOWNLOAD_SUCCESS=true
  else
    log_error "Échec du téléchargement de Tomcat"
  fi
fi

# Extraire Tomcat
if [ "$DOWNLOAD_SUCCESS" = true ]; then
  log_info "Extraction de Tomcat"
  sudo mkdir -p /opt/tomcat
  sudo tar xzf /tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz -C /opt/tomcat --strip-components=1

  # Créer un utilisateur Tomcat
  log_info "Création de l'utilisateur Tomcat"
  sudo useradd -r -m -d /opt/tomcat -s /bin/false tomcat || true

  # Configuration des permissions
  log_info "Configuration des permissions"
  sudo chown -R tomcat:tomcat /opt/tomcat
  sudo chmod +x /opt/tomcat/bin/*.sh

  # Démarrer Tomcat
  log_info "Démarrage de Tomcat"
  sudo systemctl daemon-reload
  sudo systemctl start tomcat
  sudo systemctl enable tomcat
else
  log_error "Impossible d'installer Tomcat car le téléchargement a échoué"
fi

# Installation de JMX Exporter
log_info "Installation de JMX Exporter"
JMX_EXPORTER_VERSION="0.20.0"
JMX_EXPORTER_DIR="/opt/yourmedia/monitoring"
sudo mkdir -p $JMX_EXPORTER_DIR

# Télécharger JMX Exporter
log_info "Téléchargement de JMX Exporter"
wget -q -O $JMX_EXPORTER_DIR/jmx_prometheus_javaagent.jar "https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${JMX_EXPORTER_VERSION}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar"

# Créer le fichier de configuration JMX Exporter
log_info "Création du fichier de configuration JMX Exporter"
sudo bash -c "cat > $JMX_EXPORTER_DIR/jmx-config.yml << EOF
lowercaseOutputName: true
lowercaseOutputLabelNames: true
rules:
  - pattern: '.*'
EOF"

# Mettre à jour le service Tomcat pour inclure JMX Exporter
log_info "Mise à jour du service Tomcat pour JMX Exporter"
sudo sed -i "s|Environment=\"CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC\"|Environment=\"CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC -javaagent:$JMX_EXPORTER_DIR/jmx_prometheus_javaagent.jar=9404:$JMX_EXPORTER_DIR/jmx-config.yml\"|" /etc/systemd/system/tomcat.service

# Installation de Promtail
log_info "Installation de Promtail"
PROMTAIL_VERSION="2.9.3"
PROMTAIL_DIR="/opt/yourmedia/monitoring/promtail"
sudo mkdir -p $PROMTAIL_DIR

# Télécharger Promtail
log_info "Téléchargement de Promtail"
wget -q -O $PROMTAIL_DIR/promtail "https://github.com/grafana/loki/releases/download/v${PROMTAIL_VERSION}/promtail-linux-amd64.zip"
unzip -q $PROMTAIL_DIR/promtail -d $PROMTAIL_DIR
sudo chmod +x $PROMTAIL_DIR/promtail-linux-amd64

# Créer le fichier de configuration Promtail
log_info "Création du fichier de configuration Promtail"
sudo bash -c "cat > $PROMTAIL_DIR/config.yml << EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push

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
          __path__: /opt/tomcat/logs/*.log
EOF"

# Créer un service systemd pour Promtail
log_info "Création du service systemd pour Promtail"
sudo bash -c 'cat > /etc/systemd/system/promtail.service << EOF
[Unit]
Description=Promtail service
After=network.target

[Service]
Type=simple
ExecStart=/opt/yourmedia/monitoring/promtail/promtail-linux-amd64 -config.file=/opt/yourmedia/monitoring/promtail/config.yml
Restart=always

[Install]
WantedBy=multi-user.target
EOF'

# Démarrer Promtail
log_info "Démarrage de Promtail"
sudo systemctl daemon-reload
sudo systemctl start promtail
sudo systemctl enable promtail

# Redémarrer Tomcat pour appliquer les changements JMX Exporter
log_info "Redémarrage de Tomcat pour appliquer JMX Exporter"
sudo systemctl restart tomcat

# Vérifier que JMX Exporter est accessible
log_info "Vérification de JMX Exporter"
sleep 10
if curl -s http://localhost:9404/metrics | grep -q "jvm_"; then
  log_success "JMX Exporter est accessible et fonctionne"
else
  log_info "JMX Exporter n'est pas accessible, vérifiez les logs de Tomcat"
fi

# Vérifier que Promtail est accessible
log_info "Vérification de Promtail"
if curl -s http://localhost:9080/ready; then
  log_success "Promtail est accessible et fonctionne"
else
  log_info "Promtail n'est pas accessible, vérifiez les logs"
fi

log_success "Script d'installation complet terminé"
exit 0