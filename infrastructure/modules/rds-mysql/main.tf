# -----------------------------------------------------------------------------
# Groupe de sous-réseaux pour l'instance RDS
# -----------------------------------------------------------------------------
# RDS nécessite un groupe de sous-réseaux qui définit dans quels sous-réseaux
# l'instance peut être placée. Utilise les sous-réseaux fournis (ceux du VPC par défaut).
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.project_name}-rds-subnet-group-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  subnet_ids = var.subnet_ids

  # Permet de recréer la ressource avant de détruire l'ancienne
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name    = "${var.project_name}-rds-subnet-group"
    Project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# Instance de base de données RDS MySQL
# -----------------------------------------------------------------------------
resource "aws_db_instance" "mysql_db" {
  identifier        = "${var.project_name}-mysql-db" # Nom unique de l'instance RDS
  engine            = "mysql"                        # Moteur de base de données MySQL
  engine_version    = "8.0"                          # Version 8.0 compatible avec le Free Tier
  instance_class    = var.instance_type_rds          # Type d'instance défini dans les variables (db.t3.micro par défaut)
  allocated_storage = 20                             # Taille du stockage en Go (minimum pour Free Tier)
  storage_type      = "gp2"                          # Type de stockage SSD généraliste

  db_name  = "${var.project_name}db" # Nom initial de la base de données créée
  username = var.db_username         # Nom d'utilisateur défini dans les variables
  password = var.db_password         # Mot de passe défini dans les variables

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [var.rds_security_group_id]

  # --- Paramètres pour Free Tier / Simplicité ---
  multi_az                = false # Pas de Multi-AZ pour Free Tier
  publicly_accessible     = false # Non accessible publiquement pour la sécurité
  skip_final_snapshot     = true  # Ne pas créer de snapshot final à la suppression
  backup_retention_period = 0     # Désactiver les backups automatiques pour Free Tier

  tags = {
    Name    = "${var.project_name}-mysql-db"
    Project = var.project_name
  }
}
