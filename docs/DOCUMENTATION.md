# Documentation du Projet YourMedia

Ce document centralise toute la documentation du projet YourMedia et sert de point d'entrée unique.

## 1. Vue d'ensemble

YourMedia est un projet de migration vers le cloud AWS, conçu pour être simple, utiliser les services gratuits (Free Tier) d'AWS, et être entièrement automatisé via Terraform et GitHub Actions.

### Architecture

L'architecture repose sur AWS et utilise les services suivants :

- **Compute:** AWS EC2 (t2.micro) pour l'API backend Java et le monitoring
- **Base de données:** AWS RDS MySQL (db.t3.micro)
- **Stockage:** AWS S3 pour les médias et les artefacts de build
- **Réseau:** VPC avec sous-réseaux publics
- **Conteneurs Docker:** Pour l'application React et le monitoring (Prometheus, Grafana)

## 2. Infrastructure

L'infrastructure est gérée par Terraform et organisée en modules :

- **network:** Gestion des groupes de sécurité
- **ec2-java-tomcat:** Instance EC2 pour le backend Java
- **rds-mysql:** Base de données RDS MySQL
- **s3:** Bucket S3 pour le stockage
- **ec2-monitoring:** Instance EC2 pour le monitoring et l'application React

Pour plus de détails, consultez [INFRASTRUCTURE.md](INFRASTRUCTURE.md).

## 3. Docker

Les conteneurs Docker sont utilisés pour :

- L'application React Native Web (frontend)
- Prometheus (monitoring)
- Grafana (visualisation)
- Loki (logs)
- Promtail (collecte de logs)

Pour plus de détails, consultez [DOCKER.md](DOCKER.md).

## 4. Variables et Secrets

Le projet utilise des variables standardisées pour :

- AWS (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
- Docker Hub (DOCKERHUB_USERNAME, DOCKERHUB_TOKEN, DOCKERHUB_REPO)
- Base de données (RDS_USERNAME, RDS_PASSWORD)
- SSH (EC2_SSH_PRIVATE_KEY, EC2_SSH_PUBLIC_KEY)

Pour plus de détails, consultez [VARIABLES.md](VARIABLES.md).

## 5. Workflows GitHub Actions

Les workflows GitHub Actions automatisent :

- Le déploiement et la destruction de l'infrastructure (1-infra-deploy-destroy.yml)
- Le déploiement du backend Java (2-backend-deploy.yml)
- La construction et le déploiement des conteneurs Docker (3-docker-build-deploy.yml)
- L'analyse de sécurité (4-analyse-de-securite.yml)
- Le nettoyage des images Docker (5-docker-cleanup.yml)

## 6. Optimisations

Le projet a été optimisé pour :

- Rester dans les limites du Free Tier AWS
- Standardiser les variables
- Simplifier les scripts
- Améliorer la sécurité

Pour plus de détails, consultez [OPTIMISATIONS.md](OPTIMISATIONS.md).

## 7. Dépannage

En cas de problème, consultez [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
