# -----------------------------------------------------------------------------
# Security Group pour l'instance EC2 (ec2-java-tomcat)
# -----------------------------------------------------------------------------
resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-${var.environment}-ec2-sg"
  description = "Allows inbound traffic for EC2 instance (SSH, HTTP, Tomcat, Prometheus)"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-sg"
    Project     = var.project_name
    Environment = var.environment
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
  description       = "Allow SSH from operator IP"
}

# Règle entrante: HTTP (pour accès web standard si besoin)
resource "aws_security_group_rule" "ec2_ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # Ouvert à tous
  security_group_id = aws_security_group.ec2_sg.id
  description       = "Allow HTTP traffic"
}

# Règle entrante: Tomcat (port par défaut)
resource "aws_security_group_rule" "ec2_ingress_tomcat" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # Ouvert à tous pour l'API
  security_group_id = aws_security_group.ec2_sg.id
  description       = "Allow Tomcat traffic (API)"
}

# Règle entrante: Prometheus Actuator Endpoint (depuis le SG ECS)
resource "aws_security_group_rule" "ec2_ingress_prometheus_actuator" {
  type                     = "ingress"
  from_port                = 8080 # Le port de l'API Spring Boot
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_sg.id # Autorise depuis le SG ECS
  security_group_id        = aws_security_group.ec2_sg.id
  description              = "Allow Prometheus scrape from ECS SG"
}

# Règle sortante: Autorise tout le trafic sortant
resource "aws_security_group_rule" "ec2_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1" # Tout protocole
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2_sg.id
  description       = "Allow all outbound traffic"
}


# -----------------------------------------------------------------------------
# Security Group pour la base de données RDS (rds-mysql)
# -----------------------------------------------------------------------------
resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Allows MySQL inbound traffic from EC2 instance"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-sg"
    Project     = var.project_name
    Environment = var.environment
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
  description              = "Allow MySQL traffic from EC2 SG"
}

# Règle sortante: Autorise tout le trafic sortant (généralement pas nécessaire pour RDS, mais sans danger)
resource "aws_security_group_rule" "rds_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds_sg.id
  description       = "Allow all outbound traffic"
}


# -----------------------------------------------------------------------------
# Security Group pour les tâches ECS Fargate (ecs-monitoring)
# -----------------------------------------------------------------------------
resource "aws_security_group" "ecs_sg" {
  name        = "${var.project_name}-${var.environment}-ecs-sg"
  description = "Allows inbound traffic for Grafana and outbound for Prometheus"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-sg"
    Project     = var.project_name
    Environment = var.environment
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
  description       = "Allow Grafana access from operator IP"
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
  description       = "Allow all outbound traffic"
}
