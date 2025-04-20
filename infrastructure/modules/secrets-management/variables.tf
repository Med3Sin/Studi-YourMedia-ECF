# Variables pour le module de gestion des secrets

variable "workspace_id" {
  description = "ID de l'espace de travail Terraform Cloud"
  type        = string
}

variable "organization" {
  description = "Nom de l'organisation Terraform Cloud"
  type        = string
  default     = "yourmedia"
}

variable "project_name" {
  description = "Nom du projet"
  type        = string
  default     = "yourmedia"
}

variable "environment" {
  description = "Environnement (dev, pre-prod, prod)"
  type        = string
  default     = "dev"
}
