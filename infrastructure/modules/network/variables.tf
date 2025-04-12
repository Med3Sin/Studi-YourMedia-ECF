variable "project_name" {
  description = "Nom du projet pour taguer les ressources."
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

variable "vpc_id" {
  description = "ID du VPC où créer les groupes de sécurité."
  type        = string
}

variable "operator_ip" {
  description = "Adresse IP publique autorisée pour SSH et Grafana (format CIDR, ex: '123.123.123.123/32' ou '0.0.0.0/0' pour tout autoriser)."
  type        = string
  default     = "0.0.0.0/0" # Par défaut, autorise tout accès

  validation {
    condition     = can(regex("^([0-9]{1,3}[.]){3}[0-9]{1,3}/[0-9]{1,2}$", var.operator_ip))
    error_message = "La variable operator_ip doit être au format CIDR valide (ex: '123.123.123.123/32' ou '0.0.0.0/0')."
  }
}
