# Infrastructure AWS - YourMedia

## Table des matières
- [Vue d'ensemble](#vue-densemble)
- [Ressources AWS](#ressources-aws)
- [Configuration Terraform](#configuration-terraform)
- [Sécurité](#sécurité)
- [Réseau](#réseau)
- [Stockage](#stockage)
- [Monitoring](#monitoring)
- [Maintenance](#maintenance)

## Vue d'ensemble

L'infrastructure YourMedia est déployée sur AWS et gérée avec Terraform. Elle comprend des instances EC2 pour les applications et le monitoring, une base de données RDS MySQL, et un bucket S3 pour le stockage des médias.

## Ressources AWS

### EC2 Instances

#### Instance Java/Tomcat
```hcl
resource "aws_instance" "app_server" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"
  subnet_id     = var.subnet_id
  key_name      = var.key_pair_name

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  vpc_security_group_ids = [var.ec2_security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name        = "${var.project_name}-${var.environment}-app-server"
    Project     = var.project_name
    Environment = var.environment
  }
}
```

#### Instance Monitoring
```hcl
resource "aws_instance" "monitoring_instance" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"
  subnet_id     = var.subnet_id
  key_name      = var.key_pair_name

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  vpc_security_group_ids = [var.monitoring_security_group_id]

  tags = {
    Name        = "${var.project_name}-${var.environment}-monitoring"
    Project     = var.project_name
    Environment = var.environment
  }
}
```

### RDS MySQL
```hcl
resource "aws_db_instance" "main" {
  identifier        = "${var.project_name}-${var.environment}-db"
  engine           = "mysql"
  engine_version   = "8.0"
  instance_class   = "db.t3.micro"
  allocated_storage = 20
  storage_type     = "gp2"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  vpc_security_group_ids = [var.rds_security_group_id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  backup_retention_period = 7
  skip_final_snapshot    = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-db"
    Project     = var.project_name
    Environment = var.environment
  }
}
```

### S3 Bucket
```hcl
resource "aws_s3_bucket" "media" {
  bucket = "${var.project_name}-${var.environment}-media"

  tags = {
    Name        = "${var.project_name}-${var.environment}-media"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "media" {
  bucket = aws_s3_bucket.media.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "media" {
  bucket = aws_s3_bucket.media.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

## Configuration Terraform

### Structure des modules
```
infrastructure/
├── modules/
│   ├── ec2-java-tomcat/
│   ├── ec2-monitoring/
│   ├── rds/
│   └── s3/
├── environments/
│   ├── dev/
│   └── prod/
└── main.tf
```

### Variables principales
```hcl
variable "project_name" {
  description = "Nom du projet"
  type        = string
  default     = "yourmedia"
}

variable "environment" {
  description = "Environnement (dev/prod)"
  type        = string
}

variable "region" {
  description = "Région AWS"
  type        = string
  default     = "eu-west-3"
}

variable "vpc_cidr" {
  description = "CIDR du VPC"
  type        = string
  default     = "10.0.0.0/16"
}
```

## Sécurité

### IAM Roles
```hcl
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_read_only" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}
```

### Security Groups
```hcl
resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-${var.environment}-app-sg"
  description = "Security group for application server"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

## Réseau

### VPC
```hcl
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc"
    Project     = var.project_name
    Environment = var.environment
  }
}
```

### Subnets
```hcl
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-public"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 2)
  availability_zone = "${var.region}a"

  tags = {
    Name        = "${var.project_name}-${var.environment}-private"
    Project     = var.project_name
    Environment = var.environment
  }
}
```

## Stockage

### RDS Storage
- Type: gp2
- Taille: 20GB
- Chiffrement: Activé
- Sauvegardes: 7 jours

### S3 Storage
- Versioning: Activé
- Chiffrement: SSE-S3
- Lifecycle: 30 jours standard, 90 jours IA

## Monitoring

### CloudWatch
- Métriques système
- Logs d'application
- Alertes

### Prometheus/Grafana
- Métriques personnalisées
- Dashboards
- Alertes

## Maintenance

### Mises à jour
- AMI: Amazon Linux 2023
- Java: 17
- Tomcat: 9
- MySQL: 8.0

### Sauvegardes
- RDS: Automatiques
- S3: Versioning
- Configuration: Terraform state

### Monitoring
- Health checks
- Métriques système
- Logs d'application
