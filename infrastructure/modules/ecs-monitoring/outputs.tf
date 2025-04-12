output "ec2_instance_id" {
  description = "ID de l'instance EC2 hébergeant Grafana et Prometheus."
  value       = aws_instance.monitoring_instance.id
}

output "ec2_instance_public_ip" {
  description = "Adresse IP publique de l'instance EC2 hébergeant Grafana et Prometheus."
  value       = aws_instance.monitoring_instance.public_ip
}

output "ec2_instance_private_ip" {
  description = "Adresse IP privée de l'instance EC2 hébergeant Grafana et Prometheus."
  value       = aws_instance.monitoring_instance.private_ip
}

output "grafana_url" {
  description = "URL d'accès à Grafana."
  value       = "http://${aws_instance.monitoring_instance.public_ip}:3000"
}

output "prometheus_url" {
  description = "URL d'accès à Prometheus."
  value       = "http://${aws_instance.monitoring_instance.public_ip}:9090"
}
