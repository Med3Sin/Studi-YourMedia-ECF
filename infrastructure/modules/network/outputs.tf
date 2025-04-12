# -----------------------------------------------------------------------------
# Outputs du module Network
# -----------------------------------------------------------------------------

output "ec2_security_group_id" {
  description = "ID du groupe de sécurité pour l'instance EC2 (ec2-java-tomcat)"
  value       = aws_security_group.ec2_sg.id
}

output "rds_security_group_id" {
  description = "ID du groupe de sécurité pour la base de données RDS (rds-mysql)"
  value       = aws_security_group.rds_sg.id
}

output "ecs_security_group_id" {
  description = "ID du groupe de sécurité pour les tâches ECS (ecs-monitoring)"
  value       = aws_security_group.ecs_sg.id
}

output "vpc_id" {
  description = "ID du VPC utilisé"
  value       = var.vpc_id
}

output "subnet_ids" {
  description = "Liste des IDs des sous-réseaux utilisés"
  value       = var.subnet_ids
}
