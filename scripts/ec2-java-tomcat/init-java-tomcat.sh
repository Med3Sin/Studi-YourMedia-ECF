#!/bin/bash

# Journalisation
LOG_FILE="/var/log/init-java-tomcat.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "$(date '+%Y-%m-%d %H:%M:%S') - Démarrage de l'initialisation de Java/Tomcat"

# Création des répertoires nécessaires
mkdir -p /opt/yourmedia/secure

# Récupération du nom du bucket S3 depuis les métadonnées de l'instance
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
S3_BUCKET_NAME=$(aws ec2 describe-tags --region $REGION --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=S3BucketName" --query "Tags[0].Value" --output text)

# Si le nom du bucket n'est pas trouvé, utiliser la valeur par défaut
if [ -z "$S3_BUCKET_NAME" ] || [ "$S3_BUCKET_NAME" == "None" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Nom du bucket S3 non trouvé dans les tags, utilisation de la valeur par défaut"
  S3_BUCKET_NAME="yourmedia-ecf-studi"
fi

# Téléchargement des scripts depuis S3
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement des scripts depuis S3"
aws s3 cp s3://$S3_BUCKET_NAME/scripts/ec2-java-tomcat/setup-java-tomcat.sh /opt/yourmedia/setup-java-tomcat.sh
chmod +x /opt/yourmedia/setup-java-tomcat.sh

aws s3 cp s3://$S3_BUCKET_NAME/scripts/ec2-java-tomcat/deploy-war.sh /opt/yourmedia/deploy-war.sh
chmod +x /opt/yourmedia/deploy-war.sh

# Récupération des variables depuis S3
echo "$(date '+%Y-%m-%d %H:%M:%S') - Récupération des variables depuis S3"
aws s3 cp s3://$S3_BUCKET_NAME/secrets/env.json /tmp/env.json

# Extraction des variables
RDS_USERNAME=$(jq -r '.RDS_USERNAME' /tmp/env.json)
RDS_PASSWORD=$(jq -r '.RDS_PASSWORD' /tmp/env.json)
RDS_ENDPOINT=$(jq -r '.RDS_ENDPOINT' /tmp/env.json)
RDS_NAME=$(jq -r '.RDS_NAME' /tmp/env.json)
S3_BUCKET_NAME=$(jq -r '.S3_BUCKET_NAME' /tmp/env.json)
AWS_REGION=$(jq -r '.AWS_REGION' /tmp/env.json)
JAVA_TOMCAT_EC2_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Suppression du fichier temporaire
rm /tmp/env.json

# Création du fichier de variables d'environnement
cat > /opt/yourmedia/secure/.env << EOF
RDS_USERNAME=$RDS_USERNAME
RDS_PASSWORD=$RDS_PASSWORD
RDS_ENDPOINT=$RDS_ENDPOINT
RDS_NAME=$RDS_NAME
S3_BUCKET_NAME=$S3_BUCKET_NAME
AWS_REGION=$AWS_REGION
JAVA_TOMCAT_EC2_PUBLIC_IP=$JAVA_TOMCAT_EC2_PUBLIC_IP
EOF

# Sécurisation du fichier
chmod 600 /opt/yourmedia/secure/.env
chown root:root /opt/yourmedia/secure/.env

# Exécution du script de configuration
echo "$(date '+%Y-%m-%d %H:%M:%S') - Exécution du script de configuration"
cd /opt/yourmedia
./setup-java-tomcat.sh

echo "$(date '+%Y-%m-%d %H:%M:%S') - Initialisation terminée avec succès"
