#!/bin/bash
# Script d'initialisation pour l'instance EC2 de monitoring

# Variables (seront remplacées par Terraform)
EC2_INSTANCE_PRIVATE_IP="PLACEHOLDER_IP"
DB_USERNAME="PLACEHOLDER_USERNAME"
DB_PASSWORD="PLACEHOLDER_PASSWORD"
RDS_ENDPOINT="PLACEHOLDER_ENDPOINT"
SONAR_JDBC_USERNAME="SONAR_JDBC_USERNAME"
SONAR_JDBC_PASSWORD="SONAR_JDBC_PASSWORD"
SONAR_JDBC_URL="SONAR_JDBC_URL"
GRAFANA_ADMIN_PASSWORD="GRAFANA_ADMIN_PASSWORD"
S3_BUCKET_NAME="PLACEHOLDER_BUCKET"

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Installation du script de correction des clés SSH
log "Installation du script de correction des clés SSH..."
aws s3 cp s3://${S3_BUCKET_NAME}/scripts/utils/fix-ssh-keys.sh /tmp/fix-ssh-keys.sh
chmod +x /tmp/fix-ssh-keys.sh
cp /tmp/fix-ssh-keys.sh /usr/local/bin/fix-ssh-keys.sh

# Installation des fichiers de service systemd
log "Installation des fichiers de service systemd..."
aws s3 cp s3://${S3_BUCKET_NAME}/scripts/utils/ssh-key-checker.service /etc/systemd/system/ssh-key-checker.service
aws s3 cp s3://${S3_BUCKET_NAME}/scripts/utils/ssh-key-checker.timer /etc/systemd/system/ssh-key-checker.timer

# Activation et démarrage du timer
log "Activation et démarrage du timer..."
systemctl daemon-reload
systemctl enable ssh-key-checker.timer
systemctl start ssh-key-checker.timer

# Récupération de la clé publique depuis les métadonnées de l'instance
log "Récupération de la clé publique depuis les métadonnées de l'instance..."
PUBLIC_KEY=$(curl -s http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key 2>/dev/null || echo "")
if [ ! -z "$PUBLIC_KEY" ]; then
  echo "$PUBLIC_KEY" >> /home/ec2-user/.ssh/authorized_keys
  log "Clé SSH publique AWS installée avec succès"
fi

# Ajustement des permissions
log "Ajustement des permissions..."
chown -R ec2-user:ec2-user /home/ec2-user/.ssh

# Création du répertoire de monitoring
log "Création du répertoire de monitoring..."
mkdir -p /opt/monitoring

# Téléchargement du script principal depuis S3
log "Téléchargement du script principal depuis S3..."
aws s3 cp s3://${S3_BUCKET_NAME}/scripts/ec2-monitoring/setup.sh /opt/monitoring/setup.sh

# Remplacement des variables dans le script
log "Remplacement des variables dans le script..."
sed -i "s/PLACEHOLDER_IP/${EC2_INSTANCE_PRIVATE_IP}/g" /opt/monitoring/setup.sh
sed -i "s/ec2_java_tomcat_ip=\"PLACEHOLDER_IP\"/ec2_java_tomcat_ip=\"${EC2_INSTANCE_PRIVATE_IP}\"/g" /opt/monitoring/setup.sh
sed -i "s/PLACEHOLDER_USERNAME/${DB_USERNAME}/g" /opt/monitoring/setup.sh
sed -i "s/PLACEHOLDER_PASSWORD/${DB_PASSWORD}/g" /opt/monitoring/setup.sh
sed -i "s/PLACEHOLDER_ENDPOINT/${RDS_ENDPOINT}/g" /opt/monitoring/setup.sh
sed -i "s/SONAR_JDBC_USERNAME/${SONAR_JDBC_USERNAME}/g" /opt/monitoring/setup.sh
sed -i "s/SONAR_JDBC_PASSWORD/${SONAR_JDBC_PASSWORD}/g" /opt/monitoring/setup.sh
sed -i "s|SONAR_JDBC_URL|${SONAR_JDBC_URL}|g" /opt/monitoring/setup.sh
sed -i "s/GRAFANA_ADMIN_PASSWORD/${GRAFANA_ADMIN_PASSWORD}/g" /opt/monitoring/setup.sh

# Exécution du script de correction des clés SSH
log "Exécution du script de correction des clés SSH..."
su - ec2-user -c "/usr/local/bin/fix-ssh-keys.sh"

# Exécution du script d'installation
log "Exécution du script d'installation..."
chmod +x /opt/monitoring/setup.sh
/opt/monitoring/setup.sh

log "Initialisation terminée avec succès."
