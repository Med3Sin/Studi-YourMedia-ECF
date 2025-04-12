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
  description = "ID de l'AMI Ubuntu à utiliser pour l'EC2."
  type        = string
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
