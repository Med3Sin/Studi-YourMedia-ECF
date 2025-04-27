# -----------------------------------------------------------------------------
# Module EC2 Monitoring
# -----------------------------------------------------------------------------
# Ce module crée une instance EC2 pour le monitoring de l'application
# Il installe et configure Prometheus, Grafana et SonarQube
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

  # SonarQube
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "SonarQube access"
  }

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
sudo dnf install -y aws-cli curl jq wget amazon-cloudwatch-agent

# Configurer la clé SSH
echo "$(date '+%Y-%m-%d %H:%M:%S') - Configuration de la clé SSH"
sudo mkdir -p /home/ec2-user/.ssh
echo "${var.ssh_public_key}" | sudo tee -a /home/ec2-user/.ssh/authorized_keys > /dev/null
sudo chmod 700 /home/ec2-user/.ssh
sudo chmod 600 /home/ec2-user/.ssh/authorized_keys
sudo chown -R ec2-user:ec2-user /home/ec2-user/.ssh

# Définir les variables d'environnement
export S3_BUCKET_NAME="${var.s3_bucket_name}"
export DB_USERNAME="${var.db_username}"
export DB_PASSWORD="${var.db_password}"
export RDS_ENDPOINT="${var.rds_endpoint}"
export RDS_USERNAME="${var.db_username}"
export RDS_PASSWORD="${var.db_password}"
export SONAR_JDBC_USERNAME="${var.sonar_jdbc_username}"
export SONAR_JDBC_PASSWORD="${var.sonar_jdbc_password}"
export SONAR_JDBC_URL="${var.sonar_jdbc_url}"
export GRAFANA_ADMIN_PASSWORD="${var.grafana_admin_password}"
export DOCKER_USERNAME="${var.docker_username}"
export DOCKER_REPO="${var.docker_repo}"
export DOCKERHUB_TOKEN="${var.dockerhub_token}"
export DOCKERHUB_USERNAME="${var.docker_username}"
export DOCKERHUB_REPO="${var.docker_repo}"
export EC2_APP_IP="${var.ec2_instance_private_ip}"

# Télécharger et exécuter le script d'installation depuis S3
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement des scripts depuis S3"
sudo mkdir -p /opt/monitoring
sudo aws s3 cp s3://${var.s3_bucket_name}/scripts/ec2-monitoring/setup-monitoring.sh /opt/monitoring/ || echo "Échec du téléchargement du script setup-monitoring.sh"
sudo aws s3 cp s3://${var.s3_bucket_name}/scripts/docker/docker-manager.sh /opt/monitoring/ || echo "Échec du téléchargement du script docker-manager.sh"

if [ -f "/opt/monitoring/setup-monitoring.sh" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Exécution du script setup-monitoring.sh"
    sudo chmod +x /opt/monitoring/setup-monitoring.sh
    sudo /opt/monitoring/setup-monitoring.sh
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation manuelle de Docker"
    # Installation de Docker
    sudo dnf install -y docker
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker ec2-user

    # Installation de Docker Compose
    sudo dnf install -y docker-compose

    # Création des répertoires nécessaires
    sudo mkdir -p /opt/monitoring/secure
    sudo mkdir -p /opt/monitoring/prometheus-data
    sudo mkdir -p /opt/monitoring/grafana-data
    sudo mkdir -p /opt/monitoring/sonarqube-data/data
    sudo mkdir -p /opt/monitoring/sonarqube-data/logs
    sudo mkdir -p /opt/monitoring/sonarqube-data/extensions
    sudo mkdir -p /opt/monitoring/sonarqube-data/db

    # Définir les permissions
    sudo chmod 755 /opt/monitoring
    sudo chmod 700 /opt/monitoring/secure
    sudo chown -R ec2-user:ec2-user /opt/monitoring

    # Créer un fichier docker-compose.yml minimal
    sudo cat > /opt/monitoring/docker-compose.yml << "EOL"
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
    restart: always

  grafana:
    image: grafana/grafana:10.0.3
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - /opt/monitoring/grafana-data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=YourMedia2025!
    restart: always
EOL

    # Créer un fichier prometheus.yml minimal
    sudo cat > /opt/monitoring/prometheus.yml << "EOL"
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]
EOL

    # Démarrer les conteneurs
    cd /opt/monitoring
    sudo docker-compose up -d
fi

# Copier docker-manager.sh dans /usr/local/bin si disponible
if [ -f "/opt/monitoring/docker-manager.sh" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation du script docker-manager.sh"
    sudo cp /opt/monitoring/docker-manager.sh /usr/local/bin/
    sudo chmod +x /usr/local/bin/docker-manager.sh
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Initialisation terminée avec succès"
echo "Grafana est accessible à l'adresse http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000"
echo "Prometheus est accessible à l'adresse http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9090"
echo "SonarQube est accessible à l'adresse http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000"
EOF

  tags = {
    Name        = "${var.project_name}-${var.environment}-monitoring-instance"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Role        = "Monitoring"
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

# Génération et stockage du token SonarQube
resource "null_resource" "generate_sonar_token" {
  # Créer cette ressource uniquement si le provisionnement est activé
  count = var.enable_provisioning ? 1 : 0

  # Dépend de l'instance EC2 de monitoring
  depends_on = [aws_instance.monitoring_instance]

  # Déclencher uniquement lorsque l'instance est créée ou modifiée
  triggers = {
    instance_id = aws_instance.monitoring_instance.id
  }

  # Copie du script de génération du token SonarQube
  provisioner "file" {
    source      = "${path.module}/../../scripts/ec2-monitoring/generate_sonar_token.sh"
    destination = "/tmp/generate_sonar_token.sh"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      host        = aws_instance.monitoring_instance.public_ip
      private_key = var.ssh_private_key_content != "" ? var.ssh_private_key_content : file(var.ssh_private_key_path)
    }
  }

  # Exécution du script de génération du token SonarQube
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/generate_sonar_token.sh",
      "sudo /tmp/generate_sonar_token.sh ${aws_instance.monitoring_instance.public_ip} ${var.tf_api_token} ${var.tf_workspace_id}"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      host        = aws_instance.monitoring_instance.public_ip
      private_key = var.ssh_private_key_content != "" ? var.ssh_private_key_content : file(var.ssh_private_key_path)
    }
  }
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
