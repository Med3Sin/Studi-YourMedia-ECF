output "ec2_security_group_id" {
  description = "ID du groupe de sécurité pour l'instance EC2 Java/Tomcat."
  value       = aws_security_group.ec2_sg.id
}

output "rds_security_group_id" {
  description = "ID du groupe de sécurité pour l'instance RDS MySQL."
  value       = aws_security_group.rds_sg.id
}

output "monitoring_security_group_id" {
  description = "ID du groupe de sécurité pour l'instance EC2 de monitoring."
  value       = aws_security_group.monitoring_sg.id
}
