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

# Note: La politique pour autoriser l'EC2 à écrire/lire les médias
# sera attachée au rôle IAM de l'instance EC2 (créé dans le module ec2-java-tomcat)
# plutôt que définie ici dans la politique de bucket, pour une meilleure gestion.
