# Guide de configuration de SonarQube - YourMédia

Ce document explique comment configurer et utiliser SonarQube pour l'analyse de la qualité du code dans le projet YourMédia.

## Table des matières

1. [Introduction à SonarQube](#introduction-à-sonarqube)
2. [Architecture de SonarQube](#architecture-de-sonarqube)
3. [Installation et configuration](#installation-et-configuration)
4. [Configuration des projets](#configuration-des-projets)
5. [Intégration avec GitHub](#intégration-avec-github)
6. [Analyse du code](#analyse-du-code)
7. [Interprétation des résultats](#interprétation-des-résultats)
8. [Résolution des problèmes](#résolution-des-problèmes)

## Introduction à SonarQube

SonarQube est une plateforme open source pour l'inspection continue de la qualité du code. Elle permet de détecter les bugs, les vulnérabilités et les "code smells" dans votre code. SonarQube peut analyser plus de 20 langages de programmation et s'intègre facilement avec votre pipeline CI/CD.

## Architecture de SonarQube

L'architecture de SonarQube dans le projet YourMédia comprend les composants suivants :

1. **Serveur SonarQube** : Exécuté dans un conteneur Docker sur l'instance EC2 de monitoring
2. **Base de données PostgreSQL** : Stocke les résultats d'analyse et la configuration
3. **Scanner SonarQube** : Exécuté dans le pipeline CI/CD pour analyser le code

## Installation et configuration

### Prérequis système

- Docker et docker-compose installés
- Au moins 2 Go de RAM disponible
- Au moins 1 Go d'espace disque disponible

### Configuration système requise

SonarQube nécessite certaines configurations système spécifiques :

```bash
# Augmenter la limite de mmap count
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Augmenter la limite de fichiers ouverts
echo "fs.file-max=65536" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Déploiement avec Docker

SonarQube est déployé en tant que conteneur Docker sur l'instance EC2 de monitoring. Le déploiement est géré par le script `scripts/deploy-containers.sh`.

## Configuration des projets

### Création des projets

Deux projets sont configurés dans SonarQube :

1. **yourmedia-backend** : Pour l'analyse du code Java du backend
2. **yourmedia-mobile** : Pour l'analyse du code JavaScript/React de l'application mobile

### Configuration des règles d'analyse

Chaque projet utilise un profil de qualité spécifique :

- **Java** : Utilise le profil "Sonar way" avec des règles supplémentaires pour Spring Boot
- **JavaScript/React** : Utilise le profil "Sonar way" avec des règles supplémentaires pour React

## Intégration avec GitHub

### Authentification GitHub

SonarQube est configuré pour utiliser l'authentification GitHub :

1. Un client OAuth est créé dans GitHub
2. Les identifiants client sont stockés dans les secrets GitHub
3. SonarQube utilise ces identifiants pour l'authentification

### Webhooks GitHub

Des webhooks GitHub sont configurés pour déclencher une analyse SonarQube à chaque push ou pull request :

1. Un webhook est créé dans le dépôt GitHub
2. Le webhook pointe vers l'URL de SonarQube
3. Le webhook est déclenché pour les événements push et pull_request

## Analyse du code

### Analyse manuelle

Vous pouvez déclencher une analyse manuelle en utilisant le workflow GitHub Actions :

1. Accédez à l'onglet "Actions" du dépôt GitHub
2. Sélectionnez le workflow "5 - SonarQube Analysis"
3. Cliquez sur "Run workflow"
4. Sélectionnez le projet à analyser (all, backend ou mobile)
5. Cliquez sur "Run workflow"

### Analyse automatique

Une analyse est automatiquement déclenchée à chaque push sur la branche main qui modifie les fichiers dans les répertoires `app-java` ou `app-react`.

### Configuration de l'analyse

L'analyse est configurée dans les fichiers suivants :

- `.github/workflows/5-sonarqube-analysis.yml` : Configuration du workflow GitHub Actions
- `app-java/pom.xml` : Configuration de l'analyse Java
- `app-react/sonar-project.properties` : Configuration de l'analyse JavaScript/React

## Interprétation des résultats

### Accès aux résultats

Les résultats de l'analyse sont accessibles à l'URL suivante :
- http://<EC2_MONITORING_IP>:9000

### Métriques clés

SonarQube fournit plusieurs métriques clés :

1. **Bugs** : Problèmes qui représentent des erreurs dans le code
2. **Vulnérabilités** : Problèmes qui représentent des failles de sécurité
3. **Code smells** : Problèmes qui représentent des mauvaises pratiques de programmation
4. **Couverture de code** : Pourcentage de code couvert par des tests
5. **Duplication** : Pourcentage de code dupliqué

### Quality Gates

Un "Quality Gate" est configuré pour chaque projet. Il définit les critères que le code doit respecter pour être considéré comme "passant" :

- Pas de bugs critiques ou bloquants
- Pas de vulnérabilités critiques ou bloquantes
- Couverture de code > 80%
- Duplication < 3%

## Résolution des problèmes

### Problèmes courants

#### SonarQube ne démarre pas
1. Vérifiez les logs : `docker logs sonarqube`
2. Vérifiez que les limites système sont correctement configurées
3. Vérifiez que les volumes ont les bonnes permissions

#### L'analyse échoue
1. Vérifiez les logs du workflow GitHub Actions
2. Vérifiez que le token SonarQube est correctement configuré
3. Vérifiez que l'URL de SonarQube est correcte

#### Problèmes d'authentification GitHub
1. Vérifiez que les identifiants client GitHub sont correctement configurés
2. Vérifiez que l'utilisateur GitHub a les permissions nécessaires
3. Vérifiez les logs de SonarQube pour les erreurs d'authentification
