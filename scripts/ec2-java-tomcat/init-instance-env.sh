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
if [ -z "${S3_BUCKET_NAME}" ]; then
  log "ERREUR: La variable S3_BUCKET_NAME n'est pas définie"
  error_exit "La variable S3_BUCKET_NAME est requise pour télécharger les scripts"
fi

log "Utilisation du bucket S3: ${S3_BUCKET_NAME}"
sudo aws s3 cp s3://${S3_BUCKET_NAME}/scripts/ec2-java-tomcat/install_java_tomcat.sh /opt/yourmedia/install_java_tomcat.sh || error_exit "Échec du téléchargement du script install_java_tomcat.sh"
sudo aws s3 cp s3://${S3_BUCKET_NAME}/scripts/ec2-java-tomcat/deploy-war.sh /opt/yourmedia/deploy-war.sh || error_exit "Échec du téléchargement du script deploy-war.sh"

# Rendre les scripts exécutables
sudo chmod +x /opt/yourmedia/install_java_tomcat.sh
sudo chmod +x /opt/yourmedia/deploy-war.sh

# Création d'un fichier de variables d'environnement pour les scripts
log "Création du fichier de variables d'environnement"
cat > /tmp/yourmedia-env.sh << EOF
export EC2_INSTANCE_PRIVATE_IP="${EC2_INSTANCE_PRIVATE_IP}"
# Variables RDS standardisées
export RDS_USERNAME="${RDS_USERNAME}"
export RDS_PASSWORD="${RDS_PASSWORD}"
export RDS_ENDPOINT="${RDS_ENDPOINT}"
# Variables de compatibilité (pour les scripts existants)
export DB_USERNAME="${RDS_USERNAME}"
export DB_PASSWORD="${RDS_PASSWORD}"
# Variables S3
export S3_BUCKET_NAME="${S3_BUCKET_NAME}"
# Variable Tomcat
export TOMCAT_VERSION="9.0.87"
EOF

sudo mv /tmp/yourmedia-env.sh /opt/yourmedia/env.sh
sudo chmod +x /opt/yourmedia/env.sh

# Modification du script install_java_tomcat.sh pour utiliser les variables d'environnement
log "Modification du script install_java_tomcat.sh pour utiliser les variables d'environnement"
# Vérifier si le fichier existe
if [ ! -f "/opt/yourmedia/install_java_tomcat.sh" ]; then
  error_exit "Le fichier install_java_tomcat.sh n'existe pas"
fi

# Créer un fichier temporaire avec le contenu souhaité
cat > /tmp/install_java_tomcat_header.sh << 'EOF'
#!/bin/bash
source /opt/yourmedia/env.sh

EOF

# Concaténer le fichier temporaire avec le fichier original
cat /tmp/install_java_tomcat_header.sh > /tmp/install_java_tomcat_new.sh
tail -n +2 /opt/yourmedia/install_java_tomcat.sh >> /tmp/install_java_tomcat_new.sh
sudo mv /tmp/install_java_tomcat_new.sh /opt/yourmedia/install_java_tomcat.sh
sudo chmod +x /opt/yourmedia/install_java_tomcat.sh
rm -f /tmp/install_java_tomcat_header.sh

# Exécution du script d'installation
log "Exécution du script d'installation"
sudo /opt/yourmedia/install_java_tomcat.sh

log "Initialisation terminée avec succès"
