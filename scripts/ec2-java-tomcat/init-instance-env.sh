#!/bin/bash
# Script simplifié d'initialisation pour l'instance EC2 Java Tomcat avec variables d'environnement

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Fonction pour afficher les erreurs et quitter
error_exit() {
    log "ERREUR: $1"
    exit 1
}

# Vérification des dépendances
check_dependency() {
    local cmd=$1
    local pkg=$2

    if ! command -v $cmd &> /dev/null; then
        log "Dépendance manquante: $cmd. Installation de $pkg..."
        sudo dnf install -y $pkg || error_exit "Impossible d'installer $pkg"
    fi
}

# Création du répertoire de l'application
log "Création du répertoire de l'application"
sudo mkdir -p /opt/yourmedia

# Configuration des clés SSH
log "Configuration des clés SSH"
sudo mkdir -p /home/ec2-user/.ssh
sudo chmod 700 /home/ec2-user/.ssh

# Récupération de la clé publique depuis les métadonnées
PUBLIC_KEY=$(curl -s http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key 2>/dev/null || echo "")
if [ ! -z "$PUBLIC_KEY" ]; then
  echo "$PUBLIC_KEY" | sudo tee -a /home/ec2-user/.ssh/authorized_keys > /dev/null
fi
sudo chown -R ec2-user:ec2-user /home/ec2-user/.ssh
sudo chmod 600 /home/ec2-user/.ssh/authorized_keys

# Vérification des dépendances essentielles
log "Vérification des dépendances essentielles"
check_dependency aws aws-cli
check_dependency curl curl
check_dependency sed sed

# Téléchargement des scripts depuis S3
log "Téléchargement des scripts depuis S3"
sudo aws s3 cp s3://${S3_BUCKET_NAME}/scripts/ec2-java-tomcat/install_java_tomcat.sh /opt/yourmedia/install_java_tomcat.sh
sudo aws s3 cp s3://${S3_BUCKET_NAME}/scripts/ec2-java-tomcat/deploy-war.sh /opt/yourmedia/deploy-war.sh
sudo aws s3 cp s3://${S3_BUCKET_NAME}/scripts/docker/docker-manager.sh /opt/yourmedia/docker-manager.sh

# Rendre les scripts exécutables
sudo chmod +x /opt/yourmedia/install_java_tomcat.sh
sudo chmod +x /opt/yourmedia/deploy-war.sh
sudo chmod +x /opt/yourmedia/docker-manager.sh

# Copier docker-manager.sh dans /usr/local/bin/
log "Copie de docker-manager.sh dans /usr/local/bin/"
sudo cp /opt/yourmedia/docker-manager.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/docker-manager.sh

# Création d'un fichier de variables d'environnement pour les scripts
log "Création du fichier de variables d'environnement"
cat > /tmp/yourmedia-env.sh << EOF
export EC2_INSTANCE_PRIVATE_IP="${EC2_INSTANCE_PRIVATE_IP}"
export DB_USERNAME="${DB_USERNAME}"
export DB_PASSWORD="${DB_PASSWORD}"
export RDS_ENDPOINT="${RDS_ENDPOINT}"
export S3_BUCKET_NAME="${S3_BUCKET_NAME}"
export DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME}"
export DOCKERHUB_TOKEN="${DOCKERHUB_TOKEN}"
export DOCKERHUB_REPO="${DOCKERHUB_REPO}"
EOF

sudo mv /tmp/yourmedia-env.sh /opt/yourmedia/env.sh
sudo chmod +x /opt/yourmedia/env.sh

# Modification du script install_java_tomcat.sh pour utiliser les variables d'environnement
log "Modification du script install_java_tomcat.sh pour utiliser les variables d'environnement"
sudo sed -i '1s/^/#!/bin\/bash\nsource \/opt\/yourmedia\/env.sh\n\n/' /opt/yourmedia/install_java_tomcat.sh

# Exécution du script d'installation
log "Exécution du script d'installation"
sudo /opt/yourmedia/install_java_tomcat.sh

log "Initialisation terminée avec succès"
