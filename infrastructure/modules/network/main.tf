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

# Règle entrante: Prometheus Actuator Endpoint (depuis le SG Monitoring)
resource "aws_security_group_rule" "ec2_ingress_prometheus_actuator" {
  type                     = "ingress"
  from_port                = 8080 # Le port de l'API Spring Boot
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.monitoring_sg.id # Autorise depuis le SG Monitoring
  security_group_id        = aws_security_group.ec2_sg.id
  description              = "Allow Prometheus scrape from EC2 Monitoring SG"
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
# Security Group pour l'instance EC2 Docker Monitoring
# -----------------------------------------------------------------------------
resource "aws_security_group" "monitoring_sg" {
  name        = "${var.project_name}-${var.environment}-monitoring-sg"
  description = "Allows inbound traffic for Grafana, Prometheus, cAdvisor and other monitoring tools"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_name}-${var.environment}-monitoring-sg"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Règle entrante: SSH (depuis n'importe où)
resource "aws_security_group_rule" "monitoring_ingress_ssh" {
  type              = "ingress"
  from_port         = 22 # Port SSH
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # Ouvert à tous
  security_group_id = aws_security_group.monitoring_sg.id
  description       = "Allow SSH access from anywhere"
}

# Règle entrante: Grafana (depuis n'importe où)
resource "aws_security_group_rule" "monitoring_ingress_grafana" {
  type              = "ingress"
  from_port         = 3000 # Port Grafana par défaut
  to_port           = 3000
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # Ouvert à tous
  security_group_id = aws_security_group.monitoring_sg.id
  description       = "Allow Grafana access from anywhere"
}

# Règle entrante: Prometheus (depuis n'importe où)
resource "aws_security_group_rule" "monitoring_ingress_prometheus" {
  type              = "ingress"
  from_port         = 9090 # Port Prometheus par défaut
  to_port           = 9090
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # Ouvert à tous
  security_group_id = aws_security_group.monitoring_sg.id
  description       = "Allow Prometheus access from anywhere"
}

# Règle entrante: cAdvisor (depuis n'importe où)
resource "aws_security_group_rule" "monitoring_ingress_cadvisor" {
  type              = "ingress"
  from_port         = 8081 # Port cAdvisor modifié
  to_port           = 8081
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # Ouvert à tous
  security_group_id = aws_security_group.monitoring_sg.id
  description       = "Allow cAdvisor access from anywhere"
}

# Règle entrante: Application React (depuis n'importe où)
resource "aws_security_group_rule" "monitoring_ingress_react_app" {
  type              = "ingress"
  from_port         = 8080 # Port de l'application React
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # Ouvert à tous
  security_group_id = aws_security_group.monitoring_sg.id
  description       = "Allow React application access from anywhere"
}

# Règle sortante: Autorise tout le trafic sortant
# Nécessaire pour que Prometheus puisse scraper l'EC2 et que Grafana/Prometheus puissent télécharger des images/plugins.
resource "aws_security_group_rule" "monitoring_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.monitoring_sg.id
  description       = "Allow all outbound traffic"
}
