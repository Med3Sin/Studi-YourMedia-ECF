# -----------------------------------------------------------------------------
# Module de sécurité
# -----------------------------------------------------------------------------
# Ce module gère tous les groupes de sécurité pour l'infrastructure
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Security Group pour l'instance EC2 (ec2-java-tomcat)
# -----------------------------------------------------------------------------
resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-${var.environment}-ec2-sg"
  description = "Allows inbound traffic for EC2 instance (SSH, HTTP, Tomcat, Prometheus)"
  vpc_id      = var.vpc_id

  # Règle entrante: SSH depuis l'IP de l'opérateur
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.operator_ip]
    description = "Allow SSH from operator IP"
  }

  # Règle entrante: HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic"
  }

  # Règle entrante: Tomcat
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Tomcat traffic (API)"
  }

  # Règle sortante: Autorise tout le trafic sortant
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ec2-sg"
    }
  )
}

# -----------------------------------------------------------------------------
# Security Group pour la base de données RDS (rds-mysql)
# -----------------------------------------------------------------------------
resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Allows MySQL inbound traffic from EC2 instance"
  vpc_id      = var.vpc_id

  # Règle entrante: MySQL depuis le Security Group de l'EC2
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id, aws_security_group.monitoring_sg.id]
    description     = "Allow MySQL traffic from EC2 and Monitoring SGs"
  }

  # Règle sortante: Autorise tout le trafic sortant
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-rds-sg"
    }
  )
}

# -----------------------------------------------------------------------------
# Security Group pour l'instance EC2 de monitoring
# -----------------------------------------------------------------------------
resource "aws_security_group" "monitoring_sg" {
  name        = "${var.project_name}-${var.environment}-monitoring-sg"
  description = "Allows inbound traffic for Grafana and Prometheus"
  vpc_id      = var.vpc_id

  # Règle entrante: SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.operator_ip]
    description = "Allow SSH from operator IP"
  }

  # Règle entrante: Grafana
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Grafana access from anywhere"
  }

  # Règle entrante: Prometheus
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Prometheus access from anywhere"
  }

  # Règle entrante: Node Exporter
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Node Exporter access"
  }

  # Règle entrante: MySQL Exporter
  ingress {
    from_port   = 9104
    to_port     = 9104
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow MySQL Exporter access"
  }

  # Règle entrante: CloudWatch Exporter
  ingress {
    from_port   = 9106
    to_port     = 9106
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow CloudWatch Exporter access"
  }

  # Règle sortante: Autorise tout le trafic sortant
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-monitoring-sg"
    }
  )
}
