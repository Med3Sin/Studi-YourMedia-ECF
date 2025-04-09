# Configuration du backend Terraform Cloud pour un stockage sécurisé de l'état
# L'authentification se fait via le token API Terraform Cloud (TF_API_TOKEN)
# Les variables sont stockées dans les secrets GitHub

terraform {
  cloud {
    organization = "Med3Sin"
    workspaces {
      name = "Med3Sin"
    }
  }
}
