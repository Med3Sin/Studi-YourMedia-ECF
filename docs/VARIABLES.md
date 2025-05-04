# Gestion des Variables et Secrets - YourMedia

Ce document explique la gestion des variables et des secrets dans le projet YourMedia.

## 1. Variables standardisées

Les variables ont été standardisées dans tout le projet pour assurer la cohérence et faciliter la maintenance.

### Variables AWS

- `AWS_ACCESS_KEY_ID` - Clé d'accès AWS
- `AWS_SECRET_ACCESS_KEY` - Clé secrète AWS
- `AWS_DEFAULT_REGION` - Région AWS (par défaut: eu-west-3)

### Variables Docker Hub

- `DOCKERHUB_USERNAME` - Nom d'utilisateur Docker Hub
- `DOCKERHUB_TOKEN` - Token d'authentification Docker Hub
- `DOCKERHUB_REPO` - Nom du dépôt Docker Hub

### Variables de base de données

- `RDS_USERNAME` / `DB_USERNAME` - Nom d'utilisateur pour la base de données
- `RDS_PASSWORD` / `DB_PASSWORD` - Mot de passe pour la base de données
- `DB_NAME` - Nom de la base de données (par défaut: yourmedia)

### Variables SSH

- `EC2_SSH_PRIVATE_KEY` - Contenu de la clé SSH privée
- `EC2_SSH_PUBLIC_KEY` - Contenu de la clé SSH publique
- `EC2_KEY_PAIR_NAME` - Nom de la paire de clés EC2 dans AWS

### Variables Grafana

- `GF_SECURITY_ADMIN_PASSWORD` - Mot de passe administrateur Grafana

## 2. Secrets GitHub

Les secrets GitHub sont utilisés pour stocker les informations sensibles et les rendre disponibles aux workflows GitHub Actions.

### Configuration des secrets

1. Accédez aux paramètres de votre dépôt GitHub
2. Cliquez sur "Secrets and variables" > "Actions"
3. Cliquez sur "New repository secret"
4. Entrez le nom et la valeur du secret
5. Cliquez sur "Add secret"

### Secrets à configurer manuellement

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `RDS_USERNAME`
- `RDS_PASSWORD`
- `EC2_SSH_PRIVATE_KEY`
- `EC2_SSH_PUBLIC_KEY`
- `EC2_KEY_PAIR_NAME`
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`
- `DOCKERHUB_REPO`
- `GF_SECURITY_ADMIN_PASSWORD`

### Secrets générés automatiquement

Les secrets suivants sont créés automatiquement lors de l'exécution du workflow d'infrastructure avec l'action `apply` :

- `EC2_PUBLIC_IP` - Adresse IP publique de l'instance EC2 Java
- `S3_BUCKET_NAME` - Nom du bucket S3
- `MONITORING_EC2_PUBLIC_IP` - Adresse IP publique de l'instance EC2 de monitoring

## 3. Variables Terraform

Les variables Terraform sont définies dans le fichier `infrastructure/variables.tf` et peuvent être regroupées en plusieurs catégories :

### Variables de base

- `aws_region` - Région AWS
- `project_name` - Nom du projet
- `environment` - Environnement (dev, pre-prod, prod)

### Variables d'infrastructure

- `instance_type_ec2` - Type d'instance EC2
- `instance_type_rds` - Type d'instance RDS
- `ami_id` - ID de l'AMI à utiliser
- `use_latest_ami` - Utiliser l'AMI la plus récente

### Variables de provisionnement

- `enable_provisioning` - Activer ou désactiver le provisionnement
- `ssh_private_key_path` - Chemin vers la clé SSH privée

## 4. Bonnes pratiques

- Utilisez toujours les variables standardisées dans les scripts et les workflows
- Ne stockez jamais de secrets en clair dans le code
- Utilisez les secrets GitHub pour les informations sensibles
- Préférez les références aux variables plutôt que les valeurs codées en dur
