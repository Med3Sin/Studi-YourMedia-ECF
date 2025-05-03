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
sudo dnf install -y jq wget aws-cli

# Configuration de la clé SSH
echo "$(date '+%Y-%m-%d %H:%M:%S') - Configuration de la clé SSH"
sudo mkdir -p /home/ec2-user/.ssh
sudo chmod 700 /home/ec2-user/.ssh
echo "${ssh_public_key}" | sudo tee -a /home/ec2-user/.ssh/authorized_keys > /dev/null
sudo chmod 600 /home/ec2-user/.ssh/authorized_keys
sudo chown -R ec2-user:ec2-user /home/ec2-user/.ssh

# Récupérer l'ID de l'instance pour les logs
echo "$(date '+%Y-%m-%d %H:%M:%S') - Récupération de l'ID de l'instance"
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id || echo "unknown")
echo "ID de l'instance: $INSTANCE_ID"

# Télécharger et exécuter le script d'initialisation depuis GitHub
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement du script d'initialisation depuis GitHub"
sudo mkdir -p /opt/yourmedia
echo "$(date '+%Y-%m-%d %H:%M:%S') - Répertoire /opt/yourmedia créé"

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
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement du script init-java-tomcat.sh..."
sudo wget -v -O /opt/yourmedia/init-java-tomcat.sh "$GITHUB_RAW_URL/scripts/ec2-java-tomcat/init-java-tomcat.sh" 2>&1 | tee -a /var/log/user-data-init.log

# Vérifier si le téléchargement a réussi
if [ -s /opt/yourmedia/init-java-tomcat.sh ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Script init-java-tomcat.sh téléchargé avec succès"
  sudo chmod +x /opt/yourmedia/init-java-tomcat.sh
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Permissions exécutables accordées au script"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERREUR CRITIQUE: Impossible de télécharger le script init-java-tomcat.sh"
  exit 1
fi

# Télécharger le script de configuration
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement du script de configuration setup-java-tomcat.sh..."
sudo wget -v -O /opt/yourmedia/setup-java-tomcat.sh "$GITHUB_RAW_URL/scripts/ec2-java-tomcat/setup-java-tomcat.sh" 2>&1 | tee -a /var/log/user-data-init.log

# Vérifier si le téléchargement a réussi
if [ -s /opt/yourmedia/setup-java-tomcat.sh ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Script setup-java-tomcat.sh téléchargé avec succès"
  sudo chmod +x /opt/yourmedia/setup-java-tomcat.sh
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Permissions exécutables accordées au script"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERREUR: Impossible de télécharger le script setup-java-tomcat.sh"
fi

# Exécuter le script d'initialisation
echo "$(date '+%Y-%m-%d %H:%M:%S') - Exécution du script d'initialisation"
sudo /opt/yourmedia/init-java-tomcat.sh 2>&1 | tee -a /var/log/user-data-init.log

echo "$(date '+%Y-%m-%d %H:%M:%S') - Script d'initialisation terminé"
