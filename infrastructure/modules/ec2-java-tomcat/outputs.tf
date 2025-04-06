output "public_ip" {
  description = "Adresse IP publique de l'instance EC2."
  value       = aws_instance.app_server.public_ip
}

output "private_ip" {
  description = "Adresse IP privée de l'instance EC2."
  value       = aws_instance.app_server.private_ip
}

output "instance_id" {
  description = "ID de l'instance EC2 créée."
  value       = aws_instance.app_server.id
}
