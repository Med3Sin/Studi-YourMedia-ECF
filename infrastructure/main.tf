# Fichier principal Terraform pour l'infrastructure YourMédia

# -----------------------------------------------------------------------------
# Récupération des informations du VPC par défaut
# -----------------------------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

# Récupérer tous les sous-réseaux du VPC par défaut
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Récupérer les détails du premier sous-réseau
data "aws_subnet" "default_az1" {
  id = element(tolist(data.aws_subnets.default.ids), 0)
}

# Récupérer les détails du deuxième sous-réseau (s'il existe)
data "aws_subnet" "default_az2" {
  id = element(tolist(data.aws_subnets.default.ids), 1 % length(data.aws_subnets.default.ids))
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

  project_name          = var.project_name
  db_username           = var.db_username
  db_password           = var.db_password
  instance_type_rds     = var.instance_type_rds
  vpc_id                = data.aws_vpc.default.id
  subnet_ids            = [data.aws_subnet.default_az1.id, data.aws_subnet.default_az2.id] # Utilise deux sous-réseaux pour la haute disponibilité
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
  subnet_id             = data.aws_subnet.default_az1.id # Déploie dans le sous-réseau par défaut de la première zone de disponibilité
  ec2_security_group_id = module.network.ec2_security_group_id
  s3_bucket_arn         = module.s3.bucket_arn # Fournir l'ARN du bucket S3
  # On pourrait passer l'endpoint RDS ici si l'application en a besoin au démarrage
}

# -----------------------------------------------------------------------------
# Module Monitoring Docker sur EC2 (Prometheus/Grafana)
# -----------------------------------------------------------------------------
module "ecs-monitoring" {
  source = "./modules/ecs-monitoring"

  project_name            = var.project_name
  aws_region              = var.aws_region
  vpc_id                  = data.aws_vpc.default.id
  subnet_ids              = [data.aws_subnet.default_az1.id, data.aws_subnet.default_az2.id] # Utilise deux sous-réseaux pour la haute disponibilité
  ecs_security_group_id   = module.network.ecs_security_group_id
  ec2_instance_private_ip = module.ec2-java-tomcat.private_ip # IP privée de l'EC2 pour Prometheus
  ecs_task_cpu            = var.ecs_task_cpu
  ecs_task_memory         = var.ecs_task_memory
  ecs_ami_id              = "ami-0925eac45db11fef2"  # Utilisation de l'AMI Amazon Linux 2 demandée
  key_pair_name           = var.ec2_key_pair_name    # Nom de la paire de clés SSH pour l'instance EC2 de monitoring
  ssh_private_key_path    = var.ssh_private_key_path # Chemin vers la clé privée SSH
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
  repository   = "https://github.com/${var.repo_owner}/${var.repo_name}" # URL du repo GitHub
  access_token = var.github_token                                        # Token PAT GitHub

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
