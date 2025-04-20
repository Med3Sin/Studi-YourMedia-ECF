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

# Informations sur la rotation des secrets
output "secret_rotation_info" {
  value = {
    rotation_enabled = true
    rotation_days    = var.secret_rotation_days
    next_rotation    = timeadd(time_rotating.secret_rotation.id, "${var.secret_rotation_days * 24}h")
    last_rotation    = time_rotating.secret_rotation.id
  }
  description = "Informations sur la rotation automatique des secrets"
}

# Informations sur les notifications
output "notification_info" {
  value = {
    notifications_enabled = var.enable_rotation_notifications
    notification_email   = var.notification_email != "" ? var.notification_email : "Non configuré"
    sns_topic_arn        = var.enable_rotation_notifications ? try(aws_sns_topic.secret_rotation_notification[0].arn, "Non créé") : "Désactivé"
  }
  description = "Informations sur les notifications de rotation des secrets"
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
