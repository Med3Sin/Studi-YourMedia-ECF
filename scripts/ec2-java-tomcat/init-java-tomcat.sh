#!/bin/bash
#==============================================================================
# Nom du script : init-java-tomcat.sh
# Description   : Script d'initialisation pour l'instance EC2 Java/Tomcat.
#                 Ce script télécharge et exécute les scripts de configuration
#                 nécessaires pour configurer l'environnement Java et Tomcat.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.1
# Date          : 2023-11-15
#==============================================================================
# Utilisation   : Ce script est exécuté automatiquement lors du démarrage de l'instance EC2.
#
# Exemples      :
#   sudo ./init-java-tomcat.sh
#==============================================================================
# Dépendances   :
#   - wget      : Pour télécharger les scripts depuis GitHub et récupérer les métadonnées
#   - jq        : Pour traiter les fichiers JSON
#   - aws-cli   : Pour interagir avec les services AWS
#==============================================================================
# Droits requis : Ce script doit être exécuté avec des privilèges sudo ou en tant que root.
#==============================================================================

# Journalisation
LOG_FILE="/var/log/init-java-tomcat.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "$(date '+%Y-%m-%d %H:%M:%S') - Démarrage de l'initialisation de Java/Tomcat"

# Création des répertoires nécessaires
sudo mkdir -p /opt/yourmedia/secure

# Récupération du nom du bucket S3 depuis les métadonnées de l'instance
# Attendre que les métadonnées soient disponibles
MAX_RETRIES=10
RETRY_INTERVAL=5
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  INSTANCE_ID=$(sudo wget -q -O - --timeout=5 http://169.254.169.254/latest/meta-data/instance-id)
  if [ ! -z "$INSTANCE_ID" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ID de l'instance récupéré: $INSTANCE_ID"
    break
  fi
  RETRY_COUNT=$((RETRY_COUNT+1))
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Tentative $RETRY_COUNT: Métadonnées non disponibles, nouvelle tentative dans $RETRY_INTERVAL secondes..."
  sleep $RETRY_INTERVAL
done

# Récupérer la région
REGION=$(sudo wget -q -O - --timeout=5 http://169.254.169.254/latest/meta-data/placement/region || echo "eu-west-3")
echo "$(date '+%Y-%m-%d %H:%M:%S') - Région AWS: $REGION"

# Récupérer le nom du bucket S3 depuis les tags de l'instance
if [ ! -z "$INSTANCE_ID" ]; then
  S3_BUCKET_NAME=$(sudo aws ec2 describe-tags --region "$REGION" --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=S3BucketName" --query "Tags[0].Value" --output text)
else
  S3_BUCKET_NAME="None"
fi

# Si le nom du bucket n'est pas trouvé, utiliser la valeur par défaut
if [ -z "$S3_BUCKET_NAME" ] || [ "$S3_BUCKET_NAME" == "None" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Nom du bucket S3 non trouvé dans les tags, utilisation de la valeur par défaut"
  # Récupérer le nom du bucket depuis les variables d'environnement Terraform
  S3_BUCKET_NAME="yourmedia-dev-media-797748030261-e6ly5tku"
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Nom du bucket S3: $S3_BUCKET_NAME"

# Téléchargement des scripts depuis GitHub
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement des scripts depuis GitHub"
GITHUB_RAW_URL="https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main"

# Installation de wget si nécessaire
if ! command -v wget &> /dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation de wget"
    sudo dnf install -y wget
fi

# Téléchargement du script de configuration
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement du script setup-java-tomcat.sh"
sudo wget -q -O /opt/yourmedia/setup-java-tomcat.sh "$GITHUB_RAW_URL/scripts/ec2-java-tomcat/setup-java-tomcat.sh"
sudo chmod +x /opt/yourmedia/setup-java-tomcat.sh

# Téléchargement du script de déploiement
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement du script deploy-war.sh"
sudo wget -q -O /opt/yourmedia/deploy-war.sh "$GITHUB_RAW_URL/scripts/ec2-java-tomcat/deploy-war.sh"
sudo chmod +x /opt/yourmedia/deploy-war.sh

# Création d'un fichier env.json vide si nécessaire
echo "$(date '+%Y-%m-%d %H:%M:%S') - Création d'un fichier env.json vide"
sudo bash -c 'cat > /tmp/env.json << EOF
{
  "RDS_USERNAME": "",
  "RDS_PASSWORD": "",
  "RDS_ENDPOINT": "",
  "RDS_NAME": "",
  "S3_BUCKET_NAME": "",
  "AWS_REGION": "eu-west-3"
}
EOF'

# Extraction des variables
RDS_USERNAME=$(jq -r '.RDS_USERNAME' /tmp/env.json)
RDS_PASSWORD=$(jq -r '.RDS_PASSWORD' /tmp/env.json)
RDS_ENDPOINT=$(jq -r '.RDS_ENDPOINT' /tmp/env.json)
RDS_NAME=$(jq -r '.RDS_NAME' /tmp/env.json)
S3_BUCKET_NAME=$(jq -r '.S3_BUCKET_NAME' /tmp/env.json)
AWS_REGION=$(jq -r '.AWS_REGION' /tmp/env.json)
JAVA_TOMCAT_EC2_PUBLIC_IP=$(sudo wget -q -O - http://169.254.169.254/latest/meta-data/public-ipv4)

# Suppression du fichier temporaire
sudo rm /tmp/env.json

# Création du fichier de variables d'environnement
sudo bash -c "cat > /opt/yourmedia/secure/.env << EOF
RDS_USERNAME=$RDS_USERNAME
RDS_PASSWORD=$RDS_PASSWORD
RDS_ENDPOINT=$RDS_ENDPOINT
RDS_NAME=$RDS_NAME
S3_BUCKET_NAME=$S3_BUCKET_NAME
AWS_REGION=$AWS_REGION
JAVA_TOMCAT_EC2_PUBLIC_IP=$JAVA_TOMCAT_EC2_PUBLIC_IP
EOF"

# Sécurisation du fichier
sudo chmod 600 /opt/yourmedia/secure/.env
sudo chown root:root /opt/yourmedia/secure/.env

# Exécution du script de configuration
echo "$(date '+%Y-%m-%d %H:%M:%S') - Exécution du script de configuration"
cd /opt/yourmedia
sudo ./setup-java-tomcat.sh

echo "$(date '+%Y-%m-%d %H:%M:%S') - Initialisation terminée avec succès"
