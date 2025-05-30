resource "aws_security_group" "ec2_java_tomcat" {
  name        = "ec2-java-tomcat-sg"
  description = "Security group for Java Tomcat EC2 instance"
  vpc_id      = var.vpc_id

  # Accès SSH depuis n'importe où (contrainte ECF)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access from anywhere (ECF constraint)"
  }

  # Accès HTTP pour l'application
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access for the application"
  }

  # Accès HTTPS pour l'application
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access for the application"
  }

  # Accès JMX pour le monitoring
  ingress {
    from_port   = 9404
    to_port     = 9404
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "JMX access for monitoring"
  }

  # Tous les trafics sortants autorisés
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "ec2-java-tomcat-sg"
  }
}

resource "aws_security_group" "ec2_monitoring" {
  name        = "ec2-monitoring-sg"
  description = "Security group for Monitoring EC2 instance"
  vpc_id      = var.vpc_id

  # Accès SSH depuis n'importe où (contrainte ECF)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access from anywhere (ECF constraint)"
  }

  # Accès Grafana
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Grafana access"
  }

  # Accès Prometheus
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Prometheus access"
  }

  # Accès Loki
  ingress {
    from_port   = 3100
    to_port     = 3100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Loki access"
  }

  # Accès Node Exporter
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Node Exporter access"
  }

  # Accès cAdvisor
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "cAdvisor access"
  }

  # Tous les trafics sortants autorisés
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "ec2-monitoring-sg"
  }
}

resource "aws_security_group" "rds_mysql" {
  name        = "rds-mysql-sg"
  description = "Security group for RDS MySQL instance"
  vpc_id      = var.vpc_id

  # Accès MySQL depuis les instances EC2
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_java_tomcat.id]
    description     = "MySQL access from Java Tomcat EC2"
  }

  # Tous les trafics sortants autorisés
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "rds-mysql-sg"
  }
}

# Variables nécessaires
variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
} 