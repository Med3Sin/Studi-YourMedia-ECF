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

### Interface web Terraform Cloud (Accès sécurisé)

Pour des raisons de sécurité, les secrets ne sont accessibles que via l'interface web de Terraform Cloud :

1. Connectez-vous à [Terraform Cloud](https://app.terraform.io/)
2. Accédez à votre organisation et à l'espace de travail du projet
3. Allez dans l'onglet "Variables"
4. Les variables sensibles seront masquées, mais vous pouvez cliquer sur "Reveal" pour voir leur valeur

### Sécurité renforcée

- L'accès aux secrets est limité aux utilisateurs ayant accès à Terraform Cloud
- Les secrets ne sont jamais exposés dans les logs ou les sorties de workflow
- L'authentification multi-facteurs (MFA) de Terraform Cloud ajoute une couche de sécurité supplémentaire
- Toutes les consultations de secrets sont journalisées dans les logs d'audit de Terraform Cloud

## Bonnes pratiques

1. **Ne jamais stocker de secrets en clair** dans le code source, les fichiers de configuration ou les logs
2. **Utiliser des secrets spécifiques** pour chaque service ou application
3. **Faire tourner régulièrement les secrets** (tous les 90 jours)
4. **Limiter l'accès aux secrets** aux personnes qui en ont besoin
5. **Utiliser des secrets temporaires** lorsque c'est possible
6. **Vérifier régulièrement les logs** pour s'assurer qu'aucun secret n'est exposé
7. **Utiliser des variables d'environnement** pour passer les secrets aux applications
8. **Éviter de passer des secrets en ligne de commande** car ils pourraient apparaître dans l'historique des commandes
