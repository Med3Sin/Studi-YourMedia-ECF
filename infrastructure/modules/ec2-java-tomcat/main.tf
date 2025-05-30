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

echo "$(date '+%Y-%m-%d %H:%M:%S') - Démarrage du script d'initialisation"

# Installer wget pour télécharger les scripts
echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation de wget"
sudo dnf install -y wget

# Configurer la clé SSH
echo "$(date '+%Y-%m-%d %H:%M:%S') - Configuration de la clé SSH"
sudo mkdir -p /home/ec2-user/.ssh
echo "${var.ssh_public_key}" | sudo tee -a /home/ec2-user/.ssh/authorized_keys > /dev/null
sudo chmod 700 /home/ec2-user/.ssh
sudo chmod 600 /home/ec2-user/.ssh/authorized_keys
sudo chown -R ec2-user:ec2-user /home/ec2-user/.ssh

# Télécharger et exécuter le script d'installation complet
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement et exécution du script d'installation"
sudo wget -q -O /tmp/install-all.sh "https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main/scripts/ec2-java-tomcat/install-all.sh"
sudo chmod +x /tmp/install-all.sh
sudo /tmp/install-all.sh

# Télécharger le script de déploiement WAR
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement du script de déploiement WAR"
sudo wget -q -O /opt/yourmedia/deploy-war.sh "https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main/scripts/ec2-java-tomcat/deploy-war.sh"
sudo chmod +x /opt/yourmedia/deploy-war.sh
sudo ln -sf /opt/yourmedia/deploy-war.sh /usr/local/bin/deploy-war.sh

# Configurer sudoers pour permettre à ec2-user d'exécuter le script sans mot de passe
sudo bash -c 'echo "ec2-user ALL=(ALL) NOPASSWD: /usr/local/bin/deploy-war.sh" > /etc/sudoers.d/deploy-war'
sudo chmod 440 /etc/sudoers.d/deploy-war

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
