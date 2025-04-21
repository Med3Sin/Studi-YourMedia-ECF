terraform {
  # Configuration du backend Terraform Cloud
  cloud {
    organization = "Med3Sin"
    workspaces {
      name = "Med3Sin-CLI"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Utilise une version récente du provider AWS
    }
  }

  required_version = ">= 1.0" # Version minimale de Terraform
}

provider "aws" {
  region = var.aws_region # La région AWS sera définie via une variable
  # Les clés d'accès AWS sont fournies via les variables d'environnement AWS_ACCESS_KEY_ID et AWS_SECRET_ACCESS_KEY
  # Nous utilisons les variables d'environnement pour l'authentification AWS
}
