# Module de gestion des secrets pour YourMédia
# Ce module gère les secrets générés automatiquement et les stocke dans Terraform Cloud

terraform {
  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.42.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7.0"
    }
  }
}

# Génération d'un mot de passe aléatoire pour la base de données SonarQube
resource "random_password" "sonar_jdbc_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_special      = 2
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
}

# Génération d'un mot de passe aléatoire pour l'administrateur Grafana
resource "random_password" "grafana_admin_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_special      = 2
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
}

# Stockage du mot de passe SonarQube dans Terraform Cloud
resource "tfe_variable" "sonar_jdbc_password" {
  workspace_id = var.workspace_id
  key          = "sonar_jdbc_password"
  value        = random_password.sonar_jdbc_password.result
  category     = "terraform"
  sensitive    = true
  description  = "Mot de passe généré automatiquement pour la base de données SonarQube"
}

# Stockage du nom d'utilisateur SonarQube dans Terraform Cloud
resource "tfe_variable" "sonar_jdbc_username" {
  workspace_id = var.workspace_id
  key          = "sonar_jdbc_username"
  value        = "sonar"
  category     = "terraform"
  sensitive    = false
  description  = "Nom d'utilisateur pour la base de données SonarQube"
}

# Stockage de l'URL de connexion SonarQube dans Terraform Cloud
resource "tfe_variable" "sonar_jdbc_url" {
  workspace_id = var.workspace_id
  key          = "sonar_jdbc_url"
  value        = "jdbc:postgresql://sonarqube-db:5432/sonar"
  category     = "terraform"
  sensitive    = false
  description  = "URL de connexion à la base de données SonarQube"
}

# Stockage du mot de passe administrateur Grafana dans Terraform Cloud
resource "tfe_variable" "grafana_admin_password" {
  workspace_id = var.workspace_id
  key          = "grafana_admin_password"
  value        = random_password.grafana_admin_password.result
  category     = "terraform"
  sensitive    = true
  description  = "Mot de passe généré automatiquement pour l'administrateur Grafana"
}

# Exporter les valeurs non sensibles pour une utilisation dans les workflows
output "sonar_jdbc_username" {
  value = "sonar"
  description = "Nom d'utilisateur pour la base de données SonarQube"
}

output "sonar_jdbc_url" {
  value = "jdbc:postgresql://sonarqube-db:5432/sonar"
  description = "URL de connexion à la base de données SonarQube"
}

# Exporter un message pour les valeurs sensibles
output "sensitive_values_message" {
  value = "Les valeurs sensibles (mots de passe) sont stockées dans Terraform Cloud et ne sont pas affichées ici."
  description = "Message d'information sur les valeurs sensibles"
}

# Exporter les valeurs sensibles masquées pour référence
output "sonar_jdbc_password" {
  value = sensitive(random_password.sonar_jdbc_password.result)
  description = "Mot de passe pour la base de données SonarQube (sensible)"
  sensitive = true
}

output "grafana_admin_password" {
  value = sensitive(random_password.grafana_admin_password.result)
  description = "Mot de passe pour l'administrateur Grafana (sensible)"
  sensitive = true
}
