# -----------------------------------------------------------------------------
# IAM Role et Politique pour l'instance EC2
# -----------------------------------------------------------------------------

# Politique IAM autorisant l'accès au bucket S3 spécifié
data "aws_iam_policy_document" "ec2_s3_access_policy_doc" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket" # ListBucket nécessite l'ARN du bucket lui-même
    ]
    resources = [
      var.s3_bucket_arn,       # Accès au bucket
      "${var.s3_bucket_arn}/*" # Accès aux objets dans le bucket
    ]
  }

  # Permission pour créer et décrire des tags EC2
  statement {
    actions = [
      "ec2:CreateTags",
      "ec2:DescribeTags"
    ]
    resources = [
      "arn:aws:ec2:${var.aws_region}:*:*"
    ]
  }
  # Ajouter ici d'autres permissions si nécessaire (ex: Secrets Manager, etc.)
}

resource "aws_iam_policy" "ec2_s3_access_policy" {
  name        = "${var.project_name}-${var.environment}-ec2-s3-access-policy-v2"
  description = "Politique autorisant l'EC2 à accéder au bucket S3 du projet"
  policy      = data.aws_iam_policy_document.ec2_s3_access_policy_doc.json

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-s3-access-policy"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Rôle IAM que l'instance EC2 assumera
resource "aws_iam_role" "ec2_role" {
  name                  = "${var.project_name}-${var.environment}-ec2-role-v2"
  force_detach_policies = true
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
    Name        = "${var.project_name}-${var.environment}-ec2-role"
    Project     = var.project_name
    Environment = var.environment
  }

  # Faciliter la suppression et recréation du rôle
  lifecycle {
    create_before_destroy = true
  }
}

# Attacher la politique S3 au rôle EC2
resource "aws_iam_role_policy_attachment" "ec2_s3_policy_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_s3_access_policy.arn
}

# Profil d'instance EC2 pour attacher le rôle à l'instance
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-profile"
    Project     = var.project_name
    Environment = var.environment
  }

  # Éviter les erreurs de conflit si le profil existe déjà
  lifecycle {
    create_before_destroy = true
  }
}


# -----------------------------------------------------------------------------
# Instance EC2
# -----------------------------------------------------------------------------

# Récupération automatique de l'AMI Amazon Linux 2023 la plus récente
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

# Script d'installation inline pour l'user_data
locals {
  install_script = <<-EOF
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
sudo dnf install -y jq wget aws-cli

# Configurer la clé SSH
echo "$(date '+%Y-%m-%d %H:%M:%S') - Configuration de la clé SSH"
sudo mkdir -p /home/ec2-user/.ssh
echo "${var.ssh_public_key}" | sudo tee -a /home/ec2-user/.ssh/authorized_keys > /dev/null
sudo chmod 700 /home/ec2-user/.ssh
sudo chmod 600 /home/ec2-user/.ssh/authorized_keys
sudo chown -R ec2-user:ec2-user /home/ec2-user/.ssh

# Créer le tag pour le nom du bucket S3
echo "$(date '+%Y-%m-%d %H:%M:%S') - Création du tag pour le bucket S3"
# Attendre que les métadonnées de l'instance soient disponibles
echo "Attente de la disponibilité des métadonnées de l'instance..."
for i in {1..10}; do
  INSTANCE_ID=$(curl -s --connect-timeout 5 --max-time 10 http://169.254.169.254/latest/meta-data/instance-id)
  if [ ! -z "$INSTANCE_ID" ]; then
    echo "ID de l'instance récupéré: $INSTANCE_ID"
    break
  fi
  echo "Tentative $i: Métadonnées non disponibles, nouvelle tentative dans 5 secondes..."
  sleep 5
done

# Vérifier que l'ID de l'instance a été récupéré
if [ -z "$INSTANCE_ID" ]; then
  echo "ERREUR: Impossible de récupérer l'ID de l'instance après plusieurs tentatives."
  # Continuer malgré l'erreur, le tag sera créé plus tard par le script d'initialisation
else
  # Correction de la syntaxe de la commande create-tags
  echo "Création du tag S3BucketName pour l'instance $INSTANCE_ID..."
  aws ec2 create-tags --region ${var.aws_region} --resources "$INSTANCE_ID" --tags "Key=S3BucketName,Value=${var.s3_bucket_name}"
fi

# Télécharger et exécuter le script d'initialisation depuis GitHub
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement du script d'initialisation depuis GitHub"
sudo mkdir -p /opt/yourmedia
GITHUB_RAW_URL="https://raw.githubusercontent.com/${var.repo_owner}/${var.repo_name}/main"
sudo curl -s -o /opt/yourmedia/init-java-tomcat.sh "$GITHUB_RAW_URL/scripts/ec2-java-tomcat/init-java-tomcat.sh"
sudo chmod +x /opt/yourmedia/init-java-tomcat.sh

# Exécuter le script d'initialisation
echo "$(date '+%Y-%m-%d %H:%M:%S') - Exécution du script d'initialisation"
sudo /opt/yourmedia/init-java-tomcat.sh

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
    Name         = "${var.project_name}-${var.environment}-app-server"
    Project      = var.project_name
    Environment  = var.environment
    S3BucketName = var.s3_bucket_name
  }
}
