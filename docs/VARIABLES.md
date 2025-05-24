# Variables - YourMédia

Ce document liste toutes les variables utilisées dans le projet YourMédia, organisées par catégorie.

## Table des matières

1. [Variables AWS](#variables-aws)
2. [Variables Docker](#variables-docker)
3. [Variables Monitoring](#variables-monitoring)
4. [Variables GitHub Actions](#variables-github-actions)
5. [Variables Terraform](#variables-terraform)

## Variables AWS

### EC2

| Variable | Description | Valeur par défaut |
|----------|-------------|-------------------|
| `aws_region` | Région AWS | `eu-west-3` |
| `instance_type` | Type d'instance EC2 | `t2.micro` |
| `ami_id` | ID de l'AMI Amazon Linux 2023 | `ami-0c55b159cbfafe1f0` |
| `volume_size` | Taille du volume EBS (Go) | `8` |
| `volume_type` | Type de volume EBS | `gp2` |
| `availability_zone` | Zone de disponibilité | `eu-west-3a` |

### RDS

| Variable | Description | Valeur par défaut |
|----------|-------------|-------------------|
| `db_instance_class` | Type d'instance RDS | `db.t3.micro` |
| `db_engine` | Moteur de base de données | `mysql` |
| `db_engine_version` | Version du moteur | `8.0` |
| `db_allocated_storage` | Stockage alloué (Go) | `20` |
| `db_name` | Nom de la base de données | `yourmedia` |
| `db_username` | Nom d'utilisateur | `admin` |
| `db_password` | Mot de passe | `changeme` |

### S3

| Variable | Description | Valeur par défaut |
|----------|-------------|-------------------|
| `s3_bucket_name` | Nom du bucket S3 | `yourmedia-artifacts` |
| `s3_versioning` | Activation du versioning | `true` |
| `s3_encryption` | Type de chiffrement | `AES256` |
| `s3_lifecycle_days` | Jours de rétention | `30` |

## Variables Docker

### Java/Tomcat

| Variable | Description | Valeur par défaut |
|----------|-------------|-------------------|
| `tomcat_version` | Version de Tomcat | `9.0.65` |
| `java_version` | Version de Java | `11` |
| `tomcat_user` | Utilisateur Tomcat | `tomcat` |
| `tomcat_group` | Groupe Tomcat | `tomcat` |
| `tomcat_port` | Port Tomcat | `8080` |
| `tomcat_ajp_port` | Port AJP | `8009` |

### Monitoring

| Variable | Description | Valeur par défaut |
|----------|-------------|-------------------|
| `prometheus_version` | Version de Prometheus | `2.45.0` |
| `grafana_version` | Version de Grafana | `10.0.0` |
| `loki_version` | Version de Loki | `2.8.0` |
| `promtail_version` | Version de Promtail | `2.8.0` |
| `node_exporter_version` | Version de Node Exporter | `1.6.1` |

## Variables Monitoring

### Prometheus

| Variable | Description | Valeur par défaut |
|----------|-------------|-------------------|
| `prometheus_retention_time` | Période de rétention | `15d` |
| `prometheus_scrape_interval` | Intervalle de scraping | `15s` |
| `prometheus_evaluation_interval` | Intervalle d'évaluation | `15s` |

### Grafana

| Variable | Description | Valeur par défaut |
|----------|-------------|-------------------|
| `grafana_admin_user` | Utilisateur admin | `admin` |
| `grafana_admin_password` | Mot de passe admin | `changeme` |
| `grafana_port` | Port Grafana | `3000` |

### Loki

| Variable | Description | Valeur par défaut |
|----------|-------------|-------------------|
| `loki_retention_period` | Période de rétention | `168h` |
| `loki_port` | Port Loki | `3100` |

### Promtail

| Variable | Description | Valeur par défaut |
|----------|-------------|-------------------|
| `promtail_port` | Port Promtail | `9080` |
| `promtail_positions_file` | Fichier de positions | `/var/lib/promtail/positions.yaml` |

## Variables GitHub Actions

### Déploiement

| Variable | Description | Valeur par défaut |
|----------|-------------|-------------------|
| `AWS_ACCESS_KEY_ID` | Clé d'accès AWS | - |
| `AWS_SECRET_ACCESS_KEY` | Clé secrète AWS | - |
| `AWS_REGION` | Région AWS | `eu-west-3` |
| `EC2_HOST` | Host EC2 | - |
| `EC2_USERNAME` | Utilisateur EC2 | `ec2-user` |
| `SSH_PRIVATE_KEY` | Clé SSH privée | - |

### Build

| Variable | Description | Valeur par défaut |
|----------|-------------|-------------------|
| `JAVA_VERSION` | Version de Java | `11` |
| `NODE_VERSION` | Version de Node.js | `18` |
| `MAVEN_OPTS` | Options Maven | `-Xmx2048m` |

## Variables Terraform

### Général

| Variable | Description | Valeur par défaut |
|----------|-------------|-------------------|
| `environment` | Environnement | `dev` |
| `project_name` | Nom du projet | `yourmedia` |
| `tags` | Tags AWS | `{}` |

### Réseau

| Variable | Description | Valeur par défaut |
|----------|-------------|-------------------|
| `vpc_cidr` | CIDR du VPC | `10.0.0.0/16` |
| `public_subnet_cidr` | CIDR du subnet public | `10.0.1.0/24` |
| `private_subnet_cidr` | CIDR du subnet privé | `10.0.2.0/24` |

## Ressources

- [Documentation AWS Variables](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html)
- [Documentation Docker Environment Variables](https://docs.docker.com/compose/environment-variables)
- [Documentation GitHub Actions Variables](https://docs.github.com/en/actions/learn-github-actions/variables)
- [Documentation Terraform Variables](https://www.terraform.io/language/values/variables)
