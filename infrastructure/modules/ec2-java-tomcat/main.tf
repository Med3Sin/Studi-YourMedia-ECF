variable "project_name" {
  description = "Nom du projet"
  type        = string
}

variable "environment" {
  description = "Environnement (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID du VPC"
  type        = string
}

variable "subnet_id" {
  description = "ID du sous-réseau"
  type        = string
}

variable "ec2_security_group_id" {
  description = "ID du groupe de sécurité EC2"
  type        = string
}

variable "ami_id" {
  description = "ID de l'AMI à utiliser"
  type        = string
  default     = ""
}

variable "use_latest_ami" {
  description = "Utiliser la dernière AMI Amazon Linux 2023"
  type        = bool
  default     = true
}

variable "instance_type_ec2" {
  description = "Type d'instance EC2"
  type        = string
  default     = "t2.micro"
}

variable "key_pair_name" {
  description = "Nom de la paire de clés SSH"
  type        = string
}

variable "ssh_public_key" {
  description = "Clé publique SSH"
  type        = string
  default     = ""
}

# Récupérer la dernière AMI Amazon Linux 2023
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# Créer un rôle IAM pour l'instance EC2
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-${var.environment}-ec2-role-v2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-role-v2"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Attacher la politique AmazonS3ReadOnlyAccess au rôle IAM
resource "aws_iam_role_policy_attachment" "s3_read_only" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# Attacher la politique CloudWatchAgentServerPolicy au rôle IAM
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Créer une politique personnalisée pour permettre à l'instance EC2 de décrire ses tags
resource "aws_iam_policy" "ec2_describe_tags" {
  name        = "${var.project_name}-${var.environment}-ec2-describe-tags-policy"
  description = "Permet à l'instance EC2 de décrire ses tags"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "ec2:DescribeTags"
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

# Attacher la politique personnalisée au rôle IAM
resource "aws_iam_role_policy_attachment" "ec2_describe_tags" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_describe_tags.arn
}

# Créer un profil d'instance IAM
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-${var.environment}-ec2-profile-v2"
  role = aws_iam_role.ec2_role.name
}

# Script d'installation inline pour l'user_data
locals {
  install_script = <<-EOF
#!/bin/bash
set -e

# Rediriger stdout et stderr vers un fichier log
exec > >(tee /var/log/user-data-init.log) 2>&1

echo "$(date '+%Y-%m-%d %H:%M:%S') - Démarrage du script d'initialisation minimal"

# Mettre à jour le système et installer les dépendances de base
echo "$(date '+%Y-%m-%d %H:%M:%S') - Mise à jour du système et installation des dépendances de base"
sudo dnf update -y
sudo dnf install -y wget curl

# Configurer la clé SSH
echo "$(date '+%Y-%m-%d %H:%M:%S') - Configuration de la clé SSH"
sudo mkdir -p /home/ec2-user/.ssh
echo "${var.ssh_public_key}" | sudo tee -a /home/ec2-user/.ssh/authorized_keys > /dev/null
sudo chmod 700 /home/ec2-user/.ssh
sudo chmod 600 /home/ec2-user/.ssh/authorized_keys
sudo chown -R ec2-user:ec2-user /home/ec2-user/.ssh

# Télécharger et exécuter le script d'installation complet
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement du script d'installation complet"
sudo wget -q -O /tmp/install-all.sh "https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main/scripts/ec2-java-tomcat/install-all.sh"
sudo chmod +x /tmp/install-all.sh

echo "$(date '+%Y-%m-%d %H:%M:%S') - Exécution du script d'installation complet"
sudo /tmp/install-all.sh

echo "$(date '+%Y-%m-%d %H:%M:%S') - Script d'initialisation terminé"
EOF
}

resource "aws_instance" "app_server" {
  ami                    = var.use_latest_ami ? data.aws_ami.amazon_linux_2023.id : var.ami_id
  instance_type          = var.instance_type_ec2
  key_name               = var.key_pair_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.ec2_security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # Script exécuté au premier démarrage de l'instance
  user_data = local.install_script

  # S'assurer que le profil IAM est créé avant l'instance
  depends_on = [aws_iam_instance_profile.ec2_profile]

  tags = {
    Name        = "${var.project_name}-${var.environment}-app-server"
    Project     = var.project_name
    Environment = var.environment
    AppType     = "HelloWorld"
  }
}

output "instance_id" {
  description = "ID de l'instance EC2"
  value       = aws_instance.app_server.id
}

output "private_ip" {
  description = "Adresse IP privée de l'instance EC2"
  value       = aws_instance.app_server.private_ip
}

output "public_ip" {
  description = "Adresse IP publique de l'instance EC2"
  value       = aws_instance.app_server.public_ip
}

output "public_dns" {
  description = "Nom DNS public de l'instance EC2"
  value       = aws_instance.app_server.public_dns
}
