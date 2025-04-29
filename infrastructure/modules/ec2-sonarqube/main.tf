# -----------------------------------------------------------------------------
# Module EC2 SonarQube
# -----------------------------------------------------------------------------
# Ce module crée une instance EC2 dédiée pour SonarQube
# Il installe et configure SonarQube directement sur l'instance (sans Docker)
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Ressources
# -----------------------------------------------------------------------------

# Groupe de sécurité pour l'instance EC2 de SonarQube (créé uniquement si use_existing_sg = false)
resource "aws_security_group" "sonarqube_sg" {
  count       = var.use_existing_sg ? 0 : 1
  name        = "${var.project_name}-${var.environment}-sonarqube-sg"
  description = "Security group for SonarQube instance"
  vpc_id      = var.vpc_id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "SSH access"
  }

  # SonarQube
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "SonarQube access"
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
    Name        = "${var.project_name}-${var.environment}-sonarqube-sg"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ID du groupe de sécurité à utiliser (existant ou nouveau)
locals {
  sonarqube_sg_id = var.use_existing_sg ? var.sonarqube_security_group_id : aws_security_group.sonarqube_sg[0].id
}

# Rôle IAM pour l'instance EC2 de SonarQube
resource "aws_iam_role" "sonarqube_role" {
  name = "${var.project_name}-${var.environment}-sonarqube-role"

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
    Name        = "${var.project_name}-${var.environment}-sonarqube-role"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Politique IAM pour l'instance EC2 de SonarQube
resource "aws_iam_policy" "sonarqube_policy" {
  name        = "${var.project_name}-${var.environment}-sonarqube-policy"
  description = "Policy for SonarQube instance"

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
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
        ]
        Effect = "Allow"
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/ec2/*"
      },
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-sonarqube-policy"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # Faciliter la suppression et recréation de la politique
  lifecycle {
    create_before_destroy = true
  }
}

# Attachement de la politique au rôle IAM
resource "aws_iam_role_policy_attachment" "sonarqube_policy_attachment" {
  role       = aws_iam_role.sonarqube_role.name
  policy_arn = aws_iam_policy.sonarqube_policy.arn
}

# Profil d'instance pour l'instance EC2 de SonarQube
resource "aws_iam_instance_profile" "sonarqube_profile" {
  name = "${var.project_name}-${var.environment}-sonarqube-profile"
  role = aws_iam_role.sonarqube_role.name

  tags = {
    Name        = "${var.project_name}-${var.environment}-sonarqube-profile"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Instance EC2 pour SonarQube
resource "aws_instance" "sonarqube_instance" {
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [local.sonarqube_sg_id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.sonarqube_profile.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  user_data = <<-EOF
#!/bin/bash
set -e

# Rediriger stdout et stderr vers un fichier log
exec > >(tee /var/log/user-data-init.log) 2>&1

echo "$(date '+%Y-%m-%d %H:%M:%S') - Démarrage du script d'initialisation de SonarQube"

# Mettre à jour le système
echo "$(date '+%Y-%m-%d %H:%M:%S') - Mise à jour du système"
sudo dnf update -y

# Installer les dépendances nécessaires
echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation des dépendances"
sudo dnf install -y jq wget unzip java-17-amazon-corretto-devel postgresql15 postgresql15-server

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

# Configurer la clé SSH
echo "$(date '+%Y-%m-%d %H:%M:%S') - Configuration de la clé SSH"
sudo mkdir -p /home/ec2-user/.ssh
echo "${var.ssh_public_key}" | sudo tee -a /home/ec2-user/.ssh/authorized_keys > /dev/null
sudo chmod 700 /home/ec2-user/.ssh
sudo chmod 600 /home/ec2-user/.ssh/authorized_keys
sudo chown -R ec2-user:ec2-user /home/ec2-user/.ssh

# Définir les variables d'environnement
export S3_BUCKET_NAME="${var.s3_bucket_name}"
export SONAR_ADMIN_PASSWORD="${var.sonar_admin_password}"
export DB_USERNAME="${var.db_username}"
export DB_PASSWORD="${var.db_password}"

# Télécharger et exécuter le script d'installation depuis S3
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement des scripts depuis S3"
sudo mkdir -p /opt/sonarqube
sudo aws s3 cp s3://${var.s3_bucket_name}/scripts/ec2-sonarqube/setup-sonarqube.sh /opt/sonarqube/ || echo "Échec du téléchargement du script setup-sonarqube.sh"

if [ -f "/opt/sonarqube/setup-sonarqube.sh" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Exécution du script setup-sonarqube.sh"
    sudo chmod +x /opt/sonarqube/setup-sonarqube.sh
    sudo /opt/sonarqube/setup-sonarqube.sh
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation manuelle de SonarQube"
    
    # Configurer les paramètres système pour SonarQube
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Configuration des paramètres système"
    sudo bash -c 'cat > /etc/sysctl.d/99-sonarqube.conf << EOF
vm.max_map_count=262144
fs.file-max=65536
EOF'
    sudo sysctl --system

    # Configurer les limites de ressources pour l'utilisateur sonarqube
    sudo bash -c 'cat > /etc/security/limits.d/99-sonarqube.conf << EOF
sonarqube   -   nofile   65536
sonarqube   -   nproc    4096
EOF'

    # Initialiser PostgreSQL
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Initialisation de PostgreSQL"
    sudo postgresql-setup --initdb
    
    # Configurer PostgreSQL pour accepter les connexions locales
    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/g" /var/lib/pgsql/data/postgresql.conf
    sudo sed -i "s/ident/md5/g" /var/lib/pgsql/data/pg_hba.conf
    
    # Démarrer PostgreSQL
    sudo systemctl enable postgresql
    sudo systemctl start postgresql
    
    # Créer l'utilisateur et la base de données SonarQube
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Création de l'utilisateur et de la base de données SonarQube"
    sudo -u postgres psql -c "CREATE USER ${var.db_username} WITH ENCRYPTED PASSWORD '${var.db_password}';"
    sudo -u postgres psql -c "CREATE DATABASE sonar OWNER ${var.db_username};"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sonar TO ${var.db_username};"
    
    # Créer l'utilisateur sonarqube
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Création de l'utilisateur sonarqube"
    sudo useradd -m -d /opt/sonarqube -s /bin/bash sonarqube
    
    # Télécharger et installer SonarQube
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement et installation de SonarQube"
    cd /tmp
    wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.1.69595.zip
    sudo unzip sonarqube-9.9.1.69595.zip -d /opt
    sudo mv /opt/sonarqube-9.9.1.69595/* /opt/sonarqube/
    sudo rmdir /opt/sonarqube-9.9.1.69595
    sudo chown -R sonarqube:sonarqube /opt/sonarqube
    
    # Configurer SonarQube
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Configuration de SonarQube"
    sudo bash -c "cat > /opt/sonarqube/conf/sonar.properties << EOF
sonar.jdbc.username=${var.db_username}
sonar.jdbc.password=${var.db_password}
sonar.jdbc.url=jdbc:postgresql://localhost/sonar
sonar.web.javaOpts=-Xmx512m -Xms256m
sonar.ce.javaOpts=-Xmx512m -Xms256m
sonar.search.javaOpts=-Xmx512m -Xms256m
EOF"
    
    # Créer le service systemd pour SonarQube
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Création du service systemd pour SonarQube"
    sudo bash -c 'cat > /etc/systemd/system/sonarqube.service << EOF
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonarqube
Group=sonarqube
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF'
    
    # Recharger systemd et démarrer SonarQube
    sudo systemctl daemon-reload
    sudo systemctl enable sonarqube
    sudo systemctl start sonarqube
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Initialisation terminée avec succès"
echo "SonarQube est accessible à l'adresse http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000"
EOF

  tags = {
    Name        = "${var.project_name}-${var.environment}-sonarqube-instance"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Role        = "SonarQube"
  }

  # Protéger l'instance contre la suppression accidentelle
  lifecycle {
    prevent_destroy = false # Mettre à true en production
    ignore_changes  = [ami] # Ignorer les changements d'AMI pour éviter les recréations inutiles
  }
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

# Récupération de l'AMI Amazon Linux 2023 la plus récente
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
