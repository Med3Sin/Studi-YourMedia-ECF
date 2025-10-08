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
  engine_version         = "8.0.35"
  instance_class         = var.instance_type_rds
  allocated_storage      = 20
  storage_type           = "gp2"
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  parameter_group_name   = "default.mysql8.0"
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [var.rds_security_group_id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  # Spécifier explicitement la zone de disponibilité eu-west-3a pour placer RDS dans la même zone que les EC2
  availability_zone = "${var.aws_region}a"
  # Pour rester dans le Free Tier AWS
  backup_retention_period = 0
  multi_az                = false
  # Le chiffrement est compatible avec le free tier et n'entraîne pas de coûts supplémentaires
  storage_encrypted = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-mysql-db"
    Project     = var.project_name
    Environment = var.environment
  }
}
