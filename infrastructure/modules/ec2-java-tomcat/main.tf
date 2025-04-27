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
    log "AVERTISSEMENT: La variable s3_bucket_name n'est pas définie"
    S3_BUCKET_NAME=""
else
    S3_BUCKET_NAME="${var.s3_bucket_name}"
    log "S3_BUCKET_NAME défini: $S3_BUCKET_NAME"
fi

if [ -z "${var.db_username}" ]; then
    log "AVERTISSEMENT: La variable db_username n'est pas définie"
    DB_USERNAME="yourmedia"
else
    DB_USERNAME="${var.db_username}"
    log "DB_USERNAME défini: $DB_USERNAME"
fi

if [ -z "${var.db_password}" ]; then
    log "AVERTISSEMENT: La variable db_password n'est pas définie"
    DB_PASSWORD="password"
else
    DB_PASSWORD="${var.db_password}"
    log "DB_PASSWORD défini: [MASQUÉ]"
fi

if [ -z "${var.rds_endpoint}" ]; then
    log "AVERTISSEMENT: La variable rds_endpoint n'est pas définie"
    RDS_ENDPOINT="localhost:3306"
else
    RDS_ENDPOINT="${var.rds_endpoint}"
    log "RDS_ENDPOINT défini: $RDS_ENDPOINT"
fi

# Mettre à jour le système
log "Mise à jour du système"
sudo dnf update -y

# Installer les dépendances nécessaires
log "Installation des dépendances"
sudo dnf install -y aws-cli curl jq

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
if [ -z "$S3_BUCKET_NAME" ]; then
    log "AVERTISSEMENT: S3_BUCKET_NAME n'est pas défini, impossible de télécharger les scripts depuis S3"
else
    # Vérifier si le bucket existe
    if aws s3 ls s3://$S3_BUCKET_NAME 2>&1 | grep -q 'NoSuchBucket'; then
        log "AVERTISSEMENT: Le bucket S3 $S3_BUCKET_NAME n'existe pas"
    else
        # Télécharger les scripts
        log "Téléchargement des scripts depuis s3://$S3_BUCKET_NAME/scripts/ec2-java-tomcat/"
        sudo aws s3 cp s3://$S3_BUCKET_NAME/scripts/ec2-java-tomcat/ /opt/yourmedia/ --recursive || log "AVERTISSEMENT: Échec du téléchargement de certains scripts depuis S3"
    fi
fi

# Si les scripts n'ont pas été téléchargés depuis S3, créer des scripts par défaut
if [ ! -f "/opt/yourmedia/install_java_tomcat.sh" ]; then
    log "Le script install_java_tomcat.sh n'a pas été téléchargé depuis S3, création d'un script par défaut"

    # Créer un script d'installation par défaut
    sudo bash -c 'cat > /opt/yourmedia/install_java_tomcat.sh << "EOF"
#!/bin/bash
# Script d'installation par défaut pour Java et Tomcat
set -e

echo "Installation de Java..."
sudo dnf install -y java-17-amazon-corretto-devel

echo "Création de l'utilisateur et groupe Tomcat..."
sudo groupadd tomcat 2>/dev/null || true
sudo useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat 2>/dev/null || true

echo "Téléchargement et installation de Tomcat..."
cd /tmp
wget https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.104/bin/apache-tomcat-9.0.104.tar.gz
sudo mkdir -p /opt/tomcat
sudo tar xzvf apache-tomcat-9.0.104.tar.gz -C /opt/tomcat --strip-components=1

echo "Configuration des permissions..."
sudo chown -R tomcat:tomcat /opt/tomcat
sudo chmod +x /opt/tomcat/bin/*.sh

echo "Création du service Tomcat..."
sudo bash -c "cat > /etc/systemd/system/tomcat.service << EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

Environment=JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto
Environment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat
Environment=\"CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC\"
Environment=\"JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom\"

ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

User=tomcat
Group=tomcat
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF"

echo "Démarrage de Tomcat..."
sudo systemctl daemon-reload
sudo systemctl enable tomcat
sudo systemctl start tomcat

echo "Installation terminée avec succès"
EOF'

    # Rendre le script exécutable
    sudo chmod +x /opt/yourmedia/install_java_tomcat.sh
fi

if [ ! -f "/opt/yourmedia/deploy-war.sh" ]; then
    log "Le script deploy-war.sh n'a pas été téléchargé depuis S3, création d'un script par défaut"

    # Créer un script de déploiement par défaut
    sudo bash -c 'cat > /opt/yourmedia/deploy-war.sh << "EOF"
#!/bin/bash
# Script de déploiement par défaut pour Tomcat
set -e

if [ $# -ne 1 ]; then
  echo "Usage: $0 <chemin_vers_war>"
  exit 1
fi

WAR_PATH=$1
TARGET_NAME="yourmedia-backend.war"

echo "Déploiement du fichier WAR: $WAR_PATH vers /opt/tomcat/webapps/$TARGET_NAME"

# Vérifier si le fichier existe
if [ ! -f "$WAR_PATH" ]; then
  echo "ERREUR: Le fichier $WAR_PATH n'existe pas"
  exit 1
fi

# Copier le fichier WAR dans webapps
cp $WAR_PATH /opt/tomcat/webapps/$TARGET_NAME

# Changer le propriétaire
chown tomcat:tomcat /opt/tomcat/webapps/$TARGET_NAME

# Redémarrer Tomcat
systemctl restart tomcat

echo "Déploiement terminé avec succès"
exit 0
EOF'

    # Rendre le script exécutable
    sudo chmod +x /opt/yourmedia/deploy-war.sh
fi

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

    # Exécuter le script d'installation et capturer la sortie
    log "Démarrage de l'installation de Java et Tomcat..."
    if sudo /opt/yourmedia/install_java_tomcat.sh > /var/log/install_java_tomcat.log 2>&1; then
        log "Installation de Java et Tomcat terminée avec succès"
    else
        log "AVERTISSEMENT: L'installation de Java et Tomcat a échoué. Consultez le fichier /var/log/install_java_tomcat.log pour plus de détails."
        # Ne pas quitter avec une erreur pour permettre à l'initialisation de continuer
    fi
else
    log "ERREUR: Le script install_java_tomcat.sh n'existe pas"
    # Créer un script d'installation minimal
    log "Création d'un script d'installation minimal..."
    sudo bash -c 'cat > /opt/yourmedia/install_java_tomcat.sh << "EOF"
#!/bin/bash
# Script d'installation minimal pour Java et Tomcat
set -e

echo "Installation de Java..."
sudo dnf install -y java-17-amazon-corretto-devel

echo "Installation terminée"
EOF'
    sudo chmod +x /opt/yourmedia/install_java_tomcat.sh
    sudo /opt/yourmedia/install_java_tomcat.sh > /var/log/install_java_tomcat.log 2>&1 || log "AVERTISSEMENT: L'installation minimale a échoué"
fi

# Créer un lien symbolique pour le script deploy-war.sh
log "Création d'un lien symbolique pour le script deploy-war.sh"
if [ -f "/opt/yourmedia/deploy-war.sh" ]; then
    sudo chmod +x /opt/yourmedia/deploy-war.sh
    sudo ln -sf /opt/yourmedia/deploy-war.sh /usr/local/bin/deploy-war.sh
    sudo chmod +x /usr/local/bin/deploy-war.sh

    # Configurer sudoers pour permettre à ec2-user d'exécuter le script sans mot de passe
    sudo bash -c 'echo "ec2-user ALL=(ALL) NOPASSWD: /usr/local/bin/deploy-war.sh" > /etc/sudoers.d/deploy-war'
    sudo chmod 440 /etc/sudoers.d/deploy-war

    log "Script deploy-war.sh configuré avec succès"
else
    log "AVERTISSEMENT: Le script deploy-war.sh n'existe pas, création d'un script minimal..."

    # Créer un script de déploiement minimal
    sudo bash -c 'cat > /opt/yourmedia/deploy-war.sh << "EOF"
#!/bin/bash
# Script de déploiement minimal pour Tomcat
set -e

if [ $# -ne 1 ]; then
  echo "Usage: $0 <chemin_vers_war>"
  exit 1
fi

WAR_PATH=$1
TARGET_NAME="yourmedia-backend.war"

echo "Déploiement du fichier WAR: $WAR_PATH vers /opt/tomcat/webapps/$TARGET_NAME"

# Vérifier si le fichier existe
if [ ! -f "$WAR_PATH" ]; then
  echo "ERREUR: Le fichier $WAR_PATH n'existe pas"
  exit 1
fi

# Vérifier si le répertoire webapps existe
if [ ! -d "/opt/tomcat/webapps" ]; then
  echo "Création du répertoire /opt/tomcat/webapps"
  mkdir -p /opt/tomcat/webapps
fi

# Copier le fichier WAR dans webapps
cp $WAR_PATH /opt/tomcat/webapps/$TARGET_NAME

# Changer le propriétaire si l'utilisateur tomcat existe
if id -u tomcat >/dev/null 2>&1; then
  chown tomcat:tomcat /opt/tomcat/webapps/$TARGET_NAME
fi

# Redémarrer Tomcat si le service existe
if systemctl list-unit-files | grep -q tomcat.service; then
  systemctl restart tomcat
fi

echo "Déploiement terminé avec succès"
exit 0
EOF'

    # Rendre le script exécutable et créer le lien symbolique
    sudo chmod +x /opt/yourmedia/deploy-war.sh
    sudo ln -sf /opt/yourmedia/deploy-war.sh /usr/local/bin/deploy-war.sh
    sudo chmod +x /usr/local/bin/deploy-war.sh

    # Configurer sudoers
    sudo bash -c 'echo "ec2-user ALL=(ALL) NOPASSWD: /usr/local/bin/deploy-war.sh" > /etc/sudoers.d/deploy-war'
    sudo chmod 440 /etc/sudoers.d/deploy-war

    log "Script deploy-war.sh créé et configuré avec succès"
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
