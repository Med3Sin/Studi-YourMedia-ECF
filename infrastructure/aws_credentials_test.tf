# Ce fichier est uniquement destiné à tester les identifiants AWS
# Ne pas committer ce fichier dans le dépôt Git

provider "aws" {
  region     = "eu-west-3"  # Région Paris
  # Décommentez et remplissez les lignes suivantes pour tester localement
  # access_key = "VOTRE_ACCESS_KEY_ID"
  # secret_key = "VOTRE_SECRET_ACCESS_KEY"
}

# Ressource simple pour tester l'authentification
data "aws_caller_identity" "current" {}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}
