output "bucket_name" {
  description = "Nom du bucket S3 contenant les fichiers de configuration de monitoring"
  value       = aws_s3_bucket.monitoring_config.id
}

output "bucket_arn" {
  description = "ARN du bucket S3 contenant les fichiers de configuration de monitoring"
  value       = aws_s3_bucket.monitoring_config.arn
}

output "s3_access_policy_arn" {
  description = "ARN de la politique IAM pour accéder au bucket S3 de configuration de monitoring"
  value       = aws_iam_policy.monitoring_s3_access.arn
}
