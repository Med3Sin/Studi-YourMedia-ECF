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

# Mettre à jour le système et installer les dépendances
sudo dnf update -y
sudo dnf install -y amazon-cloudwatch-agent jq

# Créer le répertoire .ssh s'il n'existe pas
sudo mkdir -p /home/ec2-user/.ssh
sudo chmod 700 /home/ec2-user/.ssh

# Installer la clé SSH publique
echo "${var.ssh_public_key}" | sudo tee -a /home/ec2-user/.ssh/authorized_keys
sudo chmod 600 /home/ec2-user/.ssh/authorized_keys
sudo chown -R ec2-user:ec2-user /home/ec2-user/.ssh

# Créer les répertoires nécessaires
sudo mkdir -p /opt/monitoring/secure
sudo chmod 755 /opt/monitoring
sudo chmod 700 /opt/monitoring/secure

# Définir les variables d'environnement pour le script
# Utiliser des valeurs par défaut si les variables ne sont pas définies
S3_BUCKET_NAME="${var.s3_bucket_name}"
EC2_INSTANCE_PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
EC2_INSTANCE_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
DB_USERNAME="${var.db_username}"
DB_PASSWORD="${var.db_password}"
RDS_ENDPOINT="${var.rds_endpoint}"
SONAR_JDBC_USERNAME="${var.sonar_jdbc_username}"
SONAR_JDBC_PASSWORD="${var.sonar_jdbc_password}"
SONAR_JDBC_URL="${var.sonar_jdbc_url}"
GRAFANA_ADMIN_PASSWORD="${var.grafana_admin_password}"
DOCKER_USERNAME="${var.docker_username}"
DOCKER_REPO="${var.docker_repo}"
DOCKERHUB_TOKEN="${var.dockerhub_token}"

# Vérifier que le nom du bucket S3 est défini
if [ -z "$S3_BUCKET_NAME" ]; then
  echo "ERREUR: La variable S3_BUCKET_NAME n'est pas définie."
  exit 1
fi

# Créer le fichier de variables d'environnement non sensibles
sudo bash -c 'cat > /opt/monitoring/env.sh << "EOL"'
#!/bin/bash
# Variables d'environnement pour le monitoring
# Généré automatiquement par Terraform

# Variables EC2
export EC2_INSTANCE_PRIVATE_IP="$${EC2_INSTANCE_PRIVATE_IP}"
export EC2_INSTANCE_PUBLIC_IP="$${EC2_INSTANCE_PUBLIC_IP}"
export EC2_APP_IP="${var.ec2_instance_private_ip}"

# Variables S3
export S3_BUCKET_NAME="$${S3_BUCKET_NAME}"
export AWS_REGION="eu-west-3"

# Variables Docker
export DOCKER_USERNAME="$${DOCKER_USERNAME}"
export DOCKER_REPO="$${DOCKER_REPO}"
export DOCKERHUB_USERNAME="$${DOCKER_USERNAME}"
export DOCKERHUB_REPO="$${DOCKER_REPO}"
EOL

# Créer le fichier de variables sensibles
sudo bash -c 'cat > /opt/monitoring/secure/sensitive-env.sh << "EOL"'
#!/bin/bash
# Variables sensibles pour le monitoring
# Généré automatiquement par Terraform

# Variables Docker Hub
export DOCKERHUB_TOKEN="$${DOCKERHUB_TOKEN}"

# Variables RDS
export RDS_USERNAME="$${DB_USERNAME}"
export RDS_PASSWORD="$${DB_PASSWORD}"
export RDS_ENDPOINT="$${RDS_ENDPOINT}"

# Extraire l'hôte et le port de RDS_ENDPOINT
if [[ "$${RDS_ENDPOINT}" == *":"* ]]; then
  export RDS_HOST=$(echo "$${RDS_ENDPOINT}" | cut -d':' -f1)
  export RDS_PORT=$(echo "$${RDS_ENDPOINT}" | cut -d':' -f2)
else
  export RDS_HOST="$${RDS_ENDPOINT}"
  export RDS_PORT="3306"
fi

# Variables de compatibilité
export DB_USERNAME="$${DB_USERNAME}"
export DB_PASSWORD="$${DB_PASSWORD}"
export DB_ENDPOINT="$${RDS_ENDPOINT}"

# Variables SonarQube
export SONAR_JDBC_USERNAME="$${SONAR_JDBC_USERNAME}"
export SONAR_JDBC_PASSWORD="$${SONAR_JDBC_PASSWORD}"
export SONAR_JDBC_URL="$${SONAR_JDBC_URL}"

# Variables Grafana
export GRAFANA_ADMIN_PASSWORD="$${GRAFANA_ADMIN_PASSWORD}"
export GF_SECURITY_ADMIN_PASSWORD="$${GRAFANA_ADMIN_PASSWORD}"
EOL

# Définir les permissions
sudo chmod 755 /opt/monitoring/env.sh
sudo chmod 600 /opt/monitoring/secure/sensitive-env.sh
sudo chown -R ec2-user:ec2-user /opt/monitoring

# Charger les variables d'environnement
sudo -E bash -c 'source /opt/monitoring/env.sh'
sudo -E bash -c 'source /opt/monitoring/secure/sensitive-env.sh'

# Se connecter à Docker Hub
echo "$DOCKERHUB_TOKEN" | sudo docker login -u "$DOCKER_USERNAME" --password-stdin

# Télécharger les scripts depuis S3
echo "Téléchargement des scripts depuis S3..."
sudo aws s3 cp s3://$S3_BUCKET_NAME/scripts/ec2-monitoring/ /opt/monitoring/ --recursive
sudo aws s3 cp s3://$S3_BUCKET_NAME/scripts/docker/ /opt/monitoring/docker/ --recursive

# Rendre les scripts exécutables
sudo chmod +x /opt/monitoring/*.sh
sudo chmod +x /opt/monitoring/docker/*.sh

# Copier docker-manager.sh dans /usr/local/bin
sudo cp /opt/monitoring/docker/docker-manager.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/docker-manager.sh

# Télécharger et exécuter le script d'initialisation depuis S3
sudo aws s3 cp s3://$S3_BUCKET_NAME/scripts/ec2-monitoring/init-instance-env.sh /tmp/init-instance.sh
sudo chmod +x /tmp/init-instance.sh

# Exporter les variables d'environnement pour le script
export EC2_INSTANCE_PRIVATE_IP="$EC2_INSTANCE_PRIVATE_IP"
export EC2_INSTANCE_PUBLIC_IP="$EC2_INSTANCE_PUBLIC_IP"
export DB_USERNAME="$DB_USERNAME"
export DB_PASSWORD="$DB_PASSWORD"
export RDS_USERNAME="$DB_USERNAME"
export RDS_PASSWORD="$DB_PASSWORD"
export RDS_ENDPOINT="$RDS_ENDPOINT"
export SONAR_JDBC_USERNAME="$SONAR_JDBC_USERNAME"
export SONAR_JDBC_PASSWORD="$SONAR_JDBC_PASSWORD"
export SONAR_JDBC_URL="$SONAR_JDBC_URL"
export GRAFANA_ADMIN_PASSWORD="$GRAFANA_ADMIN_PASSWORD"
export GF_SECURITY_ADMIN_PASSWORD="$GRAFANA_ADMIN_PASSWORD"
export S3_BUCKET_NAME="$S3_BUCKET_NAME"
export DOCKER_USERNAME="$DOCKER_USERNAME"
export DOCKER_REPO="$DOCKER_REPO"
export DOCKERHUB_TOKEN="$DOCKERHUB_TOKEN"
export DOCKERHUB_USERNAME="$DOCKER_USERNAME"
export DOCKERHUB_REPO="$DOCKER_REPO"

# Exécuter le script d'initialisation avec les variables d'environnement
sudo -E /tmp/init-instance.sh

# Exécuter le script de configuration
cd /opt/monitoring
sudo chmod +x setup.sh
sudo -E ./setup.sh
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
