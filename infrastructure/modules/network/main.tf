# -----------------------------------------------------------------------------
# Security Group pour l'instance EC2 (ec2-java-tomcat)
# -----------------------------------------------------------------------------
resource "aws_security_group" "ec2_java_tomcat" {
  name        = "${var.project_name}-ec2-java-tomcat-${var.environment}"
  description = "Security group for Java/Tomcat EC2 instance"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Tomcat access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.project_name}-ec2-java-tomcat-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
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
  source_security_group_id = aws_security_group.ec2_java_tomcat.id # Autorise uniquement depuis le SG EC2
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
resource "aws_security_group" "ec2_monitoring" {
  name        = "${var.project_name}-ec2-monitoring-${var.environment}"
  description = "Security group for Monitoring EC2 instance"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Grafana access"
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Prometheus access"
  }

  ingress {
    from_port   = 3100
    to_port     = 3100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Loki access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.project_name}-ec2-monitoring-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Règle entrante: Prometheus Actuator Endpoint (depuis le SG Monitoring)
resource "aws_security_group_rule" "ec2_ingress_prometheus_actuator" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ec2_monitoring.id
  security_group_id        = aws_security_group.ec2_java_tomcat.id
  description              = "Allow Prometheus scrape from EC2 Monitoring SG"
}

# Règle entrante: Node Exporter
resource "aws_security_group_rule" "ec2_ingress_node_exporter" {
  type              = "ingress"
  from_port         = 9100
  to_port           = 9100
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2_java_tomcat.id
  description       = "Allow Node Exporter access"
}

# Règle entrante: JMX Exporter
resource "aws_security_group_rule" "ec2_ingress_jmx" {
  type              = "ingress"
  from_port         = 9404
  to_port           = 9404
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2_java_tomcat.id
  description       = "Allow JMX Exporter access"
}

# Règle entrante: cAdvisor (depuis n'importe où)
resource "aws_security_group_rule" "monitoring_ingress_cadvisor" {
  type              = "ingress"
  from_port         = 8081
  to_port           = 8081
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2_monitoring.id
  description       = "Allow cAdvisor access from anywhere"
}

# Règle entrante: Promtail (depuis n'importe où)
resource "aws_security_group_rule" "monitoring_ingress_promtail" {
  type              = "ingress"
  from_port         = 9080
  to_port           = 9080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2_monitoring.id
  description       = "Allow Promtail access from anywhere"
}

