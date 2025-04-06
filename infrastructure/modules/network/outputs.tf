output "ec2_security_group_id" {
  description = "ID du groupe de sécurité pour l'instance EC2."
  value       = aws_security_group.ec2_sg.id
}

output "rds_security_group_id" {
  description = "ID du groupe de sécurité pour l'instance RDS."
  value       = aws_security_group.rds_sg.id
}

output "ecs_security_group_id" {
  description = "ID du groupe de sécurité pour les tâches ECS Fargate."
  value       = aws_security_group.ecs_sg.id
}
