# Fichier principal Terraform pour l'infrastructure YourMédia

# Configuration du provider Terraform Cloud pour la gestion des secrets
provider "tfe" {
  token = var.tf_api_token
}

# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
locals {
  # Définition des tags communs pour toutes les ressources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# -----------------------------------------------------------------------------
# Création d'un VPC dédié au projet
# -----------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Création d'un sous-réseau principal dans la zone de disponibilité eu-west-3a
resource "aws_subnet" "main_az1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-subnet-primary"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Création d'un deuxième sous-réseau dans la même zone de disponibilité (eu-west-3a)
resource "aws_subnet" "main_az1_secondary" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-subnet-secondary"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Création d'un sous-réseau dans une deuxième zone de disponibilité uniquement pour RDS
# (RDS nécessite des sous-réseaux dans au moins deux zones de disponibilité)
resource "aws_subnet" "rds_az2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-subnet-rds-az2"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Création d'une Internet Gateway pour permettre l'accès à Internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-igw"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Création d'une table de routage pour le VPC
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-rt"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Association de la table de routage au premier sous-réseau
resource "aws_route_table_association" "main_az1" {
  subnet_id      = aws_subnet.main_az1.id
  route_table_id = aws_route_table.main.id
}

# Association de la table de routage au deuxième sous-réseau (dans la même AZ)
resource "aws_route_table_association" "main_az1_secondary" {
  subnet_id      = aws_subnet.main_az1_secondary.id
  route_table_id = aws_route_table.main.id
}

# Association de la table de routage au sous-réseau RDS dans la deuxième AZ
resource "aws_route_table_association" "rds_az2" {
  subnet_id      = aws_subnet.rds_az2.id
  route_table_id = aws_route_table.main.id
}

# -----------------------------------------------------------------------------
# Module Réseau (Gestion des Security Groups)
# -----------------------------------------------------------------------------
module "network" {
  source = "./modules/network"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = aws_vpc.main.id
  operator_ip  = var.operator_ip
}

# -----------------------------------------------------------------------------
# Module Stockage S3
# -----------------------------------------------------------------------------
module "s3" {
  source = "./modules/s3"

  project_name            = var.project_name
  environment             = var.environment
  aws_region              = var.aws_region
  monitoring_scripts_path = "${path.module}/scripts" # Chemin vers les scripts
  scripts_base_path       = path.root                # Chemin absolu vers la racine du projet
}

# -----------------------------------------------------------------------------
# Module Base de Données RDS MySQL
# -----------------------------------------------------------------------------
module "rds-mysql" {
  source = "./modules/rds-mysql"

  project_name          = var.project_name
  environment           = var.environment
  aws_region            = var.aws_region
  db_username           = var.db_username
  db_password           = var.db_password
  db_name               = var.db_name
  instance_type_rds     = var.instance_type_rds
  vpc_id                = aws_vpc.main.id
  subnet_ids            = [aws_subnet.main_az1.id, aws_subnet.rds_az2.id] # Utilise un sous-réseau dans chaque zone de disponibilité (requis par RDS)
  rds_security_group_id = module.network.rds_security_group_id
}

# -----------------------------------------------------------------------------
# Module Compute EC2 (Java/Tomcat)
# -----------------------------------------------------------------------------
module "ec2-java-tomcat" {
  source = "./modules/ec2-java-tomcat"

  project_name          = var.project_name
  environment           = var.environment
  ami_id                = var.ami_id
  use_latest_ami        = var.use_latest_ami
  instance_type_ec2     = var.instance_type_ec2
  key_pair_name         = var.ec2_key_pair_name
  subnet_id             = aws_subnet.main_az1.id # Déploie dans le premier sous-réseau créé
  ec2_security_group_id = module.network.ec2_security_group_id
  ssh_public_key        = var.ssh_public_key # Clé SSH publique pour l'accès à l'instance
  aws_region            = var.aws_region

  # Variables pour GitHub
  repo_owner = var.repo_owner
  repo_name  = var.repo_name

  # Dépendances explicites
  depends_on = [
    module.s3
  ]
}

# Le module S3 existant est utilisé pour stocker les fichiers de configuration de monitoring
# Les scripts sont définis dans le module ec2-monitoring/scripts et sont référencés par le module S3
# pour éviter la duplication. Les scripts sont également utilisés directement dans le script d'initialisation
# de l'instance EC2 de monitoring.

# -----------------------------------------------------------------------------
# Module Monitoring Docker sur EC2 (Prometheus/Grafana)
# -----------------------------------------------------------------------------
module "ec2-monitoring" {
  source = "./modules/ec2-monitoring"

  project_name            = var.project_name
  environment             = var.environment
  aws_region              = var.aws_region
  vpc_id                  = aws_vpc.main.id
  subnet_ids              = [aws_subnet.main_az1.id, aws_subnet.main_az1_secondary.id]
  subnet_id               = aws_subnet.main_az1.id # Utilisation du premier sous-réseau
  ec2_instance_private_ip = module.ec2-java-tomcat.private_ip
  # Note: Les variables monitoring_task_cpu et monitoring_task_memory ont été supprimées
  # car nous utilisons maintenant des conteneurs Docker sur EC2 au lieu de ECS Fargate
  ami_id                       = "" # Laissez vide pour utiliser l'AMI la plus récente via data source
  use_latest_ami               = var.use_latest_ami
  use_existing_sg              = true                                        # Utiliser le groupe de sécurité existant
  monitoring_security_group_id = module.network.monitoring_security_group_id # ID du groupe de sécurité créé par le module network
  key_name                     = var.ec2_key_pair_name                       # Remplacé key_pair_name par key_name
  ssh_private_key_path         = var.ssh_private_key_path
  ssh_private_key_content      = var.ssh_private_key_content
  ssh_public_key               = var.ssh_public_key
  enable_provisioning          = false
  s3_bucket_name               = module.s3.bucket_name
  s3_config_policy_arn         = module.s3.monitoring_s3_access_policy_arn

  # Variables pour GitHub
  repo_owner = var.repo_owner
  repo_name  = var.repo_name

  # Dépendances explicites
  depends_on = [
    module.s3,
    module.rds-mysql,
    module.ec2-java-tomcat
  ]
}

# -----------------------------------------------------------------------------





