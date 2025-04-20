# Guide des variables sensibles - YourMédia

Ce document explique comment gérer les variables sensibles dans le projet YourMédia, en utilisant les secrets GitHub.

## Table des matières

1. [Introduction](#introduction)
2. [Liste des variables sensibles](#liste-des-variables-sensibles)
3. [Configuration des secrets GitHub](#configuration-des-secrets-github)
4. [Utilisation des secrets dans les workflows](#utilisation-des-secrets-dans-les-workflows)
5. [Utilisation des secrets dans les conteneurs Docker](#utilisation-des-secrets-dans-les-conteneurs-docker)
6. [Bonnes pratiques](#bonnes-pratiques)

## Introduction

Les variables sensibles (mots de passe, tokens, clés API, etc.) ne doivent jamais être stockées en clair dans le code source. Pour gérer ces variables de manière sécurisée, nous utilisons les secrets GitHub.

## Liste des variables sensibles

### Secrets AWS

| Nom du secret | Description | Utilisé par |
|--------------|-------------|------------|
| `AWS_ACCESS_KEY_ID` | Identifiant de clé d'accès AWS | Terraform, workflows GitHub Actions |
| `AWS_SECRET_ACCESS_KEY` | Clé d'accès secrète AWS | Terraform, workflows GitHub Actions |
| `EC2_KEY_PAIR_NAME` | Nom de la paire de clés EC2 | Terraform |

### Secrets de base de données

| Nom du secret | Description | Utilisé par |
|--------------|-------------|------------|
| `DB_USERNAME` | Nom d'utilisateur de la base de données RDS | Terraform, conteneurs Docker |
| `DB_PASSWORD` | Mot de passe de la base de données RDS | Terraform, conteneurs Docker |
| `TF_RDS_ENDPOINT` | Point de terminaison de la base de données RDS | Conteneurs Docker |

### Secrets SSH

| Nom du secret | Description | Utilisé par |
|--------------|-------------|------------|
| `EC2_SSH_PRIVATE_KEY` | Clé SSH privée pour se connecter aux instances EC2 | Workflows GitHub Actions |
| `EC2_SSH_PUBLIC_KEY` | Clé SSH publique pour configurer les instances EC2 | Terraform |

### Secrets Docker Hub

| Nom du secret | Description | Utilisé par |
|--------------|-------------|------------|
| `DOCKERHUB_USERNAME` | Nom d'utilisateur Docker Hub | Workflows GitHub Actions, scripts de déploiement |
| `DOCKERHUB_TOKEN` | Token d'accès Docker Hub | Workflows GitHub Actions, scripts de déploiement |

### Secrets SonarQube

| Nom du secret | Description | Utilisé par |
|--------------|-------------|------------|
| `SONAR_TOKEN` | Token d'accès SonarQube | Workflow d'analyse SonarQube |
| `GITHUB_CLIENT_ID` | ID client OAuth GitHub pour SonarQube | Conteneur SonarQube |
| `GITHUB_CLIENT_SECRET` | Secret client OAuth GitHub pour SonarQube | Conteneur SonarQube |

### Autres secrets

| Nom du secret | Description | Utilisé par |
|--------------|-------------|------------|
| `GF_SECURITY_ADMIN_PASSWORD` | Mot de passe administrateur Grafana | Conteneur Grafana |
| `GH_PAT` | Personal Access Token GitHub | Terraform, intégrations GitHub |

## Configuration des secrets GitHub

Pour configurer les secrets GitHub :

1. Accédez à votre dépôt GitHub
2. Cliquez sur "Settings" (Paramètres)
3. Dans le menu de gauche, cliquez sur "Secrets and variables" puis "Actions"
4. Cliquez sur "New repository secret"
5. Entrez le nom du secret et sa valeur
6. Cliquez sur "Add secret"

## Utilisation des secrets dans les workflows

Les secrets GitHub peuvent être utilisés dans les workflows GitHub Actions de la manière suivante :

```yaml
jobs:
  example-job:
    runs-on: ubuntu-latest
    steps:
      - name: Use a secret
        env:
          MY_SECRET: ${{ secrets.MY_SECRET }}
        run: |
          echo "Using secret: $MY_SECRET"
```

## Utilisation des secrets dans les conteneurs Docker

Les secrets sont passés aux conteneurs Docker via des variables d'environnement :

```yaml
services:
  example-service:
    image: example-image
    environment:
      - SECRET_VALUE=${SECRET_VALUE}
```

Dans les scripts de déploiement, les secrets sont exportés en tant que variables d'environnement :

```bash
export SECRET_VALUE=${{ secrets.SECRET_VALUE }}
```

## Bonnes pratiques

1. **Ne jamais stocker de secrets en clair** dans le code source, les fichiers de configuration ou les logs
2. **Utiliser des secrets spécifiques** pour chaque service ou application
3. **Faire tourner régulièrement les secrets** (tous les 90 jours)
4. **Limiter l'accès aux secrets** aux personnes qui en ont besoin
5. **Utiliser des secrets temporaires** lorsque c'est possible
6. **Vérifier régulièrement les logs** pour s'assurer qu'aucun secret n'est exposé
7. **Utiliser des variables d'environnement** pour passer les secrets aux applications
8. **Éviter de passer des secrets en ligne de commande** car ils pourraient apparaître dans l'historique des commandes
