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

variable "environment" {
  description = "Environnement de déploiement (dev, pre-prod, prod)."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "pre-prod", "prod"], var.environment)
    error_message = "L'environnement doit être 'dev', 'pre-prod' ou 'prod'."
  }
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

variable "db_name" {
  description = "Nom de la base de données MySQL."
  type        = string
  default     = "yourmedia" # Valeur par défaut, peut être remplacée par le secret GitHub DB_NAME
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
  default     = "ami-0f4982c2ea2a68de5" # Exemple: Amazon Linux 2 pour eu-west-3 (Paris) - Vérifiez la dernière version Free Tier
}

variable "use_latest_ami" {
  description = "Utiliser l'AMI Amazon Linux 2 la plus récente au lieu de l'AMI spécifiée."
  type        = bool
  default     = true
}

variable "instance_type_ec2" {
  description = "Type d'instance EC2 (Free Tier eligible)."
  type        = string
  default     = "t2.micro"
}

variable "instance_type_rds" {
  description = "Type d'instance RDS (Free Tier eligible)."
  type        = string
  default     = "db.t3.micro"
}

variable "monitoring_task_cpu" {
  description = "CPU alloué aux tâches ECS Fargate (unités)."
  type        = number
  default     = 256 # Minimum pour Fargate (équivalent à 0.25 vCPU)
}

variable "monitoring_task_memory" {
  description = "Mémoire allouée aux tâches ECS Fargate (MiB)."
  type        = number
  default     = 512 # Minimum pour Fargate
}

variable "github_token" {
  description = "Token GitHub (PAT) pour l'authentification aux services GitHub."
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

variable "ssh_private_key_path" {
  description = "Chemin vers la clé privée SSH pour se connecter aux instances EC2."
  type        = string
  default     = "~/.ssh/id_rsa"
  # Cette valeur par défaut sera remplacée par le chemin réel dans le workflow GitHub Actions.
}

variable "ssh_private_key_content" {
  description = "Contenu de la clé privée SSH pour se connecter aux instances EC2. Si fourni, remplace ssh_private_key_path."
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssh_public_key" {
  description = "Contenu de la clé publique SSH à installer sur les instances EC2."
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_provisioning" {
  description = "Activer ou désactiver le provisionnement automatique des instances EC2."
  type        = bool
  default     = false
}

variable "aws_access_key" {
  description = "Clé d'accès AWS pour l'authentification."
  type        = string
  sensitive   = true
  # Sera fourni via les secrets GitHub Actions.
}

variable "aws_secret_key" {
  description = "Clé secrète AWS pour l'authentification."
  type        = string
  sensitive   = true
  # Sera fourni via les secrets GitHub Actions.
}

variable "tf_api_token" {
  description = "Token d'API Terraform Cloud pour l'authentification."
  type        = string
  sensitive   = true
  # Sera fourni via les secrets GitHub Actions.
}

variable "tf_workspace_id" {
  description = "ID de l'espace de travail Terraform Cloud."
  type        = string
  # Sera fourni via les secrets GitHub Actions.
}

variable "tf_organization" {
  description = "Nom de l'organisation Terraform Cloud."
  type        = string
  default     = "yourmedia"
}

variable "grafana_admin_password" {
  description = "Mot de passe administrateur Grafana."
  type        = string
  default     = "admin"
  sensitive   = true
}
