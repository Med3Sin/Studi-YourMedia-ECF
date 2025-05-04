# -----------------------------------------------------------------------------
# Module EC2 Monitoring
# -----------------------------------------------------------------------------
# Ce module crée une instance EC2 pour le monitoring de l'application
# Il installe et configure Prometheus et Grafana
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Ressources
# -----------------------------------------------------------------------------

# Utiliser un groupe de sécurité existant ou en créer un nouveau
# Note: Nous utilisons directement la variable monitoring_security_group_id au lieu de récupérer le groupe de sécurité par son nom

# Groupe de sécurité pour l'instance EC2 de monitoring (créé uniquement si use_existing_sg = false)
resource "aws_security_group" "monitoring_sg" {
  count       = var.use_existing_sg ? 0 : 1
  name        = "${var.project_name}-${var.environment}-monitoring-sg"
  description = "Security group for monitoring instance"
  vpc_id      = var.vpc_id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "SSH access"
  }

  # Prometheus
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "Prometheus access"
  }

  # Grafana
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "Grafana access"
  }

  # Port 9000 réservé pour une utilisation future

  # Node Exporter
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "Node Exporter access"
  }

  # MySQL Exporter
  ingress {
    from_port   = 9104
    to_port     = 9104
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "MySQL Exporter access"
  }

  # CloudWatch Exporter
  ingress {
    from_port   = 9106
    to_port     = 9106
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "CloudWatch Exporter access"
  }

  # Application Mobile (React)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "Mobile App access"
  }

  # Autoriser tout le trafic sortant
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-monitoring-sg"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ID du groupe de sécurité à utiliser (existant ou nouveau)
locals {
  monitoring_sg_id = var.use_existing_sg ? var.monitoring_security_group_id : aws_security_group.monitoring_sg[0].id
}

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

# Politique IAM pour l'instance EC2 de monitoring
resource "aws_iam_policy" "monitoring_policy" {
  name        = "${var.project_name}-${var.environment}-monitoring-policy"
  description = "Policy for monitoring instance"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*",
        ]
      },
      {
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:Describe*",
        ]
        Effect = "Allow"
        # Limiter l'accès aux métriques CloudWatch pour améliorer la sécurité
        Resource = "arn:aws:cloudwatch:${var.aws_region}:*:*"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
        ]
        Effect = "Allow"
        # Limiter l'accès aux logs pour améliorer la sécurité
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/ec2/*"
      },
      {
        Action = [
          "ec2:CreateTags"
        ]
        Effect = "Allow"
        # Permission pour créer des tags EC2
        Resource = "arn:aws:ec2:${var.aws_region}:*:*"
      },
      {
        Action = [
          "ec2:DescribeTags"
        ]
        Effect = "Allow"
        # Permission pour décrire les tags EC2 (nécessite "*" comme ressource)
        Resource = "*"
      },
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-monitoring-policy"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # Faciliter la suppression et recréation de la politique
  lifecycle {
    create_before_destroy = true
  }
}

# Attachement de la politique au rôle IAM
resource "aws_iam_role_policy_attachment" "monitoring_policy_attachment" {
  role       = aws_iam_role.monitoring_role.name
  policy_arn = aws_iam_policy.monitoring_policy.arn
}

# Profil d'instance pour l'instance EC2 de monitoring
resource "aws_iam_instance_profile" "monitoring_profile" {
  name = "${var.project_name}-${var.environment}-monitoring-profile"
  role = aws_iam_role.monitoring_role.name

  tags = {
    Name        = "${var.project_name}-${var.environment}-monitoring-profile"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Instance EC2 pour le monitoring
resource "aws_instance" "monitoring_instance" {
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [local.monitoring_sg_id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.monitoring_profile.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  user_data = <<-EOF
#!/bin/bash
set -e

# Rediriger stdout et stderr vers un fichier log
exec > >(tee /var/log/user-data-init.log) 2>&1

echo "$(date '+%Y-%m-%d %H:%M:%S') - Démarrage du script d'initialisation"

# Mettre à jour le système
echo "$(date '+%Y-%m-%d %H:%M:%S') - Mise à jour du système"
sudo dnf update -y

# Installer les dépendances nécessaires
echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation des dépendances"
sudo dnf install -y jq wget docker aws-cli

# Démarrer et activer Docker
echo "$(date '+%Y-%m-%d %H:%M:%S') - Configuration de Docker"
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# Installation de Docker Compose
echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation de Docker Compose"
sudo wget -q -O /usr/local/bin/docker-compose "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)"
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Récupérer l'ID de l'instance pour les logs
echo "$(date '+%Y-%m-%d %H:%M:%S') - Récupération de l'ID de l'instance"
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id || echo "unknown")
echo "ID de l'instance: $INSTANCE_ID"

# Télécharger et exécuter le script d'initialisation depuis GitHub
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement du script d'initialisation depuis GitHub"
sudo mkdir -p /opt/monitoring
echo "$(date '+%Y-%m-%d %H:%M:%S') - Répertoire /opt/monitoring créé"

# Définir directement l'URL GitHub Raw
echo "$(date '+%Y-%m-%d %H:%M:%S') - Définition directe de l'URL GitHub"
GITHUB_RAW_URL="https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main"
echo "$(date '+%Y-%m-%d %H:%M:%S') - URL GitHub Raw: $GITHUB_RAW_URL"

# Tester la connectivité à GitHub
echo "$(date '+%Y-%m-%d %H:%M:%S') - Test de connectivité à GitHub..."
if sudo wget -q --spider --timeout=10 "https://raw.githubusercontent.com"; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Connectivité à GitHub OK"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERREUR: Impossible de se connecter à GitHub"
fi

# Créer les répertoires nécessaires pour les fichiers de configuration
echo "$(date '+%Y-%m-%d %H:%M:%S') - Création des répertoires nécessaires pour les fichiers de configuration"
sudo mkdir -p /opt/monitoring/prometheus-rules
sudo mkdir -p /opt/monitoring/config/prometheus
sudo mkdir -p /opt/monitoring/config/grafana/datasources
sudo mkdir -p /opt/monitoring/config/grafana/dashboards
sudo mkdir -p /opt/monitoring/data/prometheus
sudo mkdir -p /opt/monitoring/data/grafana
sudo mkdir -p /opt/monitoring/loki/chunks
sudo mkdir -p /opt/monitoring/loki/index
sudo mkdir -p /config

# Utiliser wget avec plus de verbosité pour télécharger le script d'initialisation
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement du script init-monitoring.sh..."
sudo wget -v -O /opt/monitoring/init-monitoring.sh "$GITHUB_RAW_URL/scripts/ec2-monitoring/init-monitoring.sh" 2>&1 | tee -a /var/log/user-data-init.log

# Vérifier si le téléchargement a réussi
if [ ! -s /opt/monitoring/init-monitoring.sh ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERREUR: Le téléchargement du script init-monitoring.sh a échoué. Tentative avec le chemin complet..."
  sudo wget -v -O /opt/monitoring/init-monitoring.sh "https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main/scripts/ec2-monitoring/init-monitoring.sh" 2>&1 | tee -a /var/log/user-data-init.log
fi

# Vérifier à nouveau si le téléchargement a réussi
if [ -s /opt/monitoring/init-monitoring.sh ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Script init-monitoring.sh téléchargé avec succès"
  sudo chmod +x /opt/monitoring/init-monitoring.sh
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Permissions exécutables accordées au script"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERREUR CRITIQUE: Impossible de télécharger le script init-monitoring.sh"
  exit 1
fi

# Télécharger directement le script de configuration pour éviter les problèmes
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement du script de configuration setup-monitoring.sh..."
sudo wget -v -O /opt/monitoring/setup-monitoring.sh "$GITHUB_RAW_URL/scripts/ec2-monitoring/setup-monitoring.sh" 2>&1 | tee -a /var/log/user-data-init.log

# Vérifier si le téléchargement a réussi
if [ -s /opt/monitoring/setup-monitoring.sh ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Script setup-monitoring.sh téléchargé avec succès"
  sudo chmod +x /opt/monitoring/setup-monitoring.sh
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Permissions exécutables accordées au script"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERREUR: Impossible de télécharger le script setup-monitoring.sh"
fi

# Télécharger le fichier docker-compose.yml
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement du fichier docker-compose.yml..."
sudo wget -v -O /opt/monitoring/docker-compose.yml "$GITHUB_RAW_URL/scripts/ec2-monitoring/docker-compose.yml" 2>&1 | tee -a /var/log/user-data-init.log

# Vérifier si le téléchargement a réussi
if [ -s /opt/monitoring/docker-compose.yml ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Fichier docker-compose.yml téléchargé avec succès"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERREUR: Impossible de télécharger le fichier docker-compose.yml"
fi

# Télécharger les fichiers de configuration nécessaires
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement des fichiers de configuration nécessaires"
sudo wget -q -O /opt/monitoring/config/prometheus/prometheus.yml "$GITHUB_RAW_URL/scripts/config/prometheus/prometheus.yml"
sudo wget -q -O /opt/monitoring/prometheus-rules/container-alerts.yml "$GITHUB_RAW_URL/scripts/config/prometheus/container-alerts.yml"
sudo wget -q -O /opt/monitoring/config/cloudwatch-config.yml "$GITHUB_RAW_URL/scripts/config/cloudwatch-config.yml"
sudo wget -q -O /opt/monitoring/config/loki-config.yml "$GITHUB_RAW_URL/scripts/config/loki-config.yml"
sudo wget -q -O /opt/monitoring/config/promtail-config.yml "$GITHUB_RAW_URL/scripts/config/promtail-config.yml"

# Télécharger les fichiers de configuration Grafana
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement des fichiers de configuration Grafana"
sudo wget -q -O /opt/monitoring/config/grafana/datasources/prometheus.yml "$GITHUB_RAW_URL/scripts/config/grafana/datasources/prometheus.yml"
sudo wget -q -O /opt/monitoring/config/grafana/datasources/loki.yml "$GITHUB_RAW_URL/scripts/config/grafana/datasources/loki.yml"
sudo wget -q -O /opt/monitoring/config/grafana/dashboards/default.yml "$GITHUB_RAW_URL/scripts/config/grafana/dashboards/default.yml"

# Créer un lien symbolique pour le fichier cloudwatch-config.yml
echo "$(date '+%Y-%m-%d %H:%M:%S') - Création d'un lien symbolique pour le fichier cloudwatch-config.yml"
sudo ln -sf /opt/monitoring/config/cloudwatch-config.yml /config/cloudwatch-config.yml

# Créer un fichier de configuration pour MySQL Exporter
echo "$(date '+%Y-%m-%d %H:%M:%S') - Création d'un fichier de configuration pour MySQL Exporter"
sudo bash -c "cat > /opt/monitoring/.my.cnf << EOF
[client]
user=yourmedia
password=password
host=localhost
port=3306
EOF"
sudo chmod 600 /opt/monitoring/.my.cnf

# Créer le répertoire secure pour les tokens
echo "$(date '+%Y-%m-%d %H:%M:%S') - Création du répertoire secure pour les tokens"
sudo mkdir -p /opt/monitoring/secure
sudo chmod 700 /opt/monitoring/secure

# Créer un fichier de token Docker Hub (à remplacer par le vrai token dans les variables d'environnement)
echo "$(date '+%Y-%m-%d %H:%M:%S') - Création du fichier de token Docker Hub"
# Utiliser une variable d'environnement ou un placeholder
DOCKERHUB_TOKEN="${var.dockerhub_token}"
if [ -z "$DOCKERHUB_TOKEN" ]; then
  DOCKERHUB_TOKEN="placeholder_token"
fi
echo "$DOCKERHUB_TOKEN" | sudo tee /opt/monitoring/secure/dockerhub-token.txt > /dev/null
sudo chmod 600 /opt/monitoring/secure/dockerhub-token.txt

# Créer un fichier avec le nom d'utilisateur Docker Hub
echo "$(date '+%Y-%m-%d %H:%M:%S') - Création du fichier avec le nom d'utilisateur Docker Hub"
echo "medsin" | sudo tee /opt/monitoring/secure/dockerhub-username.txt > /dev/null
sudo chmod 600 /opt/monitoring/secure/dockerhub-username.txt

# Créer un fichier avec le nom du dépôt Docker Hub
echo "$(date '+%Y-%m-%d %H:%M:%S') - Création du fichier avec le nom du dépôt Docker Hub"
echo "yourmedia-ecf" | sudo tee /opt/monitoring/secure/dockerhub-repo.txt > /dev/null
sudo chmod 600 /opt/monitoring/secure/dockerhub-repo.txt

# S'assurer que tous les scripts sont exécutables
echo "$(date '+%Y-%m-%d %H:%M:%S') - Attribution des permissions d'exécution aux scripts"
sudo chmod +x /opt/monitoring/*.sh 2>/dev/null || true

# Définir les bonnes permissions pour les répertoires de données
echo "$(date '+%Y-%m-%d %H:%M:%S') - Définition des bonnes permissions pour les répertoires de données"
sudo chown -R 1000:1000 /opt/monitoring/data
sudo chmod -R 755 /opt/monitoring/data

# Exécuter le script d'initialisation
echo "$(date '+%Y-%m-%d %H:%M:%S') - Exécution du script d'initialisation"
sudo /opt/monitoring/init-monitoring.sh 2>&1 | tee -a /var/log/user-data-init.log

# Vérifier si les conteneurs Docker sont en cours d'exécution
echo "$(date '+%Y-%m-%d %H:%M:%S') - Vérification des conteneurs Docker"
CONTAINER_COUNT=$(sudo docker ps -q | wc -l)
if [ "$CONTAINER_COUNT" -gt 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Les conteneurs Docker sont en cours d'exécution"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ Aucun conteneur Docker n'est en cours d'exécution. Démarrage manuel..."
    cd /opt/monitoring
    sudo docker-compose down
    sleep 5
    sudo docker-compose up -d
    sleep 10
    CONTAINER_COUNT=$(sudo docker ps -q | wc -l)
    if [ "$CONTAINER_COUNT" -gt 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Les conteneurs Docker ont été démarrés avec succès"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ Échec du démarrage des conteneurs Docker"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Vérification des logs Docker..."
        sudo docker-compose logs
    fi
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Script d'initialisation terminé"
EOF

  tags = {
    Name         = "${var.project_name}-${var.environment}-monitoring-instance"
    Project      = var.project_name
    Environment  = var.environment
    ManagedBy    = "Terraform"
    Role         = "Monitoring"
    S3BucketName = var.s3_bucket_name
  }

  # Protéger l'instance contre la suppression accidentelle
  lifecycle {
    prevent_destroy = false # Mettre à true en production
    ignore_changes  = [ami] # Ignorer les changements d'AMI pour éviter les recréations inutiles
  }
}

# -----------------------------------------------------------------------------
# Provisionnement des fichiers de configuration
# -----------------------------------------------------------------------------

# Copie des fichiers de configuration sur l'instance EC2
# Note: Le provisionnement est désactivé par défaut pour éviter les erreurs dans les environnements CI/CD
# Pour activer le provisionnement, définissez la variable enable_provisioning à true et fournissez une clé SSH valide
resource "null_resource" "provision_monitoring" {
  # Ne créer cette ressource que si le provisionnement est activé
  count = var.enable_provisioning ? 1 : 0

  # Déclencher uniquement lorsque l'instance est créée ou modifiée
  triggers = {
    instance_id = aws_instance.monitoring_instance.id
  }

  # Copie du fichier docker-compose.yml
  provisioner "file" {
    source      = "${path.module}/../../scripts/ec2-monitoring/docker-compose.yml"
    destination = "/tmp/docker-compose.yml"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      host        = aws_instance.monitoring_instance.public_ip
      private_key = var.ssh_private_key_content != "" ? var.ssh_private_key_content : file(var.ssh_private_key_path)
    }
  }

  # Copie du fichier prometheus.yml
  provisioner "file" {
    source      = "${path.module}/../../scripts/ec2-monitoring/prometheus.yml"
    destination = "/tmp/prometheus.yml"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      host        = aws_instance.monitoring_instance.public_ip
      private_key = var.ssh_private_key_content != "" ? var.ssh_private_key_content : file(var.ssh_private_key_path)
    }
  }

  # Copie du script de gestion Docker
  provisioner "file" {
    source      = "${path.module}/../../scripts/docker/docker-manager.sh"
    destination = "/tmp/docker-manager.sh"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      host        = aws_instance.monitoring_instance.public_ip
      private_key = var.ssh_private_key_content != "" ? var.ssh_private_key_content : file(var.ssh_private_key_path)
    }
  }

  # Copie du script de correction des permissions
  provisioner "file" {
    source      = "${path.module}/../../scripts/ec2-monitoring/fix_permissions.sh"
    destination = "/tmp/fix_permissions.sh"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      host        = aws_instance.monitoring_instance.public_ip
      private_key = var.ssh_private_key_content != "" ? var.ssh_private_key_content : file(var.ssh_private_key_path)
    }
  }

  # Exécution des scripts
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/docker-manager.sh",
      "sudo chmod +x /tmp/fix_permissions.sh",
      "sudo /tmp/docker-manager.sh deploy monitoring",
      "sudo /tmp/fix_permissions.sh"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      host        = aws_instance.monitoring_instance.public_ip
      private_key = var.ssh_private_key_content != "" ? var.ssh_private_key_content : file(var.ssh_private_key_path)
    }
  }

  depends_on = [aws_instance.monitoring_instance]
}



# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

# Récupération de l'AMI Amazon Linux 2023 la plus récente
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}
