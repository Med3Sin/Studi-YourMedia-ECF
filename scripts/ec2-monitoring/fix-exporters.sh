#!/bin/bash

# Script pour corriger les problèmes des exporters MySQL et CloudWatch
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

# Créer le répertoire pour le fichier de configuration CloudWatch
log "Création du répertoire pour le fichier de configuration CloudWatch..."
mkdir -p /opt/monitoring

# Copier le fichier de configuration CloudWatch
log "Copie du fichier de configuration CloudWatch..."
if [ -f "/opt/monitoring/cloudwatch-config.yml" ]; then
    log "Le fichier de configuration CloudWatch existe déjà."
else
    cat > /opt/monitoring/cloudwatch-config.yml << 'EOF'
---
region: eu-west-3
metrics:
  # Métriques EC2
  - aws_namespace: AWS/EC2
    aws_metric_name: CPUUtilization
    aws_dimensions: [InstanceId]
    aws_statistics: [Average, Maximum]
    aws_dimension_select:
      InstanceId: "*"

  - aws_namespace: AWS/EC2
    aws_metric_name: NetworkIn
    aws_dimensions: [InstanceId]
    aws_statistics: [Average, Sum]
    aws_dimension_select:
      InstanceId: "*"

  - aws_namespace: AWS/EC2
    aws_metric_name: NetworkOut
    aws_dimensions: [InstanceId]
    aws_statistics: [Average, Sum]
    aws_dimension_select:
      InstanceId: "*"

  - aws_namespace: AWS/EC2
    aws_metric_name: DiskReadBytes
    aws_dimensions: [InstanceId]
    aws_statistics: [Average, Sum]
    aws_dimension_select:
      InstanceId: "*"

  - aws_namespace: AWS/EC2
    aws_metric_name: DiskWriteBytes
    aws_dimensions: [InstanceId]
    aws_statistics: [Average, Sum]
    aws_dimension_select:
      InstanceId: "*"

  # Métriques RDS
  - aws_namespace: AWS/RDS
    aws_metric_name: CPUUtilization
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average, Maximum]
    aws_dimension_select:
      DBInstanceIdentifier: "*"

  - aws_namespace: AWS/RDS
    aws_metric_name: DatabaseConnections
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average, Maximum]
    aws_dimension_select:
      DBInstanceIdentifier: "*"

  - aws_namespace: AWS/RDS
    aws_metric_name: FreeStorageSpace
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average, Minimum]
    aws_dimension_select:
      DBInstanceIdentifier: "*"

  # Métriques S3
  - aws_namespace: AWS/S3
    aws_metric_name: BucketSizeBytes
    aws_dimensions: [BucketName, StorageType]
    aws_statistics: [Average]
    aws_dimension_select:
      BucketName: "*"
      StorageType: "StandardStorage"

  - aws_namespace: AWS/S3
    aws_metric_name: NumberOfObjects
    aws_dimensions: [BucketName, StorageType]
    aws_statistics: [Average]
    aws_dimension_select:
      BucketName: "*"
      StorageType: "AllStorageTypes"
EOF
    log "Fichier de configuration CloudWatch créé avec succès."
fi

# Définir les permissions
log "Définition des permissions..."
chmod 644 /opt/monitoring/cloudwatch-config.yml
chown -R ec2-user:ec2-user /opt/monitoring

# Redémarrer les conteneurs
log "Redémarrage des conteneurs..."
docker-compose -f /opt/monitoring/docker-compose.yml down
docker-compose -f /opt/monitoring/docker-compose.yml up -d

log "Correction des exporters terminée avec succès."
