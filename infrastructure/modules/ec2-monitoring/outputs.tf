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

# Instructions pour la configuration manuelle
output "manual_setup_instructions" {
  description = "Instructions pour configurer manuellement l'instance EC2 de monitoring si le provisionnement automatique est désactivé"
  value       = var.enable_provisioning ? "Le provisionnement automatique est activé. Aucune action manuelle n'est requise." : <<-EOT
Le provisionnement automatique est désactivé. Pour configurer manuellement l'instance EC2 de monitoring :

1. Connectez-vous à l'instance EC2 via SSH : ssh ec2-user@${aws_instance.monitoring_instance.public_ip}
2. Exécutez les commandes suivantes :
   - sudo yum update -y
   - sudo amazon-linux-extras install docker -y
   - sudo systemctl start docker
   - sudo systemctl enable docker
   - sudo usermod -a -G docker ec2-user
   - sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   - sudo chmod +x /usr/local/bin/docker-compose
   - sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
   - sudo mkdir -p /opt/monitoring/prometheus-data /opt/monitoring/grafana-data
   - sudo chown -R ec2-user:ec2-user /opt/monitoring

3. Copiez les fichiers de configuration depuis votre machine locale :
   - scp ${path.module}/scripts/docker-compose.yml ec2-user@${aws_instance.monitoring_instance.public_ip}:/opt/monitoring/
   - scp ${path.module}/../../scripts/docker/prometheus/prometheus.yml ec2-user@${aws_instance.monitoring_instance.public_ip}:/opt/monitoring/
   - scp ${path.module}/../../scripts/docker-manager.sh ec2-user@${aws_instance.monitoring_instance.public_ip}:/opt/monitoring/
   - scp ${path.module}/scripts/fix_permissions.sh ec2-user@${aws_instance.monitoring_instance.public_ip}:/opt/monitoring/

4. Démarrez les conteneurs :
   - cd /opt/monitoring
   - chmod +x docker-manager.sh fix_permissions.sh
   - ./docker-manager.sh deploy monitoring
   - sudo ./fix_permissions.sh
EOT
}
