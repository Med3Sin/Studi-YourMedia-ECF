# -----------------------------------------------------------------------------
# Outputs du module S3
# -----------------------------------------------------------------------------

output "bucket_name" {
  description = "Nom du bucket S3 créé"
  value       = aws_s3_bucket.media_storage.bucket
}

output "bucket_arn" {
  description = "ARN du bucket S3 créé"
  value       = aws_s3_bucket.media_storage.arn
}

output "bucket_domain_name" {
  description = "Nom de domaine du bucket S3"
  value       = aws_s3_bucket.media_storage.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Nom de domaine régional du bucket S3"
  value       = aws_s3_bucket.media_storage.bucket_regional_domain_name
}

output "monitoring_s3_access_policy_arn" {
  description = "ARN de la politique IAM pour accéder aux fichiers de configuration de monitoring dans S3"
  value       = aws_iam_policy.monitoring_s3_access.arn
}
