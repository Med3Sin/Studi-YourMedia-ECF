variable "project_name" {
  description = "Nom du projet pour taguer les ressources RDS."
  type        = string
}

variable "db_username" {
  description = "Nom d'utilisateur pour la base de données RDS."
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Mot de passe pour la base de données RDS."
  type        = string
  sensitive   = true
}

variable "instance_type_rds" {
  description = "Type d'instance RDS (Free Tier eligible)."
  type        = string
}

variable "vpc_id" {
  description = "ID du VPC où déployer l'instance RDS."
  type        = string
}

variable "subnet_ids" {
  description = "Liste des IDs des sous-réseaux pour le groupe de sous-réseaux RDS."
  type        = list(string)
}

variable "rds_security_group_id" {
  description = "ID du groupe de sécurité à attacher à l'instance RDS."
  type        = string
}
