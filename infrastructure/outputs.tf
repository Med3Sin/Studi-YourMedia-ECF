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

output "amplify_app_default_domain" {
  description = "URL par défaut de l'application frontend hébergée sur Amplify."
  value       = local.create_amplify_app ? aws_amplify_app.frontend_app[0].default_domain : "Amplify app non créée (token GitHub non fourni)"
}

output "grafana_access_note" {
  description = "Note sur comment accéder à Grafana."
  value       = "Accédez à Grafana via l'IP publique de la tâche Fargate Grafana (à récupérer manuellement dans la console AWS ECS ou via CLI) sur le port 3000. Ex: http://<GRAFANA_TASK_PUBLIC_IP>:3000"
}

output "ecs_cluster_name" {
  description = "Nom du cluster ECS pour le monitoring."
  value       = module.ecs-monitoring.ecs_cluster_name
}
