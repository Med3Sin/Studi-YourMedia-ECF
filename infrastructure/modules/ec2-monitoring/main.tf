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
# Data source pour récupérer le groupe de sécurité existant s'il existe
data "aws_security_group" "existing_monitoring_sg" {
  count  = var.use_existing_sg ? 1 : 0
  name   = "${var.project_name}-${var.environment}-monitoring-sg"
  vpc_id = var.vpc_id
}

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
  monitoring_sg_id = var.use_existing_sg ? data.aws_security_group.existing_monitoring_sg[0].id : aws_security_group.monitoring_sg[0].id
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
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-monitoring-policy"
    Project     = var.project_name
    Environment = var.environment
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
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2.id
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
yum update -y
yum install -y amazon-cloudwatch-agent

# Créer le répertoire .ssh s'il n'existe pas
mkdir -p /home/ec2-user/.ssh
chmod 700 /home/ec2-user/.ssh

# Installer la clé SSH publique
echo "${var.ssh_public_key}" >> /home/ec2-user/.ssh/authorized_keys
chmod 600 /home/ec2-user/.ssh/authorized_keys
chown -R ec2-user:ec2-user /home/ec2-user/.ssh

# Télécharger et exécuter le script d'initialisation depuis S3
aws s3 cp s3://${var.s3_bucket_name}/scripts/ec2-monitoring/init-instance.sh /tmp/init-instance.sh
chmod +x /tmp/init-instance.sh

# Remplacer les variables dans le script d'initialisation
sed -i "s/PLACEHOLDER_IP/${var.ec2_instance_private_ip}/g" /tmp/init-instance.sh
sed -i "s/PLACEHOLDER_USERNAME/${var.db_username}/g" /tmp/init-instance.sh
sed -i "s/PLACEHOLDER_PASSWORD/${var.db_password}/g" /tmp/init-instance.sh
sed -i "s/PLACEHOLDER_ENDPOINT/${var.rds_endpoint}/g" /tmp/init-instance.sh
sed -i "s/SONAR_JDBC_USERNAME/${var.sonar_jdbc_username}/g" /tmp/init-instance.sh
sed -i "s/SONAR_JDBC_PASSWORD/${var.sonar_jdbc_password}/g" /tmp/init-instance.sh
sed -i "s|SONAR_JDBC_URL|${var.sonar_jdbc_url}|g" /tmp/init-instance.sh
sed -i "s/GRAFANA_ADMIN_PASSWORD/${var.grafana_admin_password}/g" /tmp/init-instance.sh
sed -i "s/PLACEHOLDER_BUCKET/${var.s3_bucket_name}/g" /tmp/init-instance.sh

# Exécuter le script d'initialisation
/tmp/init-instance.sh
EOF

  tags = {
    Name        = "${var.project_name}-${var.environment}-monitoring-instance"
    Project     = var.project_name
    Environment = var.environment
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
      "chmod +x /tmp/docker-manager.sh",
      "chmod +x /tmp/fix_permissions.sh",
      "/tmp/docker-manager.sh deploy monitoring",
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
      "chmod +x /tmp/generate_sonar_token.sh",
      "/tmp/generate_sonar_token.sh ${aws_instance.monitoring_instance.public_ip} ${var.tf_api_token} ${var.tf_workspace_id}"
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

# Récupération de l'AMI Amazon Linux 2 la plus récente
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
