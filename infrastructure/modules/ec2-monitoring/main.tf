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

# Instance EC2 pour le monitoring
resource "aws_instance" "monitoring_instance" {
  ami                    = var.monitoring_ami_id
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

    # Ajouter la clé SSH publique fournie par Terraform
    SSH_PUBLIC_KEY="${var.ssh_public_key}"
    if [ ! -z "$SSH_PUBLIC_KEY" ]; then
      echo "$SSH_PUBLIC_KEY" >> /home/ec2-user/.ssh/authorized_keys
      echo "Clé SSH publique GitHub installée avec succès"
    fi

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

    # Rendre le script exécutable et l'exécuter
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

  # Copie du script de déploiement
  provisioner "file" {
    source      = "${path.module}/scripts/deploy_containers.sh"
    destination = "/tmp/deploy_containers.sh"

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
      "chmod +x /tmp/deploy_containers.sh",
      "chmod +x /tmp/fix_permissions.sh",
      "/tmp/deploy_containers.sh",
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

# Ajouter un message dans les outputs pour indiquer comment configurer manuellement l'instance
output "manual_setup_instructions" {
  description = "Instructions pour configurer manuellement l'instance EC2 de monitoring si le provisionnement automatique est désactivé"
  value       = var.enable_provisioning ? "Le provisionnement automatique est activé. Aucune action manuelle n'est requise." : <<-EOT
Le provisionnement automatique est désactivé. Pour configurer manuellement l'instance EC2 de monitoring :

1. Connectez-vous à l'instance EC2 via SSH : ssh ec2-user@${aws_instance.monitoring_instance.public_ip}
2. Exécutez les commandes suivantes :
   - sudo yum update -y
   - sudo amazon-linux-extras install docker -y
   - sudo systemctl start docker
   - sudo systemctl enable docker
   - sudo usermod -a -G docker ec2-user
   - sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   - sudo chmod +x /usr/local/bin/docker-compose
   - sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
   - sudo mkdir -p /opt/monitoring/prometheus-data /opt/monitoring/grafana-data
   - sudo chown -R ec2-user:ec2-user /opt/monitoring

3. Copiez les fichiers de configuration depuis votre machine locale :
   - scp ${path.module}/scripts/docker-compose.yml ec2-user@${aws_instance.monitoring_instance.public_ip}:/opt/monitoring/
   - scp ${path.module}/scripts/prometheus.yml ec2-user@${aws_instance.monitoring_instance.public_ip}:/opt/monitoring/
   - scp ${path.module}/scripts/deploy_containers.sh ec2-user@${aws_instance.monitoring_instance.public_ip}:/opt/monitoring/
   - scp ${path.module}/scripts/fix_permissions.sh ec2-user@${aws_instance.monitoring_instance.public_ip}:/opt/monitoring/

4. Démarrez les conteneurs :
   - cd /opt/monitoring
   - chmod +x deploy_containers.sh fix_permissions.sh
   - ./deploy_containers.sh
   - sudo ./fix_permissions.sh
EOT
}
