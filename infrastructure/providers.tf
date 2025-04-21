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
  # ou via les variables Terraform aws_access_key et aws_secret_key
  access_key = var.aws_access_key != "" ? var.aws_access_key : null
  secret_key = var.aws_secret_key != "" ? var.aws_secret_key : null
}
