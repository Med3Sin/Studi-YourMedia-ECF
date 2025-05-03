#!/bin/bash
set -e

# Rediriger stdout et stderr vers un fichier log
exec > >(tee /var/log/user-data-init.log) 2>&1

echo "$(date '+%Y-%m-%d %H:%M:%S') - Démarrage du script d'initialisation"

# Mettre à jour le système
echo "$(date '+%Y-%m-%d %H:%M:%S') - Mise à jour du système"
sudo dnf update -y

# Installer les dépendances nécessaires
echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation des dépendances"
sudo dnf install -y jq wget docker aws-cli

# Démarrer et activer Docker
echo "$(date '+%Y-%m-%d %H:%M:%S') - Configuration de Docker"
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# Installation de Docker Compose
echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation de Docker Compose"
sudo wget -q -O /usr/local/bin/docker-compose "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)"
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Récupérer l'ID de l'instance pour les logs
echo "$(date '+%Y-%m-%d %H:%M:%S') - Récupération de l'ID de l'instance"
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id || echo "unknown")
echo "ID de l'instance: $INSTANCE_ID"

# Télécharger et exécuter le script d'initialisation depuis GitHub
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement du script d'initialisation depuis GitHub"
sudo mkdir -p /opt/monitoring
echo "$(date '+%Y-%m-%d %H:%M:%S') - Répertoire /opt/monitoring créé"

# Définir directement l'URL GitHub Raw
echo "$(date '+%Y-%m-%d %H:%M:%S') - Définition directe de l'URL GitHub"
GITHUB_RAW_URL="https://raw.githubusercontent.com/${github_repo_owner}/${github_repo_name}/main"
echo "$(date '+%Y-%m-%d %H:%M:%S') - URL GitHub Raw: $GITHUB_RAW_URL"

# Tester la connectivité à GitHub
echo "$(date '+%Y-%m-%d %H:%M:%S') - Test de connectivité à GitHub..."
if sudo wget -q --spider --timeout=10 "https://raw.githubusercontent.com"; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Connectivité à GitHub OK"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERREUR: Impossible de se connecter à GitHub"
fi

# Télécharger le script d'initialisation
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement du script init-monitoring.sh..."
sudo wget -v -O /opt/monitoring/init-monitoring.sh "$GITHUB_RAW_URL/scripts/ec2-monitoring/init-monitoring.sh" 2>&1 | tee -a /var/log/user-data-init.log

# Vérifier si le téléchargement a réussi
if [ -s /opt/monitoring/init-monitoring.sh ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Script init-monitoring.sh téléchargé avec succès"
  sudo chmod +x /opt/monitoring/init-monitoring.sh
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Permissions exécutables accordées au script"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERREUR CRITIQUE: Impossible de télécharger le script init-monitoring.sh"
  exit 1
fi

# Télécharger le script de configuration
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement du script de configuration setup-monitoring.sh..."
sudo wget -v -O /opt/monitoring/setup-monitoring.sh "$GITHUB_RAW_URL/scripts/ec2-monitoring/setup-monitoring.sh" 2>&1 | tee -a /var/log/user-data-init.log

# Vérifier si le téléchargement a réussi
if [ -s /opt/monitoring/setup-monitoring.sh ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Script setup-monitoring.sh téléchargé avec succès"
  sudo chmod +x /opt/monitoring/setup-monitoring.sh
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Permissions exécutables accordées au script"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERREUR: Impossible de télécharger le script setup-monitoring.sh"
fi

# Télécharger le fichier docker-compose.yml
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement du fichier docker-compose.yml..."
sudo wget -v -O /opt/monitoring/docker-compose.yml "$GITHUB_RAW_URL/scripts/ec2-monitoring/docker-compose.yml" 2>&1 | tee -a /var/log/user-data-init.log

# Vérifier si le téléchargement a réussi
if [ -s /opt/monitoring/docker-compose.yml ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Fichier docker-compose.yml téléchargé avec succès"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERREUR: Impossible de télécharger le fichier docker-compose.yml"
fi

# Exécuter le script d'initialisation
echo "$(date '+%Y-%m-%d %H:%M:%S') - Exécution du script d'initialisation"
sudo /opt/monitoring/init-monitoring.sh 2>&1 | tee -a /var/log/user-data-init.log

echo "$(date '+%Y-%m-%d %H:%M:%S') - Script d'initialisation terminé"
