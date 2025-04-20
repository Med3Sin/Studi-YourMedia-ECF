output "ec2_public_ip" {
  description = "Adresse IP publique de l'instance EC2 hébergeant le backend Java."
  value       = module.ec2-java-tomcat.public_ip
  sensitive   = true
}

output "rds_endpoint" {
  description = "Endpoint de connexion à la base de données RDS MySQL."
  value       = module.rds-mysql.db_instance_endpoint
  sensitive   = true
}

output "rds_port" {
  description = "Port de connexion à la base de données RDS MySQL."
  value       = module.rds-mysql.db_instance_port
}

output "rds_db_name" {
  description = "Nom de la base de données initiale dans l'instance RDS."
  value       = module.rds-mysql.db_instance_name
}

output "s3_bucket_name" {
  description = "Nom du bucket S3 pour le stockage des médias et des builds."
  value       = module.s3.bucket_name
}

# Note: L'output amplify_app_url a été supprimé car nous utilisons maintenant des conteneurs Docker
# pour le déploiement du frontend React Native.

output "monitoring_ec2_public_ip" {
  description = "Adresse IP publique de l'instance EC2 hébergeant Grafana et Prometheus."
  value       = module.ec2-monitoring.ec2_instance_public_ip
  sensitive   = true
}

output "grafana_url" {
  description = "URL d'accès à Grafana."
  value       = module.ec2-monitoring.grafana_url
  sensitive   = true
}

output "prometheus_url" {
  description = "URL d'accès à Prometheus."
  value       = module.ec2-monitoring.prometheus_url
  sensitive   = true
}
