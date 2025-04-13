#!/bin/bash

# Script pour corriger les problèmes de permissions des conteneurs Docker
# Ce script est exécuté après le déploiement des conteneurs

# Arrêter les conteneurs existants s'ils sont en cours d'exécution
cd /opt/monitoring
docker-compose down 2>/dev/null || true

# Nettoyer les répertoires de données
rm -rf /opt/monitoring/prometheus-data/*
rm -rf /opt/monitoring/grafana-data/*

# Corriger les permissions
mkdir -p /opt/monitoring/prometheus-data
mkdir -p /opt/monitoring/grafana-data
chown -R 65534:65534 /opt/monitoring/prometheus-data
chown -R 472:472 /opt/monitoring/grafana-data

# Créer un docker-compose.yml corrigé
cat > /opt/monitoring/docker-compose.yml << 'EOL'
version: '3'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    user: "65534"
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.enable-lifecycle'
    restart: always

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    user: "472"
    ports:
      - "3000:3000"
    volumes:
      - ./grafana-data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    restart: always
    depends_on:
      - prometheus
EOL

# Créer un prometheus.yml simplifié
cat > /opt/monitoring/prometheus.yml << 'EOL'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'spring_boot'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['backend:8080']
EOL

# Démarrer les conteneurs
cd /opt/monitoring
docker-compose up -d

# Vérifier le statut des conteneurs
echo "Statut des conteneurs:"
docker ps

# Message de fin
echo "Déploiement des conteneurs Docker terminé avec succès!"
