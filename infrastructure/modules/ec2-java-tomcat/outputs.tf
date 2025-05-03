# -----------------------------------------------------------------------------
# Outputs du module EC2 Java Tomcat
# -----------------------------------------------------------------------------

output "instance_id" {
  description = "ID de l'instance EC2 hébergeant Java et Tomcat"
  value       = aws_instance.app_server.id
}

output "public_ip" {
  description = "Adresse IP publique de l'instance EC2"
  value       = aws_instance.app_server.public_ip
}

output "private_ip" {
  description = "Adresse IP privée de l'instance EC2"
  value       = aws_instance.app_server.private_ip
}

output "tomcat_url" {
  description = "URL d'accès à l'application Hello World Tomcat"
  value       = "http://${aws_instance.app_server.public_ip}:8080/hello-world"
}
