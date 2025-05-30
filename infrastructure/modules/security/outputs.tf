output "ec2_java_tomcat_sg_id" {
  description = "ID of the security group for Java Tomcat EC2 instance"
  value       = aws_security_group.ec2_java_tomcat.id
}

output "ec2_monitoring_sg_id" {
  description = "ID of the security group for Monitoring EC2 instance"
  value       = aws_security_group.ec2_monitoring.id
}

output "rds_mysql_sg_id" {
  description = "ID of the security group for RDS MySQL instance"
  value       = aws_security_group.rds_mysql.id
}
