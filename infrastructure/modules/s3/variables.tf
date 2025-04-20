variable "project_name" {
  description = "Nom du projet pour nommer le bucket S3."
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

variable "aws_region" {
  description = "Région AWS pour le bucket S3."
  type        = string
}

variable "monitoring_scripts_path" {
  description = "Chemin vers les scripts de monitoring. Si fourni, les scripts seront chargés depuis ce chemin plutôt que depuis les fichiers locaux."
  type        = string
  default     = ""
}
