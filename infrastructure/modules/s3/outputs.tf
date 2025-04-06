output "bucket_name" {
  description = "Nom du bucket S3 créé."
  value       = aws_s3_bucket.media_storage.bucket
}

output "bucket_arn" {
  description = "ARN du bucket S3 créé."
  value       = aws_s3_bucket.media_storage.arn
}

output "bucket_id" {
  description = "ID (nom) du bucket S3 créé."
  value       = aws_s3_bucket.media_storage.id
}
