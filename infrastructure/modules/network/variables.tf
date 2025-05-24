variable "project_name" {
  description = "Nom du projet"
  type        = string
}

variable "environment" {
  description = "Environnement (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID du VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR du VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "ec2_java_tomcat_ip" {
  description = "IP de l'instance EC2 Java/Tomcat"
  type        = string
  default     = "0.0.0.0/0"
}
