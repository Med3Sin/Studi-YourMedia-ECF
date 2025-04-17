# -----------------------------------------------------------------------------
# Outputs du module RDS MySQL
# -----------------------------------------------------------------------------

output "rds_endpoint" {
  description = "L'endpoint de connexion à l'instance RDS MySQL"
  value       = aws_db_instance.mysql.endpoint
}

output "db_instance_endpoint" {
  description = "Endpoint de connexion à la base de données RDS MySQL"
  value       = aws_db_instance.mysql.endpoint
}

output "rds_port" {
  description = "Le port de connexion à l'instance RDS MySQL"
  value       = aws_db_instance.mysql.port
}

output "db_instance_port" {
  description = "Port de connexion à la base de données RDS MySQL"
  value       = aws_db_instance.mysql.port
}

output "rds_username" {
  description = "Le nom d'utilisateur pour se connecter à l'instance RDS MySQL"
  value       = aws_db_instance.mysql.username
}

output "rds_database_name" {
  description = "Le nom de la base de données MySQL"
  value       = aws_db_instance.mysql.db_name
}

output "db_instance_name" {
  description = "Nom de la base de données initiale dans l'instance RDS"
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
