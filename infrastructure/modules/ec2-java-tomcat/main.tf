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

# Définir les variables d'environnement
log "Configuration des variables d'environnement"
export S3_BUCKET_NAME="${var.s3_bucket_name}"
export DB_USERNAME="${var.db_username}"
export DB_PASSWORD="${var.db_password}"
export RDS_ENDPOINT="${var.rds_endpoint}"
export RDS_USERNAME="${var.db_username}"
export RDS_PASSWORD="${var.db_password}"
export TOMCAT_VERSION="9.0.104"
export SSH_PUBLIC_KEY="${var.ssh_public_key}"

# Mettre à jour le système
log "Mise à jour du système"
sudo dnf update -y

# Installer les dépendances nécessaires
log "Installation des dépendances"
sudo dnf install -y aws-cli curl jq wget

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
        sudo mkdir -p /opt/yourmedia
        sudo aws s3 cp s3://$S3_BUCKET_NAME/scripts/ec2-java-tomcat/ /opt/yourmedia/ --recursive || log "AVERTISSEMENT: Échec du téléchargement de certains scripts depuis S3"

        # Rendre les scripts exécutables
        sudo find /opt/yourmedia -name "*.sh" -exec chmod +x {} \;

        # Exécuter le script d'installation
        if [ -f "/opt/yourmedia/setup-java-tomcat.sh" ]; then
            log "Exécution du script setup-java-tomcat.sh..."
            sudo /opt/yourmedia/setup-java-tomcat.sh > /var/log/setup-java-tomcat.log 2>&1
            if [ $? -eq 0 ]; then
                log "Installation terminée avec succès"
            else
                log "AVERTISSEMENT: L'installation a échoué. Consultez le fichier /var/log/setup-java-tomcat.log pour plus de détails."
            fi
        else
            log "AVERTISSEMENT: Le script setup-java-tomcat.sh n'a pas été téléchargé depuis S3"
        fi
    fi
fi

# Si le script setup-java-tomcat.sh n'a pas été téléchargé ou exécuté avec succès, créer un script par défaut
if [ ! -d "/opt/tomcat" ]; then
    log "Le répertoire /opt/tomcat n'existe pas, création d'un script d'installation par défaut"

    # Créer les répertoires nécessaires
    sudo mkdir -p /opt/yourmedia/secure
    sudo chmod 755 /opt/yourmedia
    sudo chmod 700 /opt/yourmedia/secure

    # Créer le fichier de variables d'environnement
    sudo bash -c 'cat > /opt/yourmedia/env.sh << "EOL"'
#!/bin/bash
# Variables d'environnement pour l'application Java Tomcat
# Généré automatiquement par user_data
# Date de génération: $(date)

# Variables EC2
export EC2_INSTANCE_PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
export EC2_INSTANCE_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
export EC2_INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
export EC2_INSTANCE_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

# Variables S3
export S3_BUCKET_NAME="${var.s3_bucket_name}"

# Variables RDS
export RDS_USERNAME="${var.db_username}"
export RDS_ENDPOINT="${var.rds_endpoint}"

# Variables de compatibilité
export DB_USERNAME="${var.db_username}"
export DB_ENDPOINT="${var.rds_endpoint}"

# Variable Tomcat
export TOMCAT_VERSION="9.0.104"

# Charger les variables sensibles
source /opt/yourmedia/secure/sensitive-env.sh 2>/dev/null || true
EOL

    # Créer le fichier de variables sensibles
    sudo bash -c 'cat > /opt/yourmedia/secure/sensitive-env.sh << "EOL"'
#!/bin/bash
# Variables sensibles pour l'application Java Tomcat
# Généré automatiquement par user_data
# Date de génération: $(date)

# Variables RDS
export RDS_PASSWORD="${var.db_password}"

# Variables de compatibilité
export DB_PASSWORD="${var.db_password}"
EOL

    # Définir les permissions
    sudo chmod 755 /opt/yourmedia/env.sh
    sudo chmod 600 /opt/yourmedia/secure/sensitive-env.sh
    sudo chown -R ec2-user:ec2-user /opt/yourmedia

    # Installation de Java
    log "Installation de Java"
    sudo dnf install -y java-17-amazon-corretto-devel

    # Création de l'utilisateur et groupe Tomcat
    log "Création de l'utilisateur et groupe Tomcat"
    sudo groupadd tomcat 2>/dev/null || true
    sudo useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat 2>/dev/null || true

    # Téléchargement et installation de Tomcat
    log "Téléchargement et installation de Tomcat"
    cd /tmp
    wget https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.104/bin/apache-tomcat-9.0.104.tar.gz
    sudo mkdir -p /opt/tomcat
    sudo tar xzvf apache-tomcat-9.0.104.tar.gz -C /opt/tomcat --strip-components=1

    # Configuration des permissions
    sudo chown -R tomcat:tomcat /opt/tomcat
    sudo chmod +x /opt/tomcat/bin/*.sh

    # Création du service Tomcat
    log "Création du service Tomcat"
    sudo bash -c 'cat > /etc/systemd/system/tomcat.service << "EOF"'
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

Environment=JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto
Environment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom"

ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

User=tomcat
Group=tomcat
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Démarrage de Tomcat
    log "Démarrage de Tomcat"
    sudo systemctl daemon-reload
    sudo systemctl enable tomcat
    sudo systemctl start tomcat

    # Création du script de déploiement WAR
    log "Création du script de déploiement WAR"
    sudo bash -c 'cat > /opt/yourmedia/deploy-war.sh << "EOF"'
#!/bin/bash
# Script pour déployer un fichier WAR dans Tomcat
# Ce script doit être exécuté avec sudo

# Vérifier si un argument a été fourni
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
EOF

    # Rendre le script exécutable
    sudo chmod +x /opt/yourmedia/deploy-war.sh

    # Créer un lien symbolique pour le script deploy-war.sh
    log "Création d'un lien symbolique pour le script deploy-war.sh"
    sudo ln -sf /opt/yourmedia/deploy-war.sh /usr/local/bin/deploy-war.sh
    sudo chmod +x /usr/local/bin/deploy-war.sh

    # Configurer sudoers pour permettre à ec2-user d'exécuter le script sans mot de passe
    sudo bash -c 'echo "ec2-user ALL=(ALL) NOPASSWD: /usr/local/bin/deploy-war.sh" > /etc/sudoers.d/deploy-war'
    sudo chmod 440 /etc/sudoers.d/deploy-war
fi

# Configurer la clé SSH
log "Configuration de la clé SSH"
sudo mkdir -p /home/ec2-user/.ssh
echo "${var.ssh_public_key}" | sudo tee -a /home/ec2-user/.ssh/authorized_keys > /dev/null
sudo chmod 700 /home/ec2-user/.ssh
sudo chmod 600 /home/ec2-user/.ssh/authorized_keys
sudo chown -R ec2-user:ec2-user /home/ec2-user/.ssh

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
