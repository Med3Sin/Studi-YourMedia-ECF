#!/bin/bash
# Script pour corriger les problèmes avec les exporters
# Auteur: Med3Sin
# Date: $(date +%Y-%m-%d)

# Fonction de journalisation
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Vérifier si le script est exécuté avec les privilèges root
if [ "$(id -u)" -ne 0 ]; then
    log "Ce script doit être exécuté avec les privilèges root (sudo)."
    exit 1
fi

# Créer le répertoire pour les fichiers de configuration
log "Création des répertoires nécessaires..."
mkdir -p /opt/monitoring

# Créer le fichier de configuration pour cloudwatch-exporter
log "Création du fichier de configuration pour cloudwatch-exporter..."
cat > /opt/monitoring/cloudwatch-config.yml << 'EOL'
region: eu-west-3
metrics:
  - aws_namespace: AWS/EC2
    aws_metric_name: CPUUtilization
    aws_dimensions: [InstanceId]
    aws_dimension_select:
      InstanceId: .*
    aws_statistics: [Average]

  - aws_namespace: AWS/EC2
    aws_metric_name: NetworkIn
    aws_dimensions: [InstanceId]
    aws_dimension_select:
      InstanceId: .*
    aws_statistics: [Average]

  - aws_namespace: AWS/EC2
    aws_metric_name: NetworkOut
    aws_dimensions: [InstanceId]
    aws_dimension_select:
      InstanceId: .*
    aws_statistics: [Average]

  - aws_namespace: AWS/EC2
    aws_metric_name: DiskReadBytes
    aws_dimensions: [InstanceId]
    aws_dimension_select:
      InstanceId: .*
    aws_statistics: [Average]

  - aws_namespace: AWS/EC2
    aws_metric_name: DiskWriteBytes
    aws_dimensions: [InstanceId]
    aws_dimension_select:
      InstanceId: .*
    aws_statistics: [Average]

  - aws_namespace: AWS/RDS
    aws_metric_name: CPUUtilization
    aws_dimensions: [DBInstanceIdentifier]
    aws_dimension_select:
      DBInstanceIdentifier: .*
    aws_statistics: [Average]

  - aws_namespace: AWS/RDS
    aws_metric_name: DatabaseConnections
    aws_dimensions: [DBInstanceIdentifier]
    aws_dimension_select:
      DBInstanceIdentifier: .*
    aws_statistics: [Average]

  - aws_namespace: AWS/RDS
    aws_metric_name: FreeStorageSpace
    aws_dimensions: [DBInstanceIdentifier]
    aws_dimension_select:
      DBInstanceIdentifier: .*
    aws_statistics: [Average]

  - aws_namespace: AWS/S3
    aws_metric_name: BucketSizeBytes
    aws_dimensions: [BucketName, StorageType]
    aws_dimension_select:
      BucketName: .*
      StorageType: StandardStorage
    aws_statistics: [Average]

  - aws_namespace: AWS/S3
    aws_metric_name: NumberOfObjects
    aws_dimensions: [BucketName, StorageType]
    aws_dimension_select:
      BucketName: .*
      StorageType: AllStorageTypes
    aws_statistics: [Average]
EOL

# Créer le fichier de configuration pour mysql-exporter
log "Création du fichier de configuration pour mysql-exporter..."
cat > /opt/monitoring/mysql-exporter-config.cnf << 'EOL'
[client]
host=${RDS_HOST}
port=${RDS_PORT}
user=${RDS_USERNAME}
password=${RDS_PASSWORD}
EOL

# Remplacer les variables d'environnement dans le fichier de configuration
log "Remplacement des variables d'environnement dans les fichiers de configuration..."
source /opt/monitoring/env.sh
source /opt/monitoring/secure/sensitive-env.sh

# Remplacer les variables dans le fichier mysql-exporter-config.cnf
sed -i "s/\${RDS_HOST}/$RDS_HOST/g" /opt/monitoring/mysql-exporter-config.cnf
sed -i "s/\${RDS_PORT}/$RDS_PORT/g" /opt/monitoring/mysql-exporter-config.cnf
sed -i "s/\${RDS_USERNAME}/$RDS_USERNAME/g" /opt/monitoring/mysql-exporter-config.cnf
sed -i "s/\${RDS_PASSWORD}/$RDS_PASSWORD/g" /opt/monitoring/mysql-exporter-config.cnf

# Définir les permissions
log "Configuration des permissions..."
chmod 644 /opt/monitoring/cloudwatch-config.yml
chmod 600 /opt/monitoring/mysql-exporter-config.cnf

# Redémarrer les conteneurs
log "Redémarrage des conteneurs..."
cd /opt/monitoring
docker-compose restart cloudwatch-exporter mysql-exporter

# Vérifier l'état des conteneurs
log "Vérification de l'état des conteneurs..."
docker ps --filter "name=cloudwatch-exporter|mysql-exporter"

log "Correction des exporters terminée avec succès."
