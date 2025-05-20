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
          "ec2:DescribeTags",
          "ec2:DescribeInstances"
        ]
        Effect = "Allow"
        # Permission pour décrire les tags EC2 et les instances (nécessite "*" comme ressource)
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

echo "$(date '+%Y-%m-%d %H:%M:%S') - Démarrage du script d'initialisation minimal"

# Créer un fichier de marqueur pour indiquer que le script a démarré
sudo touch /var/log/user-data-started

# Mettre à jour le système et installer les dépendances essentielles
echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation des dépendances essentielles"
sudo dnf update -y
sudo dnf install -y wget jq

# Installation de Docker avec gestion des conflits de paquets
echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation de Docker"
# Méthode 1: Utiliser --allowerasing pour résoudre les conflits de paquets
sudo dnf install -y --allowerasing docker

# En cas d'échec, essayer la méthode alternative
if [ $? -ne 0 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Première méthode d'installation de Docker échouée, tentative alternative..."
  # Méthode 2: Installer Docker via le référentiel Amazon Extras
  sudo dnf install -y amazon-linux-extras
  sudo amazon-linux-extras install -y docker
fi

# Vérifier si Docker est installé
if ! command -v docker &> /dev/null; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Méthodes précédentes échouées, tentative avec le référentiel Docker officiel..."
  # Méthode 3: Installer Docker via le référentiel officiel
  sudo dnf install -y yum-utils
  sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  sudo dnf install -y docker-ce docker-ce-cli containerd.io
fi

# Démarrer et activer Docker
echo "$(date '+%Y-%m-%d %H:%M:%S') - Configuration de Docker"
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# Vérifier que Docker fonctionne correctement
echo "$(date '+%Y-%m-%d %H:%M:%S') - Vérification de l'installation de Docker"
if sudo docker --version &> /dev/null; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Docker est correctement installé: $(sudo docker --version)"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ ERREUR: Docker n'est pas correctement installé"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Tentative d'installation de Docker via le gestionnaire de paquets snap"
  sudo dnf install -y snapd
  sudo systemctl enable --now snapd.socket
  sudo ln -s /var/lib/snapd/snap /snap
  sudo snap install docker
fi

# Vérifier à nouveau que Docker fonctionne
if ! sudo docker --version &> /dev/null; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ ERREUR CRITIQUE: Impossible d'installer Docker après plusieurs tentatives"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Le script continuera mais la configuration du monitoring pourrait échouer"
fi

# Installation de Docker Compose
echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation de Docker Compose"
if ! command -v docker-compose &> /dev/null; then
  sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

  # Vérifier l'installation de Docker Compose
  if docker-compose --version &> /dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Docker Compose est correctement installé: $(docker-compose --version)"
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ ERREUR: Docker Compose n'est pas correctement installé"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Tentative alternative d'installation de Docker Compose via pip"
    sudo dnf install -y python3-pip
    sudo pip3 install docker-compose
  fi
fi

# Créer les répertoires nécessaires
echo "$(date '+%Y-%m-%d %H:%M:%S') - Création des répertoires nécessaires"
sudo mkdir -p /opt/monitoring
sudo mkdir -p /opt/monitoring/scripts
sudo mkdir -p /opt/monitoring/secure

# Définir l'URL GitHub Raw
GITHUB_RAW_URL="https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main"

# Télécharger les scripts d'initialisation
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement des scripts d'initialisation"
sudo wget -q -O /opt/monitoring/init-monitoring.sh "$GITHUB_RAW_URL/scripts/ec2-monitoring/init-monitoring.sh"
sudo wget -q -O /opt/monitoring/setup-monitoring-complete.sh "$GITHUB_RAW_URL/scripts/ec2-monitoring/setup-monitoring-complete.sh"
sudo wget -q -O /opt/monitoring/fix-grafana.sh "$GITHUB_RAW_URL/scripts/ec2-monitoring/fix-grafana.sh"

# Vérifier si les téléchargements ont réussi
if [ ! -s /opt/monitoring/init-monitoring.sh ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERREUR: Le téléchargement du script init-monitoring.sh a échoué. Tentative avec le chemin complet..."
  sudo wget -v -O /opt/monitoring/init-monitoring.sh "https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main/scripts/ec2-monitoring/init-monitoring.sh"
fi

if [ ! -s /opt/monitoring/setup-monitoring-complete.sh ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERREUR: Le téléchargement du script setup-monitoring-complete.sh a échoué. Tentative avec le chemin complet..."
  sudo wget -v -O /opt/monitoring/setup-monitoring-complete.sh "https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main/scripts/ec2-monitoring/setup-monitoring-complete.sh"
fi

if [ ! -s /opt/monitoring/fix-grafana.sh ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERREUR: Le téléchargement du script fix-grafana.sh a échoué. Tentative avec le chemin complet..."
  sudo wget -v -O /opt/monitoring/fix-grafana.sh "https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main/scripts/ec2-monitoring/fix-grafana.sh"
fi

# Vérifier à nouveau si les téléchargements ont réussi
if [ -s /opt/monitoring/init-monitoring.sh ] && [ -s /opt/monitoring/setup-monitoring-complete.sh ] && [ -s /opt/monitoring/fix-grafana.sh ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Scripts téléchargés avec succès"
  sudo chmod +x /opt/monitoring/init-monitoring.sh
  sudo chmod +x /opt/monitoring/setup-monitoring-complete.sh
  sudo chmod +x /opt/monitoring/fix-grafana.sh
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERREUR CRITIQUE: Impossible de télécharger un ou plusieurs scripts"
  exit 1
fi

# Configuration des variables d'environnement Docker Hub
echo "$(date '+%Y-%m-%d %H:%M:%S') - Configuration des variables d'environnement Docker Hub"
# Utiliser des valeurs codées en dur pour le moment
DOCKERHUB_USERNAME="medsin"
DOCKERHUB_TOKEN=""
DOCKERHUB_REPO="yourmedia-ecf"

# Stocker les variables dans des fichiers sécurisés
echo "$(date '+%Y-%m-%d %H:%M:%S') - Stockage des variables Docker Hub"
sudo mkdir -p /opt/monitoring/secure
sudo chmod 700 /opt/monitoring/secure

if [ -n "$DOCKERHUB_USERNAME" ]; then
  echo "$DOCKERHUB_USERNAME" | sudo tee /opt/monitoring/secure/dockerhub-username.txt > /dev/null
  sudo chmod 600 /opt/monitoring/secure/dockerhub-username.txt
fi

if [ -n "$DOCKERHUB_TOKEN" ]; then
  echo "$DOCKERHUB_TOKEN" | sudo tee /opt/monitoring/secure/dockerhub-token.txt > /dev/null
  sudo chmod 600 /opt/monitoring/secure/dockerhub-token.txt
fi

if [ -n "$DOCKERHUB_REPO" ]; then
  echo "$DOCKERHUB_REPO" | sudo tee /opt/monitoring/secure/dockerhub-repo.txt > /dev/null
  sudo chmod 600 /opt/monitoring/secure/dockerhub-repo.txt
fi

# Exporter les variables pour le script d'initialisation
export DOCKERHUB_USERNAME="$DOCKERHUB_USERNAME"
export DOCKERHUB_TOKEN="$DOCKERHUB_TOKEN"
export DOCKERHUB_REPO="$DOCKERHUB_REPO"

# Télécharger le script de configuration Prometheus
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement du script de configuration Prometheus"
sudo wget -q -O /opt/monitoring/create-prometheus-config.sh "$GITHUB_RAW_URL/scripts/ec2-monitoring/create-prometheus-config.sh"

# Vérifier si le téléchargement a réussi
if [ -s /opt/monitoring/create-prometheus-config.sh ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Script de configuration Prometheus téléchargé avec succès"
  sudo chmod +x /opt/monitoring/create-prometheus-config.sh

  # Exécuter le script de configuration Prometheus
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Exécution du script de configuration Prometheus"
  sudo /opt/monitoring/create-prometheus-config.sh
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Échec du téléchargement du script de configuration Prometheus"

  # Créer manuellement le fichier de configuration Prometheus
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Création manuelle du fichier de configuration Prometheus"
  sudo mkdir -p /opt/monitoring/config/prometheus
  sudo bash -c 'cat > /opt/monitoring/config/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          # - alertmanager:9093

rule_files:
  - "/etc/prometheus/rules/*.yml"

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "node-exporter"
    static_configs:
      - targets: ["node-exporter:9100"]

  - job_name: "cadvisor"
    static_configs:
      - targets: ["cadvisor:8080"]

  - job_name: "java-tomcat"
    metrics_path: /metrics
    static_configs:
      - targets: ["10.0.1.100:9100"]
        labels:
          instance: "java-tomcat"
EOF'

  # Créer un lien symbolique vers le fichier de configuration
  sudo ln -sf /opt/monitoring/config/prometheus/prometheus.yml /opt/monitoring/prometheus.yml
fi

# Exécuter les scripts d'initialisation avec les variables d'environnement
echo "$(date '+%Y-%m-%d %H:%M:%S') - Exécution des scripts d'initialisation"
sudo -E /opt/monitoring/init-monitoring.sh

# Attendre que le script d'initialisation se termine
echo "$(date '+%Y-%m-%d %H:%M:%S') - Attente de la fin du script d'initialisation"
sleep 10

# Exécuter le script de configuration complète du monitoring
echo "$(date '+%Y-%m-%d %H:%M:%S') - Exécution du script de configuration complète du monitoring"
sudo -E /opt/monitoring/setup-monitoring-complete.sh

# Attendre que le script de configuration complète se termine
echo "$(date '+%Y-%m-%d %H:%M:%S') - Attente de la fin du script de configuration complète"
sleep 10

# Exécuter le script de correction de Grafana
echo "$(date '+%Y-%m-%d %H:%M:%S') - Exécution du script de correction de Grafana"
sudo -E /opt/monitoring/fix-grafana.sh

# Télécharger et configurer le service systemd pour la mise à jour des cibles Prometheus
echo "$(date '+%Y-%m-%d %H:%M:%S') - Configuration du service systemd pour la mise à jour des cibles Prometheus"
sudo wget -q -O /etc/systemd/system/update-prometheus-targets.service "$GITHUB_RAW_URL/scripts/ec2-monitoring/update-prometheus-targets.service"
sudo wget -q -O /etc/systemd/system/update-prometheus-targets.timer "$GITHUB_RAW_URL/scripts/ec2-monitoring/update-prometheus-targets.timer"
sudo wget -q -O /opt/monitoring/scripts/update-prometheus-targets.sh "$GITHUB_RAW_URL/scripts/ec2-monitoring/update-prometheus-targets.sh"
sudo chmod +x /opt/monitoring/scripts/update-prometheus-targets.sh
sudo systemctl daemon-reload
sudo systemctl enable update-prometheus-targets.timer
sudo systemctl start update-prometheus-targets.timer
sudo systemctl start update-prometheus-targets.service

# Créer un fichier de marqueur pour indiquer que le script a terminé
sudo touch /var/log/user-data-completed

echo "$(date '+%Y-%m-%d %H:%M:%S') - Script d'initialisation minimal terminé"
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
