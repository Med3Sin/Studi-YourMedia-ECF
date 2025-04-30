# Gestion des variables sensibles et automatisation - YourMédia

Ce document explique comment gérer les variables sensibles dans le projet YourMédia, en utilisant les secrets GitHub et l'automatisation Terraform.

## Table des matières

1. [Introduction](#introduction)
2. [Liste des variables sensibles](#liste-des-variables-sensibles)
3. [Architecture de la solution](#architecture-de-la-solution)
4. [Configuration des secrets GitHub](#configuration-des-secrets-github)
5. [Automatisation des variables d'environnement](#automatisation-des-variables-denvironnement)
6. [Utilisation des secrets dans les workflows](#utilisation-des-secrets-dans-les-workflows)
7. [Utilisation des secrets dans les conteneurs Docker](#utilisation-des-secrets-dans-les-conteneurs-docker)
8. [Dépannage](#dépannage)
9. [Bonnes pratiques](#bonnes-pratiques)

## Introduction

Les variables sensibles (mots de passe, tokens, clés API, etc.) ne doivent jamais être stockées en clair dans le code source. Pour gérer ces variables de manière sécurisée, nous utilisons les secrets GitHub comme source unique de vérité pour toutes les variables sensibles du projet, combinés avec une solution d'automatisation basée sur Terraform et S3 pour transmettre ces variables aux instances EC2.

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

## Architecture de la solution

L'architecture de la solution d'automatisation des variables d'environnement se compose des éléments suivants :

1. **S3 Bucket** : Stocke les scripts et les variables d'environnement sensibles
2. **Fichier JSON chiffré** : Contient les variables d'environnement sensibles
3. **Scripts d'initialisation** : Récupèrent les variables depuis S3 et les configurent sur les instances EC2
4. **Rôles IAM** : Permettent aux instances EC2 d'accéder au bucket S3

### Flux de travail

1. Les variables sont définies dans Terraform Cloud ou dans les secrets GitHub.
2. Terraform crée un fichier JSON chiffré dans le bucket S3 contenant ces variables.
3. Les instances EC2 récupèrent ce fichier au démarrage et configurent les variables d'environnement localement.
4. Les fichiers contenant les variables sensibles sont sécurisés avec des permissions restrictives.

### Dépendances entre ressources

Les ressources sont créées dans l'ordre suivant pour garantir que les dépendances sont respectées :

1. S3 Bucket
2. Objets S3 (scripts, configurations, variables)
3. RDS MySQL
4. EC2 Java/Tomcat
5. EC2 Monitoring

Les dépendances sont explicitement définies dans le code Terraform pour éviter les problèmes de création de ressources.

## Configuration des secrets GitHub

Pour configurer les secrets GitHub :

1. Accédez à votre dépôt GitHub
2. Cliquez sur "Settings" (Paramètres)
3. Dans le menu de gauche, cliquez sur "Secrets and variables" puis "Actions"
4. Cliquez sur "New repository secret"
5. Entrez le nom du secret et sa valeur
6. Cliquez sur "Add secret"

> **Note importante** : La consultation des secrets GitHub n'est pas possible directement via l'interface GitHub pour des raisons de sécurité. Si vous avez besoin de consulter un secret, vous devrez créer un workflow temporaire spécifique à cet effet.

## Automatisation des variables d'environnement

### Scripts d'initialisation

Deux scripts d'initialisation sont utilisés pour configurer les instances EC2 :

1. **init-java-tomcat.sh** : Configure l'instance EC2 Java/Tomcat en installant Java, Tomcat et en déployant l'application.
2. **init-monitoring.sh** : Configure l'instance EC2 Monitoring en installant Docker, Prometheus et Grafana.

Ces scripts récupèrent les variables d'environnement depuis le bucket S3 et les configurent localement.

### Variables gérées

Les variables suivantes sont gérées par cette solution :

#### Variables RDS
- `RDS_USERNAME`
- `RDS_PASSWORD`
- `RDS_ENDPOINT`
- `RDS_NAME`

#### Variables Grafana
- `GRAFANA_ADMIN_PASSWORD`

#### Variables AWS
- `AWS_REGION`
- `S3_BUCKET_NAME`

#### Variables d'application
- `MONITORING_EC2_PUBLIC_IP`
- `JAVA_TOMCAT_EC2_PUBLIC_IP`

### Maintenance

Pour mettre à jour les variables d'environnement :

1. Mettez à jour les variables dans Terraform Cloud ou GitHub Secrets.
2. Exécutez `terraform apply` pour mettre à jour le fichier JSON dans S3.
3. Redémarrez les instances EC2 ou exécutez le script d'initialisation manuellement.

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

## Dépannage

Si les instances EC2 ne démarrent pas correctement, vérifiez les logs suivants :

- `/var/log/user-data-init.log` : Log du script d'initialisation user-data.
- `/var/log/init-monitoring.log` ou `/var/log/init-java-tomcat.log` : Logs des scripts d'initialisation.
- `/var/log/setup-monitoring.log` ou `/var/log/setup-java-tomcat.log` : Logs des scripts de configuration.

### Sécurisation de la base de données

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

### Correction des clés SSH

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
