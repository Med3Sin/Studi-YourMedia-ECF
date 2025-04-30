#!/bin/bash
#==============================================================================
# Nom du script : init-monitoring-unified.sh
# Description   : Script unifié d'initialisation pour l'instance EC2 de monitoring.
#                 Ce script configure l'environnement de l'instance, télécharge les scripts
#                 nécessaires depuis S3, récupère les variables d'environnement et initialise
#                 les conteneurs Docker.
# Version       : 2.0
# Date          : 2025-05-01
#==============================================================================
# Utilisation   : sudo ./init-monitoring-unified.sh
#==============================================================================
# Dépendances   :
#   - aws-cli   : Pour télécharger les scripts depuis S3
#   - docker    : Pour gérer les conteneurs
#   - curl      : Pour récupérer les métadonnées de l'instance
#   - jq        : Pour traiter les fichiers JSON
#==============================================================================

# Journalisation
LOG_FILE="/var/log/init-monitoring.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Fonction pour afficher les erreurs et quitter
error_exit() {
    log "ERREUR: $1"
    exit 1
}

# Vérification des droits sudo
if [ "$(id -u)" -ne 0 ]; then
    error_exit "Ce script doit être exécuté avec sudo ou en tant que root"
fi

# Création des répertoires nécessaires
log "Création des répertoires nécessaires"
mkdir -p /opt/monitoring/secure
mkdir -p /opt/monitoring/data/prometheus
mkdir -p /opt/monitoring/data/grafana
mkdir -p /opt/monitoring/config
mkdir -p /opt/monitoring/prometheus-rules

# Récupération du nom du bucket S3 depuis les métadonnées de l'instance
log "Récupération du nom du bucket S3 depuis les métadonnées de l'instance"
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
S3_BUCKET_NAME=$(aws ec2 describe-tags --region $REGION --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=S3BucketName" --query "Tags[0].Value" --output text)

# Si le nom du bucket n'est pas trouvé, utiliser la valeur par défaut
if [ -z "$S3_BUCKET_NAME" ] || [ "$S3_BUCKET_NAME" == "None" ]; then
    log "Nom du bucket S3 non trouvé dans les tags, utilisation de la valeur par défaut"
    S3_BUCKET_NAME="yourmedia-ecf-studi"
fi

# Vérification des dépendances essentielles
log "Vérification des dépendances essentielles"
check_dependency() {
    local cmd=$1
    local pkg=$2

    if ! command -v $cmd &> /dev/null; then
        log "Dépendance manquante: $cmd. Installation de $pkg..."
        dnf install -y $pkg || error_exit "Impossible d'installer $pkg"
    fi
}

check_dependency aws aws-cli
check_dependency curl curl
check_dependency jq jq
check_dependency docker docker

# Téléchargement des scripts depuis S3
log "Téléchargement des scripts depuis S3"
aws s3 cp s3://$S3_BUCKET_NAME/scripts/ec2-monitoring/setup-monitoring.sh /opt/monitoring/setup-monitoring.sh
chmod +x /opt/monitoring/setup-monitoring.sh

# Récupération des variables depuis S3
log "Récupération des variables depuis S3"
aws s3 cp s3://$S3_BUCKET_NAME/secrets/env.json /tmp/env.json

# Extraction des variables
RDS_USERNAME=$(jq -r '.RDS_USERNAME' /tmp/env.json)
RDS_PASSWORD=$(jq -r '.RDS_PASSWORD' /tmp/env.json)
RDS_ENDPOINT=$(jq -r '.RDS_ENDPOINT' /tmp/env.json)
RDS_NAME=$(jq -r '.RDS_NAME' /tmp/env.json)
GRAFANA_ADMIN_PASSWORD=$(jq -r '.GRAFANA_ADMIN_PASSWORD' /tmp/env.json)
S3_BUCKET_NAME=$(jq -r '.S3_BUCKET_NAME' /tmp/env.json)
AWS_REGION=$(jq -r '.AWS_REGION' /tmp/env.json)
MONITORING_EC2_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
EC2_INSTANCE_PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# Suppression du fichier temporaire
rm /tmp/env.json

# Création du fichier de variables d'environnement
log "Création du fichier de variables d'environnement"
cat > /opt/monitoring/secure/.env << EOF
RDS_USERNAME=$RDS_USERNAME
RDS_PASSWORD=$RDS_PASSWORD
RDS_ENDPOINT=$RDS_ENDPOINT
RDS_NAME=$RDS_NAME
GRAFANA_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD
S3_BUCKET_NAME=$S3_BUCKET_NAME
AWS_REGION=$AWS_REGION
MONITORING_EC2_PUBLIC_IP=$MONITORING_EC2_PUBLIC_IP
EC2_INSTANCE_PRIVATE_IP=$EC2_INSTANCE_PRIVATE_IP
EOF

# Sécurisation du fichier
chmod 600 /opt/monitoring/secure/.env
chown root:root /opt/monitoring/secure/.env

# Création du fichier env.sh pour les scripts shell
log "Création du fichier env.sh pour les scripts shell"
cat > /opt/monitoring/env.sh << EOF
#!/bin/bash
# Variables d'environnement pour le monitoring
# Généré automatiquement par init-monitoring-unified.sh
# Date de génération: $(date)

# Variables EC2
export EC2_INSTANCE_PRIVATE_IP="$EC2_INSTANCE_PRIVATE_IP"
export EC2_INSTANCE_PUBLIC_IP="$MONITORING_EC2_PUBLIC_IP"
export EC2_INSTANCE_ID="$INSTANCE_ID"
export EC2_INSTANCE_REGION="$REGION"

# Variables S3
export S3_BUCKET_NAME="$S3_BUCKET_NAME"
export AWS_REGION="$AWS_REGION"

# Variables RDS
export RDS_USERNAME="$RDS_USERNAME"
export RDS_PASSWORD="$RDS_PASSWORD"
export RDS_ENDPOINT="$RDS_ENDPOINT"
export RDS_NAME="$RDS_NAME"

# Variables Grafana
export GRAFANA_ADMIN_PASSWORD="$GRAFANA_ADMIN_PASSWORD"
export GF_SECURITY_ADMIN_PASSWORD="$GRAFANA_ADMIN_PASSWORD"

# Variables de compatibilité
export DB_USERNAME="$RDS_USERNAME"
export DB_PASSWORD="$RDS_PASSWORD"
export DB_ENDPOINT="$RDS_ENDPOINT"
EOF

chmod +x /opt/monitoring/env.sh

# Installation de Docker si nécessaire
log "Vérification de l'installation de Docker"
if ! command -v docker &> /dev/null; then
    log "Installation de Docker..."
    dnf install -y docker
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ec2-user
else
    log "Docker est déjà installé"
    # S'assurer que Docker est démarré
    if ! systemctl is-active --quiet docker; then
        systemctl start docker
        systemctl enable docker
    fi
fi

# Installation de Docker Compose si nécessaire
log "Vérification de l'installation de Docker Compose"
if ! command -v docker-compose &> /dev/null; then
    log "Installation de Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
else
    log "Docker Compose est déjà installé"
fi

# Téléchargement des fichiers de configuration supplémentaires
log "Téléchargement des fichiers de configuration supplémentaires"
aws s3 cp --recursive s3://$S3_BUCKET_NAME/scripts/ec2-monitoring/ /opt/monitoring/
aws s3 cp --recursive s3://$S3_BUCKET_NAME/scripts/config/ /opt/monitoring/config/

# Rendre les scripts exécutables
log "Rendre les scripts exécutables"
find /opt/monitoring -name "*.sh" -exec chmod +x {} \;

# Configurer les limites de ressources système
log "Configuration des limites de ressources système"
if ! grep -q "ec2-user.*nofile" /etc/security/limits.conf; then
    echo "ec2-user soft nofile 4096" | tee -a /etc/security/limits.conf
    echo "ec2-user hard nofile 4096" | tee -a /etc/security/limits.conf
    echo "ec2-user soft nproc 2048" | tee -a /etc/security/limits.conf
    echo "ec2-user hard nproc 2048" | tee -a /etc/security/limits.conf
fi

# Exécution du script de configuration
log "Exécution du script de configuration"
cd /opt/monitoring
source /opt/monitoring/env.sh
./setup-monitoring.sh

# Installation des services systemd pour la surveillance des conteneurs
log "Installation des services systemd pour la surveillance des conteneurs"
if [ -f "/opt/monitoring/container-health-check.service" ]; then
    cp /opt/monitoring/container-health-check.service /etc/systemd/system/
    cp /opt/monitoring/container-health-check.timer /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable container-health-check.timer
    systemctl start container-health-check.timer
    log "Service container-health-check installé et activé"
fi

if [ -f "/opt/monitoring/container-tests.service" ]; then
    cp /opt/monitoring/container-tests.service /etc/systemd/system/
    cp /opt/monitoring/container-tests.timer /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable container-tests.timer
    systemctl start container-tests.timer
    log "Service container-tests installé et activé"
fi

# Vérification des conteneurs en cours d'exécution
log "Vérification des conteneurs en cours d'exécution"
docker ps

log "Initialisation terminée avec succès"
