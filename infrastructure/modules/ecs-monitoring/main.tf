# -----------------------------------------------------------------------------
# IAM Role pour l'instance EC2
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "ec2_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "monitoring_role" {
  name               = "${var.project_name}-monitoring-role-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json

  tags = {
    Name    = "${var.project_name}-monitoring-role"
    Project = var.project_name
  }

  # Permet de recréer la ressource avant de détruire l'ancienne
  lifecycle {
    create_before_destroy = true
  }
}

# Politique pour accéder à ECR (si nécessaire)
resource "aws_iam_role_policy_attachment" "ecr_policy" {
  role       = aws_iam_role.monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECR-FullAccess"
}

# Profil d'instance EC2 pour attacher le rôle à l'instance
resource "aws_iam_instance_profile" "monitoring_profile" {
  name = "${var.project_name}-monitoring-profile-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  role = aws_iam_role.monitoring_role.name

  tags = {
    Name    = "${var.project_name}-monitoring-profile"
    Project = var.project_name
  }

  # Permet de recréer la ressource avant de détruire l'ancienne
  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Préparation des fichiers de configuration
# -----------------------------------------------------------------------------
# Préparation du fichier docker-compose.yml
data "template_file" "docker_compose" {
  template = file("${path.module}/scripts/docker-compose.yml.tpl")
}

# Création d'un fichier local pour docker-compose.yml
resource "local_file" "docker_compose" {
  content  = data.template_file.docker_compose.rendered
  filename = "${path.module}/scripts/docker-compose.yml"
}

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
  # Déclencher uniquement lorsque l'instance est créée ou que le fichier docker-compose.yml change
  triggers = {
    instance_id = aws_instance.monitoring_instance.id
    docker_compose_sha1 = sha1(data.template_file.docker_compose.rendered)
  }

  # Copier le fichier docker-compose.yml sur l'instance EC2
  provisioner "file" {
    content     = data.template_file.docker_compose.rendered
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
