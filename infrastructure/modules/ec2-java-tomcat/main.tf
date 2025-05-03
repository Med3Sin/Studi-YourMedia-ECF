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
      "ec2:CreateTags"
    ]
    resources = [
      "arn:aws:ec2:${var.aws_region}:*:*"
    ]
  }

  # Permission pour décrire les tags EC2 (nécessite "*" comme ressource)
  statement {
    actions = [
      "ec2:DescribeTags"
    ]
    resources = [
      "*"
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

# Récupérer l'ID de l'instance pour les logs
echo "$(date '+%Y-%m-%d %H:%M:%S') - Récupération de l'ID de l'instance"
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id || echo "unknown")
echo "ID de l'instance: $INSTANCE_ID"

# Télécharger et exécuter le script d'initialisation depuis GitHub
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement du script d'initialisation depuis GitHub"
sudo mkdir -p /opt/yourmedia
echo "$(date '+%Y-%m-%d %H:%M:%S') - Répertoire /opt/yourmedia créé"

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

# Utiliser wget avec plus de verbosité pour télécharger le script d'initialisation
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement du script init-java-tomcat.sh..."
sudo wget -v -O /opt/yourmedia/init-java-tomcat.sh "$GITHUB_RAW_URL/scripts/ec2-java-tomcat/init-java-tomcat.sh" 2>&1 | tee -a /var/log/user-data-init.log

# Vérifier si le téléchargement a réussi
if [ ! -s /opt/yourmedia/init-java-tomcat.sh ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERREUR: Le téléchargement du script init-java-tomcat.sh a échoué. Tentative avec le chemin complet..."
  sudo wget -v -O /opt/yourmedia/init-java-tomcat.sh "https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main/scripts/ec2-java-tomcat/init-java-tomcat.sh" 2>&1 | tee -a /var/log/user-data-init.log
fi

# Vérifier à nouveau si le téléchargement a réussi
if [ -s /opt/yourmedia/init-java-tomcat.sh ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Script init-java-tomcat.sh téléchargé avec succès"
  sudo chmod +x /opt/yourmedia/init-java-tomcat.sh
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Permissions exécutables accordées au script"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERREUR CRITIQUE: Impossible de télécharger le script init-java-tomcat.sh"
  exit 1
fi

# Télécharger directement le script de configuration pour éviter les problèmes
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement du script de configuration setup-java-tomcat.sh..."
sudo wget -v -O /opt/yourmedia/setup-java-tomcat.sh "$GITHUB_RAW_URL/scripts/ec2-java-tomcat/setup-java-tomcat.sh" 2>&1 | tee -a /var/log/user-data-init.log

# Vérifier si le téléchargement a réussi
if [ -s /opt/yourmedia/setup-java-tomcat.sh ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Script setup-java-tomcat.sh téléchargé avec succès"
  sudo chmod +x /opt/yourmedia/setup-java-tomcat.sh
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Permissions exécutables accordées au script"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERREUR: Impossible de télécharger le script setup-java-tomcat.sh"
fi

# S'assurer que tous les scripts sont exécutables
echo "$(date '+%Y-%m-%d %H:%M:%S') - Attribution des permissions d'exécution aux scripts"
sudo chmod +x /opt/yourmedia/*.sh 2>/dev/null || true

# Définir la version de Tomcat
export TOMCAT_VERSION=9.0.104
echo "$(date '+%Y-%m-%d %H:%M:%S') - Version de Tomcat à installer: $TOMCAT_VERSION"

# Exécuter le script d'initialisation avec la variable TOMCAT_VERSION
echo "$(date '+%Y-%m-%d %H:%M:%S') - Exécution du script d'initialisation"
sudo -E /opt/yourmedia/init-java-tomcat.sh 2>&1 | tee -a /var/log/user-data-init.log

# Vérifier si Tomcat est en cours d'exécution
echo "$(date '+%Y-%m-%d %H:%M:%S') - Vérification finale de l'état de Tomcat"
if sudo systemctl is-active --quiet tomcat; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Tomcat est en cours d'exécution"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ Tomcat n'est pas en cours d'exécution. Démarrage manuel..."

    # Vérifier si le service Tomcat existe
    if [ -f "/etc/systemd/system/tomcat.service" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Le service Tomcat existe, tentative de démarrage"
        sudo systemctl daemon-reload
        sudo systemctl start tomcat
        sudo systemctl enable tomcat
        sleep 10
        if sudo systemctl is-active --quiet tomcat; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Tomcat a été démarré avec succès"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ Échec du démarrage de Tomcat"
        fi
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ Le service Tomcat n'existe pas, exécution manuelle de setup-java-tomcat.sh"
        cd /opt/yourmedia
        export TOMCAT_VERSION=9.0.104
        sudo -E ./setup-java-tomcat.sh
        sleep 10
        if sudo systemctl is-active --quiet tomcat; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Tomcat a été démarré avec succès après installation manuelle"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ Échec du démarrage de Tomcat après installation manuelle"
        fi
    fi
fi

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
