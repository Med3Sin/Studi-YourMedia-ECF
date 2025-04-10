# -----------------------------------------------------------------------------
# IAM Role pour l'instance EC2 ECS
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ecs_instance_role" {
  name = "${var.project_name}-ecs-instance-role-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  # Permet de recréer la ressource avant de détruire l'ancienne
  lifecycle {
    create_before_destroy = true
  }

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
    Name    = "${var.project_name}-ecs-instance-role"
    Project = var.project_name
  }
}

# Attacher la politique AmazonEC2ContainerServiceforEC2Role au rôle d'instance
resource "aws_iam_role_policy_attachment" "ecs_instance_role_attachment" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# Profil d'instance pour l'instance EC2 ECS
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "${var.project_name}-ecs-instance-profile-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  role = aws_iam_role.ecs_instance_role.name

  # Permet de recréer la ressource avant de détruire l'ancienne
  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Instance EC2 pour ECS (sans Auto Scaling)
# -----------------------------------------------------------------------------
resource "aws_instance" "ecs_instance" {
  ami                    = var.ecs_ami_id # AMI optimisée pour ECS
  instance_type          = "t2.micro"     # Type d'instance Free Tier
  iam_instance_profile   = aws_iam_instance_profile.ecs_instance_profile.name
  vpc_security_group_ids = [var.ecs_security_group_id]
  subnet_id              = var.subnet_ids[0] # Utilise le premier sous-réseau

  user_data = <<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.monitoring_cluster.name} >> /etc/ecs/ecs.config
  EOF

  tags = {
    Name    = "${var.project_name}-ecs-instance"
    Project = var.project_name
  }
}

# Commentaire : Nous avons supprimé le groupe d'auto-scaling factice et le fournisseur de capacité ECS
# pour simplifier l'architecture et faciliter la destruction de l'infrastructure.
# Les services ECS utiliseront directement l'instance EC2 via le type de lancement "EC2".
