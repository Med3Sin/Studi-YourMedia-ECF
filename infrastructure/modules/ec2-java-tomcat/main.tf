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

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a /var/log/user-data-init.log
}

# Fonction pour afficher les erreurs et quitter
error_exit() {
    log "ERREUR: $1"
    exit 1
}

# Vérification des variables requises
if [ -z "${var.s3_bucket_name}" ]; then
    error_exit "La variable s3_bucket_name n'est pas définie"
fi

if [ -z "${var.db_username}" ]; then
    error_exit "La variable db_username n'est pas définie"
fi

if [ -z "${var.db_password}" ]; then
    error_exit "La variable db_password n'est pas définie"
fi

if [ -z "${var.rds_endpoint}" ]; then
    error_exit "La variable rds_endpoint n'est pas définie"
fi

# Mettre à jour le système
log "Mise à jour du système"
dnf update -y

# Installer les dépendances nécessaires
log "Installation des dépendances"
dnf install -y aws-cli curl jq

# Définir les variables d'environnement
log "Configuration des variables d'environnement"
EC2_INSTANCE_PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
EC2_INSTANCE_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
EC2_INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
EC2_INSTANCE_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

# Exporter les variables
export EC2_INSTANCE_PRIVATE_IP="$EC2_INSTANCE_PRIVATE_IP"
export EC2_INSTANCE_PUBLIC_IP="$EC2_INSTANCE_PUBLIC_IP"
export EC2_INSTANCE_ID="$EC2_INSTANCE_ID"
export EC2_INSTANCE_REGION="$EC2_INSTANCE_REGION"
export DB_USERNAME="${var.db_username}"
export DB_PASSWORD="${var.db_password}"
export RDS_ENDPOINT="${var.rds_endpoint}"
export S3_BUCKET_NAME="${var.s3_bucket_name}"
export RDS_USERNAME="${var.db_username}"
export RDS_PASSWORD="${var.db_password}"
export TOMCAT_VERSION="9.0.104"

# Vérifier que les variables sont bien définies
log "Vérification des variables d'environnement"
log "S3_BUCKET_NAME: $S3_BUCKET_NAME"
log "RDS_ENDPOINT: $RDS_ENDPOINT"
log "EC2_INSTANCE_PRIVATE_IP: $EC2_INSTANCE_PRIVATE_IP"
log "EC2_INSTANCE_PUBLIC_IP: $EC2_INSTANCE_PUBLIC_IP"

# Créer les répertoires nécessaires avec des droits root
log "Création des répertoires nécessaires"
sudo rm -rf /opt/yourmedia 2>/dev/null || true
sudo mkdir -p /opt/yourmedia/secure || error_exit "Échec de la création du répertoire /opt/yourmedia/secure"
sudo chmod 755 /opt/yourmedia || error_exit "Échec de la modification des permissions de /opt/yourmedia"
sudo chmod 700 /opt/yourmedia/secure || error_exit "Échec de la modification des permissions de /opt/yourmedia/secure"

# Créer le fichier de variables d'environnement
log "Création du fichier de variables d'environnement"
sudo bash -c 'cat > /opt/yourmedia/env.sh << "EOL"'
#!/bin/bash
# Variables d'environnement pour l'application Java Tomcat
# Généré automatiquement par user_data
# Date de génération: $(date)

# Variables EC2
export EC2_INSTANCE_PRIVATE_IP="$${EC2_INSTANCE_PRIVATE_IP}"
export EC2_INSTANCE_PUBLIC_IP="$${EC2_INSTANCE_PUBLIC_IP}"
export EC2_INSTANCE_ID="$${EC2_INSTANCE_ID}"
export EC2_INSTANCE_REGION="$${EC2_INSTANCE_REGION}"

# Variables S3
export S3_BUCKET_NAME="$${S3_BUCKET_NAME}"

# Variables RDS
export RDS_USERNAME="$${RDS_USERNAME}"
export RDS_ENDPOINT="$${RDS_ENDPOINT}"

# Variables de compatibilité
export DB_USERNAME="$${DB_USERNAME}"
export DB_ENDPOINT="$${RDS_ENDPOINT}"

# Variable Tomcat
export TOMCAT_VERSION="$${TOMCAT_VERSION}"

# Charger les variables sensibles
source /opt/yourmedia/secure/sensitive-env.sh 2>/dev/null || true
EOL

# Créer le fichier de variables sensibles
log "Création du fichier de variables sensibles"
sudo bash -c 'cat > /opt/yourmedia/secure/sensitive-env.sh << "EOL"'
#!/bin/bash
# Variables sensibles pour l'application Java Tomcat
# Généré automatiquement par user_data
# Date de génération: $(date)

# Variables RDS
export RDS_PASSWORD="$${RDS_PASSWORD}"

# Variables de compatibilité
export DB_PASSWORD="$${DB_PASSWORD}"
EOL

# Définir les permissions
sudo chmod 755 /opt/yourmedia/env.sh
sudo chmod 600 /opt/yourmedia/secure/sensitive-env.sh
sudo chown -R ec2-user:ec2-user /opt/yourmedia

# Télécharger les scripts depuis S3
log "Téléchargement des scripts depuis S3"
sudo aws s3 cp s3://${var.s3_bucket_name}/scripts/ec2-java-tomcat/ /opt/yourmedia/ --recursive || log "AVERTISSEMENT: Échec du téléchargement de certains scripts depuis S3"

# Rendre les scripts exécutables
log "Rendre les scripts exécutables"
sudo find /opt/yourmedia -name "*.sh" -exec chmod +x {} \;

# Configurer la clé SSH
log "Configuration de la clé SSH"
sudo mkdir -p /home/ec2-user/.ssh
echo "${var.ssh_public_key}" | sudo tee -a /home/ec2-user/.ssh/authorized_keys > /dev/null
sudo chmod 700 /home/ec2-user/.ssh
sudo chmod 600 /home/ec2-user/.ssh/authorized_keys
sudo chown -R ec2-user:ec2-user /home/ec2-user/.ssh

# Exécuter le script d'installation de Java et Tomcat
log "Exécution du script d'installation de Java et Tomcat"
if [ -f "/opt/yourmedia/install_java_tomcat.sh" ]; then
    sudo chmod +x /opt/yourmedia/install_java_tomcat.sh
    sudo /opt/yourmedia/install_java_tomcat.sh || error_exit "Échec de l'exécution du script d'installation de Java et Tomcat"
else
    error_exit "Le script install_java_tomcat.sh n'existe pas"
fi

# Créer un lien symbolique pour le script deploy-war.sh
log "Création d'un lien symbolique pour le script deploy-war.sh"
if [ -f "/opt/yourmedia/deploy-war.sh" ]; then
    sudo chmod +x /opt/yourmedia/deploy-war.sh
    sudo ln -sf /opt/yourmedia/deploy-war.sh /usr/local/bin/deploy-war.sh
    sudo chmod +x /usr/local/bin/deploy-war.sh

    # Configurer sudoers pour permettre à ec2-user d'exécuter le script sans mot de passe
    echo "ec2-user ALL=(ALL) NOPASSWD: /usr/local/bin/deploy-war.sh" | sudo tee /etc/sudoers.d/deploy-war > /dev/null
    sudo chmod 440 /etc/sudoers.d/deploy-war

    log "Script deploy-war.sh configuré avec succès"
else
    log "AVERTISSEMENT: Le script deploy-war.sh n'existe pas"
fi

log "Initialisation terminée avec succès"
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
  }
}
