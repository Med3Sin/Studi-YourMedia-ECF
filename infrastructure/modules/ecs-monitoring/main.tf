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
# Préparation du script d'initialisation
# -----------------------------------------------------------------------------
data "template_file" "install_script" {
  template = file("${path.module}/scripts/install_docker.sh")
  vars = {
    ec2_instance_private_ip = var.ec2_instance_private_ip
  }
}

# -----------------------------------------------------------------------------
# Instance EC2 pour Grafana et Prometheus
# -----------------------------------------------------------------------------
resource "aws_instance" "monitoring_instance" {
  ami                    = var.ecs_ami_id
  instance_type          = "t2.micro"
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [var.ecs_security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.monitoring_profile.name

  # Script exécuté au premier démarrage de l'instance
  user_data = data.template_file.install_script.rendered

  tags = {
    Name    = "${var.project_name}-monitoring-instance"
    Project = var.project_name
  }
}
