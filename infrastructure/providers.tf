# Configuration du backend distant (Terraform Cloud)
# Le backend distant permet de stocker l'état Terraform de manière sécurisée
# et de permettre le travail collaboratif sur l'infrastructure
terraform {
  backend "remote" {
    # Organisation dans Terraform Cloud
    organization = "Med3Sin"

    # Configuration du workspace
    # Un workspace est un environnement isolé pour gérer un ensemble de ressources
    workspaces {
      name = "Med3Sin"
    }
  }

  # Définition des providers requis
  # Les providers sont des plugins qui permettent d'interagir avec les APIs des services cloud
  required_providers {
    # Provider AWS pour gérer les ressources AWS
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Version 5.x du provider AWS
    }
  }

  # Version minimale de Terraform requise
  required_version = ">= 1.0"
}

# Configuration du provider AWS
# Le provider AWS permet d'interagir avec les services AWS
provider "aws" {
  # Région AWS où seront déployées les ressources
  # Cette variable est définie dans variables.tf
  region = var.aws_region
  # Les credentials (AWS_ACCESS_KEY_ID et AWS_SECRET_ACCESS_KEY)
  # seront automatiquement récupérés depuis les variables d'environnement
  # ou les secrets configurés dans GitHub Actions.
} 