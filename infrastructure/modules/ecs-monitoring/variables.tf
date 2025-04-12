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

variable "ecs_ami_id" {
  description = "ID de l'AMI optimisée pour ECS."
  type        = string
  default     = "ami-0f4982c2ea2a68de5" # AMI Amazon Linux 2 optimisée pour ECS dans eu-west-3 (Paris)
}

variable "key_pair_name" {
  description = "Nom de la paire de clés SSH pour l'instance EC2."
  type        = string
}

variable "ssh_private_key_path" {
  description = "Chemin vers la clé privée SSH pour se connecter à l'instance EC2."
  type        = string
  default     = "~/.ssh/id_rsa"
}
