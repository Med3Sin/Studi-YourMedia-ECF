#!/bin/bash
#==============================================================================
# Nom du script : init-monitoring.sh
# Description   : Script unifié d'initialisation pour l'instance EC2 de monitoring.
#                 Ce script configure l'environnement de l'instance, télécharge les scripts
#                 nécessaires depuis S3, récupère les variables d'environnement et initialise
#                 les conteneurs Docker.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 2.0
# Date          : 2025-05-01
#==============================================================================
# Utilisation   : sudo ./init-monitoring.sh
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

# Attendre que les métadonnées soient disponibles
MAX_RETRIES=10
RETRY_INTERVAL=5
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    INSTANCE_ID=$(curl -s --connect-timeout 2 --max-time 5 http://169.254.169.254/latest/meta-data/instance-id)
    if [ ! -z "$INSTANCE_ID" ]; then
        log "ID de l'instance récupéré: $INSTANCE_ID"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT+1))
    log "Tentative $RETRY_COUNT: Métadonnées non disponibles, nouvelle tentative dans $RETRY_INTERVAL secondes..."
    sleep $RETRY_INTERVAL
done

# Récupérer la région
REGION=$(curl -s --connect-timeout 2 --max-time 5 http://169.254.169.254/latest/meta-data/placement/region || echo "eu-west-3")
log "Région AWS: $REGION"

# Récupérer le nom du bucket S3 depuis les tags de l'instance
if [ ! -z "$INSTANCE_ID" ]; then
    S3_BUCKET_NAME=$(aws ec2 describe-tags --region "$REGION" --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=S3BucketName" --query "Tags[0].Value" --output text)
else
    S3_BUCKET_NAME="None"
fi

# Si le nom du bucket n'est pas trouvé, utiliser la valeur par défaut
if [ -z "$S3_BUCKET_NAME" ] || [ "$S3_BUCKET_NAME" == "None" ]; then
    log "Nom du bucket S3 non trouvé dans les tags, utilisation de la valeur par défaut"
    # Récupérer le nom du bucket depuis les variables d'environnement Terraform
    S3_BUCKET_NAME="yourmedia-dev-media-797748030261-e6ly5tku"
fi

log "Nom du bucket S3: $S3_BUCKET_NAME"

# Vérification des dépendances essentielles
log "Vérification des dépendances essentielles"
check_dependency() {
    local cmd=$1
    local pkg=$2

    if ! command -v $cmd &> /dev/null; then
        log "Dépendance manquante: $cmd. Installation de $pkg..."
        sudo dnf install -y $pkg || error_exit "Impossible d'installer $pkg"
    fi
}

check_dependency aws aws-cli
check_dependency curl curl
check_dependency jq jq
check_dependency docker docker

# Téléchargement des scripts depuis GitHub
log "Téléchargement des scripts depuis GitHub"
GITHUB_RAW_URL="https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main"

# Téléchargement du script de configuration
log "Téléchargement du script setup-monitoring.sh"
curl -s -o /opt/monitoring/setup-monitoring.sh "$GITHUB_RAW_URL/scripts/ec2-monitoring/setup-monitoring.sh"
chmod +x /opt/monitoring/setup-monitoring.sh

# Création d'un fichier env.json vide si nécessaire
log "Création d'un fichier env.json vide"
echo '{
  "RDS_USERNAME": "",
  "RDS_PASSWORD": "",
  "RDS_ENDPOINT": "",
  "RDS_NAME": "",
  "GRAFANA_ADMIN_PASSWORD": "admin",
  "S3_BUCKET_NAME": "",
  "AWS_REGION": "eu-west-3"
}' > /tmp/env.json

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
    sudo dnf install -y docker
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker ec2-user
else
    log "Docker est déjà installé"
    # S'assurer que Docker est démarré
    if ! sudo systemctl is-active --quiet docker; then
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
fi

# Installation de Docker Compose si nécessaire
log "Vérification de l'installation de Docker Compose"
if ! command -v docker-compose &> /dev/null; then
    log "Installation de Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
else
    log "Docker Compose est déjà installé"
fi

# Téléchargement des fichiers de configuration supplémentaires depuis GitHub
log "Téléchargement des fichiers de configuration supplémentaires depuis GitHub"

# Téléchargement des fichiers de configuration Prometheus
log "Téléchargement des fichiers de configuration Prometheus"
mkdir -p /opt/monitoring/config/prometheus
curl -s -o /opt/monitoring/config/prometheus/prometheus.yml "$GITHUB_RAW_URL/scripts/config/prometheus/prometheus.yml"
curl -s -o /opt/monitoring/config/prometheus/container-alerts.yml "$GITHUB_RAW_URL/scripts/config/prometheus/container-alerts.yml"

# Téléchargement des fichiers de configuration Grafana
log "Téléchargement des fichiers de configuration Grafana"
mkdir -p /opt/monitoring/config/grafana
curl -s -o /opt/monitoring/config/grafana/grafana.ini "$GITHUB_RAW_URL/scripts/config/grafana/grafana.ini"

# Téléchargement des fichiers de configuration Loki et Promtail
log "Téléchargement des fichiers de configuration Loki et Promtail"
curl -s -o /opt/monitoring/config/loki-config.yml "$GITHUB_RAW_URL/scripts/config/loki-config.yml"
curl -s -o /opt/monitoring/config/promtail-config.yml "$GITHUB_RAW_URL/scripts/config/promtail-config.yml"

# Téléchargement du fichier docker-compose.yml
log "Téléchargement du fichier docker-compose.yml"
curl -s -o /opt/monitoring/docker-compose.yml "$GITHUB_RAW_URL/scripts/ec2-monitoring/docker-compose.yml"

# Téléchargement des services systemd
log "Téléchargement des services systemd"
curl -s -o /opt/monitoring/container-health-check.service "$GITHUB_RAW_URL/scripts/ec2-monitoring/container-health-check.service"
curl -s -o /opt/monitoring/container-health-check.timer "$GITHUB_RAW_URL/scripts/ec2-monitoring/container-health-check.timer"
curl -s -o /opt/monitoring/container-tests.service "$GITHUB_RAW_URL/scripts/ec2-monitoring/container-tests.service"
curl -s -o /opt/monitoring/container-tests.timer "$GITHUB_RAW_URL/scripts/ec2-monitoring/container-tests.timer"

# Créer des liens symboliques pour la compatibilité avec les anciens scripts
log "Création de liens symboliques pour la compatibilité"
ln -sf /opt/monitoring/config/prometheus/prometheus.yml /opt/monitoring/prometheus.yml
ln -sf /opt/monitoring/config/prometheus/container-alerts.yml /opt/monitoring/prometheus-rules/container-alerts.yml
ln -sf /opt/monitoring/config/cloudwatch-config.yml /opt/monitoring/cloudwatch-config.yml
ln -sf /opt/monitoring/config/loki-config.yml /opt/monitoring/loki-config.yml
ln -sf /opt/monitoring/config/promtail-config.yml /opt/monitoring/promtail-config.yml

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
    sudo cp /opt/monitoring/container-health-check.service /etc/systemd/system/
    sudo cp /opt/monitoring/container-health-check.timer /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable container-health-check.timer
    sudo systemctl start container-health-check.timer
    log "Service container-health-check installé et activé"
fi

if [ -f "/opt/monitoring/container-tests.service" ]; then
    sudo cp /opt/monitoring/container-tests.service /etc/systemd/system/
    sudo cp /opt/monitoring/container-tests.timer /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable container-tests.timer
    sudo systemctl start container-tests.timer
    log "Service container-tests installé et activé"
fi

# Vérification des conteneurs en cours d'exécution
log "Vérification des conteneurs en cours d'exécution"
sudo docker ps

log "Initialisation terminée avec succès"
