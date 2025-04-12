#!/bin/bash

# Script d'installation de Docker et de configuration de Grafana/Prometheus
# pour l'instance EC2 de monitoring

# Mettre à jour le système
sudo yum update -y

# Installer Docker
sudo amazon-linux-extras enable docker
sudo yum install -y docker
sudo systemctl enable docker
sudo systemctl start docker

# Ajouter l'utilisateur ec2-user au groupe docker
sudo usermod -a -G docker ec2-user

# Installer Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Créer le répertoire pour les configurations
sudo mkdir -p /opt/monitoring

# Copier le fichier docker-compose.yml depuis le template
sudo cp ${docker_compose_path} /opt/monitoring/docker-compose.yml

# Créer le fichier de configuration pour Prometheus
sudo cat > /opt/monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'tomcat'
    static_configs:
      - targets: ['EC2_INSTANCE_PRIVATE_IP:8080']
EOF

# Remplacer EC2_INSTANCE_PRIVATE_IP par l'IP privée de l'instance EC2 Java/Tomcat
sudo sed -i "s/EC2_INSTANCE_PRIVATE_IP/${ec2_instance_private_ip}/g" /opt/monitoring/prometheus.yml

# Définir les permissions correctes
sudo chown -R ec2-user:ec2-user /opt/monitoring

# Démarrer les conteneurs
cd /opt/monitoring
sudo docker-compose up -d

# Afficher un message de confirmation
echo "Grafana et Prometheus ont été installés avec succès."
echo "Grafana est accessible à l'adresse http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000"
echo "Prometheus est accessible à l'adresse http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9090"
