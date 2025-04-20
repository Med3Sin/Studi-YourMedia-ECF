# -----------------------------------------------------------------------------
# Outputs du module RDS MySQL
# -----------------------------------------------------------------------------

output "db_instance_endpoint" {
  description = "Endpoint de connexion à la base de données RDS MySQL"
  value       = aws_db_instance.mysql.endpoint
}

output "db_instance_port" {
  description = "Port de connexion à la base de données RDS MySQL"
  value       = aws_db_instance.mysql.port
}

output "db_instance_username" {
  description = "Nom d'utilisateur pour se connecter à la base de données RDS MySQL"
  value       = aws_db_instance.mysql.username
}

output "db_instance_name" {
  description = "Nom de la base de données initiale dans l'instance RDS"
  value       = aws_db_instance.mysql.db_name
}

# Alias pour compatibilité avec le code existant
output "rds_endpoint" {
  description = "Alias pour db_instance_endpoint"
  value       = aws_db_instance.mysql.endpoint
}

output "rds_port" {
  description = "Alias pour db_instance_port"
  value       = aws_db_instance.mysql.port
}

output "rds_username" {
  description = "Alias pour db_instance_username"
  value       = aws_db_instance.mysql.username
}

output "rds_database_name" {
  description = "Alias pour db_instance_name"
  value       = aws_db_instance.mysql.db_name
}

output "db_instance_id" {
  description = "Identifiant de l'instance RDS MySQL"
  value       = aws_db_instance.mysql.id
}

output "db_subnet_group_name" {
  description = "Nom du groupe de sous-réseaux RDS"
  value       = aws_db_subnet_group.rds_subnet_group.name
}
