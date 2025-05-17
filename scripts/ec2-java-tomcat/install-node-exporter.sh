#!/bin/bash
# Script pour installer node_exporter sur l'instance Java Tomcat
# Ce script installe et configure node_exporter pour la surveillance Prometheus

set -e

# Rediriger stdout et stderr vers un fichier log
exec > >(tee -a /var/log/install-node-exporter.log) 2>&1

echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation de node_exporter"

# Vérifier si node_exporter est déjà installé
if systemctl is-active --quiet node_exporter; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - node_exporter est déjà en cours d'exécution"
  exit 0
fi

# Télécharger node_exporter
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement de node_exporter"
NODE_EXPORTER_VERSION="1.7.0"
wget -q -O /tmp/node_exporter.tar.gz "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"

# Vérifier si le téléchargement a réussi
if [ ! -s /tmp/node_exporter.tar.gz ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ Échec du téléchargement de node_exporter"
  # Essayer une version alternative
  NODE_EXPORTER_VERSION="1.6.1"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Tentative avec la version ${NODE_EXPORTER_VERSION}"
  wget -q -O /tmp/node_exporter.tar.gz "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
  
  if [ ! -s /tmp/node_exporter.tar.gz ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ Échec du téléchargement de node_exporter"
    exit 1
  fi
fi

# Extraire l'archive
echo "$(date '+%Y-%m-%d %H:%M:%S') - Extraction de node_exporter"
sudo tar xzf /tmp/node_exporter.tar.gz -C /tmp

# Déplacer le binaire
echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation de node_exporter"
sudo mv /tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/

# Créer un utilisateur pour node_exporter
echo "$(date '+%Y-%m-%d %H:%M:%S') - Création de l'utilisateur node_exporter"
sudo useradd -rs /bin/false node_exporter || true

# Créer un service systemd
echo "$(date '+%Y-%m-%d %H:%M:%S') - Création du service systemd"
sudo bash -c 'cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF'

# Démarrer et activer le service
echo "$(date '+%Y-%m-%d %H:%M:%S') - Démarrage du service node_exporter"
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter

# Vérifier l'état du service
echo "$(date '+%Y-%m-%d %H:%M:%S') - Vérification de l'état du service node_exporter"
if systemctl is-active --quiet node_exporter; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ node_exporter est en cours d'exécution"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ Échec du démarrage de node_exporter"
  sudo systemctl status node_exporter
fi

# Nettoyer les fichiers temporaires
echo "$(date '+%Y-%m-%d %H:%M:%S') - Nettoyage des fichiers temporaires"
sudo rm -rf /tmp/node_exporter.tar.gz /tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64

echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation de node_exporter terminée"
