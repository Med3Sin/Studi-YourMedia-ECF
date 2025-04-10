# -----------------------------------------------------------------------------
# Security Group pour l'instance EC2 (ec2-java-tomcat)
# -----------------------------------------------------------------------------
resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-ec2-sg"
  description = "Autorise le trafic entrant pour instance EC2 SSH Tomcat Prometheus"
  vpc_id      = var.vpc_id

  tags = {
    Name    = "${var.project_name}-ec2-sg"
    Project = var.project_name
  }
}

# Règle entrante: SSH ouvert à toutes les adresses IP (pour admin et déploiement GH Actions via SSH)
resource "aws_security_group_rule" "ec2_ingress_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # Ouvert à toutes les adresses IP - ATTENTION: Moins sécurisé, à éviter en production
  security_group_id = aws_security_group.ec2_sg.id
  description       = "Allow SSH from anywhere"
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

# Règle sortante: Accès à RDS MySQL
resource "aws_security_group_rule" "ec2_egress_mysql" {
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.rds_sg.id
  security_group_id        = aws_security_group.ec2_sg.id
  description              = "Allow outbound MySQL traffic to RDS"
}

# Règle sortante: Accès aux services AWS (S3, etc.)
resource "aws_security_group_rule" "ec2_egress_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # Nécessaire pour accéder aux services AWS
  security_group_id = aws_security_group.ec2_sg.id
  description       = "Allow outbound HTTPS traffic for AWS services"
}

# Règle sortante: Accès HTTP pour téléchargements et mises à jour
resource "aws_security_group_rule" "ec2_egress_http" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # Nécessaire pour les téléchargements et mises à jour
  security_group_id = aws_security_group.ec2_sg.id
  description       = "Allow outbound HTTP traffic for downloads and updates"
}

# -----------------------------------------------------------------------------
# Security Group pour la base de données RDS (rds-mysql)
# -----------------------------------------------------------------------------
resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-rds-sg"
  description = "Autorise le trafic entrant MySQL depuis instance EC2"
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
  description              = "Allow MySQL traffic from EC2 SG"
}

# Note: RDS n'a généralement pas besoin de règles sortantes, mais nous en ajoutons une
# pour les mises à jour et la maintenance AWS
resource "aws_security_group_rule" "rds_egress_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # Nécessaire pour les services AWS
  security_group_id = aws_security_group.rds_sg.id
  description       = "Allow outbound HTTPS traffic for AWS services"
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

# Règle entrante: Grafana ouvert à toutes les adresses IP
resource "aws_security_group_rule" "ecs_ingress_grafana" {
  type              = "ingress"
  from_port         = 3000 # Port Grafana par défaut
  to_port           = 3000
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # Ouvert à toutes les adresses IP - ATTENTION: Moins sécurisé, à éviter en production
  security_group_id = aws_security_group.ecs_sg.id
  description       = "Allow Grafana access from anywhere"
}

# Règle sortante: Accès à l'EC2 pour Prometheus
resource "aws_security_group_rule" "ecs_egress_prometheus" {
  type                     = "egress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ec2_sg.id
  security_group_id        = aws_security_group.ecs_sg.id
  description              = "Allow Prometheus to scrape EC2 metrics"
}

# Règle sortante: Accès HTTPS pour télécharger des images Docker et des plugins
resource "aws_security_group_rule" "ecs_egress_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # Nécessaire pour les téléchargements
  security_group_id = aws_security_group.ecs_sg.id
  description       = "Allow outbound HTTPS traffic for downloads"
}

# Règle sortante: Accès HTTP pour télécharger des images Docker et des plugins
resource "aws_security_group_rule" "ecs_egress_http" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # Nécessaire pour les téléchargements
  security_group_id = aws_security_group.ecs_sg.id
  description       = "Allow outbound HTTP traffic for downloads"
}
