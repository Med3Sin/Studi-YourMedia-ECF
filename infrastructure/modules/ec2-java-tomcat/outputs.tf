# -----------------------------------------------------------------------------
# Outputs du module EC2 Java Tomcat
# -----------------------------------------------------------------------------

output "instance_id" {
  description = "ID de l'instance EC2 hébergeant Java et Tomcat"
  value       = aws_instance.ec2_instance.id
}

output "public_ip" {
  description = "Adresse IP publique de l'instance EC2"
  value       = aws_instance.ec2_instance.public_ip
}

output "private_ip" {
  description = "Adresse IP privée de l'instance EC2"
  value       = aws_instance.ec2_instance.private_ip
}

output "tomcat_url" {
  description = "URL d'accès à Tomcat"
  value       = "http://${aws_instance.ec2_instance.public_ip}:8080"
}
