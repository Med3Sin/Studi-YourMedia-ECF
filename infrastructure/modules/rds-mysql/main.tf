# -----------------------------------------------------------------------------
# Groupe de sous-réseaux pour l'instance RDS
# -----------------------------------------------------------------------------
# RDS nécessite un groupe de sous-réseaux qui définit dans quels sous-réseaux
# l'instance peut être placée. Utilise les sous-réseaux fournis (ceux du VPC par défaut).
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.project_name}-${var.environment}-rds-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-subnet-group"
    Project     = var.project_name
    Environment = var.environment
  }
}

# -----------------------------------------------------------------------------
# Instance RDS MySQL
# -----------------------------------------------------------------------------
resource "aws_db_instance" "mysql" {
  identifier             = "${var.project_name}-${var.environment}-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.instance_type_rds
  allocated_storage      = 20
  storage_type           = "gp2"
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  parameter_group_name   = "default.mysql8.0"
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [var.rds_security_group_id]
  publicly_accessible    = true
  skip_final_snapshot    = true
  # Pour rester dans le Free Tier AWS
  backup_retention_period = 0
  multi_az                = false
  storage_encrypted       = false

  tags = {
    Name        = "${var.project_name}-${var.environment}-mysql-db"
    Project     = var.project_name
    Environment = var.environment
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "rds_endpoint" {
  description = "L'endpoint de connexion à l'instance RDS MySQL"
  value       = aws_db_instance.mysql.endpoint
}

output "rds_port" {
  description = "Le port de connexion à l'instance RDS MySQL"
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
