#!/bin/bash

# Script de déploiement des conteneurs Docker pour le monitoring
# Ce script est exécuté après l'installation de Docker et Docker Compose

# Création des répertoires pour les volumes
sudo mkdir -p /opt/monitoring/prometheus-data
sudo mkdir -p /opt/monitoring/grafana-data
sudo chown -R ec2-user:ec2-user /opt/monitoring

# Copie des fichiers de configuration
cp /tmp/docker-compose.yml /opt/monitoring/
cp /tmp/prometheus.yml /opt/monitoring/

# Démarrage des conteneurs
cd /opt/monitoring
docker-compose up -d

# Vérification du statut des conteneurs
echo "Statut des conteneurs:"
docker ps

# Message de fin
echo "Déploiement des conteneurs Docker terminé avec succès!"
