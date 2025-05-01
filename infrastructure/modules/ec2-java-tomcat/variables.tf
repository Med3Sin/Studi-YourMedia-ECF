variable "project_name" {
  description = "Nom du projet pour taguer les ressources EC2."
  type        = string
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

variable "ami_id" {
  description = "ID de l'AMI Amazon Linux 2023 à utiliser pour l'EC2."
  type        = string
  default     = "" # Laissez vide pour utiliser l'AMI la plus récente via data source
}

variable "use_latest_ami" {
  description = "Utiliser l'AMI Amazon Linux 2023 la plus récente au lieu de l'AMI spécifiée."
  type        = bool
  default     = true
}

variable "instance_type_ec2" {
  description = "Type d'instance EC2 (Free Tier eligible)."
  type        = string
}

variable "key_pair_name" {
  description = "Nom de la paire de clés EC2 à utiliser pour l'accès SSH."
  type        = string
}

variable "subnet_id" {
  description = "ID du sous-réseau public où déployer l'instance EC2."
  type        = string
}

variable "ec2_security_group_id" {
  description = "ID du groupe de sécurité à attacher à l'instance EC2."
  type        = string
}

# Variable pour le nom du bucket S3 (pour la politique IAM)
variable "s3_bucket_arn" {
  description = "ARN du bucket S3 pour accorder les permissions à l'EC2."
  type        = string
  default     = "" # Sera fourni par le module racine
}

# Variable pour la clé SSH publique
variable "ssh_public_key" {
  description = "Clé SSH publique à installer sur l'instance"
  type        = string
  default     = "" # Sera fourni par le module racine via les secrets GitHub
}

# Variables pour le bucket S3
variable "s3_bucket_name" {
  description = "Nom du bucket S3 pour télécharger les scripts"
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "Région AWS pour le déploiement"
  type        = string
  default     = "eu-west-3"
}

# Variables pour la base de données
variable "db_username" {
  description = "Nom d'utilisateur de la base de données"
  type        = string
  default     = ""
}

variable "db_password" {
  description = "Mot de passe de la base de données"
  type        = string
  default     = ""
  sensitive   = true
}

variable "rds_endpoint" {
  description = "Point de terminaison de la base de données RDS"
  type        = string
  default     = ""
}

# Variables pour Docker Hub
variable "dockerhub_username" {
  description = "Nom d'utilisateur Docker Hub"
  type        = string
  default     = ""
}

variable "dockerhub_token" {
  description = "Token Docker Hub"
  type        = string
  default     = ""
  sensitive   = true
}

variable "dockerhub_repo" {
  description = "Nom du dépôt Docker Hub"
  type        = string
  default     = ""
}

# Variables pour GitHub
variable "repo_owner" {
  description = "Propriétaire du dépôt GitHub (utilisateur ou organisation)"
  type        = string
  default     = "Med3Sin"
}

variable "repo_name" {
  description = "Nom du dépôt GitHub"
  type        = string
  default     = "Studi-YourMedia-ECF"
}
