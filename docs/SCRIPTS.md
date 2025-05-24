# Scripts

## Vue d'ensemble

Ce document décrit les scripts utilisés dans le projet YourMedia, leur objectif et leur utilisation.

## Scripts d'Infrastructure

### 1. Déploiement AWS

#### `infrastructure/deploy.sh`
- Déploie l'infrastructure AWS
- Utilise Terraform
- Gère les variables d'environnement
- Applique les configurations

#### `infrastructure/destroy.sh`
- Détruit l'infrastructure AWS
- Nettoie les ressources
- Sauvegarde les données importantes
- Vérifie les dépendances

### 2. Configuration EC2

#### `scripts/ec2-java-tomcat/setup.sh`
- Configure l'instance Java
- Installe Tomcat
- Configure les variables d'environnement
- Démarre les services

#### `scripts/ec2-react/setup.sh`
- Configure l'instance React
- Installe Node.js
- Configure Nginx
- Démarre les services

## Scripts de Monitoring

### 1. Installation et Configuration

#### `scripts/ec2-monitoring/setup-monitoring.sh`
- Installe les dépendances système
- Configure les limites système
- Configure les services systemd
- Configure les permissions

#### `scripts/ec2-monitoring/setup-monitoring-complete.sh`
- Configure Grafana
- Configure Prometheus
- Configure Loki
- Configure Promtail

#### `scripts/ec2-monitoring/init-monitoring.sh`
- Initialise l'environnement de monitoring
- Télécharge les configurations
- Configure les services
- Démarre les conteneurs

### 2. Maintenance et Gestion

#### `scripts/ec2-monitoring/docker-manager.sh`
- Gère les conteneurs Docker
- Déploie les services
- Gère les configurations
- Vérifie l'état des services

#### `scripts/ec2-monitoring/docker-cleanup.sh`
- Nettoie les conteneurs arrêtés
- Supprime les images non utilisées
- Nettoie les volumes orphelins
- Nettoie les réseaux non utilisés

#### `scripts/ec2-monitoring/restart-monitoring.sh`
- Redémarre les services de monitoring
- Met à jour les configurations
- Vérifie l'état des services
- Gère les erreurs

### 3. Logs et Métriques

#### `scripts/ec2-monitoring/sync-tomcat-logs.sh`
- Synchronise les logs Tomcat
- Configure la rotation des logs
- Gère les permissions
- Vérifie l'intégrité des logs

#### `scripts/ec2-monitoring/get-aws-resources-info.sh`
- Récupère les informations des ressources AWS
- Génère les configurations
- Met à jour les variables d'environnement
- Configure les exporters

### 4. Sécurité et Vérification

#### `scripts/ec2-monitoring/setup-ssh-keys.sh`
- Configure les clés SSH
- Gère les permissions
- Configure l'authentification
- Vérifie la sécurité

#### `scripts/ec2-monitoring/check-grafana.sh`
- Vérifie l'état de Grafana
- Vérifie les datasources
- Vérifie les dashboards
- Vérifie les utilisateurs

### 5. Services Systemd

#### `docker-cleanup.service` et `docker-cleanup.timer`
- Service de nettoyage automatique des ressources Docker
- Exécution périodique
- Gestion des logs
- Gestion des erreurs

#### `sync-tomcat-logs.service` et `sync-tomcat-logs.timer`
- Service de synchronisation des logs Tomcat
- Exécution périodique
- Gestion des logs
- Gestion des erreurs

## Scripts d'Application

### 1. Java

#### `scripts/app-java/build.sh`
- Compile le code
- Exécute les tests
- Génère le JAR
- Vérifie la qualité

#### `scripts/app-java/deploy.sh`
- Déploie l'application
- Configure Tomcat
- Gère les versions
- Vérifie le déploiement

### 2. React

#### `scripts/app-react/build.sh`
- Installe les dépendances
- Compile le code
- Optimise les assets
- Génère le build

#### `scripts/app-react/deploy.sh`
- Déploie l'application
- Configure Nginx
- Gère le cache
- Vérifie le déploiement

## Scripts de Base de Données

### 1. Administration

#### `scripts/database/backup.sh`
- Sauvegarde la base
- Compression
- Rotation
- Vérification

#### `scripts/database/restore.sh`
- Restaure la base
- Vérifie l'intégrité
- Gère les versions
- Nettoie les logs

### 2. Maintenance

#### `scripts/database/optimize.sh`
- Optimise les tables
- Analyse les index
- Nettoie les logs
- Vérifie la performance

#### `scripts/database/migrate.sh`
- Applique les migrations
- Vérifie les versions
- Gère les rollbacks
- Documente les changements

## Scripts Utilitaires

### 1. Système

#### `scripts/utils/check-system.sh`
- Vérifie les ressources
- Vérifie les services
- Vérifie les logs
- Génère un rapport

#### `scripts/utils/cleanup-system.sh`
- Nettoie les logs
- Nettoie le cache
- Optimise le système
- Vérifie l'espace

### 2. Docker

#### `scripts/utils/docker-manager.sh`
- Gère les conteneurs
- Gère les images
- Gère les volumes
- Gère les réseaux

#### `scripts/utils/docker-cleanup.sh`
- Nettoie les conteneurs
- Nettoie les images
- Nettoie les volumes
- Optimise l'espace

## Scripts de CI/CD

### 1. GitHub Actions

#### `.github/workflows/1-infra-deploy-destroy.yml`
- Déploie l'infrastructure
- Vérifie les changements
- Gère les secrets
- Documente les actions

#### `.github/workflows/2-app-deploy.yml`
- Déploie les applications
- Exécute les tests
- Gère les versions
- Vérifie le déploiement

### 2. Tests

#### `scripts/tests/run-tests.sh`
- Exécute les tests unitaires
- Exécute les tests d'intégration
- Génère les rapports
- Vérifie la couverture

#### `scripts/tests/analyze-tests.sh`
- Analyse les résultats
- Génère les statistiques
- Identifie les problèmes
- Propose des améliorations

## Documentation

### 1. Génération

#### `scripts/docs/generate-docs.sh`
- Génère la documentation
- Met à jour les diagrammes
- Vérifie les liens
- Publie les changements

#### `scripts/docs/verify-docs.sh`
- Vérifie la documentation
- Vérifie les exemples
- Vérifie les commandes
- Vérifie les versions

### 2. Maintenance

#### `scripts/docs/cleanup-docs.sh`
- Nettoie la documentation
- Archive les anciennes versions
- Optimise les images
- Vérifie les références

#### `scripts/docs/update-docs.sh`