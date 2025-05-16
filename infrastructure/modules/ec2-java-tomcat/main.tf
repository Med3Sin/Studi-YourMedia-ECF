# -----------------------------------------------------------------------------
# IAM Role et Politique pour l'instance EC2
# -----------------------------------------------------------------------------

# Politique IAM pour l'instance EC2 (avec permissions S3 pour accéder aux fichiers)
data "aws_iam_policy_document" "ec2_policy_doc" {
  # Permission pour décrire les tags EC2 (nécessite "*" comme ressource)
  statement {
    actions = [
      "ec2:DescribeTags"
    ]
    resources = [
      "*"
    ]
  }

  # Permissions pour accéder aux objets dans S3
  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::*",
      "arn:aws:s3:::*/*"
    ]
  }
}

resource "aws_iam_policy" "ec2_policy" {
  name        = "${var.project_name}-${var.environment}-ec2-policy-v2"
  description = "Politique simplifiée pour l'EC2 Java Tomcat (Hello World)"
  policy      = data.aws_iam_policy_document.ec2_policy_doc.json

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-policy"
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

# Attacher la politique au rôle EC2
resource "aws_iam_role_policy_attachment" "ec2_policy_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_policy.arn
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
sudo dnf install -y jq wget aws-cli java-17-amazon-corretto-devel net-tools

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

# Créer les répertoires nécessaires
echo "$(date '+%Y-%m-%d %H:%M:%S') - Création des répertoires nécessaires"
sudo mkdir -p /opt/yourmedia/secure
sudo mkdir -p /opt/tomcat
sudo chmod 755 /opt/yourmedia
sudo chmod 700 /opt/yourmedia/secure

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

# Création du fichier de service Tomcat
echo "$(date '+%Y-%m-%d %H:%M:%S') - Création du fichier de service Tomcat..."
# Trouver le chemin correct de Java
JAVA_HOME_PATH=$(find /usr/lib/jvm -name "java-17-amazon-corretto*" -type d | head -n 1)
if [ -z "$JAVA_HOME_PATH" ]; then
    JAVA_HOME_PATH="/usr/lib/jvm/java-17-amazon-corretto.x86_64"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Chemin Java non trouvé, utilisation de la valeur par défaut: $JAVA_HOME_PATH"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Chemin Java trouvé: $JAVA_HOME_PATH"
fi

sudo bash -c "cat > /etc/systemd/system/tomcat.service << EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

Environment=JAVA_HOME=$JAVA_HOME_PATH
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

# Télécharger le script de déploiement WAR depuis GitHub
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement du script de déploiement WAR depuis GitHub"
sudo mkdir -p /opt/yourmedia
sudo wget -q -O /opt/yourmedia/deploy-war.sh "$GITHUB_RAW_URL/scripts/ec2-java-tomcat/deploy-war.sh"

# Vérifier si le téléchargement a réussi
if [ ! -s /opt/yourmedia/deploy-war.sh ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERREUR: Le téléchargement du script deploy-war.sh a échoué. Création d'une version simplifiée..."

  # Créer une version simplifiée du script de déploiement WAR
  sudo bash -c 'cat > /opt/yourmedia/deploy-war.sh << EOF
#!/bin/bash
#==============================================================================
# Nom du script : deploy-war.sh
# Description   : Script pour déployer un fichier WAR dans Tomcat.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2023-05-04
#==============================================================================

# Vérifier si un argument a été fourni
if [ \$# -ne 1 ]; then
  echo "Usage: \$0 <chemin_vers_war>"
  exit 1
fi

WAR_PATH=\$1
WAR_NAME=\$(basename \$WAR_PATH)
APP_NAME=\$(echo \$WAR_NAME | sed 's/\.war$//')

echo "Déploiement du fichier WAR: \$WAR_PATH vers /opt/tomcat/webapps/\$WAR_NAME"

# Vérifier si le fichier existe
if [ ! -f "\$WAR_PATH" ]; then
  echo "Le fichier \$WAR_PATH n'\''existe pas"
  exit 1
fi

# Copier le fichier WAR dans webapps
sudo cp \$WAR_PATH /opt/tomcat/webapps/\$WAR_NAME
sudo chown tomcat:tomcat /opt/tomcat/webapps/\$WAR_NAME

# Redémarrer Tomcat
sudo systemctl restart tomcat
sleep 10

echo "Déploiement terminé avec succès"
echo "L'\''application est accessible à l'\''adresse: http://\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080/\$APP_NAME/"
exit 0
EOF'
fi

# S'assurer que le script est exécutable
echo "$(date '+%Y-%m-%d %H:%M:%S') - Attribution des permissions d'exécution au script"
sudo chmod +x /opt/yourmedia/deploy-war.sh

# Créer l'utilisateur et groupe Tomcat
echo "$(date '+%Y-%m-%d %H:%M:%S') - Création de l'utilisateur et groupe Tomcat"
sudo groupadd tomcat 2>/dev/null || true
sudo useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat 2>/dev/null || true

# Télécharger et installer Tomcat
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement et installation de Tomcat"
TOMCAT_VERSION=9.0.104
cd /tmp
sudo wget -q https://dlcdn.apache.org/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz

# Vérifier si le téléchargement a réussi
if [ ! -s /tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERREUR: Le téléchargement de Tomcat a échoué. Tentative avec une URL alternative..."
  sudo wget -q https://archive.apache.org/dist/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz
fi

# Extraire Tomcat
echo "$(date '+%Y-%m-%d %H:%M:%S') - Extraction de Tomcat"
sudo tar xzf apache-tomcat-$TOMCAT_VERSION.tar.gz -C /opt/tomcat --strip-components=1

# Créer les répertoires nécessaires s'ils n'existent pas
echo "$(date '+%Y-%m-%d %H:%M:%S') - Création des répertoires nécessaires"
sudo mkdir -p /opt/tomcat/temp
sudo mkdir -p /opt/tomcat/logs
sudo mkdir -p /opt/tomcat/webapps

# Configuration des permissions
echo "$(date '+%Y-%m-%d %H:%M:%S') - Configuration des permissions"
sudo chown -R tomcat:tomcat /opt/tomcat
sudo chmod +x /opt/tomcat/bin/*.sh
sudo chmod -R 755 /opt/tomcat/webapps
sudo chmod -R 755 /opt/tomcat/logs
sudo chmod -R 755 /opt/tomcat/temp

# Recharger systemd et démarrer Tomcat
echo "$(date '+%Y-%m-%d %H:%M:%S') - Démarrage de Tomcat"
sudo systemctl daemon-reload
sudo systemctl start tomcat
sudo systemctl enable tomcat

# Vérifier si Tomcat est en cours d'exécution
echo "$(date '+%Y-%m-%d %H:%M:%S') - Vérification de l'état de Tomcat"
sleep 10
if sudo systemctl is-active --quiet tomcat; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Tomcat est en cours d'exécution"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ Tomcat n'est pas en cours d'exécution. Vérification des journaux..."
    sudo journalctl -u tomcat --no-pager -n 50

    # Vérifier le fichier de service Tomcat
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Vérification du fichier de service Tomcat"
    if [ -f "/etc/systemd/system/tomcat.service" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Le fichier de service Tomcat existe"

        # Vérifier les permissions des scripts Tomcat
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Vérification des permissions des scripts Tomcat"
        sudo chmod +x /opt/tomcat/bin/*.sh

        # Vérifier si le répertoire temp existe
        if [ ! -d "/opt/tomcat/temp" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Le répertoire temp n'existe pas. Création..."
            sudo mkdir -p /opt/tomcat/temp
            sudo chown tomcat:tomcat /opt/tomcat/temp
        fi

        # Redémarrer Tomcat
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Redémarrage de Tomcat"
        sudo systemctl daemon-reload
        sudo systemctl restart tomcat
        sleep 10

        if sudo systemctl is-active --quiet tomcat; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Tomcat a été démarré avec succès"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ Échec du démarrage de Tomcat"
        fi
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ Le fichier de service Tomcat n'existe pas"
    fi
fi

# Vérifier si le port 8080 est ouvert
echo "$(date '+%Y-%m-%d %H:%M:%S') - Vérification du port 8080"
if sudo netstat -tuln | grep -q ":8080"; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Le port 8080 est ouvert"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ Le port 8080 n'est pas ouvert. Redémarrage de Tomcat..."
    sudo systemctl restart tomcat
    sleep 10
    if sudo netstat -tuln | grep -q ":8080"; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Le port 8080 est maintenant ouvert"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ Le port 8080 n'est toujours pas ouvert"
    fi
fi

# Créer un lien symbolique pour le script de déploiement
echo "$(date '+%Y-%m-%d %H:%M:%S') - Création d'un lien symbolique pour le script de déploiement"
sudo ln -sf /opt/yourmedia/deploy-war.sh /usr/local/bin/deploy-war.sh
sudo chmod +x /usr/local/bin/deploy-war.sh

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
