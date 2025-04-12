#!/bin/bash

# Script d'installation de Docker et de configuration des conteneurs Prometheus et Grafana
# Ce script est exécuté au démarrage de l'instance EC2 via user_data

# Variables passées par Terraform
EC2_INSTANCE_PRIVATE_IP=${ec2_instance_private_ip}
DOCKER_COMPOSE_PATH=${docker_compose_path}

# Mise à jour du système
echo "Mise à jour du système..."
sudo yum update -y

# Installation de Docker
echo "Installation de Docker..."
sudo amazon-linux-extras install docker -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# Installation de Docker Compose
echo "Installation de Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Création du répertoire pour les configurations et données
echo "Création des répertoires pour Prometheus et Grafana..."
sudo mkdir -p /opt/monitoring
sudo mkdir -p /opt/monitoring/prometheus-data
sudo mkdir -p /opt/monitoring/grafana-data

# Création du fichier de configuration Prometheus
echo "Configuration de Prometheus..."
cat << EOF | sudo tee /opt/monitoring/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'spring-actuator'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['${EC2_INSTANCE_PRIVATE_IP}:8080']
EOF

# Déplacement du fichier docker-compose.yml
echo "Configuration de Docker Compose..."
sudo cp $DOCKER_COMPOSE_PATH /opt/monitoring/docker-compose.yml

# Démarrage des conteneurs
echo "Démarrage des conteneurs Prometheus et Grafana..."
cd /opt/monitoring
sudo docker-compose up -d

echo "Installation terminée!"
