#!/bin/bash
# OBSOLÈTE - CONSERVÉ POUR RÉFÉRENCE UNIQUEMENT
# Ce script est obsolète et a été remplacé par fix_permissions.sh et restart-containers.sh
# Veuillez utiliser ces scripts à la place.
#
# Script de correction pour les problèmes de déploiement des conteneurs Docker sur l'instance EC2 de monitoring
#
# EXIGENCES EN MATIÈRE DE DROITS :
# Ce script doit être exécuté avec des privilèges sudo ou en tant que root.
# Exemple d'utilisation : sudo ./fix-monitoring-legacy.sh
#
# Le script vérifie automatiquement les droits et affichera une erreur si nécessaire.

# Fonctions pour les messages
info() { echo "[INFO] $1"; }
success() { echo "[SUCCÈS] $1"; }
error() { echo "[ERREUR] $1" >&2; }

# Vérifier si l'utilisateur a les droits sudo
if [ "$(id -u)" -ne 0 ]; then
    error "Ce script doit être exécuté avec sudo"
    error "Exemple: sudo $0 $*"
    exit 1
fi

# 1. Arrêter tous les conteneurs existants
info "Arrêt de tous les conteneurs Docker..."
docker-compose -f /opt/monitoring/docker-compose.yml down 2>/dev/null || true
docker rm -f $(docker ps -aq) 2>/dev/null || true

# 2. Corriger l'image CloudWatch Exporter dans docker-compose.yml
info "Correction de l'image CloudWatch Exporter..."
sed -i 's/prom\/cloudwatch-exporter:0.15.2/prom\/cloudwatch-exporter:latest/g' /opt/monitoring/docker-compose.yml

# 3. Définir un mot de passe sécurisé pour Grafana
info "Configuration du mot de passe Grafana..."
GRAFANA_PASSWORD="YourMedia2025!"
echo "export GRAFANA_ADMIN_PASSWORD=$GRAFANA_PASSWORD" >> /opt/monitoring/aws-resources.env
echo "export GF_SECURITY_ADMIN_PASSWORD=$GRAFANA_PASSWORD" >> /opt/monitoring/aws-resources.env
source /opt/monitoring/aws-resources.env

# 4. Corriger les permissions des répertoires
info "Correction des permissions des répertoires..."
mkdir -p /opt/monitoring/prometheus-data
mkdir -p /opt/monitoring/grafana-data
mkdir -p /opt/monitoring/sonarqube-data/data
mkdir -p /opt/monitoring/sonarqube-data/logs
mkdir -p /opt/monitoring/sonarqube-data/extensions
mkdir -p /opt/monitoring/sonarqube-data/db
mkdir -p /opt/monitoring/cloudwatch-config

# 5. Définir les bonnes permissions
info "Configuration des permissions..."
chown -R 65534:65534 /opt/monitoring/prometheus-data
chown -R 472:472 /opt/monitoring/grafana-data
chown -R 999:999 /opt/monitoring/sonarqube-data/data
chown -R 999:999 /opt/monitoring/sonarqube-data/logs
chown -R 999:999 /opt/monitoring/sonarqube-data/extensions
chown -R 999:999 /opt/monitoring/sonarqube-data/db

# 6. Créer un fichier de configuration CloudWatch Exporter simplifié
info "Création du fichier de configuration CloudWatch Exporter..."
cat > /opt/monitoring/cloudwatch-config/cloudwatch-config.yml << EOF
---
region: eu-west-3
metrics:
  - aws_namespace: AWS/S3
    aws_metric_name: BucketSizeBytes
    aws_dimensions: [BucketName, StorageType]
    aws_statistics: [Average]

  - aws_namespace: AWS/RDS
    aws_metric_name: CPUUtilization
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average]
EOF

# 7. Démarrer les conteneurs sans CloudWatch Exporter pour commencer
info "Création d'un docker-compose temporaire sans CloudWatch Exporter..."
cat > /opt/monitoring/docker-compose-temp.yml << EOF
version: '3'

services:
  prometheus:
    image: prom/prometheus:v2.45.0
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
    restart: always

  grafana:
    image: grafana/grafana:10.0.3
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - /opt/monitoring/grafana-data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-YourMedia2025!}
      - GF_USERS_ALLOW_SIGN_UP=false
    restart: always

  # Base de données PostgreSQL pour SonarQube
  sonarqube-db:
    image: postgres:13
    container_name: sonarqube-db
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_USER=sonar
      - POSTGRES_PASSWORD=sonar123
      - POSTGRES_DB=sonar
    volumes:
      - /opt/monitoring/sonarqube-data/db:/var/lib/postgresql/data
    restart: always

  # SonarQube pour l'analyse de code
  sonarqube:
    image: sonarqube:9.9-community
    container_name: sonarqube
    depends_on:
      - sonarqube-db
    ports:
      - "9000:9000"
    environment:
      - SONAR_JDBC_URL=jdbc:postgresql://sonarqube-db:5432/sonar
      - SONAR_JDBC_USERNAME=sonar
      - SONAR_JDBC_PASSWORD=sonar123
      - SONAR_ES_JAVA_OPTS=-Xms512m -Xmx512m
    volumes:
      - /opt/monitoring/sonarqube-data/data:/opt/sonarqube/data
      - /opt/monitoring/sonarqube-data/logs:/opt/sonarqube/logs
      - /opt/monitoring/sonarqube-data/extensions:/opt/sonarqube/extensions
    restart: always
    ulimits:
      nofile:
        soft: 65536
        hard: 65536
EOF

# 8. Démarrer les conteneurs avec le fichier temporaire
info "Démarrage des conteneurs avec le fichier temporaire..."
cd /opt/monitoring
docker-compose -f docker-compose-temp.yml up -d

# 9. Vérifier si les conteneurs sont en cours d'exécution
info "Vérification des conteneurs..."
sleep 10
docker ps

# 10. Afficher les URLs d'accès
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo ""
echo "Accès aux interfaces:"
echo "- Prometheus: http://$PUBLIC_IP:9090"
echo "- Grafana: http://$PUBLIC_IP:3000 (admin/YourMedia2025!)"
echo "- SonarQube: http://$PUBLIC_IP:9000 (admin/admin)"

success "Script de correction terminé. Vérifiez les conteneurs avec 'docker ps'."
