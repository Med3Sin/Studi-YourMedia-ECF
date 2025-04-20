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

variable "secret_rotation_days" {
  description = "Nombre de jours entre chaque rotation des secrets"
  type        = number
  default     = 90 # Rotation tous les 90 jours par défaut
  validation {
    condition     = var.secret_rotation_days >= 30 && var.secret_rotation_days <= 365
    error_message = "La période de rotation des secrets doit être comprise entre 30 et 365 jours."
  }
}

variable "enable_rotation_notifications" {
  description = "Activer les notifications lors de la rotation des secrets"
  type        = bool
  default     = true
}

variable "notification_email" {
  description = "Adresse email pour recevoir les notifications de rotation des secrets"
  type        = string
  default     = "" # Doit être configuré par l'utilisateur
  validation {
    condition     = var.notification_email == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.notification_email))
    error_message = "L'adresse email doit être valide ou vide."
  }
}

variable "aws_region" {
  description = "Région AWS pour les services de notification"
  type        = string
  default     = "eu-west-3" # Paris
}
