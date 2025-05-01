variable "aws_region" {
  description = "La région AWS où déployer les ressources."
  type        = string
  default     = "eu-west-3" # Paris, une région souvent éligible au Free Tier
}



variable "project_name" {
  description = "Nom du projet utilisé pour nommer les ressources."
  type        = string
  default     = "yourmedia"
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

variable "db_username" {
  description = "Nom d'utilisateur pour la base de données RDS."
  type        = string
  sensitive   = true # Marqué comme sensible, la valeur viendra des secrets GitHub
}

variable "db_password" {
  description = "Mot de passe pour la base de données RDS."
  type        = string
  sensitive   = true # Marqué comme sensible, la valeur viendra des secrets GitHub
}

variable "db_name" {
  description = "Nom de la base de données MySQL."
  type        = string
  default     = "yourmedia" # Valeur par défaut, peut être remplacée par le secret GitHub DB_NAME
}

variable "ec2_key_pair_name" {
  description = "Nom de la paire de clés EC2 à utiliser pour l'accès SSH."
  type        = string
  # Aucune valeur par défaut, devra être fournie (ex: via tfvars ou variable d'environnement TF_VAR_ec2_key_pair_name)
  # ou directement dans le workflow GitHub Actions.
}

variable "operator_ip" {
  description = "Votre adresse IP publique pour autoriser l'accès SSH à l'EC2 et l'accès à Grafana."
  type        = string
  default     = "0.0.0.0/0" # ATTENTION: Pour la simplicité, ouvert à tous. À restreindre en production!
  # Vous pouvez la trouver via des sites comme https://www.whatismyip.com/ et la remplacer ici ou via une variable.
}

variable "ami_id" {
  description = "ID de l'AMI Amazon Linux 2023 à utiliser pour l'EC2 (doit correspondre à la région)."
  type        = string
  default     = "" # Laissez vide pour utiliser l'AMI la plus récente via data source
}

variable "use_latest_ami" {
  description = "Utiliser l'AMI Amazon Linux 2023 la plus récente au lieu de l'AMI spécifiée."
  type        = bool
  default     = true
}

variable "instance_type_ec2" {
  description = "Type d'instance EC2 (Free Tier eligible)."
  type        = string
  default     = "t2.micro"
}

variable "instance_type_rds" {
  description = "Type d'instance RDS (Free Tier eligible)."
  type        = string
  default     = "db.t3.micro"
}

# Note: Les variables monitoring_task_cpu et monitoring_task_memory ont été supprimées
# car nous utilisons maintenant des conteneurs Docker sur EC2 au lieu de ECS Fargate

variable "github_token" {
  description = "Token GitHub (PAT) pour l'authentification aux services GitHub."
  type        = string
  sensitive   = true
  # Sera fourni via les secrets GitHub Actions.
}

variable "repo_owner" {
  description = "Propriétaire du repository GitHub (votre nom d'utilisateur ou organisation)."
  type        = string
  # Sera fourni via les secrets GitHub Actions ou une variable d'environnement.
}

variable "repo_name" {
  description = "Nom du repository GitHub."
  type        = string
  # Sera fourni via les secrets GitHub Actions ou une variable d'environnement.
}

variable "ssh_private_key_path" {
  description = "Chemin vers la clé privée SSH pour se connecter aux instances EC2."
  type        = string
  default     = "~/.ssh/id_rsa"
  # Cette valeur par défaut sera remplacée par le chemin réel dans le workflow GitHub Actions.
}

variable "ssh_private_key_content" {
  description = "Contenu de la clé privée SSH pour se connecter aux instances EC2. Si fourni, remplace ssh_private_key_path."
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssh_public_key" {
  description = "Contenu de la clé publique SSH à installer sur les instances EC2."
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_provisioning" {
  description = "Activer ou désactiver le provisionnement automatique des instances EC2."
  type        = bool
  default     = false
}

variable "aws_access_key" {
  description = "Clé d'accès AWS pour l'authentification."
  type        = string
  sensitive   = true
  default     = "" # Valeur vide par défaut, sera fournie via les secrets GitHub Actions ou les variables d'environnement
}

variable "aws_secret_key" {
  description = "Clé secrète AWS pour l'authentification."
  type        = string
  sensitive   = true
  default     = "" # Valeur vide par défaut, sera fournie via les secrets GitHub Actions ou les variables d'environnement
}

variable "tf_api_token" {
  description = "Token d'API Terraform Cloud pour l'authentification."
  type        = string
  sensitive   = true
  # Sera fourni via les secrets GitHub Actions.
}

variable "tf_workspace_id" {
  description = "ID de l'espace de travail Terraform Cloud."
  type        = string
  # Sera fourni via les secrets GitHub Actions.
}

variable "tf_organization" {
  description = "Nom de l'organisation Terraform Cloud."
  type        = string
  default     = "yourmedia"
}

variable "grafana_admin_password" {
  description = "Mot de passe administrateur Grafana."
  type        = string
  default     = "admin"
  sensitive   = true
}



# Variables Docker Hub (minuscules)
# Ces variables sont utilisées dans Terraform et sont des alias pour les variables standard
variable "dockerhub_username" {
  description = "Alias pour DOCKERHUB_USERNAME (compatibilité Terraform)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "dockerhub_token" {
  description = "Alias pour DOCKERHUB_TOKEN (compatibilité Terraform)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "dockerhub_repo" {
  description = "Alias pour DOCKERHUB_REPO (compatibilité Terraform)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "last_rotation_date" {
  description = "Date de la dernière rotation des identifiants."
  type        = string
  default     = ""
}

# Variables Docker Hub standardisées (majuscules)
# Ces variables sont utilisées dans Terraform Cloud et les workflows GitHub Actions
# Elles sont considérées comme les variables standard pour Docker Hub

variable "DOCKERHUB_TOKEN" {
  description = "Token Docker Hub pour l'authentification (standard)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "TF_API_TOKEN" {
  description = "Token d'API Terraform Cloud pour l'authentification (version majuscule)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "AWS_ACCESS_KEY_ID" {
  description = "Clé d'accès AWS pour l'authentification (version majuscule)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "AWS_SECRET_ACCESS_KEY" {
  description = "Clé secrète AWS pour l'authentification (version majuscule)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "GITHUB_TOKEN" {
  description = "Token GitHub (PAT) pour l'authentification aux services GitHub (version majuscule)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "DB_USERNAME" {
  description = "Nom d'utilisateur pour la base de données RDS (version majuscule)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "DB_PASSWORD" {
  description = "Mot de passe pour la base de données RDS (version majuscule)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "SSH_PUBLIC_KEY" {
  description = "Contenu de la clé publique SSH à installer sur les instances EC2 (version majuscule)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "SSH_PRIVATE_KEY" {
  description = "Contenu de la clé privée SSH pour se connecter aux instances EC2 (version majuscule)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "GRAFANA_ADMIN_PASSWORD" {
  description = "Mot de passe administrateur Grafana (version majuscule)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "grafana_url" {
  description = "URL de l'interface Grafana."
  type        = string
  default     = ""
}

variable "DOCKERHUB_USERNAME" {
  description = "Nom d'utilisateur Docker Hub pour l'authentification (standard)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "DOCKERHUB_REPO" {
  description = "Nom du dépôt Docker Hub pour stocker les images (standard)."
  type        = string
  default     = ""
  sensitive   = true
}

# Variables manquantes identifiées dans les avertissements Terraform

variable "monitoring_ec2_public_ip" {
  description = "Adresse IP publique de l'instance EC2 de monitoring."
  type        = string
  default     = ""
}

variable "ec2_public_ip" {
  description = "Adresse IP publique de l'instance EC2 principale."
  type        = string
  default     = ""
}

variable "docker_username" {
  description = "Alias pour DOCKERHUB_USERNAME (compatibilité)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "docker_repo" {
  description = "Alias pour DOCKERHUB_REPO (compatibilité)."
  type        = string
  default     = ""
}

variable "rds_endpoint" {
  description = "Point de terminaison RDS (endpoint)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "TF_RDS_ENDPOINT" {
  description = "Point de terminaison RDS (endpoint) généré par Terraform."
  type        = string
  default     = ""
  sensitive   = true
}

variable "RDS_PASSWORD" {
  description = "Mot de passe pour la base de données RDS (alias)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "RDS_USERNAME" {
  description = "Nom d'utilisateur pour la base de données RDS (alias)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "AWS_DEFAULT_REGION" {
  description = "Région AWS par défaut pour les opérations."
  type        = string
  default     = "eu-west-3"
}

variable "DOCKER_USERNAME" {
  description = "Alias pour DOCKERHUB_USERNAME (compatibilité)."
  type        = string
  default     = ""
  sensitive   = true
}

# Variables supplémentaires potentiellement utilisées

variable "GITHUB_CLIENT_ID" {
  description = "ID client pour l'authentification OAuth GitHub."
  type        = string
  default     = ""
  sensitive   = true
}

variable "GITHUB_CLIENT_SECRET" {
  description = "Secret client pour l'authentification OAuth GitHub."
  type        = string
  default     = ""
  sensitive   = true
}

variable "GF_SECURITY_ADMIN_PASSWORD" {
  description = "Mot de passe administrateur Grafana (format variable d'environnement)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "EC2_SSH_PRIVATE_KEY" {
  description = "Contenu de la clé privée SSH pour les instances EC2 (format spécifique)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "TF_EC2_PUBLIC_IP" {
  description = "Adresse IP publique de l'instance EC2 générée par Terraform."
  type        = string
  default     = ""
}

variable "TF_MONITORING_EC2_PUBLIC_IP" {
  description = "Adresse IP publique de l'instance EC2 de monitoring générée par Terraform."
  type        = string
  default     = ""
}

variable "TF_S3_BUCKET_NAME" {
  description = "Nom du bucket S3 généré par Terraform."
  type        = string
  default     = ""
}

variable "s3_bucket_name" {
  description = "Nom du bucket S3 (alias pour TF_S3_BUCKET_NAME)."
  type        = string
  default     = ""
}

variable "EC2_SSH_PUBLIC_KEY" {
  description = "Contenu de la clé publique SSH pour les instances EC2 (format spécifique)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "TF_WORKSPACE_ID" {
  description = "ID de l'espace de travail Terraform Cloud (version majuscule)."
  type        = string
  default     = ""
}
