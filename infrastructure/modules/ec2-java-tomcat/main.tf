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

# Rediriger stdout et stderr vers un fichier log
exec > >(tee /var/log/user-data-init.log) 2>&1

echo "$(date '+%Y-%m-%d %H:%M:%S') - Démarrage du script d'initialisation"

# Mettre à jour le système
echo "$(date '+%Y-%m-%d %H:%M:%S') - Mise à jour du système"
sudo dnf update -y

# Installer les dépendances nécessaires
echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation des dépendances"
# Installer jq et wget
sudo dnf install -y jq wget

# Vérifier si aws-cli est installé
echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation d'AWS CLI"
if ! command -v aws &> /dev/null; then
    sudo dnf install -y aws-cli || {
        echo "Installation d'AWS CLI via le package aws-cli a échoué, tentative avec awscli..."
        sudo dnf install -y awscli
    }
else
    echo "AWS CLI est déjà installé, version: $(aws --version)"
fi

# Gérer l'installation de curl séparément pour éviter les conflits avec curl-minimal
echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation de curl"
if ! command -v curl &> /dev/null; then
    # Si curl n'est pas installé, l'installer avec --allowerasing pour résoudre les conflits
    sudo dnf install -y --allowerasing curl
else
    echo "curl est déjà installé, version: $(curl --version | head -n 1)"
fi

# S'assurer que netstat est installé
echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation de net-tools"
if ! command -v netstat &> /dev/null; then
    sudo dnf install -y net-tools
else
    echo "net-tools est déjà installé"
fi

# Configurer la clé SSH
echo "$(date '+%Y-%m-%d %H:%M:%S') - Configuration de la clé SSH"
sudo mkdir -p /home/ec2-user/.ssh
echo "${var.ssh_public_key}" | sudo tee -a /home/ec2-user/.ssh/authorized_keys > /dev/null
sudo chmod 700 /home/ec2-user/.ssh
sudo chmod 600 /home/ec2-user/.ssh/authorized_keys
sudo chown -R ec2-user:ec2-user /home/ec2-user/.ssh

# Définir les variables d'environnement
export S3_BUCKET_NAME="${var.s3_bucket_name}"
export DB_USERNAME="${var.db_username}"
export DB_PASSWORD="${var.db_password}"
export RDS_ENDPOINT="${var.rds_endpoint}"
export RDS_USERNAME="${var.db_username}"
export RDS_PASSWORD="${var.db_password}"
export TOMCAT_VERSION="9.0.104"

# Télécharger et exécuter le script d'installation depuis S3
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement des scripts depuis S3"
sudo mkdir -p /opt/yourmedia
sudo aws s3 cp s3://${var.s3_bucket_name}/scripts/ec2-java-tomcat/setup-java-tomcat.sh /opt/yourmedia/ || echo "Échec du téléchargement du script setup-java-tomcat.sh"

if [ -f "/opt/yourmedia/setup-java-tomcat.sh" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Exécution du script setup-java-tomcat.sh"
    sudo chmod +x /opt/yourmedia/setup-java-tomcat.sh
    sudo /opt/yourmedia/setup-java-tomcat.sh
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation manuelle de Java et Tomcat"
    # Installation de Java
    sudo dnf install -y java-17-amazon-corretto-devel

    # Création de l'utilisateur et groupe Tomcat
    sudo groupadd tomcat 2>/dev/null || true
    sudo useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat 2>/dev/null || true

    # Téléchargement et installation de Tomcat
    cd /tmp
    sudo wget https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.104/bin/apache-tomcat-9.0.104.tar.gz
    sudo mkdir -p /opt/tomcat
    sudo tar xzvf apache-tomcat-9.0.104.tar.gz -C /opt/tomcat --strip-components=1

    # Configuration des permissions
    sudo chown -R tomcat:tomcat /opt/tomcat
    sudo chmod +x /opt/tomcat/bin/*.sh

    # Création du service Tomcat
    sudo cat > /etc/systemd/system/tomcat.service << "EOL"
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
EOL

    # Démarrage de Tomcat
    sudo systemctl daemon-reload
    sudo systemctl enable tomcat
    sudo systemctl start tomcat
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Initialisation terminée avec succès"
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
