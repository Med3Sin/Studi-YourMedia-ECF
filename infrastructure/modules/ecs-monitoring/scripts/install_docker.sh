#!/bin/bash

# Script d'installation de Docker et de configuration de Grafana/Prometheus
# pour l'instance EC2 de monitoring

# Mettre à jour le système
yum update -y

# Installer Docker
amazon-linux-extras enable docker
yum install -y docker
systemctl enable docker
systemctl start docker

# Ajouter l'utilisateur ec2-user au groupe docker
usermod -a -G docker ec2-user

# Installer Docker Compose
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Créer le répertoire pour les configurations
mkdir -p /opt/monitoring

# Créer le fichier docker-compose.yml
cat > /opt/monitoring/docker-compose.yml << 'EOF'
version: '3'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - /opt/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    restart: always

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    depends_on:
      - prometheus
    restart: always

volumes:
  prometheus_data:
  grafana_data:
EOF

# Créer le fichier de configuration pour Prometheus
cat > /opt/monitoring/prometheus.yml << 'EOF'
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
sed -i "s/EC2_INSTANCE_PRIVATE_IP/${ec2_instance_private_ip}/g" /opt/monitoring/prometheus.yml

# Démarrer les conteneurs
cd /opt/monitoring
docker-compose up -d

# Afficher un message de confirmation
echo "Grafana et Prometheus ont été installés avec succès."
echo "Grafana est accessible à l'adresse http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000"
echo "Prometheus est accessible à l'adresse http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9090"
