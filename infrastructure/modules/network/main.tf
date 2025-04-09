# -----------------------------------------------------------------------------
# Security Group pour l'instance EC2 (ec2-java-tomcat)
# -----------------------------------------------------------------------------
resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-ec2-sg"
  description = "Autorise le trafic entrant pour instance EC2 SSH HTTP Tomcat Prometheus" # Removed accent from 'Autorise'
  vpc_id      = var.vpc_id

  tags = {
    Name    = "${var.project_name}-ec2-sg"
    Project = var.project_name
  }
}

# Règle entrante: SSH depuis l'IP de l'opérateur (pour admin et déploiement GH Actions via SSH)
resource "aws_security_group_rule" "ec2_ingress_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.operator_ip] # Restreint à l'IP fournie
  security_group_id = aws_security_group.ec2_sg.id
  description       = "Autoriser SSH depuis l'IP de l'opérateur"
}

# Règle entrante: HTTP (pour accès web standard si besoin)
resource "aws_security_group_rule" "ec2_ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # Ouvert à tous
  security_group_id = aws_security_group.ec2_sg.id
  description       = "Autoriser le trafic HTTP"
}

# Règle entrante: Tomcat (port par défaut)
resource "aws_security_group_rule" "ec2_ingress_tomcat" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # Ouvert à tous pour l'API
  security_group_id = aws_security_group.ec2_sg.id
  description       = "Autoriser le trafic Tomcat (API)"
}

# Règle entrante: Prometheus Actuator Endpoint (depuis le SG ECS)
resource "aws_security_group_rule" "ec2_ingress_prometheus_actuator" {
  type                     = "ingress"
  from_port                = 8080 # Le port de l'API Spring Boot
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_sg.id # Autorise depuis le SG ECS
  security_group_id        = aws_security_group.ec2_sg.id
  description              = "Autoriser le scraping Prometheus depuis le SG ECS"
}

# Règle sortante: Autorise tout le trafic sortant
resource "aws_security_group_rule" "ec2_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1" # Tout protocole
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2_sg.id
  description       = "Autoriser tout le trafic sortant"
}


# -----------------------------------------------------------------------------
# Security Group pour la base de données RDS (rds-mysql)
# -----------------------------------------------------------------------------
resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-rds-sg"
  description = "Autorise le trafic entrant MySQL depuis l'instance EC2" # Removed accents from 'Autorise' and 'depuis'
  vpc_id      = var.vpc_id

  tags = {
    Name    = "${var.project_name}-rds-sg"
    Project = var.project_name
  }
}

# Règle entrante: MySQL depuis le Security Group de l'EC2
resource "aws_security_group_rule" "rds_ingress_mysql" {
  type                     = "ingress"
  from_port                = 3306 # Port MySQL par défaut
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ec2_sg.id # Autorise uniquement depuis le SG EC2
  security_group_id        = aws_security_group.rds_sg.id
  description              = "Autoriser le trafic MySQL depuis le SG EC2"
}

# Règle sortante: Autorise tout le trafic sortant (généralement pas nécessaire pour RDS, mais sans danger)
resource "aws_security_group_rule" "rds_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds_sg.id
  description       = "Autoriser tout le trafic sortant"
}


# -----------------------------------------------------------------------------
# Security Group pour les tâches ECS Fargate (ecs-monitoring)
# -----------------------------------------------------------------------------
resource "aws_security_group" "ecs_sg" {
  name        = "${var.project_name}-ecs-sg"
  description = "Autorise le trafic entrant pour Grafana et sortant pour Prometheus"
  vpc_id      = var.vpc_id

  tags = {
    Name    = "${var.project_name}-ecs-sg"
    Project = var.project_name
  }
}

# Règle entrante: Grafana (depuis l'IP de l'opérateur)
resource "aws_security_group_rule" "ecs_ingress_grafana" {
  type              = "ingress"
  from_port         = 3000 # Port Grafana par défaut
  to_port           = 3000
  protocol          = "tcp"
  cidr_blocks       = [var.operator_ip] # Restreint à l'IP fournie
  security_group_id = aws_security_group.ecs_sg.id
  description       = "Autoriser l'accès Grafana depuis l'IP de l'opérateur"
}

# Règle sortante: Autorise tout le trafic sortant
# Nécessaire pour que Prometheus puisse scraper l'EC2 et que Grafana/Prometheus puissent télécharger des images/plugins.
resource "aws_security_group_rule" "ecs_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs_sg.id
  description       = "Autoriser tout le trafic sortant"
}
