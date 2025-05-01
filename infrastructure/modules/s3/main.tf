# Récupère l'identité de l'appelant (compte AWS) pour les politiques
data "aws_caller_identity" "current" {}

# Crée un nom de bucket unique en ajoutant l'ID de compte et la région
# pour éviter les conflits de noms globaux S3.
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "media_storage" {
  # Nom du bucket doit être globalement unique
  bucket = "${var.project_name}-${var.environment}-media-${data.aws_caller_identity.current.account_id}-${random_string.bucket_suffix.result}"

  # Permettre la suppression du bucket même s'il contient des objets
  force_destroy = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-media-storage"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Bloquer l'accès public par défaut pour la sécurité
resource "aws_s3_bucket_public_access_block" "media_storage_public_access" {
  bucket = aws_s3_bucket.media_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Activer le versioning pour la récupération de fichiers
resource "aws_s3_bucket_versioning" "media_storage_versioning" {
  bucket = aws_s3_bucket.media_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

# (Optionnel mais recommandé) Chiffrement côté serveur par défaut
resource "aws_s3_bucket_server_side_encryption_configuration" "media_storage_encryption" {
  bucket = aws_s3_bucket.media_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Configuration du cycle de vie pour nettoyer automatiquement les anciens objets
resource "aws_s3_bucket_lifecycle_configuration" "media_storage_lifecycle" {
  bucket = aws_s3_bucket.media_storage.id

  # Ajouter une dépendance explicite pour s'assurer que le bucket est créé avant la configuration du cycle de vie
  depends_on = [aws_s3_bucket.media_storage, aws_s3_bucket_versioning.media_storage_versioning]

  # Règle pour les builds temporaires
  rule {
    id     = "cleanup-old-builds"
    status = "Enabled"

    # Préfixe pour les fichiers de build
    filter {
      prefix = "builds/"
    }

    # Expiration des objets après 30 jours
    expiration {
      days = 30
    }

    # Suppression des versions précédentes après 7 jours
    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }

  # Règle pour les fichiers WAR déployés
  rule {
    id     = "cleanup-old-wars"
    status = "Enabled"

    # Préfixe pour les fichiers WAR
    filter {
      prefix = "deploy/"
    }

    # Expiration des objets après 60 jours
    expiration {
      days = 60
    }

    # Suppression des versions précédentes après 14 jours
    noncurrent_version_expiration {
      noncurrent_days = 14
    }
  }
}



# Téléchargement des fichiers de configuration et des scripts dans le bucket S3

# Scripts de monitoring
resource "aws_s3_object" "monitoring_setup_script" {
  bucket = aws_s3_bucket.media_storage.id
  key    = "scripts/ec2-monitoring/setup-monitoring.sh"
  source = "${var.scripts_base_path}/scripts/ec2-monitoring/setup-monitoring.sh"
}

resource "aws_s3_object" "monitoring_init_script" {
  bucket = aws_s3_bucket.media_storage.id
  key    = "scripts/ec2-monitoring/init-monitoring.sh"
  source = "${var.scripts_base_path}/scripts/ec2-monitoring/init-monitoring.sh"
}

resource "aws_s3_object" "monitoring_docker_compose" {
  bucket = aws_s3_bucket.media_storage.id
  key    = "scripts/ec2-monitoring/docker-compose.yml"
  source = "${var.scripts_base_path}/scripts/ec2-monitoring/docker-compose.yml"
}

# Scripts Java/Tomcat
resource "aws_s3_object" "java_tomcat_setup_script" {
  bucket = aws_s3_bucket.media_storage.id
  key    = "scripts/ec2-java-tomcat/setup-java-tomcat.sh"
  source = "${var.scripts_base_path}/scripts/ec2-java-tomcat/setup-java-tomcat.sh"
}

resource "aws_s3_object" "java_tomcat_init_script" {
  bucket = aws_s3_bucket.media_storage.id
  key    = "scripts/ec2-java-tomcat/init-java-tomcat.sh"
  source = "${var.scripts_base_path}/scripts/ec2-java-tomcat/init-java-tomcat.sh"
}

resource "aws_s3_object" "deploy_war_script" {
  bucket = aws_s3_bucket.media_storage.id
  key    = "scripts/ec2-java-tomcat/deploy-war.sh"
  source = "${var.scripts_base_path}/scripts/ec2-java-tomcat/deploy-war.sh"
}

# Scripts Docker
resource "aws_s3_object" "docker_manager_script" {
  bucket = aws_s3_bucket.media_storage.id
  key    = "scripts/utils/docker-manager.sh"
  source = "${var.scripts_base_path}/scripts/utils/docker-manager.sh"
}

# Création du fichier JSON pour stocker les variables d'environnement sensibles
resource "local_file" "env_json" {
  content = jsonencode({
    RDS_USERNAME           = var.rds_username
    RDS_PASSWORD           = var.rds_password
    RDS_ENDPOINT           = var.rds_endpoint
    RDS_NAME               = var.rds_name
    GRAFANA_ADMIN_PASSWORD = var.grafana_admin_password
    S3_BUCKET_NAME         = aws_s3_bucket.media_storage.bucket
    AWS_REGION             = var.aws_region
  })
  filename = "${path.module}/env.json"
}

# Upload du fichier JSON vers S3
resource "aws_s3_object" "env_json" {
  bucket                 = aws_s3_bucket.media_storage.id
  key                    = "secrets/env.json"
  source                 = local_file.env_json.filename
  server_side_encryption = "AES256"
  depends_on             = [local_file.env_json]
}

# Nettoyage du fichier local après l'upload
resource "null_resource" "cleanup" {
  provisioner "local-exec" {
    command = "rm -f ${path.module}/env.json"
  }
  depends_on = [aws_s3_object.env_json]
}

# Politique IAM pour permettre à l'instance EC2 de monitoring d'accéder aux fichiers de configuration
data "aws_iam_policy_document" "monitoring_s3_access" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.media_storage.arn,
      "${aws_s3_bucket.media_storage.arn}/scripts/*"
    ]
  }
}

resource "aws_iam_policy" "monitoring_s3_access" {
  name        = "${var.project_name}-${var.environment}-monitoring-s3-access"
  description = "Permet à l'instance EC2 de monitoring d'accéder aux fichiers de configuration dans S3"
  policy      = data.aws_iam_policy_document.monitoring_s3_access.json
}

# Note: La politique pour autoriser l'EC2 à écrire/lire les médias
# sera attachée au rôle IAM de l'instance EC2 (créé dans le module ec2-java-tomcat)
# plutôt que définie ici dans la politique de bucket, pour une meilleure gestion.
