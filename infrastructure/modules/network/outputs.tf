# -----------------------------------------------------------------------------
# Outputs du module Network
# -----------------------------------------------------------------------------

output "ec2_security_group_id" {
  description = "ID du groupe de sécurité pour l'instance EC2 (ec2-java-tomcat)"
  value       = aws_security_group.ec2_java_tomcat.id
}

output "rds_security_group_id" {
  description = "ID du groupe de sécurité pour la base de données RDS (rds-mysql)"
  value       = aws_security_group.rds_sg.id
}

output "monitoring_security_group_id" {
  description = "ID du groupe de sécurité pour l'instance EC2 de monitoring (ec2-monitoring)"
  value       = aws_security_group.ec2_monitoring.id
}

output "vpc_id" {
  description = "ID du VPC utilisé"
  value       = var.vpc_id
}
