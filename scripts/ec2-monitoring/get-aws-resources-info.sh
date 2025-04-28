#!/bin/bash
#==============================================================================
# Nom du script : get-aws-resources-info.sh
# Description   : Script pour récupérer automatiquement les informations de la base RDS et du bucket S3.
#                 Ce script récupère les informations des ressources AWS (RDS, S3) et les stocke
#                 dans des fichiers de configuration pour les services de monitoring.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2025-04-27
#==============================================================================
# Utilisation   : sudo ./get-aws-resources-info.sh
#
# Exemples      :
#   sudo ./get-aws-resources-info.sh
#==============================================================================
# Dépendances   :
#   - aws-cli   : Pour récupérer les informations des ressources AWS
#   - jq        : Pour traiter les réponses JSON
#   - curl      : Pour les requêtes HTTP
#   - openssl   : Pour générer des mots de passe aléatoires
#==============================================================================
# Variables d'environnement :
#   - S3_BUCKET_NAME : Nom du bucket S3 (optionnel, sera détecté automatiquement si non défini)
#   - RDS_ENDPOINT   : Endpoint RDS (optionnel, sera détecté automatiquement si non défini)
#   - RDS_USERNAME   : Nom d'utilisateur RDS (optionnel, valeur par défaut: yourmedia)
#   - RDS_PASSWORD   : Mot de passe RDS (optionnel, sera généré aléatoirement si non défini)
#   - AWS_REGION     : Région AWS (optionnel, valeur par défaut: eu-west-3)
#   - GRAFANA_ADMIN_PASSWORD : Mot de passe administrateur Grafana (optionnel, valeur par défaut: admin)
#==============================================================================

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Fonction pour afficher les erreurs et quitter
error_exit() {
    log "ERREUR: $1"
    exit 1
}

# Vérification si le script est exécuté avec sudo
if [ "$(id -u)" -ne 0 ]; then
    error_exit "Ce script doit être exécuté avec sudo"
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

check_dependency aws aws-cli
check_dependency jq jq
check_dependency curl curl

# Vérification des variables d'environnement
if [ -z "$S3_BUCKET_NAME" ]; then
    # Essayer de récupérer depuis les variables d'environnement système
    if [ -f "/opt/monitoring/env.sh" ]; then
        log "Chargement des variables d'environnement depuis /opt/monitoring/env.sh"
        source /opt/monitoring/env.sh
    else
        error_exit "La variable S3_BUCKET_NAME n'est pas définie et le fichier env.sh n'existe pas"
    fi
fi

# Vérifier à nouveau après avoir chargé env.sh
if [ -z "$S3_BUCKET_NAME" ]; then
    error_exit "La variable S3_BUCKET_NAME n'est pas définie"
fi

# Créer le répertoire de configuration s'il n'existe pas
CONFIG_DIR="/opt/monitoring"
mkdir -p $CONFIG_DIR

# Récupérer les informations RDS
log "Récupération des informations RDS..."
if [ -n "$RDS_ENDPOINT" ]; then
    log "Utilisation de la variable d'environnement RDS_ENDPOINT: $RDS_ENDPOINT"
else
    # Essayer de récupérer l'endpoint RDS via AWS CLI
    log "Tentative de récupération de l'endpoint RDS via AWS CLI..."
    RDS_ENDPOINT=$(aws rds describe-db-instances --query "DBInstances[?DBInstanceIdentifier=='yourmedia-dev-mysql'].Endpoint.Address" --output text)

    if [ -z "$RDS_ENDPOINT" ]; then
        log "Impossible de récupérer l'endpoint RDS. Utilisation de la valeur par défaut."
        RDS_ENDPOINT="yourmedia-dev-mysql.cluster-xxxxxxxxx.eu-west-3.rds.amazonaws.com"
    else
        log "Endpoint RDS récupéré: $RDS_ENDPOINT"
    fi
fi

# Récupérer les informations de la base de données
if [ -z "$RDS_USERNAME" ] || [ -z "$RDS_PASSWORD" ]; then
    log "Les variables RDS_USERNAME ou RDS_PASSWORD ne sont pas définies."
    log "Utilisation des valeurs par défaut pour la démonstration (à ne pas utiliser en production)."
    # Générer un mot de passe aléatoire si non défini
    RDS_USERNAME=${RDS_USERNAME:-"yourmedia"}
    if [ -z "$RDS_PASSWORD" ]; then
        log "Génération d'un mot de passe aléatoire pour la démonstration"
        RDS_PASSWORD=$(openssl rand -base64 12)
        log "Mot de passe généré avec succès (non affiché pour des raisons de sécurité)"
    else
        log "Utilisation du mot de passe fourni via la variable d'environnement"
    fi
else
    log "Utilisation des variables d'environnement RDS_USERNAME et RDS_PASSWORD"
fi

# Récupérer les informations du bucket S3
log "Récupération des informations du bucket S3..."
if [ -n "$S3_BUCKET_NAME" ]; then
    log "Utilisation de la variable d'environnement S3_BUCKET_NAME: $S3_BUCKET_NAME"
else
    # Essayer de récupérer le nom du bucket S3 via AWS CLI
    log "Tentative de récupération du nom du bucket S3 via AWS CLI..."
    S3_BUCKET_NAME=$(aws s3api list-buckets --query "Buckets[?contains(Name, 'yourmedia-dev-media')].Name" --output text | head -n 1)

    if [ -z "$S3_BUCKET_NAME" ]; then
        log "Impossible de récupérer le nom du bucket S3. Utilisation de la valeur par défaut."
        S3_BUCKET_NAME="yourmedia-dev-media-default"
    else
        log "Nom du bucket S3 récupéré: $S3_BUCKET_NAME"
    fi
fi

# Récupérer la région AWS
AWS_REGION=${AWS_REGION:-"eu-west-3"}
log "Région AWS: $AWS_REGION"

# Créer le fichier de configuration pour les variables d'environnement
log "Création du fichier de configuration pour les variables d'environnement..."
cat > $CONFIG_DIR/aws-resources.env << EOF
# Fichier généré automatiquement par get-aws-resources-info.sh
# Date de génération: $(date)

# Informations RDS
export RDS_ENDPOINT="$RDS_ENDPOINT"
export RDS_USERNAME="$RDS_USERNAME"
export RDS_PASSWORD="$RDS_PASSWORD"
# Variables de compatibilité (pour les scripts existants)
# Note: Nous standardisons sur RDS_* comme noms de variables principaux
# mais nous conservons DB_* pour la compatibilité avec les scripts existants
export DB_USERNAME="$RDS_USERNAME"
export DB_PASSWORD="$RDS_PASSWORD"
# Ajouter un commentaire pour indiquer que ces variables sont dépréciées
echo "# ATTENTION: Les variables DB_USERNAME et DB_PASSWORD sont dépréciées." >> $CONFIG_DIR/aws-resources.env
echo "# Utilisez plutôt RDS_USERNAME et RDS_PASSWORD pour les nouveaux scripts." >> $CONFIG_DIR/aws-resources.env

# Informations S3
export S3_BUCKET_NAME="$S3_BUCKET_NAME"
export AWS_REGION="$AWS_REGION"

# Informations pour SonarQube
export SONAR_JDBC_URL="jdbc:postgresql://sonarqube-db:5432/sonar"
export SONAR_JDBC_USERNAME="sonar"
export SONAR_JDBC_PASSWORD="sonar123"

# Informations pour Grafana
export GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-admin}"
EOF

# Définir les permissions appropriées - fichier accessible uniquement par root
chmod 400 $CONFIG_DIR/aws-resources.env
chown root:root $CONFIG_DIR/aws-resources.env
# Créer un répertoire sécurisé pour les secrets
mkdir -p $CONFIG_DIR/secrets
chmod 700 $CONFIG_DIR/secrets
chown root:root $CONFIG_DIR/secrets
# Créer un lien symbolique vers le fichier de configuration dans le répertoire sécurisé
ln -sf $CONFIG_DIR/aws-resources.env $CONFIG_DIR/secrets/aws-resources.env

# Créer le fichier de configuration pour CloudWatch Exporter
log "Création du fichier de configuration pour CloudWatch Exporter..."
cat > $CONFIG_DIR/cloudwatch-config.yml << EOF
---
region: $AWS_REGION
metrics:
  - aws_namespace: AWS/S3
    aws_metric_name: BucketSizeBytes
    aws_dimensions: [BucketName, StorageType]
    aws_dimension_select:
      BucketName: [$S3_BUCKET_NAME]
    aws_statistics: [Average]

  - aws_namespace: AWS/S3
    aws_metric_name: NumberOfObjects
    aws_dimensions: [BucketName, StorageType]
    aws_dimension_select:
      BucketName: [$S3_BUCKET_NAME]
    aws_statistics: [Average]

  - aws_namespace: AWS/RDS
    aws_metric_name: CPUUtilization
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average]

  - aws_namespace: AWS/RDS
    aws_metric_name: DatabaseConnections
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average]

  - aws_namespace: AWS/RDS
    aws_metric_name: FreeStorageSpace
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average]
EOF

# Appliquer les prérequis système pour SonarQube
log "Application des prérequis système pour SonarQube..."

# Augmenter la limite de mmap count
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Augmenter la limite de fichiers ouverts
echo "fs.file-max=65536" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Créer les répertoires pour SonarQube
mkdir -p $CONFIG_DIR/sonarqube-data/data
mkdir -p $CONFIG_DIR/sonarqube-data/logs
mkdir -p $CONFIG_DIR/sonarqube-data/extensions
mkdir -p $CONFIG_DIR/sonarqube-data/db

# Définir les permissions appropriées
chown -R 1000:1000 $CONFIG_DIR/sonarqube-data/data
chown -R 1000:1000 $CONFIG_DIR/sonarqube-data/logs
chown -R 1000:1000 $CONFIG_DIR/sonarqube-data/extensions
chown -R 999:999 $CONFIG_DIR/sonarqube-data/db

log "Configuration terminée avec succès!"
log "Les informations RDS et S3 ont été récupérées et stockées dans $CONFIG_DIR/aws-resources.env"
log "Pour utiliser ces variables, exécutez: source $CONFIG_DIR/aws-resources.env"

# Afficher un résumé des informations récupérées
log "Résumé des informations récupérées:"
log "- RDS Endpoint: $RDS_ENDPOINT"
log "- S3 Bucket: $S3_BUCKET_NAME"
log "- AWS Region: $AWS_REGION"

exit 0
