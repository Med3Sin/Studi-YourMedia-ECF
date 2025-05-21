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

### 1. Installation

#### `scripts/ec2-monitoring/setup-monitoring.sh`
- Installe Prometheus
- Configure Grafana
- Configure Loki
- Configure Promtail

#### `scripts/ec2-monitoring/configure-dashboards.sh`
- Importe les dashboards
- Configure les datasources
- Configure les alertes
- Configure les utilisateurs

### 2. Maintenance

#### `scripts/ec2-monitoring/backup-monitoring.sh`
- Sauvegarde les configurations
- Sauvegarde les dashboards
- Sauvegarde les données
- Rotation des backups

#### `scripts/ec2-monitoring/cleanup-monitoring.sh`
- Nettoie les logs
- Nettoie les métriques
- Nettoie les snapshots
- Optimise le stockage

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
- Met à jour la documentation
- Synchronise les versions
- Vérifie la cohérence
- Publie les changements

## Structure des Scripts

```
scripts/
├── config/           # Fichiers de configuration
├── database/         # Scripts de gestion de la base de données
├── ec2-java-tomcat/  # Scripts de déploiement Java
├── ec2-monitoring/   # Scripts de configuration du monitoring
└── utils/           # Scripts utilitaires
```

## Scripts Utilitaires

### standardize-scripts.sh

Script de standardisation des scripts shell du projet.

**Utilisation :**
```bash
sudo ./scripts/utils/standardize-scripts.sh
```

**Fonctionnalités :**
- Ajoute un en-tête standard à tous les scripts shell
- Vérifie la cohérence des conventions de nommage
- Met à jour les permissions des fichiers

### cleanup-obsolete.sh

Script de nettoyage des fichiers obsolètes.

**Utilisation :**
```bash
sudo ./scripts/utils/cleanup-obsolete.sh
```

**Fonctionnalités :**
- Supprime les fichiers obsolètes non référencés
- Met à jour les références obsolètes dans le code
- Vérifie les dépendances avant suppression

## Scripts de Déploiement

### setup-monitoring.sh

Script de configuration du monitoring.

**Utilisation :**
```bash
sudo ./scripts/ec2-monitoring/setup-monitoring.sh
```

**Fonctionnalités :**
- Installation de Docker et Docker Compose
- Configuration de Prometheus, Grafana et cAdvisor
- Mise en place des dashboards et alertes

### setup-java-app.sh

Script de déploiement de l'application Java.

**Utilisation :**
```bash
sudo ./scripts/ec2-java-tomcat/setup-java-app.sh
```

**Fonctionnalités :**
- Installation de Java et Tomcat
- Configuration de l'environnement
- Déploiement de l'application

## Scripts de Base de Données

### setup-database.sh

Script de configuration de la base de données.

**Utilisation :**
```bash
sudo ./scripts/database/setup-database.sh
```

**Fonctionnalités :**
- Création de la base de données
- Configuration des utilisateurs
- Import des données initiales

## Conventions de Nommage

1. **Scripts Shell :**
   - Utiliser le suffixe `.sh`
   - Nom en kebab-case (ex: `setup-monitoring.sh`)
   - Préfixe descriptif (ex: `setup-`, `cleanup-`, `backup-`)

2. **Fichiers de Configuration :**
   - Utiliser le suffixe `.yml` ou `.json`
   - Nom en kebab-case
   - Préfixe du service (ex: `prometheus-`, `grafana-`)

## Bonnes Pratiques

1. **Sécurité :**
   - Vérifier les permissions des fichiers
   - Utiliser des chemins absolus
   - Valider les entrées utilisateur

2. **Maintenance :**
   - Documenter les modifications
   - Ajouter des commentaires explicatifs
   - Utiliser des variables pour les valeurs configurables

3. **Débogage :**
   - Activer le mode debug avec `set -x`
   - Utiliser la fonction `log()` pour les messages
   - Vérifier les codes de retour

## Dépannage

### Problèmes Courants

1. **Erreurs de Permission :**
   ```bash
   sudo chmod +x script.sh
   ```

2. **Erreurs de Chemin :**
   - Utiliser des chemins absolus
   - Vérifier les variables d'environnement

3. **Erreurs de Syntaxe :**
   - Vérifier avec `shellcheck`
   - Tester dans un environnement isolé

## Maintenance

### Mise à Jour des Scripts

1. Vérifier les dépendances
2. Tester dans un environnement de développement
3. Mettre à jour la documentation
4. Créer un commit avec un message descriptif

### Nettoyage

1. Supprimer les fichiers temporaires
2. Archiver les anciennes versions
3. Mettre à jour les références

## Ressources

- [Bash Reference Manual](https://www.gnu.org/software/bash/manual/bash.html)
- [Shell Scripting Best Practices](https://github.com/koalaman/shellcheck)
- [Docker Documentation](https://docs.docker.com/) 