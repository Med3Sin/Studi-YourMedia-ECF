variable "project_name" {
  description = "Nom du projet pour taguer les ressources SonarQube."
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
  description = "Région AWS où déployer les ressources SonarQube."
  type        = string
}

variable "vpc_id" {
  description = "ID du VPC où déployer l'instance EC2 de SonarQube."
  type        = string
}

variable "subnet_id" {
  description = "ID du sous-réseau pour l'instance EC2 de SonarQube."
  type        = string
}

variable "instance_type" {
  description = "Type d'instance EC2 pour SonarQube."
  type        = string
  default     = "t2.small"  # SonarQube a besoin de plus de ressources qu'un t2.micro
}

variable "root_volume_size" {
  description = "Taille du volume racine en Go."
  type        = number
  default     = 30  # SonarQube a besoin de plus d'espace disque
}

variable "allowed_cidr_blocks" {
  description = "Liste des blocs CIDR autorisés à accéder à l'instance EC2 de SonarQube."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ami_id" {
  description = "ID de l'AMI Amazon Linux 2023 pour l'instance EC2 de SonarQube."
  type        = string
  default     = ""  # Laissez vide pour utiliser l'AMI la plus récente via data source
}

variable "use_existing_sg" {
  description = "Utiliser un groupe de sécurité existant au lieu d'en créer un nouveau."
  type        = bool
  default     = false
}

variable "sonarqube_security_group_id" {
  description = "ID du groupe de sécurité pour l'instance EC2 de SonarQube (obligatoire si use_existing_sg = true)."
  type        = string
  default     = ""
}

variable "use_latest_ami" {
  description = "Utiliser l'AMI Amazon Linux 2023 la plus récente au lieu de l'AMI spécifiée."
  type        = bool
  default     = true
}

variable "key_name" {
  description = "Nom de la paire de clés SSH pour l'instance EC2 de SonarQube."
  type        = string
}

variable "ssh_private_key_path" {
  description = "Chemin vers la clé privée SSH pour se connecter à l'instance EC2 de SonarQube."
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "ssh_private_key_content" {
  description = "Contenu de la clé privée SSH pour se connecter à l'instance EC2 de SonarQube. Si fourni, remplace ssh_private_key_path."
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssh_public_key" {
  description = "Contenu de la clé publique SSH à installer sur l'instance EC2 de SonarQube."
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_provisioning" {
  description = "Activer ou désactiver le provisionnement automatique de l'instance EC2 de SonarQube."
  type        = bool
  default     = false
}

variable "s3_bucket_name" {
  description = "Nom du bucket S3 contenant les fichiers de configuration de SonarQube."
  type        = string
}

variable "s3_config_policy_arn" {
  description = "ARN de la politique IAM pour accéder au bucket S3 de configuration de SonarQube."
  type        = string
}

variable "db_username" {
  description = "Nom d'utilisateur pour la base de données PostgreSQL de SonarQube."
  type        = string
  default     = "sonar"
  sensitive   = true
}

variable "db_password" {
  description = "Mot de passe pour la base de données PostgreSQL de SonarQube."
  type        = string
  default     = ""
  sensitive   = true
}

variable "sonar_admin_password" {
  description = "Mot de passe administrateur SonarQube."
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "tf_api_token" {
  description = "Token d'API Terraform Cloud pour l'authentification."
  type        = string
  sensitive   = true
  default     = ""
}

variable "tf_workspace_id" {
  description = "ID de l'espace de travail Terraform Cloud."
  type        = string
  default     = ""
}

variable "docker_username" {
  description = "Nom d'utilisateur Docker Hub pour télécharger les images Docker."
  type        = string
  default     = "medsin"
}

variable "docker_repo" {
  description = "Nom du dépôt Docker Hub pour les images Docker."
  type        = string
  default     = "yourmedia-ecf"
}

variable "dockerhub_token" {
  description = "Token d'accès Docker Hub pour l'authentification."
  type        = string
  sensitive   = true
  default     = ""
}
