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
# Note: Les ressources aws_s3_object ont été commentées car les fichiers n'existent pas encore
# Ils seront créés et uploadés manuellement ou via un script séparé

# Exemple de ressource aws_s3_object (commentée pour validation)
# resource "aws_s3_object" "example" {
#   bucket = aws_s3_bucket.media_storage.id
#   key    = "example.txt"
#   content = "Contenu d'exemple"
# }

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
