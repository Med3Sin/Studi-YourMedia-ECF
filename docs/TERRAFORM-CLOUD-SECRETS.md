# Gestion des secrets dans Terraform Cloud - YourMédia

Ce document explique comment les secrets sont générés automatiquement et stockés dans Terraform Cloud pour le projet YourMédia.

## Table des matières

1. [Introduction](#introduction)
2. [Secrets générés automatiquement](#secrets-générés-automatiquement)
3. [Comment accéder aux secrets](#comment-accéder-aux-secrets)
4. [Workflow de récupération des secrets](#workflow-de-récupération-des-secrets)
5. [Bonnes pratiques](#bonnes-pratiques)

## Introduction

Pour améliorer la sécurité et la gestion des secrets, le projet YourMédia utilise Terraform Cloud comme gestionnaire de secrets centralisé. Certains secrets sont générés automatiquement lors du déploiement de l'infrastructure et stockés dans Terraform Cloud.

## Secrets générés automatiquement

Les secrets suivants sont générés automatiquement et stockés dans Terraform Cloud :

| Nom du secret | Description | Généré par |
|--------------|-------------|------------|
| `sonar_jdbc_username` | Nom d'utilisateur pour la base de données SonarQube | Module `secrets_management` |
| `sonar_jdbc_password` | Mot de passe pour la base de données SonarQube | Module `secrets_management` |
| `sonar_jdbc_url` | URL de connexion à la base de données SonarQube | Module `secrets_management` |
| `grafana_admin_password` | Mot de passe administrateur Grafana | Module `secrets_management` |
| `sonar_token` | Token d'accès à l'API SonarQube | Script `generate_sonar_token.sh` |

## Comment accéder aux secrets

### Option 1 : Interface web Terraform Cloud

1. Connectez-vous à [Terraform Cloud](https://app.terraform.io/)
2. Accédez à votre organisation et à l'espace de travail du projet
3. Allez dans l'onglet "Variables"
4. Les variables sensibles seront masquées, mais vous pouvez cliquer sur "Reveal" pour voir leur valeur

### Option 2 : Workflow GitHub Actions

Un workflow GitHub Actions a été créé pour récupérer les secrets depuis Terraform Cloud :

1. Accédez à l'onglet "Actions" de votre dépôt GitHub
2. Sélectionnez le workflow "6 - Retrieve Secrets from Terraform Cloud"
3. Cliquez sur "Run workflow"
4. Entrez le nom du secret à récupérer (ex: `sonar_jdbc_password`)
5. Choisissez si vous souhaitez afficher la valeur du secret (attention : la valeur sera visible dans les logs)
6. Cliquez sur "Run workflow"

### Option 3 : Script en ligne de commande

Un script a été créé pour récupérer les secrets depuis Terraform Cloud en ligne de commande :

```bash
./scripts/retrieve-terraform-secrets.sh <TF_API_TOKEN> <TF_WORKSPACE_ID> <SECRET_NAME> [SHOW_VALUE]
```

Exemple :
```bash
./scripts/retrieve-terraform-secrets.sh "your_api_token" "ws-xxxxxxxx" "sonar_jdbc_password" true
```

## Workflow de récupération des secrets

Le workflow "6 - Retrieve Secrets from Terraform Cloud" permet de récupérer les secrets stockés dans Terraform Cloud. Ce workflow est réservé aux administrateurs du projet.

### Paramètres du workflow

- **Secret Name** : Nom du secret à récupérer
- **Show Value** : Afficher la valeur du secret (attention : la valeur sera visible dans les logs)

### Sécurité du workflow

- Le workflow est limité aux administrateurs du projet (utilisateur GitHub : `Med3Sin`)
- Les valeurs sensibles sont masquées par défaut
- Un avertissement est affiché si la valeur du secret est affichée

## Bonnes pratiques

1. **Ne jamais stocker de secrets en clair** dans le code source, les fichiers de configuration ou les logs
2. **Utiliser des secrets spécifiques** pour chaque service ou application
3. **Faire tourner régulièrement les secrets** (tous les 90 jours)
4. **Limiter l'accès aux secrets** aux personnes qui en ont besoin
5. **Utiliser des secrets temporaires** lorsque c'est possible
6. **Vérifier régulièrement les logs** pour s'assurer qu'aucun secret n'est exposé
7. **Utiliser des variables d'environnement** pour passer les secrets aux applications
8. **Éviter de passer des secrets en ligne de commande** car ils pourraient apparaître dans l'historique des commandes
