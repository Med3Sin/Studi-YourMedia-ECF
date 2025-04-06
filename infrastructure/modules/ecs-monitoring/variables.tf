variable "project_name" {
  description = "Nom du projet pour taguer les ressources ECS."
  type        = string
}

variable "aws_region" {
  description = "Région AWS où déployer les ressources ECS."
  type        = string
}

variable "vpc_id" {
  description = "ID du VPC où déployer les tâches ECS."
  type        = string
}

variable "subnet_ids" {
  description = "Liste des IDs des sous-réseaux publics pour les tâches ECS Fargate (accès Grafana)."
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "ID du groupe de sécurité à attacher aux tâches ECS."
  type        = string
}

variable "ec2_instance_private_ip" {
  description = "Adresse IP privée de l'instance EC2 (pour la cible Prometheus)."
  type        = string
}

variable "ecs_task_cpu" {
  description = "CPU alloué aux tâches ECS Fargate (unités)."
  type        = number
}

variable "ecs_task_memory" {
  description = "Mémoire allouée aux tâches ECS Fargate (MiB)."
  type        = number
}
