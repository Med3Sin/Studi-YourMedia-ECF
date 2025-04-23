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

variable "subnet_id" {
  description = "ID du sous-réseau pour l'instance EC2 de monitoring."
  type        = string
}

variable "instance_type" {
  description = "Type d'instance EC2 pour le monitoring."
  type        = string
  default     = "t2.micro"
}

variable "root_volume_size" {
  description = "Taille du volume racine en Go."
  type        = number
  default     = 20
}

variable "allowed_cidr_blocks" {
  description = "Liste des blocs CIDR autorisés à accéder à l'instance EC2 de monitoring."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ec2_instance_private_ip" {
  description = "Adresse IP privée de l'instance EC2 Java/Tomcat (pour la cible Prometheus)."
  type        = string
}

# Ces variables ne sont plus utilisées car nous utilisons des conteneurs Docker sur EC2 au lieu de ECS Fargate
# Elles sont conservées pour la compatibilité avec les anciens scripts
variable "monitoring_task_cpu" {
  description = "CPU alloué aux conteneurs Docker sur l'instance EC2 de monitoring (non utilisé)."
  type        = number
  default     = 256 # Valeur par défaut pour la compatibilité avec les anciens scripts
}

variable "monitoring_task_memory" {
  description = "Mémoire allouée aux conteneurs Docker sur l'instance EC2 de monitoring (non utilisé)."
  type        = number
  default     = 512 # Valeur par défaut pour la compatibilité avec les anciens scripts
}

variable "ami_id" {
  description = "ID de l'AMI Amazon Linux 2023 pour l'instance EC2 de monitoring."
  type        = string
  default     = "" # Laissez vide pour utiliser l'AMI la plus récente via data source
}

variable "use_existing_sg" {
  description = "Utiliser un groupe de sécurité existant au lieu d'en créer un nouveau."
  type        = bool
  default     = false # Modifié de true à false pour éviter la dépendance circulaire
}

variable "monitoring_security_group_id" {
  description = "ID du groupe de sécurité pour l'instance EC2 de monitoring (obligatoire si use_existing_sg = true)."
  type        = string
  default     = ""
}

variable "use_latest_ami" {
  description = "Utiliser l'AMI Amazon Linux 2023 la plus récente au lieu de l'AMI spécifiée."
  type        = bool
  default     = true
}

variable "key_name" {
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

variable "ssh_public_key" {
  description = "Contenu de la clé publique SSH à installer sur l'instance EC2 de monitoring."
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_provisioning" {
  description = "Activer ou désactiver le provisionnement automatique de l'instance EC2 de monitoring."
  type        = bool
  default     = false
}

variable "s3_bucket_name" {
  description = "Nom du bucket S3 contenant les fichiers de configuration de monitoring."
  type        = string
}

variable "s3_config_policy_arn" {
  description = "ARN de la politique IAM pour accéder au bucket S3 de configuration de monitoring."
  type        = string
}

variable "db_username" {
  description = "Nom d'utilisateur pour la base de données RDS."
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "db_password" {
  description = "Mot de passe pour la base de données RDS."
  type        = string
  default     = ""
  sensitive   = true
}

variable "rds_endpoint" {
  description = "Endpoint de la base de données RDS."
  type        = string
  default     = ""
}

variable "sonar_jdbc_username" {
  description = "Nom d'utilisateur pour la base de données SonarQube."
  type        = string
  default     = "sonar"
  sensitive   = true
}

variable "sonar_jdbc_password" {
  description = "Mot de passe pour la base de données SonarQube."
  type        = string
  default     = ""
  sensitive   = true
}

variable "sonar_jdbc_url" {
  description = "URL de connexion à la base de données SonarQube."
  type        = string
  default     = "jdbc:postgresql://sonarqube-db:5432/sonar"
}

variable "grafana_admin_password" {
  description = "Mot de passe administrateur Grafana."
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
