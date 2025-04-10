terraform {
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

  # Utilisation explicite des variables pour les identifiants AWS
  # Si les variables sont vides, Terraform cherchera les identifiants dans les variables d'environnement
  # ou dans le fichier de configuration AWS (~/.aws/credentials)
  access_key = var.aws_access_key_id != "" ? var.aws_access_key_id : null
  secret_key = var.aws_secret_access_key != "" ? var.aws_secret_access_key : null
}
