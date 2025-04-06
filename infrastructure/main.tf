# Fichier principal Terraform pour l'infrastructure YourMédia

# -----------------------------------------------------------------------------
# Récupération des informations du VPC par défaut
# -----------------------------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  # On suppose que le VPC par défaut a des sous-réseaux publics
}

# -----------------------------------------------------------------------------
# Module Réseau (Gestion des Security Groups)
# -----------------------------------------------------------------------------
module "network" {
  source = "./modules/network"

  project_name = var.project_name
  vpc_id       = data.aws_vpc.default.id
  operator_ip  = var.operator_ip
}

# -----------------------------------------------------------------------------
# Module Stockage S3
# -----------------------------------------------------------------------------
module "s3" {
  source = "./modules/s3"

  project_name = var.project_name
  aws_region   = var.aws_region # Nécessaire pour la politique de déploiement Amplify
}

# -----------------------------------------------------------------------------
# Module Base de Données RDS MySQL
# -----------------------------------------------------------------------------
module "rds-mysql" {
  source = "./modules/rds-mysql"

  project_name        = var.project_name
  db_username         = var.db_username
  db_password         = var.db_password
  instance_type_rds   = var.instance_type_rds
  vpc_id              = data.aws_vpc.default.id
  subnet_ids          = data.aws_subnets.default.ids # Utilise les sous-réseaux du VPC par défaut
  rds_security_group_id = module.network.rds_security_group_id
}

# -----------------------------------------------------------------------------
# Module Compute EC2 (Java/Tomcat)
# -----------------------------------------------------------------------------
module "ec2-java-tomcat" {
  source = "./modules/ec2-java-tomcat"

  project_name          = var.project_name
  ami_id                = var.ami_id
  instance_type_ec2     = var.instance_type_ec2
  key_pair_name         = var.ec2_key_pair_name
  subnet_id             = data.aws_subnets.default.ids[0] # Déploie dans le premier sous-réseau public par défaut
  ec2_security_group_id = module.network.ec2_security_group_id
  # On pourrait passer l'endpoint RDS et le nom du bucket S3 ici si l'application en a besoin au démarrage
}

# -----------------------------------------------------------------------------
# Module Monitoring ECS Fargate (Prometheus/Grafana)
# -----------------------------------------------------------------------------
module "ecs-monitoring" {
  source = "./modules/ecs-monitoring"

  project_name            = var.project_name
  aws_region              = var.aws_region
  vpc_id                  = data.aws_vpc.default.id
  subnet_ids              = data.aws_subnets.default.ids # Utilise les sous-réseaux publics pour l'accès Grafana
  ecs_security_group_id   = module.network.ecs_security_group_id
  ec2_instance_private_ip = module.ec2-java-tomcat.private_ip # IP privée de l'EC2 pour Prometheus
  ecs_task_cpu            = var.ecs_task_cpu
  ecs_task_memory         = var.ecs_task_memory
}

# -----------------------------------------------------------------------------
# Ressource AWS Amplify Hosting pour le Frontend
# -----------------------------------------------------------------------------
resource "aws_amplify_app" "frontend_app" {
  name         = "${var.project_name}-frontend"
  repository   = "https://github.com/${var.repo_owner}/${var.repo_name}" # URL du repo GitHub
  access_token = var.github_token                                       # Token PAT GitHub

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
            - yarn install # Ou npm install
        build:
          commands:
            - yarn run build # Ou npm run build
      artifacts:
        baseDirectory: build # Ou le dossier de sortie de votre build web
        files:
          - '**/*'
      cache:
        paths:
          - node_modules/**/*
  EOT

  # Variables d'environnement pour le build Amplify si nécessaire
  # environment_variables = {
  #   EXAMPLE_VAR = "example_value"
  # }

  tags = {
    Project = var.project_name
    ManagedBy = "Terraform"
  }
}

# Branche par défaut (ex: main ou master)
resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.frontend_app.id
  branch_name = "main" # Ou la branche principale de votre repo

  # Activer le build automatique à chaque push sur cette branche
  enable_auto_build = true

  tags = {
    Project = var.project_name
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
