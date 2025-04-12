# -----------------------------------------------------------------------------
# Outputs du module S3
# -----------------------------------------------------------------------------

output "bucket_name" {
  description = "Nom du bucket S3 créé"
  value       = aws_s3_bucket.media_bucket.bucket
}

output "bucket_arn" {
  description = "ARN du bucket S3 créé"
  value       = aws_s3_bucket.media_bucket.arn
}

output "bucket_domain_name" {
  description = "Nom de domaine du bucket S3"
  value       = aws_s3_bucket.media_bucket.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Nom de domaine régional du bucket S3"
  value       = aws_s3_bucket.media_bucket.bucket_regional_domain_name
}
