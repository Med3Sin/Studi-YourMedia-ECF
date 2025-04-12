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

# Créer des sous-réseaux si aucun n'est trouvé
resource "aws_subnet" "az1" {
  count                   = length(data.aws_subnets.default.ids) > 0 ? 0 : 1
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = cidrsubnet(data.aws_vpc.default.cidr_block, 8, 1)
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-subnet-az1"
  }
}

resource "aws_subnet" "az2" {
  count                   = length(data.aws_subnets.default.ids) > 0 ? 0 : 1
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = cidrsubnet(data.aws_vpc.default.cidr_block, 8, 2)
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-subnet-az2"
  }
}

locals {
  # Utiliser les sous-réseaux existants ou les nouveaux sous-réseaux créés
  subnet_id_az1 = length(data.aws_subnets.default.ids) > 0 ? tolist(data.aws_subnets.default.ids)[0] : aws_subnet.az1[0].id
  subnet_id_az2 = length(data.aws_subnets.default.ids) > 1 ? tolist(data.aws_subnets.default.ids)[1] : (length(data.aws_subnets.default.ids) > 0 ? tolist(data.aws_subnets.default.ids)[0] : aws_subnet.az2[0].id)
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
  subnet_ids            = [local.subnet_id_az1, local.subnet_id_az2] # Utilise deux sous-réseaux pour la haute disponibilité
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
  subnet_id             = local.subnet_id_az1 # Déploie dans le premier sous-réseau disponible
  ec2_security_group_id = module.network.ec2_security_group_id
  s3_bucket_arn         = module.s3.bucket_arn # Fournir l'ARN du bucket S3
  # On pourrait passer l'endpoint RDS ici si l'application en a besoin au démarrage
}

# -----------------------------------------------------------------------------
# Module Monitoring ECS Fargate (Prometheus/Grafana)
# -----------------------------------------------------------------------------
module "ecs-monitoring" {
  source = "./modules/ecs-monitoring"

  project_name            = var.project_name
  aws_region              = var.aws_region
  vpc_id                  = data.aws_vpc.default.id
  subnet_ids              = [local.subnet_id_az1, local.subnet_id_az2] # Utilise deux sous-réseaux pour la haute disponibilité
  ecs_security_group_id   = module.network.ecs_security_group_id
  ec2_instance_private_ip = module.ec2-java-tomcat.private_ip # IP privée de l'EC2 pour Prometheus
  ecs_task_cpu            = var.ecs_task_cpu
  ecs_task_memory         = var.ecs_task_memory
  ecs_ami_id              = "ami-0925eac45db11fef2" # Utilisation de l'AMI Amazon Linux 2 demandée
  key_pair_name           = var.ec2_key_pair_name # Utilisation de la même paire de clés que pour l'EC2 Java/Tomcat
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
  count = local.create_amplify_app ? 1 : 0 # Créer 0 ou 1 instance en fonction de la condition
  name  = "${var.project_name}-frontend"
  # Utiliser une URL de dépôt valide ou null pour créer l'application sans dépôt
  repository   = null             # Désactiver temporairement la connexion au dépôt GitHub
  access_token = var.github_token # Token PAT GitHub

  # Configuration du build (simple copie depuis S3 dans ce cas)
  # Amplify peut builder lui-même, mais pour suivre le plan, on build via GH Actions et on déploie depuis S3.
  # Cependant, la configuration la plus simple est de laisser Amplify builder depuis le repo.
  # On choisit cette option pour simplifier le Terraform. Le workflow GH Actions fera juste le push.
  # Spécifier le répertoire app-react comme répertoire de base
  build_spec = <<-EOT
    version: 1
    frontend:
      phases:
        preBuild:
          commands:
            - cd app-react
            - yarn install || npm install
        build:
          commands:
            - yarn run build || npm run build
      artifacts:
        baseDirectory: app-react/build # Dossier de sortie du build React
        files:
          - '**/*'
      cache:
        paths:
          - app-react/node_modules/**/*
  EOT

  # Variables d'environnement pour le build Amplify si nécessaire
  environment_variables = {
    NODE_ENV = "production"
  }

  # Activer la détection automatique des branches
  enable_auto_branch_creation = true
  enable_branch_auto_build    = true
  enable_branch_auto_deletion = true

  # Configuration de la branche par défaut (main)
  auto_branch_creation_patterns = ["main", "dev", "feature/*"]

  # Configuration de la branche principale
  auto_branch_creation_config {
    enable_auto_build           = true
    enable_pull_request_preview = true
    framework                   = "React"
    stage                       = "PRODUCTION"
  }

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

  # Configuration spécifique à React
  framework = "React"
  stage     = "PRODUCTION"

  # Variables d'environnement spécifiques à la branche main
  environment_variables = {
    NODE_ENV = "production"
  }

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
