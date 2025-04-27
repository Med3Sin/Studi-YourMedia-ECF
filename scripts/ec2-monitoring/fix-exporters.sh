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
sudo mkdir -p /opt/monitoring/cloudwatch-config

# Copier le fichier de configuration CloudWatch
log "Copie du fichier de configuration CloudWatch..."
if [ -f "/opt/monitoring/cloudwatch-config/cloudwatch-config.yml" ]; then
    log "Le fichier de configuration CloudWatch existe déjà."
else
    sudo bash -c 'cat > /opt/monitoring/cloudwatch-config/cloudwatch-config.yml << "EOF"'
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
sudo chmod 644 /opt/monitoring/cloudwatch-config/cloudwatch-config.yml
sudo chown -R ec2-user:ec2-user /opt/monitoring

# Corriger la configuration de mysql-exporter dans docker-compose.yml
log "Correction de la configuration de mysql-exporter dans docker-compose.yml..."
sudo bash -c 'cat > /opt/monitoring/mysql-exporter-fix.yml << EOF
  mysql-exporter:
    image: prom/mysqld-exporter:v0.15.0
    container_name: mysql-exporter
    ports:
      - "9104:9104"
    environment:
      - DATA_SOURCE_NAME=\${RDS_USERNAME:-yourmedia}:\${RDS_PASSWORD:-password}@tcp(\${RDS_HOST:-localhost}:\${RDS_PORT:-3306})/
    entrypoint:
      - /bin/mysqld_exporter
    command:
      - --web.listen-address=:9104
      - --collect.info_schema.tables
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 256m
    cpu_shares: 256
EOF'

# Remplacer la section mysql-exporter dans docker-compose.yml
log "Remplacement de la section mysql-exporter dans docker-compose.yml..."
sudo sed -i '/mysql-exporter:/,/cpu_shares: 256/c\\' /opt/monitoring/docker-compose.yml
sudo sed -i '/mysql-exporter:/d' /opt/monitoring/docker-compose.yml
sudo bash -c 'cat /opt/monitoring/mysql-exporter-fix.yml >> /opt/monitoring/docker-compose.yml'

# Redémarrer les conteneurs
log "Redémarrage des conteneurs..."
sudo docker-compose -f /opt/monitoring/docker-compose.yml down
sudo docker-compose -f /opt/monitoring/docker-compose.yml up -d

log "Correction des exporters terminée avec succès."
