variable "project_name" {
  description = "Nom du projet"
  type        = string
}

variable "environment" {
  description = "Environnement (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "Région AWS"
  type        = string
  default     = "eu-west-3"
}
