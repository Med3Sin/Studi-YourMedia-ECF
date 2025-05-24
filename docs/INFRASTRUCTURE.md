# Infrastructure AWS - YourMédia

Ce document décrit l'infrastructure AWS du projet YourMédia, gérée par Terraform.

## Table des matières

1. [Architecture](#architecture)
2. [Réseau](#réseau)
3. [Compute (EC2)](#compute-ec2)
4. [Base de données (RDS)](#base-de-données-rds)
5. [Stockage (S3)](#stockage-s3)
6. [Sécurité](#sécurité)
7. [Coûts](#coûts)
8. [Améliorations futures](#améliorations-futures)

## Architecture

L'infrastructure utilise les services AWS suivants :

- EC2 : Instances pour le backend Java et le monitoring
- RDS : Base de données MySQL
- S3 : Stockage des artefacts et des logs
- VPC : Réseau privé
- IAM : Gestion des accès
- CloudWatch : Monitoring AWS

## Réseau

### VPC

- Région : eu-west-3 (Paris)
- CIDR : 10.0.0.0/16
- Sous-réseaux :
  - Public : 10.0.1.0/24, 10.0.2.0/24
  - Privé : 10.0.3.0/24, 10.0.4.0/24
- NAT Gateway : 1 par AZ
- Internet Gateway : 1

### Security Groups

1. **EC2 Java/Tomcat**
   - SSH (22) : IP dynamique
   - HTTP (80) : 0.0.0.0/0
   - HTTPS (443) : 0.0.0.0/0
   - JMX (8080) : SG Monitoring

2. **EC2 Monitoring**
   - SSH (22) : IP dynamique
   - Prometheus (9090) : SG Monitoring
   - Grafana (3000) : IP dynamique
   - Loki (3100) : SG Monitoring
   - Promtail (9080) : SG Monitoring

3. **RDS MySQL**
   - MySQL (3306) : SG EC2 Java/Tomcat

## Compute (EC2)

### Instance Java/Tomcat

- Type : t2.micro
- AMI : Amazon Linux 2023
- Stockage : 8 Go gp2
- AZ : eu-west-3a
- Rôle IAM : YourMediaEC2Role
- Services :
  - Tomcat 9
  - Java 11
  - JMX Exporter

### Instance Monitoring

- Type : t2.micro
- AMI : Amazon Linux 2023
- Stockage : 8 Go gp2
- AZ : eu-west-3a
- Rôle IAM : YourMediaMonitoringRole
- Services :
  - Prometheus
  - Grafana
  - Loki
  - Promtail
  - cAdvisor
  - Node Exporter

## Base de données (RDS)

### MySQL

- Instance : db.t3.micro
- Version : 8.0
- Stockage : 20 Go gp2
- AZ : eu-west-3a
- Backup : 7 jours
- Maintenance : dimanche 03:00-04:00
- Paramètres :
  - character_set_server = utf8mb4
  - collation_server = utf8mb4_unicode_ci
  - max_connections = 100
  - innodb_buffer_pool_size = 1G

## Stockage (S3)

### Buckets

1. **yourmedia-artifacts**
   - WAR files
   - Builds React
   - Configurations

2. **yourmedia-logs**
   - Logs Tomcat
   - Logs système
   - Logs Docker

### Configuration

- Versioning : activé
- Encryption : SSE-S3
- Lifecycle :
  - Logs : 7 jours
  - Artifacts : 30 jours

## Sécurité

### IAM

1. **YourMediaEC2Role**
   - S3 : Read/Write
   - CloudWatch : Write
   - SSM : Read

2. **YourMediaMonitoringRole**
   - S3 : Read
   - CloudWatch : Write
   - SSM : Read

### Secrets

- RDS : AWS Secrets Manager
- SSH : GitHub Secrets
- Docker : GitHub Secrets

## Coûts

### Estimation mensuelle

- EC2 : ~$30
- RDS : ~$20
- S3 : ~$5
- NAT Gateway : ~$30
- Total : ~$85

### Optimisations

- Reserved Instances
- Spot Instances
- S3 Lifecycle
- RDS Backup

## Améliorations futures

1. **Haute disponibilité**
   - Multi-AZ
   - Auto Scaling
   - Load Balancer

2. **Sécurité**
   - WAF
   - Shield
   - GuardDuty

3. **Performance**
   - ElastiCache
   - CloudFront
   - RDS Read Replicas

4. **Monitoring**
   - CloudWatch Alarms
   - X-Ray
   - CloudTrail

## Ressources

- [Documentation AWS](https://docs.aws.amazon.com)
- [Documentation Terraform](https://www.terraform.io/docs)
- [Documentation MySQL](https://dev.mysql.com/doc)
- [Documentation S3](https://docs.aws.amazon.com/s3)
