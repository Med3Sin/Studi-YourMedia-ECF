# Guide d'utilisation des workflows automatisés

Ce guide explique comment utiliser les workflows GitHub Actions automatisés pour déployer l'infrastructure et les applications.

## Table des matières

1. [Introduction](#introduction)
2. [Prérequis](#prérequis)
3. [Workflow de déploiement d'infrastructure (0)](#workflow-de-déploiement-dinfrastructure)
4. [Workflow d'exportation des outputs Terraform (1)](#workflow-dexportation-des-outputs-terraform)
5. [Workflow de déploiement backend (2)](#workflow-de-déploiement-backend)
6. [Workflow de déploiement frontend (3)](#workflow-de-déploiement-frontend)
7. [Résolution des problèmes](#résolution-des-problèmes)

## Introduction

Ce projet utilise plusieurs workflows GitHub Actions pour automatiser le déploiement de l'infrastructure et des applications. Les workflows sont numérotés de 0 à 3 pour indiquer l'ordre logique d'exécution :

0. **Déploiement d'infrastructure** : Déploie l'infrastructure AWS avec Terraform
1. **Exportation des outputs Terraform** : Exporte les outputs Terraform vers GitHub Secrets
2. **Déploiement backend** : Compile et déploie l'application backend Java
3. **Déploiement frontend** : Compile l'application frontend React Native Web

Cette approche présente plusieurs avantages :

- **Sécurité** : Les informations sensibles sont stockées de manière sécurisée dans GitHub Secrets
- **Automatisation** : Pas besoin de copier-coller manuellement les outputs Terraform
- **Cohérence** : Garantit que les mêmes valeurs sont utilisées dans tous les workflows
- **Gratuité** : Utilisation des fonctionnalités natives de GitHub sans coûts supplémentaires

## Prérequis

Pour utiliser ces workflows automatisés, vous devez avoir configuré les secrets GitHub suivants :

1. **Secrets AWS** :
   - `AWS_ACCESS_KEY_ID` et `AWS_SECRET_ACCESS_KEY` : Pour accéder à AWS

2. **Secrets Terraform** :
   - `TF_API_TOKEN` : Pour accéder à Terraform Cloud

3. **Secrets GitHub** :
   - `GH_PAT` : Token GitHub avec permission pour mettre à jour les secrets (scope: `repo`)

4. **Secrets SSH** :
   - `EC2_SSH_PRIVATE_KEY` : Clé SSH privée pour se connecter à l'instance EC2

Ces secrets sont utilisés par les différents workflows pour accéder aux ressources nécessaires.

## Workflow de déploiement d'infrastructure

Le workflow de déploiement d'infrastructure (`0-infra-deploy-destroy.yml`) est responsable du déploiement et de la destruction de l'infrastructure AWS avec Terraform.

### Utilisation

1. Allez dans l'onglet "Actions" de votre dépôt GitHub
2. Sélectionnez le workflow "0 - Infrastructure Deployment and Destruction"
3. Cliquez sur "Run workflow"
4. Sélectionnez l'action à effectuer (deploy ou destroy)
5. Sélectionnez l'environnement (dev ou prod)
6. Cliquez sur "Run workflow"

Après un déploiement réussi, n'oubliez pas d'exécuter le workflow d'exportation des outputs Terraform pour mettre à jour les secrets GitHub.

## Workflow d'exportation des outputs Terraform

Le workflow d'exportation des outputs Terraform (`1-terraform-outputs-to-secrets.yml`) exporte les outputs Terraform vers GitHub Secrets pour qu'ils puissent être utilisés par les autres workflows.

### Utilisation

1. Allez dans l'onglet "Actions" de votre dépôt GitHub
2. Sélectionnez le workflow "1 - Terraform Outputs to GitHub Secrets"
3. Cliquez sur "Run workflow"
4. Sélectionnez l'environnement (dev ou prod)
5. Cliquez sur "Run workflow"

Ce workflow va :
1. Se connecter à Terraform Cloud
2. Récupérer les outputs Terraform
3. Créer ou mettre à jour les secrets GitHub correspondants

## Workflow de déploiement backend

Le workflow de déploiement backend (`2-backend-deploy.yml`) compile et déploie l'application backend Java sur l'instance EC2 en utilisant les secrets GitHub.

### Utilisation

1. Allez dans l'onglet "Actions" de votre dépôt GitHub
2. Sélectionnez le workflow "2 - Build and Deploy Backend (Java WAR)"
3. Cliquez sur "Run workflow"
4. Laissez l'option "Utiliser les valeurs manuelles" décochée pour utiliser les secrets GitHub
5. Cliquez sur "Run workflow"

### Mode manuel (fallback)

Si vous rencontrez des problèmes avec GitHub Secrets, vous pouvez toujours utiliser le mode manuel :

1. Cochez l'option "Utiliser les valeurs manuelles"
2. Entrez manuellement l'adresse IP EC2 et le nom du bucket S3
3. Cliquez sur "Run workflow"

## Workflow de déploiement frontend

Le workflow de déploiement frontend fonctionne de manière similaire au workflow backend.

### Utilisation

1. Allez dans l'onglet "Actions" de votre dépôt GitHub
2. Sélectionnez le workflow "3 - Build Frontend (React Native Web CI)"
3. Cliquez sur "Run workflow"
4. Laissez l'option "Utiliser les valeurs manuelles" décochée pour utiliser les secrets GitHub
5. Cliquez sur "Run workflow"

## Résolution des problèmes

### Erreur "Secret not found"

Si vous obtenez une erreur indiquant qu'un secret n'a pas été trouvé :

1. Vérifiez que le workflow `1-terraform-outputs-to-secrets.yml` a été exécuté avec succès
2. Vérifiez que les secrets GitHub ont été correctement créés
3. Vérifiez que le token GitHub (`GH_PAT`) a les permissions nécessaires pour créer des secrets

### Erreur d'authentification Terraform Cloud

Si vous obtenez une erreur d'authentification Terraform Cloud :

1. Vérifiez que le secret `TF_API_TOKEN` est correctement configuré
2. Vérifiez que le token a les permissions nécessaires pour accéder à l'organisation et au workspace Terraform Cloud

### Erreur de connexion SSH

Si vous obtenez une erreur de connexion SSH :

1. Vérifiez que le secret `EC2_SSH_PRIVATE_KEY` est correctement configuré
2. Vérifiez que l'instance EC2 est en cours d'exécution
3. Vérifiez que le groupe de sécurité autorise le trafic SSH depuis l'adresse IP du runner GitHub Actions
