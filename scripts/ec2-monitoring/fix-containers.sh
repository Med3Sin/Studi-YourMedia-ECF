#!/bin/bash
# Script pour corriger les problèmes des conteneurs Docker de monitoring
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

# 1. Corriger le problème de cloudwatch-exporter
log "Correction du problème de cloudwatch-exporter..."
mkdir -p /opt/monitoring/cloudwatch-config
if [ ! -f "/opt/monitoring/cloudwatch-config/cloudwatch-config.yml" ]; then
    log "Création du fichier de configuration cloudwatch-config.yml..."
    cat > /opt/monitoring/cloudwatch-config/cloudwatch-config.yml << "EOF"
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
EOF
    log "Fichier de configuration cloudwatch-config.yml créé avec succès."
else
    log "Le fichier cloudwatch-config.yml existe déjà."
fi

# Définir les permissions
log "Définition des permissions..."
chmod 644 /opt/monitoring/cloudwatch-config/cloudwatch-config.yml
chown -R ec2-user:ec2-user /opt/monitoring/cloudwatch-config

# 2. Corriger le problème de mysql-exporter
log "Correction du problème de mysql-exporter..."
cat > /opt/monitoring/mysql-exporter-fix.yml << EOF
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
EOF

# 3. Corriger le problème de SonarQube (Elasticsearch)
log "Correction du problème de SonarQube (Elasticsearch)..."

# Augmenter la limite de mmap count (nécessaire pour Elasticsearch)
log "Augmentation de la limite de mmap count..."
sysctl -w vm.max_map_count=262144
if grep -q "vm.max_map_count" /etc/sysctl.conf; then
    sed -i 's/vm.max_map_count=.*/vm.max_map_count=262144/' /etc/sysctl.conf
else
    echo "vm.max_map_count=262144" >> /etc/sysctl.conf
fi
sysctl -p

# Augmenter la limite de fichiers ouverts
log "Augmentation de la limite de fichiers ouverts..."
sysctl -w fs.file-max=65536
if grep -q "fs.file-max" /etc/sysctl.conf; then
    sed -i 's/fs.file-max=.*/fs.file-max=65536/' /etc/sysctl.conf
else
    echo "fs.file-max=65536" >> /etc/sysctl.conf
fi
sysctl -p

# Configurer les limites de ressources pour l'utilisateur ec2-user
log "Configuration des limites de ressources pour l'utilisateur ec2-user..."
if ! grep -q "ec2-user.*nofile" /etc/security/limits.conf; then
    echo "ec2-user soft nofile 65536" >> /etc/security/limits.conf
    echo "ec2-user hard nofile 65536" >> /etc/security/limits.conf
fi
if ! grep -q "ec2-user.*nproc" /etc/security/limits.conf; then
    echo "ec2-user soft nproc 4096" >> /etc/security/limits.conf
    echo "ec2-user hard nproc 4096" >> /etc/security/limits.conf
fi

# Créer les répertoires pour SonarQube s'ils n'existent pas
log "Création des répertoires pour SonarQube..."
mkdir -p /opt/monitoring/sonarqube-data/data
mkdir -p /opt/monitoring/sonarqube-data/logs
mkdir -p /opt/monitoring/sonarqube-data/extensions
mkdir -p /opt/monitoring/sonarqube-data/db

# Définir les permissions appropriées pour SonarQube
log "Configuration des permissions pour SonarQube..."
chown -R 999:999 /opt/monitoring/sonarqube-data/data
chown -R 999:999 /opt/monitoring/sonarqube-data/logs
chown -R 999:999 /opt/monitoring/sonarqube-data/extensions
chown -R 999:999 /opt/monitoring/sonarqube-data/db
chmod -R 755 /opt/monitoring/sonarqube-data/data
chmod -R 755 /opt/monitoring/sonarqube-data/logs
chmod -R 755 /opt/monitoring/sonarqube-data/extensions
chmod -R 700 /opt/monitoring/sonarqube-data/db

# 4. Mettre à jour le fichier docker-compose.yml
log "Mise à jour du fichier docker-compose.yml..."

# Sauvegarder le fichier original
if [ -f "/opt/monitoring/docker-compose.yml" ]; then
    cp /opt/monitoring/docker-compose.yml /opt/monitoring/docker-compose.yml.bak
    
    # Remplacer la section mysql-exporter dans docker-compose.yml
    log "Remplacement de la section mysql-exporter dans docker-compose.yml..."
    sed -i '/mysql-exporter:/,/cpu_shares: 256/c\\' /opt/monitoring/docker-compose.yml
    sed -i '/mysql-exporter:/d' /opt/monitoring/docker-compose.yml
    cat /opt/monitoring/mysql-exporter-fix.yml >> /opt/monitoring/docker-compose.yml
    
    # Mettre à jour la section cloudwatch-exporter dans docker-compose.yml
    log "Mise à jour de la section cloudwatch-exporter dans docker-compose.yml..."
    sed -i '/cloudwatch-exporter:/,/cpu_shares: 256/c\  cloudwatch-exporter:\n    image: prom/cloudwatch-exporter:latest\n    container_name: cloudwatch-exporter\n    ports:\n      - "9106:9106"\n    volumes:\n      - /opt/monitoring/cloudwatch-config:/config\n    command:\n      - --config.file=/config/cloudwatch-config.yml\n    restart: always\n    logging:\n      driver: "json-file"\n      options:\n        max-size: "10m"\n        max-file: "3"\n    mem_limit: 256m\n    cpu_shares: 256' /opt/monitoring/docker-compose.yml
    
    # Mettre à jour la section sonarqube dans docker-compose.yml pour réduire la mémoire initiale d'Elasticsearch
    log "Mise à jour de la section sonarqube dans docker-compose.yml..."
    sed -i 's/SONAR_ES_JAVA_OPTS=-Xms512m -Xmx512m/SONAR_ES_JAVA_OPTS=-Xms256m -Xmx512m/' /opt/monitoring/docker-compose.yml
else
    log "Le fichier docker-compose.yml n'existe pas. Création d'un nouveau fichier..."
    cat > /opt/monitoring/docker-compose.yml << "EOF"
version: '3'

services:
  prometheus:
    image: ${DOCKER_USERNAME:-medsin}/${DOCKER_REPO:-yourmedia-ecf}:prometheus-latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - /opt/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - /opt/monitoring/prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=15d'
      - '--storage.tsdb.retention.size=1GB'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 512m
    cpu_shares: 512

  grafana:
    image: ${DOCKER_USERNAME:-medsin}/${DOCKER_REPO:-yourmedia-ecf}:grafana-latest
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - /opt/monitoring/grafana-data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-YourMedia2025!}
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer
    depends_on:
      - prometheus
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 512m
    cpu_shares: 512

  # Base de données PostgreSQL pour SonarQube
  sonarqube-db:
    image: postgres:13
    container_name: sonarqube-db
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_USER=${SONAR_JDBC_USERNAME:-sonar}
      - POSTGRES_PASSWORD=${SONAR_JDBC_PASSWORD:-sonar123}
      - POSTGRES_DB=sonar
    volumes:
      - /opt/monitoring/sonarqube-data/db:/var/lib/postgresql/data
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 512m
    cpu_shares: 512

  # SonarQube pour l'analyse de code
  sonarqube:
    image: ${DOCKER_USERNAME:-medsin}/${DOCKER_REPO:-yourmedia-ecf}:sonarqube-latest
    container_name: sonarqube
    depends_on:
      - sonarqube-db
    ports:
      - "9000:9000"
    environment:
      - SONAR_JDBC_URL=${SONAR_JDBC_URL:-jdbc:postgresql://sonarqube-db:5432/sonar}
      - SONAR_JDBC_USERNAME=${SONAR_JDBC_USERNAME:-sonar}
      - SONAR_JDBC_PASSWORD=${SONAR_JDBC_PASSWORD:-sonar123}
      # Limiter la mémoire utilisée par Elasticsearch pour éviter les erreurs OOM
      - SONAR_ES_JAVA_OPTS=-Xms256m -Xmx512m
      # Limiter la mémoire globale de SonarQube
      - SONAR_WEB_JAVA_OPTS=-Xmx512m -Xms256m
      - SONAR_CE_JAVA_OPTS=-Xmx512m -Xms256m
    volumes:
      - /opt/monitoring/sonarqube-data/data:/opt/sonarqube/data
      - /opt/monitoring/sonarqube-data/logs:/opt/sonarqube/logs
      - /opt/monitoring/sonarqube-data/extensions:/opt/sonarqube/extensions
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    # Augmenter légèrement la limite de mémoire pour éviter les erreurs OOM
    mem_limit: 1536m
    cpu_shares: 1024
    ulimits:
      nofile:
        soft: 65536
        hard: 65536

  # Exportateur CloudWatch pour surveiller les services AWS (S3, RDS, EC2)
  cloudwatch-exporter:
    image: prom/cloudwatch-exporter:latest
    container_name: cloudwatch-exporter
    ports:
      - "9106:9106"
    volumes:
      - /opt/monitoring/cloudwatch-config:/config
    command:
      - --config.file=/config/cloudwatch-config.yml
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 256m
    cpu_shares: 256

  # Exportateur MySQL pour surveiller RDS
  mysql-exporter:
    image: prom/mysqld-exporter:v0.15.0
    container_name: mysql-exporter
    ports:
      - "9104:9104"
    environment:
      - DATA_SOURCE_NAME=${RDS_USERNAME:-yourmedia}:${RDS_PASSWORD:-password}@tcp(${RDS_HOST:-localhost}:${RDS_PORT:-3306})/
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
EOF
fi

# 5. Redémarrer les conteneurs
log "Redémarrage des conteneurs..."
cd /opt/monitoring
docker-compose down
docker-compose up -d

# 6. Vérifier le statut des conteneurs
log "Vérification du statut des conteneurs..."
sleep 10
docker ps

log "Correction des conteneurs terminée avec succès."
log "Si certains conteneurs ne démarrent toujours pas, vérifiez les logs avec 'docker logs <nom_conteneur>'."
