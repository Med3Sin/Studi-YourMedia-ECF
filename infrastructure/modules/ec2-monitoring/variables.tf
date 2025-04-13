variable "project_name" {
  description = "Nom du projet pour taguer les ressources de monitoring."
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
  description = "Région AWS où déployer les ressources de monitoring."
  type        = string
}

variable "vpc_id" {
  description = "ID du VPC où déployer l'instance EC2 de monitoring."
  type        = string
}

variable "subnet_ids" {
  description = "Liste des IDs des sous-réseaux pour l'instance EC2 de monitoring."
  type        = list(string)
}

variable "monitoring_security_group_id" {
  description = "ID du groupe de sécurité à attacher à l'instance EC2 de monitoring."
  type        = string
  # Renommer en ec2_security_group_id dans une future version pour plus de cohérence
}

variable "ec2_instance_private_ip" {
  description = "Adresse IP privée de l'instance EC2 Java/Tomcat (pour la cible Prometheus)."
  type        = string
}

variable "monitoring_task_cpu" {
  description = "CPU alloué aux conteneurs Docker (maintenu pour compatibilité, sera supprimé dans une future version)."
  type        = number
}

variable "monitoring_task_memory" {
  description = "Mémoire allouée aux conteneurs Docker (maintenu pour compatibilité, sera supprimé dans une future version)."
  type        = number
}

variable "monitoring_ami_id" {
  description = "ID de l'AMI Amazon Linux 2 pour l'instance EC2 de monitoring."
  type        = string
  default     = "ami-0f4982c2ea2a68de5" # AMI Amazon Linux 2 dans eu-west-3 (Paris)
  # Renommer en ec2_ami_id dans une future version pour plus de cohérence
}

variable "key_pair_name" {
  description = "Nom de la paire de clés SSH pour l'instance EC2 de monitoring."
  type        = string
}

variable "ssh_private_key_path" {
  description = "Chemin vers la clé privée SSH pour se connecter à l'instance EC2 de monitoring."
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "ssh_private_key_content" {
  description = "Contenu de la clé privée SSH pour se connecter à l'instance EC2 de monitoring. Si fourni, remplace ssh_private_key_path."
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_provisioning" {
  description = "Activer ou désactiver le provisionnement automatique de l'instance EC2 de monitoring."
  type        = bool
  default     = false
}

variable "s3_config_bucket_name" {
  description = "Nom du bucket S3 contenant les fichiers de configuration de monitoring."
  type        = string
}

variable "s3_config_policy_arn" {
  description = "ARN de la politique IAM pour accéder au bucket S3 de configuration de monitoring."
  type        = string
}
