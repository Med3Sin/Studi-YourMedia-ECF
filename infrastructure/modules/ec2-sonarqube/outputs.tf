output "instance_id" {
  description = "ID de l'instance EC2 SonarQube"
  value       = aws_instance.sonarqube_instance.id
}

output "public_ip" {
  description = "Adresse IP publique de l'instance EC2 SonarQube"
  value       = aws_instance.sonarqube_instance.public_ip
}

output "private_ip" {
  description = "Adresse IP privée de l'instance EC2 SonarQube"
  value       = aws_instance.sonarqube_instance.private_ip
}

output "sonarqube_url" {
  description = "URL de SonarQube"
  value       = "http://${aws_instance.sonarqube_instance.public_ip}:9000"
}
