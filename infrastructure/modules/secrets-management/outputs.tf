# Outputs pour le module de gestion des secrets

# Exporter les valeurs non sensibles pour une utilisation dans les workflows
output "sonar_jdbc_username" {
  value       = "sonar"
  description = "Nom d'utilisateur pour la base de données SonarQube"
}

output "sonar_jdbc_url" {
  value       = "jdbc:postgresql://sonarqube-db:5432/sonar"
  description = "URL de connexion à la base de données SonarQube"
}

# Exporter un message pour les valeurs sensibles
output "sensitive_values_message" {
  value       = "Les valeurs sensibles (mots de passe) sont stockées dans Terraform Cloud et ne sont pas affichées ici."
  description = "Message d'information sur les valeurs sensibles"
}

# Exporter les valeurs sensibles masquées pour référence
output "sonar_jdbc_password" {
  value       = sensitive(random_password.sonar_jdbc_password.result)
  description = "Mot de passe pour la base de données SonarQube (sensible)"
  sensitive   = true
}

output "grafana_admin_password" {
  value       = sensitive(random_password.grafana_admin_password.result)
  description = "Mot de passe pour l'administrateur Grafana (sensible)"
  sensitive   = true
}
