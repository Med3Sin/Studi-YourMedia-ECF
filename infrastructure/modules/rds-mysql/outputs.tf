output "db_instance_endpoint" {
  description = "Endpoint de connexion à l'instance de base de données RDS."
  value       = aws_db_instance.mysql_db.endpoint
  sensitive   = true # L'endpoint peut être considéré comme sensible
}

output "db_instance_port" {
  description = "Port de connexion à l'instance de base de données RDS."
  value       = aws_db_instance.mysql_db.port
}

output "db_instance_name" {
  description = "Nom de la base de données initiale créée dans l'instance RDS."
  value       = aws_db_instance.mysql_db.db_name
}

output "db_instance_username" {
  description = "Nom d'utilisateur administrateur de l'instance RDS."
  value       = aws_db_instance.mysql_db.username
  sensitive   = true
}
