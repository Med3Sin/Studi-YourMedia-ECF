terraform {
  # Commenté pour permettre l'exécution en mode local
  # cloud {
  #   organization = "Med3Sin"
  #   workspaces {
  #     name = "Med3Sin-CLI"
  #   }
  # }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Utilise une version récente du provider AWS
    }
  }

  required_version = ">= 1.0" # Version minimale de Terraform
}

provider "aws" {
  region     = var.aws_region # La région AWS sera définie via une variable
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}
