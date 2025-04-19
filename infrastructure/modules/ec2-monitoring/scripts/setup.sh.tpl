#!/bin/bash
# Script principal de configuration pour l'instance EC2 de monitoring

# Installation de Docker
sudo amazon-linux-extras install docker -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Création des répertoires pour les volumes
sudo mkdir -p /opt/monitoring/prometheus-data
sudo mkdir -p /opt/monitoring/grafana-data
sudo chown -R ec2-user:ec2-user /opt/monitoring

# Téléchargement des fichiers de configuration depuis S3
aws s3 cp s3://${s3_bucket_name}/monitoring/prometheus.yml /opt/monitoring/
aws s3 cp s3://${s3_bucket_name}/monitoring/docker-compose.yml /opt/monitoring/
aws s3 cp s3://${s3_bucket_name}/monitoring/deploy_containers.sh /opt/monitoring/
aws s3 cp s3://${s3_bucket_name}/monitoring/fix_permissions.sh /opt/monitoring/
aws s3 cp s3://${s3_bucket_name}/monitoring/cloudwatch-config.yml /opt/monitoring/

# Remplacer les variables dans les fichiers de configuration
# Utiliser des guillemets simples pour éviter l'interprétation des variables shell
sed -i 's/\${ec2_java_tomcat_ip}/${ec2_instance_private_ip}/g' /opt/monitoring/prometheus.yml
sed -i -e 's/\${db_username}/${db_username}/g' \
       -e 's/\${db_password}/${db_password}/g' \
       -e 's/\${rds_endpoint}/${rds_endpoint}/g' /opt/monitoring/docker-compose.yml
sed -i -e 's/\${aws_region}/${aws_region}/g' \
       -e 's/\${s3_bucket_name}/${s3_bucket_name}/g' \
       -e 's/\${rds_endpoint}/${rds_endpoint}/g' /opt/monitoring/cloudwatch-config.yml

# Rendre les scripts exécutables
chmod +x /opt/monitoring/deploy_containers.sh
chmod +x /opt/monitoring/fix_permissions.sh

# Exécuter les scripts
cd /opt/monitoring
./deploy_containers.sh
sudo ./fix_permissions.sh
