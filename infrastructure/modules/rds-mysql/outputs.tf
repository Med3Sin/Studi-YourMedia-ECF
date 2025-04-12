# -----------------------------------------------------------------------------
# Outputs du module RDS MySQL
# -----------------------------------------------------------------------------

output "db_instance_endpoint" {
  description = "Endpoint de connexion à la base de données RDS MySQL"
  value       = aws_db_instance.mysql_db.endpoint
}

output "db_instance_port" {
  description = "Port de connexion à la base de données RDS MySQL"
  value       = aws_db_instance.mysql_db.port
}

output "db_instance_name" {
  description = "Nom de la base de données initiale dans l'instance RDS"
  value       = aws_db_instance.mysql_db.db_name
}

output "db_instance_id" {
  description = "Identifiant de l'instance RDS MySQL"
  value       = aws_db_instance.mysql_db.id
}

output "db_subnet_group_name" {
  description = "Nom du groupe de sous-réseaux RDS"
  value       = aws_db_subnet_group.rds_subnet_group.name
}
