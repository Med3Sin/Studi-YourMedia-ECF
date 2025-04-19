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

# Politique de bucket pour autoriser Amplify Hosting à lire les artefacts de build
# Note: On suppose que le build frontend est placé dans un préfixe "builds/frontend/"
data "aws_iam_policy_document" "amplify_read_policy_doc" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket" # Nécessaire pour certains processus Amplify
    ]
    resources = [
      aws_s3_bucket.media_storage.arn,                       # Accès au bucket lui-même (pour ListBucket)
      "${aws_s3_bucket.media_storage.arn}/builds/frontend/*" # Accès aux objets dans le dossier de build
    ]
    principals {
      type        = "Service"
      identifiers = ["amplify.amazonaws.com"]
    }
    # Condition pour s'assurer que la requête vient bien d'Amplify pour ce compte/région
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:amplify:${var.aws_region}:${data.aws_caller_identity.current.account_id}:apps/*"]
    }
  }
}

resource "aws_s3_bucket_policy" "amplify_read_policy" {
  bucket = aws_s3_bucket.media_storage.id
  policy = data.aws_iam_policy_document.amplify_read_policy_doc.json
}

# Téléchargement des fichiers de configuration de monitoring dans le bucket S3
# Les fichiers sont référencés depuis le module ec2-monitoring pour éviter la duplication
resource "aws_s3_object" "docker_compose_yml" {
  bucket = aws_s3_bucket.media_storage.id
  key    = "monitoring/docker-compose.yml"
  source = var.monitoring_scripts_path != "" ? "${var.monitoring_scripts_path}/docker-compose.yml" : "${path.module}/files/docker-compose.yml"
  etag   = var.monitoring_scripts_path != "" ? filemd5("${var.monitoring_scripts_path}/docker-compose.yml") : filemd5("${path.module}/files/docker-compose.yml")
}

resource "aws_s3_object" "prometheus_yml" {
  bucket = aws_s3_bucket.media_storage.id
  key    = "monitoring/prometheus.yml"
  source = var.monitoring_scripts_path != "" ? "${var.monitoring_scripts_path}/prometheus.yml" : "${path.module}/files/prometheus.yml"
  etag   = var.monitoring_scripts_path != "" ? filemd5("${var.monitoring_scripts_path}/prometheus.yml") : filemd5("${path.module}/files/prometheus.yml")
}

resource "aws_s3_object" "deploy_containers_sh" {
  bucket = aws_s3_bucket.media_storage.id
  key    = "monitoring/deploy_containers.sh"
  source = var.monitoring_scripts_path != "" ? "${var.monitoring_scripts_path}/deploy_containers.sh" : "${path.module}/files/deploy_containers.sh"
  etag   = var.monitoring_scripts_path != "" ? filemd5("${var.monitoring_scripts_path}/deploy_containers.sh") : filemd5("${path.module}/files/deploy_containers.sh")
}

resource "aws_s3_object" "fix_permissions_sh" {
  bucket = aws_s3_bucket.media_storage.id
  key    = "monitoring/fix_permissions.sh"
  source = var.monitoring_scripts_path != "" ? "${var.monitoring_scripts_path}/fix_permissions.sh" : "${path.module}/files/fix_permissions.sh"
  etag   = var.monitoring_scripts_path != "" ? filemd5("${var.monitoring_scripts_path}/fix_permissions.sh") : filemd5("${path.module}/files/fix_permissions.sh")
}

resource "aws_s3_object" "cloudwatch_config_yml" {
  bucket = aws_s3_bucket.media_storage.id
  key    = "monitoring/cloudwatch-config.yml"
  source = var.monitoring_scripts_path != "" ? "${var.monitoring_scripts_path}/cloudwatch-config.yml" : "${path.module}/files/cloudwatch-config.yml"
  etag   = var.monitoring_scripts_path != "" ? filemd5("${var.monitoring_scripts_path}/cloudwatch-config.yml") : filemd5("${path.module}/files/cloudwatch-config.yml")
}

# Téléchargement du script d'installation principal
resource "aws_s3_object" "setup_sh" {
  bucket = aws_s3_bucket.media_storage.id
  key    = "monitoring/setup.sh"
  content = templatefile("${path.module}/../ec2-monitoring/scripts/setup.sh.tpl", {
    # Utiliser des variables qui seront remplacées par le script user_data
    # Les valeurs réelles sont substituées par le script user_data de l'instance EC2
    ec2_instance_private_ip = "PLACEHOLDER_IP",
    ec2_java_tomcat_ip      = "PLACEHOLDER_IP", # Ajouter cette variable pour prometheus.yml
    db_username             = "PLACEHOLDER_USERNAME",
    db_password             = "PLACEHOLDER_PASSWORD",
    rds_endpoint            = "PLACEHOLDER_ENDPOINT",
    # Ces variables sont disponibles dans le module S3
    aws_region     = var.aws_region,
    s3_bucket_name = aws_s3_bucket.media_storage.id
  })
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
      "${aws_s3_bucket.media_storage.arn}/monitoring/*"
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
