# -----------------------------------------------------------------------------
# ECS Cluster
# -----------------------------------------------------------------------------
resource "aws_ecs_cluster" "monitoring_cluster" {
  name = "${var.project_name}-monitoring-cluster"

  tags = {
    Name    = "${var.project_name}-monitoring-cluster"
    Project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group pour les conteneurs ECS
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name = "/ecs/${var.project_name}-monitoring-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  # Permet de recréer la ressource avant de détruire l'ancienne
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name    = "${var.project_name}-monitoring-logs"
    Project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# IAM Roles pour les tâches ECS
# -----------------------------------------------------------------------------

# Rôle d'exécution de tâche (Task Execution Role)
# Permet à ECS de tirer les images et d'envoyer les logs à CloudWatch
data "aws_iam_policy_document" "ecs_task_execution_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.project_name}-ecs-task-exec-role-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume_role_policy.json

  tags = {
    Name    = "${var.project_name}-ecs-task-exec-role"
    Project = var.project_name
  }

  # Permet de recréer la ressource avant de détruire l'ancienne
  lifecycle {
    create_before_destroy = true
  }
}

# Politique managée AWS pour l'exécution des tâches ECS
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# (Optionnel mais bonne pratique) Rôle de tâche (Task Role)
# Rôle assumé par le conteneur lui-même s'il doit interagir avec AWS
# data "aws_iam_policy_document" "ecs_task_assume_role_policy" {
#   statement {
#     actions = "sts:AssumeRole"
#     principals {
#       type        = "Service"
#       identifiers = ["ecs-tasks.amazonaws.com"]
#     }
#   }
# }
# resource "aws_iam_role" "ecs_task_role" {
#   name               = "${var.project_name}-ecs-task-role"
#   assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role_policy.json
#   tags = {
#     Name    = "${var.project_name}-ecs-task-role"
#     Project = var.project_name
#   }
# }
# Ajouter ici des aws_iam_role_policy_attachment si les tâches ont besoin de permissions spécifiques

# -----------------------------------------------------------------------------
# Préparation des configurations et définitions de tâches
# -----------------------------------------------------------------------------

# Rend le fichier de configuration Prometheus en injectant l'IP privée de l'EC2
data "template_file" "prometheus_config" {
  template = file("${path.module}/config/prometheus.yml")
  vars = {
    ec2_private_ip = var.ec2_instance_private_ip
  }
}

# Définition de conteneur Prometheus directement dans Terraform
locals {
  prometheus_container_definition = jsonencode([
    {
      name      = "${var.project_name}-prometheus",
      image     = "prom/prometheus:latest",
      essential = true,
      memory    = 512, # Allocation de mémoire en MB
      cpu       = 256, # Allocation de CPU en unités (1024 = 1 vCPU),
      portMappings = [
        {
          containerPort = 9090,
          hostPort      = 9090,
          protocol      = "tcp"
        }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name,
          "awslogs-region"        = var.aws_region,
          "awslogs-stream-prefix" = "ecs-prometheus"
        }
      },
      environment = [
        {
          name  = "PROMETHEUS_CONFIG_BASE64",
          value = base64encode(data.template_file.prometheus_config.rendered)
        }
      ],
      command = [
        "/bin/sh",
        "-c",
        "echo $PROMETHEUS_CONFIG_BASE64 | base64 -d > /etc/prometheus/prometheus.yml && /bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/prometheus --web.console.libraries=/usr/share/prometheus/console_libraries --web.console.templates=/usr/share/prometheus/consoles"
      ]
    }
  ])

  grafana_container_definition = jsonencode([
    {
      name      = "${var.project_name}-grafana",
      image     = "grafana/grafana-oss:latest",
      essential = true,
      memory    = 512, # Allocation de mémoire en MB
      cpu       = 256, # Allocation de CPU en unités (1024 = 1 vCPU),
      portMappings = [
        {
          containerPort = 3000,
          hostPort      = 3000,
          protocol      = "tcp"
        }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name,
          "awslogs-region"        = var.aws_region,
          "awslogs-stream-prefix" = "ecs-grafana"
        }
      },
      environment = [
        {
          name  = "GF_SECURITY_ADMIN_USER",
          value = "admin"
        },
        {
          name  = "GF_SECURITY_ADMIN_PASSWORD",
          value = "YourSecurePassword123!"
        },
        {
          name  = "GF_SERVER_ROOT_URL",
          value = "http://localhost:3000"
        },
        {
          name  = "GF_INSTALL_PLUGINS",
          value = ""
        }
      ]
    }
  ])
}

# -----------------------------------------------------------------------------
# Définitions de Tâches ECS
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "prometheus_task" {
  family       = "${var.project_name}-prometheus"
  network_mode = "bridge" # Mode réseau standard pour EC2
  # Pas de requires_compatibilities pour EC2
  # Pas besoin de spécifier CPU/mémoire au niveau de la tâche pour EC2
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  # task_role_arn            = aws_iam_role.ecs_task_role.arn # Si on utilise un Task Role

  # Utilise la définition de conteneur définie dans locals
  container_definitions = local.prometheus_container_definition

  tags = {
    Name    = "${var.project_name}-prometheus-task"
    Project = var.project_name
  }
}

resource "aws_ecs_task_definition" "grafana_task" {
  family       = "${var.project_name}-grafana"
  network_mode = "bridge" # Mode réseau standard pour EC2
  # Pas de requires_compatibilities pour EC2
  # Pas besoin de spécifier CPU/mémoire au niveau de la tâche pour EC2
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  # task_role_arn            = aws_iam_role.ecs_task_role.arn # Si on utilise un Task Role

  container_definitions = local.grafana_container_definition

  tags = {
    Name    = "${var.project_name}-grafana-task"
    Project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# Services ECS Fargate
# -----------------------------------------------------------------------------
resource "aws_ecs_service" "prometheus_service" {
  name            = "${var.project_name}-prometheus-service"
  cluster         = aws_ecs_cluster.monitoring_cluster.id
  task_definition = aws_ecs_task_definition.prometheus_task.arn
  launch_type     = "EC2"
  desired_count   = 1 # Exécute une seule instance de Prometheus

  # Suppression de la configuration réseau car nous utilisons le mode réseau "bridge"

  # Pas de load balancer pour Prometheus dans cette config simple

  # Assure que la définition de tâche est créée avant le service
  depends_on = [aws_ecs_task_definition.prometheus_task]

  tags = {
    Name    = "${var.project_name}-prometheus-service"
    Project = var.project_name
  }
}

resource "aws_ecs_service" "grafana_service" {
  name            = "${var.project_name}-grafana-service"
  cluster         = aws_ecs_cluster.monitoring_cluster.id
  task_definition = aws_ecs_task_definition.grafana_task.arn
  launch_type     = "EC2"
  desired_count   = 1

  # Suppression de la configuration réseau car nous utilisons le mode réseau "bridge"

  # Pas de load balancer pour Grafana dans cette config simple

  depends_on = [aws_ecs_task_definition.grafana_task]

  tags = {
    Name    = "${var.project_name}-grafana-service"
    Project = var.project_name
  }
}
