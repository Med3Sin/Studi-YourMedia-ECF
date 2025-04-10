# -----------------------------------------------------------------------------
# Groupe de sous-réseaux pour l'instance RDS
# -----------------------------------------------------------------------------
# Documentation AWS :
# - Groupes de sous-réseaux RDS : https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_VPC.WorkingWithRDSInstanceinaVPC.html#USER_VPC.Subnets
# - Limites et contraintes : https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_VPC.WorkingWithRDSInstanceinaVPC.html#USER_VPC.Subnets.Limitations
#
# RDS nécessite un groupe de sous-réseaux qui définit dans quels sous-réseaux
# l'instance peut être placée. Utilise les sous-réseaux fournis (ceux du VPC par défaut).
#
# IMPORTANT: Nous utilisons un nom fixe pour le groupe de sous-réseaux car:
# 1. AWS ne permet pas de changer le groupe de sous-réseaux d'une instance RDS
#    pour un autre groupe dans le même VPC
# 2. Utiliser un timestamp dans le nom créerait un nouveau groupe à chaque exécution
#    de Terraform, ce qui provoquerait une erreur lors de la mise à jour de l'instance RDS
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.project_name}-rds-subnet-group"
  subnet_ids = var.subnet_ids

  # Nous ne pouvons pas utiliser create_before_destroy ici car cela créerait un nouveau
  # groupe de sous-réseaux avant de détruire l'ancien, ce qui provoquerait un conflit de noms
  # lifecycle {
  #   create_before_destroy = true
  # }

  tags = {
    Name    = "${var.project_name}-rds-subnet-group"
    Project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# Instance de base de données RDS MySQL
# -----------------------------------------------------------------------------
# Documentation AWS :
# - RDS MySQL : https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_MySQL.html
# - Types d'instances RDS : https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.html
# - Limites Free Tier : https://aws.amazon.com/free/?all-free-tier.sort-by=item.additionalFields.SortRank&all-free-tier.sort-order=asc&awsf.Free%20Tier%20Types=tier%23always-free%7Ctier%2312months&awsf.Free%20Tier%20Categories=categories%23databases
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
