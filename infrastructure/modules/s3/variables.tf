variable "project_name" {
  description = "Nom du projet pour nommer le bucket S3."
  type        = string
}

variable "aws_region" {
  description = "Région AWS (utilisée pour la politique Amplify)."
  type        = string
}
