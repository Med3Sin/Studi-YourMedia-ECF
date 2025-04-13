# Fichier principal Terraform pour l'infrastructure YourMédia

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

# Création d'un sous-réseau dans la zone de disponibilité eu-west-3a
resource "aws_subnet" "main_az1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-subnet-az1"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Création d'un sous-réseau dans une deuxième zone de disponibilité pour RDS
# (RDS nécessite des sous-réseaux dans au moins deux zones de disponibilité)
resource "aws_subnet" "main_az2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-subnet-az2"
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

# Association de la table de routage au deuxième sous-réseau
resource "aws_route_table_association" "main_az2" {
  subnet_id      = aws_subnet.main_az2.id
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

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region # Nécessaire pour la politique de déploiement Amplify
}

# -----------------------------------------------------------------------------
# Module Base de Données RDS MySQL
# -----------------------------------------------------------------------------
module "rds-mysql" {
  source = "./modules/rds-mysql"

  project_name          = var.project_name
  environment           = var.environment
  db_username           = var.db_username
  db_password           = var.db_password
  db_name               = var.db_name
  instance_type_rds     = var.instance_type_rds
  vpc_id                = aws_vpc.main.id
  subnet_ids            = [aws_subnet.main_az1.id, aws_subnet.main_az2.id] # Utilise deux sous-réseaux dans la même zone de disponibilité
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
  instance_type_ec2     = var.instance_type_ec2
  key_pair_name         = var.ec2_key_pair_name
  subnet_id             = aws_subnet.main_az1.id # Déploie dans le premier sous-réseau créé
  ec2_security_group_id = module.network.ec2_security_group_id
  s3_bucket_arn         = module.s3.bucket_arn # Fournir l'ARN du bucket S3
  # On pourrait passer l'endpoint RDS ici si l'application en a besoin au démarrage
}

# -----------------------------------------------------------------------------
# Module Monitoring Docker sur EC2 (Prometheus/Grafana)
# -----------------------------------------------------------------------------
module "ec2-monitoring" {
  source = "./modules/ec2-monitoring"

  project_name                 = var.project_name
  environment                  = var.environment
  aws_region                   = var.aws_region
  vpc_id                       = aws_vpc.main.id
  subnet_ids                   = [aws_subnet.main_az1.id, aws_subnet.main_az2.id] # Utilise deux sous-réseaux dans la même zone de disponibilité
  monitoring_security_group_id = module.network.monitoring_security_group_id
  ec2_instance_private_ip      = module.ec2-java-tomcat.private_ip # IP privée de l'EC2 pour Prometheus
  monitoring_task_cpu          = var.monitoring_task_cpu
  monitoring_task_memory       = var.monitoring_task_memory
  monitoring_ami_id            = "ami-0925eac45db11fef2"  # Utilisation de l'AMI Amazon Linux 2 demandée
  key_pair_name                = var.ec2_key_pair_name    # Nom de la paire de clés SSH pour l'instance EC2 de monitoring
  ssh_private_key_path         = var.ssh_private_key_path # Chemin vers la clé privée SSH
  ssh_private_key_content      = ""                      # Contenu de la clé privée SSH (vide par défaut)
  enable_provisioning          = false                    # Désactiver le provisionnement automatique
}

# -----------------------------------------------------------------------------
# Ressource AWS Amplify Hosting pour le Frontend
# -----------------------------------------------------------------------------
# Création conditionnelle de l'app Amplify en fonction de la disponibilité du token GitHub
locals {
  create_amplify_app = var.github_token != "" # Créer l'app Amplify seulement si github_token n'est pas vide
}

resource "aws_amplify_app" "frontend_app" {
  count        = local.create_amplify_app ? 1 : 0 # Créer 0 ou 1 instance en fonction de la condition
  name         = "${var.project_name}-frontend"
  repository   = "https://github.com/${var.repo_owner}/Studi-YourMedia-ECF" # URL du repo GitHub
  access_token = var.github_token                                           # Token PAT GitHub

  # Configuration du build (simple copie depuis S3 dans ce cas)
  # Amplify peut builder lui-même, mais pour suivre le plan, on build via GH Actions et on déploie depuis S3.
  # Cependant, la configuration la plus simple est de laisser Amplify builder depuis le repo.
  # On choisit cette option pour simplifier le Terraform. Le workflow GH Actions fera juste le push.
  build_spec = <<-EOT
    version: 1
    frontend:
      phases:
        preBuild:
          commands:
            - cd app-react
            - npm run amplify:install
        build:
          commands:
            - npm run build
      artifacts:
        baseDirectory: app-react/dist
        files:
          - '**/*'
      cache:
        paths:
          - app-react/node_modules/**/*
  EOT

  # Variables d'environnement pour le build Amplify si nécessaire
  # environment_variables = {
  #   EXAMPLE_VAR = "example_value"
  # }

  tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

# Branche par défaut (ex: main ou master)
resource "aws_amplify_branch" "main" {
  count       = local.create_amplify_app ? 1 : 0 # Créer seulement si l'app Amplify est créée
  app_id      = aws_amplify_app.frontend_app[0].id
  branch_name = "main" # Ou la branche principale de votre repo

  # Activer le build automatique à chaque push sur cette branche
  enable_auto_build = true

  tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

# (Optionnel) Domaine personnalisé - Non inclus pour rester simple et Free Tier
# resource "aws_amplify_domain_association" "main" {
#   app_id      = aws_amplify_app.frontend_app.id
#   domain_name = "votre.domaine.com"
#   sub_domain {
#     branch_name = aws_amplify_branch.main.branch_name
#     prefix      = "" # Pour le domaine racine
#   }
#   sub_domain {
#     branch_name = aws_amplify_branch.main.branch_name
#     prefix      = "www" # Pour le sous-domaine www
#   }
# }
