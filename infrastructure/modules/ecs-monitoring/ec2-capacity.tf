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

# Associer l'instance au cluster ECS
resource "aws_ecs_capacity_provider" "ec2_capacity_provider" {
  name = "${var.project_name}-ec2-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.dummy_asg.arn

    managed_scaling {
      maximum_scaling_step_size = 1
      minimum_scaling_step_size = 1
      status                    = "DISABLED"
      target_capacity           = 100
    }
  }
}

# Groupe Auto Scaling factice (requis par ECS Capacity Provider)
resource "aws_autoscaling_group" "dummy_asg" {
  name                = "${var.project_name}-dummy-asg"
  vpc_zone_identifier = [var.subnet_ids[0]]
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1

  # Utilise un launch template minimal
  launch_template {
    id      = aws_launch_template.dummy_lt.id
    version = "$Latest"
  }

  # Ne pas lancer d'instances réelles
  suspended_processes = [
    "Launch", "Terminate", "HealthCheck", "ReplaceUnhealthy", "AZRebalance",
    "AlarmNotification", "ScheduledActions", "AddToLoadBalancer"
  ]

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }
}

# Launch template factice pour le groupe Auto Scaling factice
resource "aws_launch_template" "dummy_lt" {
  name_prefix   = "${var.project_name}-dummy-lt-"
  image_id      = var.ecs_ami_id
  instance_type = "t2.micro"
}

# Associer le capacity provider au cluster ECS
resource "aws_ecs_cluster_capacity_providers" "cluster_capacity" {
  cluster_name       = aws_ecs_cluster.monitoring_cluster.name
  capacity_providers = [aws_ecs_capacity_provider.ec2_capacity_provider.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2_capacity_provider.name
    weight            = 1
    base              = 1
  }
}
