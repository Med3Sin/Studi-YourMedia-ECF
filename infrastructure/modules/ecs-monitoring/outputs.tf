output "ecs_cluster_name" {
  description = "Nom du cluster ECS créé pour le monitoring."
  value       = aws_ecs_cluster.monitoring_cluster.name
}

output "prometheus_service_name" {
  description = "Nom du service ECS pour Prometheus."
  value       = aws_ecs_service.prometheus_service.name
}

output "grafana_service_name" {
  description = "Nom du service ECS pour Grafana."
  value       = aws_ecs_service.grafana_service.name
}

output "cloudwatch_log_group_name" {
  description = "Nom du groupe de logs CloudWatch pour les tâches ECS."
  value       = aws_cloudwatch_log_group.ecs_logs.name
}

# Note: L'accès à Grafana se fera via l'IP publique de la tâche Fargate Grafana.
# Cette IP doit être récupérée manuellement depuis la console AWS (ECS -> Cluster -> Service Grafana -> Tâches -> Cliquer sur la tâche -> Network -> Public IP)
# ou via l'AWS CLI après le déploiement. L'URL sera http://<IP_PUBLIQUE_GRAFANA>:3000
