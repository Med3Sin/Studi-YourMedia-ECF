#!/bin/bash

# Script d'installation de Docker et Docker Compose sur Amazon Linux 2
# Ce script est exécuté lors de l'initialisation de l'instance EC2 de monitoring

# Mise à jour du système
sudo yum update -y

# Installation de Docker
sudo amazon-linux-extras install docker -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# Installation de Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Vérification des installations
echo "Docker version:"
docker --version
echo "Docker Compose version:"
docker-compose --version

# Création du répertoire pour les fichiers de configuration
sudo mkdir -p /opt/monitoring
sudo chown ec2-user:ec2-user /opt/monitoring

# Message de fin
echo "Installation de Docker et Docker Compose terminée avec succès!"
