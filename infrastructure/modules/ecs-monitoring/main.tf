# -----------------------------------------------------------------------------
# IAM Role pour l'instance EC2 de monitoring
# -----------------------------------------------------------------------------

# Rôle IAM pour l'instance EC2 de monitoring
resource "aws_iam_role" "monitoring_role" {
  name = "${var.project_name}-${var.environment}-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-monitoring-role"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Politique pour accéder à ECR (si nécessaire pour tirer des images Docker)
resource "aws_iam_role_policy_attachment" "ecr_policy" {
  role       = aws_iam_role.monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECR-FullAccess"
}

# Profil d'instance pour attacher le rôle IAM à l'instance EC2
resource "aws_iam_instance_profile" "monitoring_profile" {
  name = "${var.project_name}-${var.environment}-monitoring-profile"
  role = aws_iam_role.monitoring_role.name
}

# -----------------------------------------------------------------------------
# Préparation des fichiers de configuration
# -----------------------------------------------------------------------------

# Préparation du script d'initialisation
locals {
  install_script_template = <<-EOT
#!/bin/bash

# Script d'installation de Docker et de configuration des conteneurs Prometheus et Grafana
# Ce script est exécuté au démarrage de l'instance EC2 via user_data

# Variables passées par Terraform
EC2_INSTANCE_PRIVATE_IP=${var.ec2_instance_private_ip}
DOCKER_COMPOSE_PATH=/tmp/docker-compose.yml

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
      - targets: ['$${EC2_INSTANCE_PRIVATE_IP}:8080']
EOF

# Déplacement du fichier docker-compose.yml
echo "Configuration de Docker Compose..."
sudo cp $DOCKER_COMPOSE_PATH /opt/monitoring/docker-compose.yml

# Démarrage des conteneurs
echo "Démarrage des conteneurs Prometheus et Grafana..."
cd /opt/monitoring
sudo docker-compose up -d

echo "Installation terminée!"
EOT
}

# -----------------------------------------------------------------------------
# Instance EC2 pour Grafana et Prometheus
# -----------------------------------------------------------------------------
# Provisionnement du fichier docker-compose.yml sur l'instance EC2
resource "null_resource" "copy_docker_compose" {
  # Déclencher uniquement lorsque l'instance est créée
  triggers = {
    instance_id = aws_instance.monitoring_instance.id
  }

  # Copier le fichier docker-compose.yml sur l'instance EC2
  provisioner "file" {
    source      = "${path.module}/scripts/docker-compose.yml"
    destination = "/tmp/docker-compose.yml"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      host        = aws_instance.monitoring_instance.public_ip
      private_key = file(var.ssh_private_key_path)
    }
  }

  depends_on = [aws_instance.monitoring_instance]
}

resource "aws_instance" "monitoring_instance" {
  ami                    = var.ecs_ami_id
  instance_type          = "t2.micro"
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [var.ecs_security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.monitoring_profile.name
  key_name               = var.key_pair_name

  # Script exécuté au premier démarrage de l'instance
  user_data = local.install_script_template

  tags = {
    Name        = "${var.project_name}-${var.environment}-monitoring-instance"
    Project     = var.project_name
    Environment = var.environment
  }
}
