# Configuration des Secrets GitHub

Ce document explique comment configurer les secrets GitHub pour le projet YourMedia.

## Secrets GitHub standardisés

Les secrets suivants sont considérés comme les secrets standard pour le projet YourMedia :

| Secret | Description | Utilisation |
|--------|-------------|-------------|
| `DOCKERHUB_USERNAME` | Nom d'utilisateur Docker Hub | Authentification auprès de Docker Hub |
| `DOCKERHUB_TOKEN` | Token d'authentification Docker Hub | Authentification auprès de Docker Hub |
| `DOCKERHUB_REPO` | Nom du dépôt Docker Hub | Référence aux images Docker |
| `AWS_ACCESS_KEY_ID` | Clé d'accès AWS | Authentification auprès d'AWS |
| `AWS_SECRET_ACCESS_KEY` | Clé secrète AWS | Authentification auprès d'AWS |
| `AWS_DEFAULT_REGION` | Région AWS par défaut | Configuration AWS |
| `RDS_USERNAME` | Nom d'utilisateur RDS | Connexion à la base de données |
| `RDS_PASSWORD` | Mot de passe RDS | Connexion à la base de données |
| `EC2_SSH_PRIVATE_KEY` | Clé SSH privée pour EC2 | Connexion SSH aux instances EC2 |
| `EC2_SSH_PUBLIC_KEY` | Clé SSH publique pour EC2 | Configuration des instances EC2 |
| `GF_SECURITY_ADMIN_PASSWORD` | Mot de passe administrateur Grafana | Authentification Grafana |
| `TF_API_TOKEN` | Token d'API Terraform Cloud | Authentification Terraform Cloud |
| `TF_WORKSPACE_ID` | ID de l'espace de travail Terraform Cloud | Configuration Terraform Cloud |
| `GH_PAT` | Token d'accès personnel GitHub | Téléchargement des scripts depuis GitHub |

## Configuration des secrets GitHub

Pour configurer les secrets GitHub, suivez ces étapes :

1. Accédez aux paramètres de votre dépôt GitHub
2. Cliquez sur "Settings" > "Secrets and variables" > "Actions"
3. Cliquez sur "New repository secret"
4. Ajoutez chaque secret avec son nom et sa valeur
5. Cliquez sur "Add secret" pour enregistrer

## Synchronisation avec Terraform Cloud

Le script `scripts/utils/sync-github-secrets-to-terraform.sh` synchronise automatiquement ces secrets entre GitHub et Terraform Cloud. Il crée également les variables de compatibilité nécessaires.

> **Note importante** : Le secret `GH_PAT` est particulièrement important depuis la version 2.0 du projet, car il est utilisé pour télécharger les scripts directement depuis GitHub au lieu de les stocker dans un bucket S3. Pour plus de détails sur cette nouvelle approche, consultez le document [SCRIPTS-GITHUB-APPROACH.md](SCRIPTS-GITHUB-APPROACH.md).

Pour exécuter ce script, utilisez la commande suivante :

```bash
export GITHUB_TOKEN=your_github_token
export TF_API_TOKEN=your_terraform_token
export GITHUB_REPOSITORY=your_github_repository
export TF_WORKSPACE_ID=your_terraform_workspace_id
./scripts/utils/sync-github-secrets-to-terraform.sh
```

## Variables de compatibilité

Pour maintenir la compatibilité avec les scripts existants, les variables suivantes sont également supportées :

| Variable | Alias pour | Contexte d'utilisation |
|----------|------------|------------------------|
| `DOCKER_USERNAME` | `DOCKERHUB_USERNAME` | Scripts anciens, workflows GitHub Actions |
| `DOCKER_PASSWORD` | `DOCKERHUB_TOKEN` | Scripts anciens |
| `DOCKER_REPO` | `DOCKERHUB_REPO` | Scripts anciens, workflows GitHub Actions |
| `DB_USERNAME` | `RDS_USERNAME` | Scripts anciens |
| `DB_PASSWORD` | `RDS_PASSWORD` | Scripts anciens |
| `DB_ENDPOINT` | `RDS_ENDPOINT` | Scripts anciens |

## Sécurité des secrets

Pour garantir la sécurité des secrets :

1. Utilisez des tokens avec des privilèges limités
2. Faites une rotation régulière des secrets
3. Ne partagez jamais les secrets en clair
4. Utilisez des variables d'environnement pour les scripts locaux
5. Évitez de stocker les secrets dans le code source

## Vérification des secrets configurés

Pour vérifier que les secrets sont correctement configurés, vous pouvez exécuter le workflow GitHub Actions "1-infra-deploy-destroy.yml" en mode check-only :

1. Accédez à l'onglet "Actions" de votre dépôt GitHub
2. Sélectionnez le workflow "1-infra-deploy-destroy.yml"
3. Cliquez sur "Run workflow"
4. Sélectionnez "check-only" comme action
5. Cliquez sur "Run workflow"

Le workflow vérifiera que tous les secrets nécessaires sont configurés correctement.
