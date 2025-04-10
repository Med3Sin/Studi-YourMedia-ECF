output "ec2_public_ip" {
  description = "Adresse IP publique de l'instance EC2 hébergeant le backend Java."
  value       = module.ec2-java-tomcat.public_ip
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

# Output supprimé pour éviter les problèmes de sensibilité
# L'URL Amplify peut être récupérée directement depuis la console AWS

output "grafana_access_note" {
  description = "Note sur comment accéder à Grafana."
  value       = "Accédez à Grafana via l'IP publique de l'instance EC2 exécutant le conteneur Grafana sur le port 3000. Ex: http://<EC2_PUBLIC_IP>:3000"
}

output "ecs_cluster_name" {
  description = "Nom du cluster ECS pour le monitoring."
  value       = module.ecs-monitoring.ecs_cluster_name
}
