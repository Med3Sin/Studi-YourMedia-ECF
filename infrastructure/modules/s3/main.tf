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

# Note: La politique de bucket pour Amplify a été supprimée car nous utilisons maintenant des conteneurs Docker
# pour le déploiement du frontend React Native au lieu d'AWS Amplify.

# Téléchargement des fichiers de configuration de monitoring dans le bucket S3
# Les fichiers sont maintenant centralisés dans le dossier scripts
resource "aws_s3_object" "docker_compose_yml" {
  bucket = aws_s3_bucket.media_storage.id
  key    = "monitoring/docker-compose.yml"
  source = "${path.module}/../../scripts/ec2-monitoring/docker-compose.yml"
  etag   = filemd5("${path.module}/../../scripts/ec2-monitoring/docker-compose.yml")
}

resource "aws_s3_object" "prometheus_yml" {
  bucket = aws_s3_bucket.media_storage.id
  key    = "monitoring/prometheus.yml"
  source = "${path.module}/../../scripts/ec2-monitoring/prometheus.yml"
  etag   = filemd5("${path.module}/../../scripts/ec2-monitoring/prometheus.yml")
}

resource "aws_s3_object" "docker_manager_sh" {
  bucket = aws_s3_bucket.media_storage.id
  key    = "monitoring/docker-manager.sh"
  source = "${path.module}/../../scripts/docker/docker-manager.sh"
  etag   = filemd5("${path.module}/../../scripts/docker/docker-manager.sh")
}

resource "aws_s3_object" "fix_permissions_sh" {
  bucket = aws_s3_bucket.media_storage.id
  key    = "monitoring/fix_permissions.sh"
  source = "${path.module}/../../scripts/ec2-monitoring/fix_permissions.sh"
  etag   = filemd5("${path.module}/../../scripts/ec2-monitoring/fix_permissions.sh")
}

resource "aws_s3_object" "cloudwatch_config_yml" {
  bucket = aws_s3_bucket.media_storage.id
  key    = "monitoring/cloudwatch-config.yml"
  source = "${path.module}/../../scripts/ec2-monitoring/cloudwatch-config.yml"
  etag   = filemd5("${path.module}/../../scripts/ec2-monitoring/cloudwatch-config.yml")
}

# Téléchargement du script d'installation principal
resource "aws_s3_object" "setup_sh" {
  bucket = aws_s3_bucket.media_storage.id
  key    = "monitoring/setup.sh"
  source = "${path.module}/../../scripts/ec2-monitoring/setup.sh"
  etag   = filemd5("${path.module}/../../scripts/ec2-monitoring/setup.sh")
}

# Téléchargement des scripts de correction des clés SSH
resource "aws_s3_object" "fix_ssh_keys_sh" {
  bucket = aws_s3_bucket.media_storage.id
  key    = "monitoring/fix-ssh-keys.sh"
  source = "${path.module}/../../scripts/utils/fix-ssh-keys.sh"
  etag   = filemd5("${path.module}/../../scripts/utils/fix-ssh-keys.sh")
}

resource "aws_s3_object" "ssh_key_checker_service" {
  bucket = aws_s3_bucket.media_storage.id
  key    = "monitoring/ssh-key-checker.service"
  source = "${path.module}/../../scripts/utils/ssh-key-checker.service"
  etag   = filemd5("${path.module}/../../scripts/utils/ssh-key-checker.service")
}

resource "aws_s3_object" "ssh_key_checker_timer" {
  bucket = aws_s3_bucket.media_storage.id
  key    = "monitoring/ssh-key-checker.timer"
  source = "${path.module}/../../scripts/utils/ssh-key-checker.timer"
  etag   = filemd5("${path.module}/../../scripts/utils/ssh-key-checker.timer")
}

# Téléchargement du script d'initialisation
resource "aws_s3_object" "init_instance_sh" {
  bucket = aws_s3_bucket.media_storage.id
  key    = "monitoring/init-instance.sh"
  source = "${path.module}/../../scripts/ec2-monitoring/init-instance.sh"
  etag   = filemd5("${path.module}/../../scripts/ec2-monitoring/init-instance.sh")
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
