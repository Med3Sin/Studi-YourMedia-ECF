# Module S3 pour stocker les fichiers de configuration de monitoring

# Récupère l'identité de l'appelant (compte AWS) pour les politiques
data "aws_caller_identity" "current" {}

# Crée un nom de bucket unique en ajoutant l'ID de compte et la région
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Bucket S3 pour stocker les fichiers de configuration de monitoring
resource "aws_s3_bucket" "monitoring_config" {
  bucket = "${var.project_name}-${var.environment}-monitoring-config-${data.aws_caller_identity.current.account_id}-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "${var.project_name}-${var.environment}-monitoring-config"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Bloquer l'accès public par défaut pour la sécurité
resource "aws_s3_bucket_public_access_block" "monitoring_config_public_access" {
  bucket = aws_s3_bucket.monitoring_config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Activer le versioning pour la récupération de fichiers
resource "aws_s3_bucket_versioning" "monitoring_config_versioning" {
  bucket = aws_s3_bucket.monitoring_config.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Chiffrement côté serveur par défaut
resource "aws_s3_bucket_server_side_encryption_configuration" "monitoring_config_encryption" {
  bucket = aws_s3_bucket.monitoring_config.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Téléchargement des fichiers de configuration dans le bucket S3
resource "aws_s3_object" "docker_compose_yml" {
  bucket = aws_s3_bucket.monitoring_config.id
  key    = "docker-compose.yml"
  source = "${path.module}/files/docker-compose.yml"
  etag   = filemd5("${path.module}/files/docker-compose.yml")
}

resource "aws_s3_object" "prometheus_yml" {
  bucket = aws_s3_bucket.monitoring_config.id
  key    = "prometheus.yml"
  source = "${path.module}/files/prometheus.yml"
  etag   = filemd5("${path.module}/files/prometheus.yml")
}

resource "aws_s3_object" "deploy_containers_sh" {
  bucket = aws_s3_bucket.monitoring_config.id
  key    = "deploy_containers.sh"
  source = "${path.module}/files/deploy_containers.sh"
  etag   = filemd5("${path.module}/files/deploy_containers.sh")
}

resource "aws_s3_object" "fix_permissions_sh" {
  bucket = aws_s3_bucket.monitoring_config.id
  key    = "fix_permissions.sh"
  source = "${path.module}/files/fix_permissions.sh"
  etag   = filemd5("${path.module}/files/fix_permissions.sh")
}

# Politique IAM pour permettre à l'instance EC2 de monitoring d'accéder au bucket
data "aws_iam_policy_document" "monitoring_s3_access" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.monitoring_config.arn,
      "${aws_s3_bucket.monitoring_config.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "monitoring_s3_access" {
  name        = "${var.project_name}-${var.environment}-monitoring-s3-access"
  description = "Permet à l'instance EC2 de monitoring d'accéder aux fichiers de configuration dans S3"
  policy      = data.aws_iam_policy_document.monitoring_s3_access.json
}
