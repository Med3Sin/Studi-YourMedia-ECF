# -----------------------------------------------------------------------------
# IAM Role pour l'instance EC2 de monitoring
# -----------------------------------------------------------------------------

# Rôle IAM pour l'instance EC2 de monitoring
resource "aws_iam_role" "monitoring_role" {
  name                  = "${var.project_name}-${var.environment}-monitoring-role-v2"
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
    Name        = "${var.project_name}-${var.environment}-monitoring-role"
    Project     = var.project_name
    Environment = var.environment
  }

  # Faciliter la suppression et recréation du rôle
  lifecycle {
    create_before_destroy = true
  }
}

# Politique pour accéder aux services AWS nécessaires
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  role       = aws_iam_role.monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Attacher la politique d'accès au bucket S3 de configuration
resource "aws_iam_role_policy_attachment" "s3_config_access" {
  role       = aws_iam_role.monitoring_role.name
  policy_arn = var.s3_config_policy_arn
}

# Profil d'instance pour attacher le rôle IAM à l'instance EC2
resource "aws_iam_instance_profile" "monitoring_profile" {
  name = "${var.project_name}-${var.environment}-monitoring-profile"
  role = aws_iam_role.monitoring_role.name

  # Éviter les erreurs de conflit si le profil existe déjà
  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Instance EC2 pour Grafana et Prometheus
# -----------------------------------------------------------------------------

# Récupération automatique de l'AMI Amazon Linux 2 la plus récente
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
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

# Instance EC2 pour le monitoring
resource "aws_instance" "monitoring_instance" {
  ami                    = var.use_latest_ami ? data.aws_ami.amazon_linux_2.id : var.monitoring_ami_id
  instance_type          = "t2.micro"
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [var.monitoring_security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.monitoring_profile.name
  key_name               = var.key_pair_name

  # Script d'initialisation minimal qui télécharge et exécute le script principal depuis S3
  user_data = <<-EOF
    #!/bin/bash
    # Mise à jour du système et installation de l'AWS CLI
    sudo yum update -y
    sudo yum install -y aws-cli

    # Configuration des clés SSH
    echo "--- Configuration des clés SSH ---"
    mkdir -p /home/ec2-user/.ssh
    chmod 700 /home/ec2-user/.ssh
    touch /home/ec2-user/.ssh/authorized_keys
    chmod 600 /home/ec2-user/.ssh/authorized_keys

    # Fonction pour corriger les clés SSH
    fix_ssh_keys() {
      echo "Vérification et correction des clés SSH..."

      # Vérifier si le fichier authorized_keys existe
      if [ ! -f /home/ec2-user/.ssh/authorized_keys ]; then
        echo "Le fichier authorized_keys n'existe pas. Rien à faire."
        return
      fi

      # Sauvegarder le fichier original
      cp /home/ec2-user/.ssh/authorized_keys /home/ec2-user/.ssh/authorized_keys.bak

      # Supprimer les guillemets simples dans le fichier authorized_keys
      sed "s/'//g" /home/ec2-user/.ssh/authorized_keys.bak > /home/ec2-user/.ssh/authorized_keys.tmp

      # Vérifier le format des clés SSH
      > /home/ec2-user/.ssh/authorized_keys.new
      while IFS= read -r line; do
        # Ignorer les lignes vides ou commentées
        if [[ -z "$line" || "$line" == \#* ]]; then
          echo "$line" >> /home/ec2-user/.ssh/authorized_keys.new
          continue
        fi

        # Vérifier si la ligne commence par ssh-rsa, ssh-ed25519, etc.
        if [[ "$line" =~ ^(ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ]]; then
          echo "$line" >> /home/ec2-user/.ssh/authorized_keys.new
        else
          # Si la ligne ne commence pas par un type de clé SSH valide,
          # vérifier si elle contient un type de clé SSH valide
          if [[ "$line" =~ (ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ]]; then
            # Extraire la partie qui commence par le type de clé SSH
            key_part=$(echo "$line" | grep -o "ssh-[^ ]*.*")
            echo "$key_part" >> /home/ec2-user/.ssh/authorized_keys.new
          else
            # Si la ligne ne contient pas de type de clé SSH valide, l'ignorer
            echo "Ligne ignorée (format non reconnu): $line"
          fi
        fi
      done < /home/ec2-user/.ssh/authorized_keys.tmp

      # Remplacer le fichier authorized_keys
      mv /home/ec2-user/.ssh/authorized_keys.new /home/ec2-user/.ssh/authorized_keys

      # Ajuster les permissions
      chmod 600 /home/ec2-user/.ssh/authorized_keys

      # Supprimer les fichiers temporaires
      rm -f /home/ec2-user/.ssh/authorized_keys.tmp

      echo "Correction des clés SSH terminée."
    }

    # Ajouter la clé SSH publique fournie par Terraform
    SSH_PUBLIC_KEY="${var.ssh_public_key}"
    if [ ! -z "$SSH_PUBLIC_KEY" ]; then
      # Supprimer les guillemets simples qui pourraient être présents dans la clé
      CLEAN_KEY=$(echo "$SSH_PUBLIC_KEY" | sed "s/'//g")
      echo "$CLEAN_KEY" >> /home/ec2-user/.ssh/authorized_keys
      echo "Clé SSH publique GitHub installée avec succès"

      # Corriger les clés SSH
      fix_ssh_keys
    fi

    # Créer un service systemd pour vérifier périodiquement les clés SSH
    cat > /tmp/fix-ssh-keys.sh << 'EOF'
#!/bin/bash
# Script pour vérifier et corriger les clés SSH dans le fichier authorized_keys

# Fonction pour corriger les clés SSH
fix_ssh_keys() {
  echo "Vérification et correction des clés SSH..."

  # Vérifier si le fichier authorized_keys existe
  if [ ! -f ~/.ssh/authorized_keys ]; then
    echo "Le fichier authorized_keys n'existe pas. Rien à faire."
    return
  fi

  # Sauvegarder le fichier original
  cp ~/.ssh/authorized_keys ~/.ssh/authorized_keys.bak

  # Supprimer les guillemets simples dans le fichier authorized_keys
  sed "s/'//g" ~/.ssh/authorized_keys.bak > ~/.ssh/authorized_keys.tmp

  # Vérifier le format des clés SSH
  > ~/.ssh/authorized_keys.new
  while IFS= read -r line; do
    # Ignorer les lignes vides ou commentées
    if [[ -z "$line" || "$line" == \#* ]]; then
      echo "$line" >> ~/.ssh/authorized_keys.new
      continue
    fi

    # Vérifier si la ligne commence par ssh-rsa, ssh-ed25519, etc.
    if [[ "$line" =~ ^(ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ]]; then
      echo "$line" >> ~/.ssh/authorized_keys.new
    else
      # Si la ligne ne commence pas par un type de clé SSH valide,
      # vérifier si elle contient un type de clé SSH valide
      if [[ "$line" =~ (ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ]]; then
        # Extraire la partie qui commence par le type de clé SSH
        key_part=$(echo "$line" | grep -o "ssh-[^ ]*.*")
        echo "$key_part" >> ~/.ssh/authorized_keys.new
      else
        # Si la ligne ne contient pas de type de clé SSH valide, l'ignorer
        echo "Ligne ignorée (format non reconnu): $line"
      fi
    fi
  done < ~/.ssh/authorized_keys.tmp

  # Remplacer le fichier authorized_keys
  mv ~/.ssh/authorized_keys.new ~/.ssh/authorized_keys

  # Ajuster les permissions
  chmod 600 ~/.ssh/authorized_keys

  # Supprimer les fichiers temporaires
  rm -f ~/.ssh/authorized_keys.tmp

  echo "Correction des clés SSH terminée."
}

# Exécuter la fonction de correction
fix_ssh_keys
EOF

    chmod +x /tmp/fix-ssh-keys.sh
    cp /tmp/fix-ssh-keys.sh /usr/local/bin/fix-ssh-keys.sh

    # Créer un service systemd pour exécuter le script périodiquement
    cat > /etc/systemd/system/ssh-key-checker.service << 'EOFSERVICE'
[Unit]
Description=SSH Key Format Checker
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/fix-ssh-keys.sh
User=ec2-user
Group=ec2-user
EOFSERVICE

    cat > /etc/systemd/system/ssh-key-checker.timer << 'EOFTIMER'
[Unit]
Description=Run SSH Key Format Checker periodically

[Timer]
OnBootSec=5min
OnUnitActiveSec=1h
RandomizedDelaySec=5min

[Install]
WantedBy=timers.target
EOFTIMER

    # Activer et démarrer le timer
    systemctl daemon-reload
    systemctl enable ssh-key-checker.timer
    systemctl start ssh-key-checker.timer

    # Récupérer également la clé publique depuis les métadonnées de l'instance (si disponible)
    PUBLIC_KEY=$(curl -s http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key 2>/dev/null || echo "")
    if [ ! -z "$PUBLIC_KEY" ]; then
      echo "$PUBLIC_KEY" >> /home/ec2-user/.ssh/authorized_keys
      echo "Clé SSH publique AWS installée avec succès"
    fi

    # Ajuster les permissions
    chown -R ec2-user:ec2-user /home/ec2-user/.ssh

    # Créer le répertoire de monitoring
    mkdir -p /opt/monitoring

    # Télécharger le script principal depuis S3
    aws s3 cp s3://${var.s3_bucket_name}/monitoring/setup.sh /opt/monitoring/setup.sh

    # Remplacer les variables dans le script
    # Utiliser des guillemets simples pour éviter l'interprétation des variables shell
    # Remplacer les placeholders par les valeurs réelles
    sed -i 's/PLACEHOLDER_IP/${var.ec2_instance_private_ip}/g' /opt/monitoring/setup.sh
    # Remplacer également la variable ec2_java_tomcat_ip pour prometheus.yml
    sed -i 's/ec2_java_tomcat_ip = "PLACEHOLDER_IP"/ec2_java_tomcat_ip = "${var.ec2_instance_private_ip}"/g' /opt/monitoring/setup.sh
    sed -i 's/PLACEHOLDER_USERNAME/${var.db_username}/g' /opt/monitoring/setup.sh
    sed -i 's/PLACEHOLDER_PASSWORD/${var.db_password}/g' /opt/monitoring/setup.sh
    sed -i 's/PLACEHOLDER_ENDPOINT/${var.rds_endpoint}/g' /opt/monitoring/setup.sh

    # Ajouter les variables pour SonarQube
    sed -i 's/SONAR_JDBC_USERNAME/${var.sonar_jdbc_username}/g' /opt/monitoring/setup.sh
    sed -i 's/SONAR_JDBC_PASSWORD/${var.sonar_jdbc_password}/g' /opt/monitoring/setup.sh
    sed -i 's|SONAR_JDBC_URL|${var.sonar_jdbc_url}|g' /opt/monitoring/setup.sh

    # Ajouter la variable pour le mot de passe administrateur Grafana
    sed -i 's/GRAFANA_ADMIN_PASSWORD/${var.grafana_admin_password}/g' /opt/monitoring/setup.sh

    # Installation du script de correction des clés SSH
    cat > /tmp/fix_ssh_keys.sh << 'EOFFIX'
#!/bin/bash
# Script pour vérifier et corriger les clés SSH dans le fichier authorized_keys
# Ce script supprime les guillemets simples qui entourent les clés SSH

# Fonction pour corriger les clés SSH
fix_ssh_keys() {
    echo "[INFO] Vérification et correction des clés SSH..."

    # Vérifier si le fichier authorized_keys existe
    if [ ! -f ~/.ssh/authorized_keys ]; then
        echo "[WARN] Le fichier authorized_keys n'existe pas. Rien à faire."
        return
    fi

    # Sauvegarder le fichier original
    cp ~/.ssh/authorized_keys ~/.ssh/authorized_keys.bak

    # Supprimer les guillemets simples dans le fichier authorized_keys
    sed "s/'//g" ~/.ssh/authorized_keys.bak > ~/.ssh/authorized_keys.tmp

    # Vérifier le format des clés SSH
    > ~/.ssh/authorized_keys.new
    while IFS= read -r line; do
        # Ignorer les lignes vides ou commentées
        if [[ -z "$line" || "$line" == \#* ]]; then
            echo "$line" >> ~/.ssh/authorized_keys.new
            continue
        fi

        # Vérifier si la ligne commence par ssh-rsa, ssh-ed25519, etc.
        if [[ "$line" =~ ^(ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ]]; then
            echo "$line" >> ~/.ssh/authorized_keys.new
        else
            # Si la ligne ne commence pas par un type de clé SSH valide,
            # vérifier si elle contient un type de clé SSH valide
            if [[ "$line" =~ (ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ]]; then
                # Extraire la partie qui commence par le type de clé SSH
                key_part=$(echo "$line" | grep -o "ssh-[^ ]*.*")
                echo "$key_part" >> ~/.ssh/authorized_keys.new
            else
                # Si la ligne ne contient pas de type de clé SSH valide, l'ignorer
                echo "[WARN] Ligne ignorée (format non reconnu): $line"
            fi
        fi
    done < ~/.ssh/authorized_keys.tmp

    # Remplacer le fichier authorized_keys
    mv ~/.ssh/authorized_keys.new ~/.ssh/authorized_keys

    # Ajuster les permissions
    chmod 600 ~/.ssh/authorized_keys

    # Supprimer les fichiers temporaires
    rm -f ~/.ssh/authorized_keys.tmp

    echo "[INFO] Correction des clés SSH terminée."
}

# Exécuter la fonction de correction
fix_ssh_keys
EOFFIX

    # Rendre le script exécutable
    chmod +x /tmp/fix_ssh_keys.sh

    # Exécuter le script en tant qu'utilisateur ec2-user
    su - ec2-user -c "/tmp/fix_ssh_keys.sh"

    # Copier le script dans /usr/local/bin pour une utilisation future
    cp /tmp/fix_ssh_keys.sh /usr/local/bin/
    chmod +x /usr/local/bin/fix_ssh_keys.sh

    # Créer un service systemd pour exécuter le script périodiquement
    cat > /etc/systemd/system/ssh-key-checker.service << 'EOFSERVICE'
[Unit]
Description=SSH Key Format Checker
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/fix_ssh_keys.sh
User=ec2-user
Group=ec2-user
EOFSERVICE

    cat > /etc/systemd/system/ssh-key-checker.timer << 'EOFTIMER'
[Unit]
Description=Run SSH Key Format Checker periodically

[Timer]
OnBootSec=5min
OnUnitActiveSec=1h
RandomizedDelaySec=5min

[Install]
WantedBy=timers.target
EOFTIMER

    # Activer et démarrer le timer
    systemctl daemon-reload
    systemctl enable ssh-key-checker.timer
    systemctl start ssh-key-checker.timer

    # Rendre le script d'installation exécutable et l'exécuter
    chmod +x /opt/monitoring/setup.sh
    /opt/monitoring/setup.sh
  EOF

  tags = {
    Name        = "${var.project_name}-${var.environment}-monitoring-instance"
    Project     = var.project_name
    Environment = var.environment
  }
}

# -----------------------------------------------------------------------------
# Provisionnement des fichiers de configuration
# -----------------------------------------------------------------------------

# Copie des fichiers de configuration sur l'instance EC2
# Note: Le provisionnement est désactivé par défaut pour éviter les erreurs dans les environnements CI/CD
# Pour activer le provisionnement, définissez la variable enable_provisioning à true et fournissez une clé SSH valide
resource "null_resource" "provision_monitoring" {
  # Ne créer cette ressource que si le provisionnement est activé
  count = var.enable_provisioning ? 1 : 0

  # Déclencher uniquement lorsque l'instance est créée ou modifiée
  triggers = {
    instance_id = aws_instance.monitoring_instance.id
  }

  # Copie du fichier docker-compose.yml
  provisioner "file" {
    source      = "${path.module}/scripts/docker-compose.yml"
    destination = "/tmp/docker-compose.yml"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      host        = aws_instance.monitoring_instance.public_ip
      private_key = var.ssh_private_key_content != "" ? var.ssh_private_key_content : file(var.ssh_private_key_path)
    }
  }

  # Copie du fichier prometheus.yml
  provisioner "file" {
    source      = "${path.module}/scripts/prometheus.yml"
    destination = "/tmp/prometheus.yml"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      host        = aws_instance.monitoring_instance.public_ip
      private_key = var.ssh_private_key_content != "" ? var.ssh_private_key_content : file(var.ssh_private_key_path)
    }
  }

  # Copie du script de gestion Docker
  provisioner "file" {
    source      = "${path.module}/../../scripts/docker-manager.sh"
    destination = "/tmp/docker-manager.sh"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      host        = aws_instance.monitoring_instance.public_ip
      private_key = var.ssh_private_key_content != "" ? var.ssh_private_key_content : file(var.ssh_private_key_path)
    }
  }

  # Copie du script de correction des permissions
  provisioner "file" {
    source      = "${path.module}/scripts/fix_permissions.sh"
    destination = "/tmp/fix_permissions.sh"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      host        = aws_instance.monitoring_instance.public_ip
      private_key = var.ssh_private_key_content != "" ? var.ssh_private_key_content : file(var.ssh_private_key_path)
    }
  }

  # Exécution des scripts
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/docker-manager.sh",
      "chmod +x /tmp/fix_permissions.sh",
      "/tmp/docker-manager.sh deploy monitoring",
      "sudo /tmp/fix_permissions.sh"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      host        = aws_instance.monitoring_instance.public_ip
      private_key = var.ssh_private_key_content != "" ? var.ssh_private_key_content : file(var.ssh_private_key_path)
    }
  }

  depends_on = [aws_instance.monitoring_instance]
}

# Génération et stockage du token SonarQube
resource "null_resource" "generate_sonar_token" {
  # Créer cette ressource uniquement si le provisionnement est activé
  count = var.enable_provisioning ? 1 : 0

  # Dépend de l'instance EC2 de monitoring
  depends_on = [aws_instance.monitoring_instance]

  # Déclencher uniquement lorsque l'instance est créée ou modifiée
  triggers = {
    instance_id = aws_instance.monitoring_instance.id
  }

  # Copie du script de génération du token SonarQube
  provisioner "file" {
    source      = "${path.module}/scripts/generate_sonar_token.sh"
    destination = "/tmp/generate_sonar_token.sh"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      host        = aws_instance.monitoring_instance.public_ip
      private_key = var.ssh_private_key_content != "" ? var.ssh_private_key_content : file(var.ssh_private_key_path)
    }
  }

  # Exécution du script de génération du token SonarQube
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/generate_sonar_token.sh",
      "/tmp/generate_sonar_token.sh ${aws_instance.monitoring_instance.public_ip} ${var.tf_api_token} ${var.tf_workspace_id}"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      host        = aws_instance.monitoring_instance.public_ip
      private_key = var.ssh_private_key_content != "" ? var.ssh_private_key_content : file(var.ssh_private_key_path)
    }
  }
}


