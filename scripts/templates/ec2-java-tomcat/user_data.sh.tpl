#!/bin/bash
#==============================================================================
# Script d'initialisation pour l'instance EC2 Java Tomcat (Hello World)
# Ce script télécharge et exécute les scripts nécessaires pour installer
# Java et Tomcat sur une instance EC2 Amazon Linux 2023.
#==============================================================================
set -e

# Rediriger stdout et stderr vers un fichier log
exec > >(tee /var/log/user-data-init.log) 2>&1

echo "$(date '+%Y-%m-%d %H:%M:%S') - Démarrage du script d'initialisation Hello World"

# Mettre à jour le système
echo "$(date '+%Y-%m-%d %H:%M:%S') - Mise à jour du système"
sudo dnf update -y

# Installer les dépendances nécessaires
echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation des dépendances"
sudo dnf install -y jq wget

# Configuration de la clé SSH
echo "$(date '+%Y-%m-%d %H:%M:%S') - Configuration de la clé SSH"
sudo mkdir -p /home/ec2-user/.ssh
sudo chmod 700 /home/ec2-user/.ssh
echo "${ssh_public_key}" | sudo tee -a /home/ec2-user/.ssh/authorized_keys > /dev/null
sudo chmod 600 /home/ec2-user/.ssh/authorized_keys
sudo chown -R ec2-user:ec2-user /home/ec2-user/.ssh

# Créer le répertoire pour les scripts
echo "$(date '+%Y-%m-%d %H:%M:%S') - Création du répertoire pour les scripts"
sudo mkdir -p /opt/yourmedia/secure
sudo chmod 755 /opt/yourmedia
sudo chmod 700 /opt/yourmedia/secure

# Définir l'URL GitHub Raw
GITHUB_RAW_URL="https://raw.githubusercontent.com/${github_repo_owner}/${github_repo_name}/main"
echo "$(date '+%Y-%m-%d %H:%M:%S') - URL GitHub Raw: $GITHUB_RAW_URL"

# Télécharger les scripts nécessaires
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement des scripts"
sudo wget -q -O /opt/yourmedia/init-java-tomcat.sh "$GITHUB_RAW_URL/scripts/ec2-java-tomcat/init-java-tomcat.sh"
sudo wget -q -O /opt/yourmedia/setup-java-tomcat.sh "$GITHUB_RAW_URL/scripts/ec2-java-tomcat/setup-java-tomcat.sh"
sudo wget -q -O /opt/yourmedia/deploy-war.sh "$GITHUB_RAW_URL/scripts/config/tomcat/deploy-war.sh"

# Rendre les scripts exécutables
echo "$(date '+%Y-%m-%d %H:%M:%S') - Attribution des permissions d'exécution aux scripts"
sudo chmod +x /opt/yourmedia/*.sh

# Définir la version de Tomcat
export TOMCAT_VERSION=9.0.104
echo "$(date '+%Y-%m-%d %H:%M:%S') - Version de Tomcat à installer: $TOMCAT_VERSION"

# Exécuter le script d'initialisation
echo "$(date '+%Y-%m-%d %H:%M:%S') - Exécution du script d'initialisation"
sudo -E /opt/yourmedia/init-java-tomcat.sh 2>&1 | tee -a /var/log/user-data-init.log

# Vérifier si Tomcat est en cours d'exécution
echo "$(date '+%Y-%m-%d %H:%M:%S') - Vérification de l'état de Tomcat"
if sudo systemctl is-active --quiet tomcat; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Tomcat est en cours d'exécution"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ Tomcat n'est pas en cours d'exécution. Démarrage manuel..."
    sudo systemctl start tomcat
    sudo systemctl enable tomcat
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Script d'initialisation terminé"
