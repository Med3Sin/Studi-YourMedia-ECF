variable "project_name" {
  description = "Nom du projet pour taguer les ressources."
  type        = string
}

variable "vpc_id" {
  description = "ID du VPC où créer les groupes de sécurité."
  type        = string
}

variable "operator_ip" {
  description = "Adresse IP publique autorisée pour SSH et Grafana."
  type        = string
}
