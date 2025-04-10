variable "aws_region" {
  description = "La région AWS où déployer les ressources."
  type        = string
  default     = "eu-west-3" # Paris, une région souvent éligible au Free Tier
}

variable "project_name" {
  description = "Nom du projet utilisé pour nommer les ressources."
  type        = string
  default     = "yourmedia"
}

variable "db_username" {
  description = "Nom d'utilisateur pour la base de données RDS."
  type        = string
  sensitive   = true # Marqué comme sensible, la valeur viendra des secrets GitHub
}

variable "db_password" {
  description = "Mot de passe pour la base de données RDS."
  type        = string
  sensitive   = true # Marqué comme sensible, la valeur viendra des secrets GitHub
}

variable "ec2_key_pair_name" {
  description = "Nom de la paire de clés EC2 à utiliser pour l'accès SSH."
  type        = string
  # Aucune valeur par défaut, devra être fournie (ex: via tfvars ou variable d'environnement TF_VAR_ec2_key_pair_name)
  # ou directement dans le workflow GitHub Actions.
}

variable "operator_ip" {
  description = "Votre adresse IP publique pour autoriser l'accès SSH à l'EC2 et l'accès à Grafana."
  type        = string
  default     = "0.0.0.0/0" # ATTENTION: Pour la simplicité, ouvert à tous. À restreindre en production!
  # Vous pouvez la trouver via des sites comme https://www.whatismyip.com/ et la remplacer ici ou via une variable.
}

variable "ami_id" {
  description = "ID de l'AMI Amazon Linux 2 à utiliser pour l'EC2 (doit correspondre à la région)."
  type        = string
  default     = "ami-0925eac45db11fef2" # Amazon Linux 2 AMI pour eu-west-3 (Paris) - Recommandé pour le Free Tier
}

variable "instance_type_ec2" {
  description = "Type d'instance EC2 (Free Tier eligible)."
  type        = string
  default     = "t2.micro"
}

variable "instance_type_rds" {
  description = "Type d'instance RDS (Free Tier eligible)."
  type        = string
  default     = "db.t2.micro"
}

variable "ecs_task_cpu" {
  description = "CPU alloué aux tâches ECS (unités)."
  type        = number
  default     = 256 # 0.25 vCPU
}

variable "ecs_task_memory" {
  description = "Mémoire allouée aux tâches ECS (MiB)."
  type        = number
  default     = 512 # 0.5 GB
}

variable "github_token" {
  description = "Token GitHub (PAT) pour connecter Amplify au repository."
  type        = string
  sensitive   = true
  # Sera fourni via les secrets GitHub Actions.
}

variable "repo_owner" {
  description = "Propriétaire du repository GitHub (votre nom d'utilisateur ou organisation)."
  type        = string
  # Sera fourni via les secrets GitHub Actions ou une variable d'environnement.
}

variable "repo_name" {
  description = "Nom du repository GitHub."
  type        = string
  # Sera fourni via les secrets GitHub Actions ou une variable d'environnement.
}
