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

# Charger les variables d'environnement si elles existent
if [ -f "/opt/yourmedia/env.sh" ]; then
    log "Chargement des variables d'environnement depuis /opt/yourmedia/env.sh"
    source /opt/yourmedia/env.sh
fi

# Charger les variables sensibles si elles existent
if [ -f "/opt/yourmedia/secure/sensitive-env.sh" ]; then
    log "Chargement des variables sensibles depuis /opt/yourmedia/secure/sensitive-env.sh"
    source /opt/yourmedia/secure/sensitive-env.sh
fi

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
# Récupérer la variable S3_BUCKET_NAME depuis les métadonnées de l'instance si elle n'est pas définie
if [ -z "${S3_BUCKET_NAME}" ]; then
  log "La variable S3_BUCKET_NAME n'est pas définie, tentative de récupération depuis les métadonnées de l'instance..."
  # Récupérer les tags de l'instance
  INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
  REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

  # Récupérer le tag S3_BUCKET_NAME
  S3_BUCKET_NAME=$(aws ec2 describe-tags --region $REGION --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=S3_BUCKET_NAME" --query "Tags[0].Value" --output text)

  if [ -z "${S3_BUCKET_NAME}" ] || [ "${S3_BUCKET_NAME}" = "None" ]; then
    log "ERREUR: Impossible de récupérer la variable S3_BUCKET_NAME depuis les métadonnées de l'instance"
    error_exit "La variable S3_BUCKET_NAME est requise pour télécharger les scripts"
  fi

  # Exporter la variable pour les scripts suivants
  export S3_BUCKET_NAME
  log "Variable S3_BUCKET_NAME récupérée depuis les métadonnées de l'instance: ${S3_BUCKET_NAME}"
fi

log "Utilisation du bucket S3: ${S3_BUCKET_NAME}"
sudo aws s3 cp s3://${S3_BUCKET_NAME}/scripts/ec2-java-tomcat/install_java_tomcat.sh /opt/yourmedia/install_java_tomcat.sh || error_exit "Échec du téléchargement du script install_java_tomcat.sh"

# Vérifier si le script deploy-war.sh existe déjà dans le répertoire /opt/yourmedia
if [ -f "/opt/yourmedia/deploy-war.sh" ]; then
  log "Le script deploy-war.sh existe déjà. Sauvegarde du script existant..."
  sudo mv /opt/yourmedia/deploy-war.sh /opt/yourmedia/deploy-war.sh.bak
fi

# Télécharger le script deploy-war.sh depuis S3
sudo aws s3 cp s3://${S3_BUCKET_NAME}/scripts/ec2-java-tomcat/deploy-war.sh /opt/yourmedia/deploy-war.sh || error_exit "Échec du téléchargement du script deploy-war.sh"

# Télécharger le script fix_permissions.sh depuis S3
sudo aws s3 cp s3://${S3_BUCKET_NAME}/scripts/ec2-java-tomcat/fix_permissions.sh /opt/yourmedia/fix_permissions.sh || log "AVERTISSEMENT: Échec du téléchargement du script fix_permissions.sh"

# Rendre les scripts exécutables
sudo chmod +x /opt/yourmedia/install_java_tomcat.sh
sudo chmod +x /opt/yourmedia/deploy-war.sh
if [ -f "/opt/yourmedia/fix_permissions.sh" ]; then
    sudo chmod +x /opt/yourmedia/fix_permissions.sh
fi

# Création d'un fichier de variables d'environnement pour les scripts
log "Création du fichier de variables d'environnement"

# Créer un répertoire sécurisé pour les variables d'environnement
sudo mkdir -p /opt/yourmedia/secure
sudo chmod 700 /opt/yourmedia/secure

# Créer un fichier pour les variables non sensibles
cat > /tmp/yourmedia-env.sh << EOF
export EC2_INSTANCE_PRIVATE_IP="${EC2_INSTANCE_PRIVATE_IP}"
# Variables RDS standardisées (références sécurisées)
export RDS_USERNAME="\$(cat /opt/yourmedia/secure/rds_username.txt 2>/dev/null || echo "${RDS_USERNAME}")"
export RDS_ENDPOINT="\$(cat /opt/yourmedia/secure/rds_endpoint.txt 2>/dev/null || echo "${RDS_ENDPOINT}")"
# Variables de compatibilité (pour les scripts existants)
export DB_USERNAME="\$RDS_USERNAME"
# Variables S3
export S3_BUCKET_NAME="${S3_BUCKET_NAME}"
# Variable Tomcat
export TOMCAT_VERSION="9.0.87"
# Charger les variables sensibles
source /opt/yourmedia/secure/sensitive-env.sh 2>/dev/null || true
EOF

# Créer un fichier pour les variables sensibles
cat > /tmp/sensitive-env.sh << EOF
# Variables sensibles
export RDS_PASSWORD="${RDS_PASSWORD}"
export DB_PASSWORD="\$RDS_PASSWORD"
EOF

# Déplacer les fichiers vers leurs emplacements définitifs
sudo mv /tmp/yourmedia-env.sh /opt/yourmedia/env.sh
sudo mv /tmp/sensitive-env.sh /opt/yourmedia/secure/sensitive-env.sh

# Définir les permissions appropriées
sudo chmod +x /opt/yourmedia/env.sh
sudo chmod 600 /opt/yourmedia/secure/sensitive-env.sh

# Stocker les variables non sensibles dans des fichiers séparés pour une meilleure sécurité
echo "${RDS_USERNAME}" | sudo tee /opt/yourmedia/secure/rds_username.txt > /dev/null
echo "${RDS_ENDPOINT}" | sudo tee /opt/yourmedia/secure/rds_endpoint.txt > /dev/null
sudo chmod 600 /opt/yourmedia/secure/rds_username.txt
sudo chmod 600 /opt/yourmedia/secure/rds_endpoint.txt

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

# Exécution du script de correction des permissions
if [ -f "/opt/yourmedia/fix_permissions.sh" ]; then
    log "Exécution du script de correction des permissions"
    sudo /opt/yourmedia/fix_permissions.sh || log "AVERTISSEMENT: L'exécution du script fix_permissions.sh a échoué."
fi

# Exécution du script d'installation
log "Exécution du script d'installation"
sudo /opt/yourmedia/install_java_tomcat.sh

log "Initialisation terminée avec succès"
