variable "project_name" {
  description = "Nom du projet pour taguer les ressources."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "ID of the VPC where security groups will be created"
  type        = string
}

variable "operator_ip" {
  description = "Adresse IP publique autorisée pour SSH et administration (format CIDR, ex: '123.123.123.123/32')."
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(regex("^([0-9]{1,3}[.]){3}[0-9]{1,3}/[0-9]{1,2}$", var.operator_ip))
    error_message = "La variable operator_ip doit être au format CIDR valide (ex: '123.123.123.123/32' ou '0.0.0.0/0')."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
