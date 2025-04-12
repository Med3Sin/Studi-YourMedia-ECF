# -----------------------------------------------------------------------------
# IAM Role pour l'instance EC2 de monitoring
# -----------------------------------------------------------------------------

# Rôle IAM pour l'instance EC2 de monitoring
resource "aws_iam_role" "monitoring_role" {
  name = "${var.project_name}-monitoring-role"

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
    Name    = "${var.project_name}-monitoring-role"
    Project = var.project_name
  }
}

# Politique pour accéder à ECR (si nécessaire pour tirer des images Docker)
resource "aws_iam_role_policy_attachment" "ecr_policy" {
  role       = aws_iam_role.monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECR-FullAccess"
}

# Profil d'instance pour attacher le rôle IAM à l'instance EC2
resource "aws_iam_instance_profile" "monitoring_profile" {
  name = "${var.project_name}-monitoring-profile"
  role = aws_iam_role.monitoring_role.name
}

# -----------------------------------------------------------------------------
# Préparation des fichiers de configuration
# -----------------------------------------------------------------------------

# Préparation du script d'initialisation
data "template_file" "install_script" {
  template = file("${path.module}/scripts/install_docker.sh")
  vars = {
    ec2_instance_private_ip = var.ec2_instance_private_ip
    docker_compose_path     = "/tmp/docker-compose.yml"
  }
}

# -----------------------------------------------------------------------------
# Instance EC2 pour Grafana et Prometheus
# -----------------------------------------------------------------------------
# Provisionnement du fichier docker-compose.yml sur l'instance EC2
resource "null_resource" "copy_docker_compose" {
  # Déclencher uniquement lorsque l'instance est créée
  triggers = {
    instance_id = aws_instance.monitoring_instance.id
  }

  # Copier le fichier docker-compose.yml sur l'instance EC2
  provisioner "file" {
    source      = "${path.module}/scripts/docker-compose.yml"
    destination = "/tmp/docker-compose.yml"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      host        = aws_instance.monitoring_instance.public_ip
      private_key = file(var.ssh_private_key_path)
    }
  }

  depends_on = [aws_instance.monitoring_instance]
}

resource "aws_instance" "monitoring_instance" {
  ami                    = var.ecs_ami_id
  instance_type          = "t2.micro"
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [var.ecs_security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.monitoring_profile.name
  key_name               = var.key_pair_name

  # Script exécuté au premier démarrage de l'instance
  user_data = data.template_file.install_script.rendered

  tags = {
    Name    = "${var.project_name}-monitoring-instance"
    Project = var.project_name
  }
}
