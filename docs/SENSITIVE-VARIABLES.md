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

Les variables sensibles (mots de passe, tokens, clés API, etc.) ne doivent jamais être stockées en clair dans le code source. Pour gérer ces variables de manière sécurisée, nous utilisons les secrets GitHub comme source unique de vérité pour toutes les variables sensibles du projet, y compris celles utilisées par Terraform.

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

| Nom du secret | Description | Utilisé par | Généré automatiquement |
|--------------|-------------|------------|------------------------|
| `SONAR_TOKEN` | Token d'accès SonarQube | Workflow d'analyse SonarQube | Oui, par le script `generate_sonar_token.sh` |
| `SONAR_HOST_URL` | URL de l'instance SonarQube | Workflow d'analyse SonarQube | Non, construit à partir de `TF_MONITORING_EC2_PUBLIC_IP` |
| `SONAR_JDBC_USERNAME` | Nom d'utilisateur pour la base de données SonarQube | Conteneur SonarQube | Oui, par le module `secrets_management` |
| `SONAR_JDBC_PASSWORD` | Mot de passe pour la base de données SonarQube | Conteneur SonarQube | Oui, par le module `secrets_management` |
| `SONAR_JDBC_URL` | URL de connexion à la base de données SonarQube | Conteneur SonarQube | Oui, par le module `secrets_management` |
| `GITHUB_CLIENT_ID` | ID client OAuth GitHub pour SonarQube | Conteneur SonarQube | Non |
| `GITHUB_CLIENT_SECRET` | Secret client OAuth GitHub pour SonarQube | Conteneur SonarQube | Non |

### Secrets Terraform Cloud

| Nom du secret | Description | Utilisé par | Généré automatiquement |
|--------------|-------------|------------|------------------------|
| `TF_API_TOKEN` | Token d'API Terraform Cloud | Workflows GitHub Actions, scripts | Non |
| `TF_WORKSPACE_ID` | ID de l'espace de travail Terraform Cloud | Workflows GitHub Actions, scripts | Non |

### Autres secrets

| Nom du secret | Description | Utilisé par | Généré automatiquement |
|--------------|-------------|------------|------------------------|
| `GF_SECURITY_ADMIN_PASSWORD` | Mot de passe administrateur Grafana | Conteneur Grafana | Oui, par le module `secrets_management` |
| `GH_PAT` | Personal Access Token GitHub | Terraform, intégrations GitHub | Non |

## Configuration des secrets GitHub

Pour configurer les secrets GitHub :

1. Accédez à votre dépôt GitHub
2. Cliquez sur "Settings" (Paramètres)
3. Dans le menu de gauche, cliquez sur "Secrets and variables" puis "Actions"
4. Cliquez sur "New repository secret"
5. Entrez le nom du secret et sa valeur
6. Cliquez sur "Add secret"

> **Note importante** : Pour consulter la valeur d'un secret existant (ce qui n'est pas possible directement via l'interface GitHub), consultez le document [CONSULTER-SECRETS-GITHUB.md](./CONSULTER-SECRETS-GITHUB.md) qui explique comment le faire de manière sécurisée.

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
9. **Centraliser les secrets dans GitHub Secrets** pour simplifier la gestion et éviter les duplications
10. **Utiliser l'authentification multi-facteurs (MFA)** pour accéder à GitHub

## Sécurisation de la base de données

Pour sécuriser la base de données MySQL, un script a été créé pour révoquer les privilèges de l'utilisateur root et créer un utilisateur dédié pour l'application :

```bash
./scripts/database/secure-database.sh [DB_HOST] [DB_PORT] [DB_ROOT_USER] [DB_ROOT_PASSWORD] [NEW_DB_USER] [NEW_DB_PASSWORD]
```

Ce script :
1. Révoque les privilèges de l'utilisateur root sur la base de données yourmedia
2. Crée un utilisateur dédié avec des privilèges limités
3. Génère un mot de passe fort si aucun n'est fourni
4. Met à jour les secrets dans GitHub (si les variables d'environnement nécessaires sont définies)
5. Affiche des instructions pour mettre à jour manuellement les secrets dans GitHub Actions

## Génération du token SonarQube

Pour générer un token SonarQube et le stocker comme secret GitHub, un script a été créé :

```bash
./scripts/ec2-monitoring/generate_sonar_token.sh [SONAR_HOST] [TF_API_TOKEN] [TF_WORKSPACE_ID] [SONAR_ADMIN_USER] [SONAR_ADMIN_PASSWORD]
```

Ce script :
1. Attend que SonarQube soit opérationnel
2. Génère un token SonarQube avec un nom unique
3. Stocke le token comme secret GitHub
4. Affiche des instructions pour ajouter le token comme secret GitHub

## Correction des clés SSH

Pour corriger les problèmes de format des clés SSH dans le fichier authorized_keys, un script a été créé :

```bash
./scripts/utils/fix-ssh-keys.sh [--force]
```

Ce script :
1. Vérifie le format des clés SSH dans le fichier authorized_keys
2. Supprime les guillemets simples qui entourent les clés SSH
3. Extrait les clés SSH valides des lignes mal formatées
4. Sauvegarde le fichier original avant de le modifier
5. Peut être exécuté périodiquement via un service systemd
