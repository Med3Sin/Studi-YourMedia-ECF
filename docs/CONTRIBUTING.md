# Guide de contribution pour YourMedia

Ce guide explique comment contribuer au projet YourMedia, en détaillant les processus de développement, les normes de code et les bonnes pratiques à suivre.

## Table des matières

1. [Introduction](#introduction)
2. [Configuration de l'environnement de développement](#configuration-de-lenvironnement-de-développement)
3. [Structure du projet](#structure-du-projet)
4. [Workflow de développement](#workflow-de-développement)
5. [Normes de code](#normes-de-code)
6. [Tests](#tests)
7. [Déploiement](#déploiement)
8. [Documentation](#documentation)
9. [Sécurité](#sécurité)
10. [Ressources](#ressources)

## Introduction

YourMedia est une application de gestion de médias qui utilise une architecture moderne basée sur des conteneurs Docker. Le projet est divisé en plusieurs composants :

- **Application mobile React Native** : Interface utilisateur pour les appareils mobiles
- **Backend Java Spring Boot** : API REST pour la logique métier
- **Infrastructure Terraform** : Code d'infrastructure pour le déploiement sur AWS
- **Monitoring** : Outils de surveillance (Grafana, Prometheus, SonarQube)

## Configuration de l'environnement de développement

### Prérequis

- Git
- Docker et Docker Compose
- Node.js (version 20 ou supérieure)
- Java JDK 17
- Maven
- Terraform (version 1.5.x ou supérieure)
- AWS CLI
- Un compte GitHub

### Installation

1. Cloner le dépôt :
   ```bash
   git clone https://github.com/Med3Sin/Studi-YourMedia-ECF.git
   cd Studi-YourMedia-ECF
   ```

2. Configurer les variables d'environnement :
   ```bash
   cp .env.example .env
   # Modifier le fichier .env avec vos propres valeurs
   ```

3. Installer les dépendances :
   ```bash
   # Pour l'application React Native
   cd app-react
   npm install
   
   # Pour l'application Java
   cd ../app-java
   mvn install
   ```

4. Démarrer l'environnement de développement local :
   ```bash
   docker-compose up -d
   ```

## Structure du projet

```
Studi-YourMedia-ECF/
├── .github/                  # Workflows GitHub Actions
├── app-react/                # Application mobile React Native
├── app-java/                 # Backend Java Spring Boot
├── infrastructure/           # Code Terraform pour l'infrastructure
│   ├── modules/              # Modules Terraform réutilisables
│   └── environments/         # Configurations spécifiques aux environnements
├── scripts/                  # Scripts utilitaires
├── docs/                     # Documentation
└── diagrams/                 # Diagrammes d'architecture
```

## Workflow de développement

### Branches

Nous utilisons le workflow Git Flow avec les branches suivantes :

- `main` : Code de production stable
- `develop` : Branche de développement principale
- `feature/*` : Nouvelles fonctionnalités
- `bugfix/*` : Corrections de bugs
- `release/*` : Préparation des versions
- `hotfix/*` : Corrections urgentes en production

### Processus de développement

1. Créer une nouvelle branche à partir de `develop` :
   ```bash
   git checkout develop
   git pull
   git checkout -b feature/ma-nouvelle-fonctionnalite
   ```

2. Développer et tester localement :
   ```bash
   # Exécuter les tests
   cd app-react
   npm test
   
   cd ../app-java
   mvn test
   ```

3. Soumettre une Pull Request (PR) vers `develop` :
   - Remplir le modèle de PR
   - Demander une revue de code
   - S'assurer que tous les tests passent

4. Après approbation, fusionner la PR dans `develop`

5. Pour les versions, créer une branche `release/X.Y.Z` à partir de `develop`, puis fusionner dans `main` et `develop`

## Normes de code

### Général

- Utiliser UTF-8 pour tous les fichiers
- Utiliser LF (Unix) pour les fins de ligne
- Limiter les lignes à 100 caractères
- Documenter le code avec des commentaires pertinents

### JavaScript/React Native

- Suivre les règles ESLint et Prettier
- Utiliser les fonctions fléchées et les hooks React
- Préférer les composants fonctionnels aux composants de classe
- Utiliser TypeScript pour les nouveaux composants

### Java

- Suivre les conventions de code Java standard
- Utiliser les annotations Spring Boot appropriées
- Documenter les API avec Swagger/OpenAPI
- Écrire des tests unitaires pour chaque classe

### Terraform

- Suivre les conventions HashiCorp
- Utiliser des modules pour le code réutilisable
- Documenter les variables et les outputs
- Exécuter `terraform fmt` avant de committer

## Tests

### Tests unitaires

- **React Native** : Jest et React Testing Library
- **Java** : JUnit 5 et Mockito

### Tests d'intégration

- Utiliser Docker Compose pour les tests d'intégration
- Tester les interactions entre les composants

### Tests de sécurité

- Exécuter des analyses de sécurité régulières
- Utiliser OWASP Dependency Check pour les dépendances
- Utiliser Trivy pour les images Docker

## Déploiement

### Environnements

- **dev** : Environnement de développement
- **staging** : Environnement de pré-production
- **prod** : Environnement de production

### Processus de déploiement

1. Les déploiements sont gérés par GitHub Actions
2. Les workflows sont déclenchés automatiquement ou manuellement
3. Les déploiements canary sont utilisés pour réduire les risques

### Rollback

En cas de problème après un déploiement :

1. Utiliser le workflow de rollback dans GitHub Actions
2. Vérifier les logs et les métriques pour identifier la cause
3. Documenter l'incident et les actions correctives

## Documentation

### Types de documentation

- **Documentation utilisateur** : Guides d'utilisation de l'application
- **Documentation technique** : Architecture, API, etc.
- **Documentation de développement** : Ce guide et autres ressources pour les développeurs

### Diagrammes

- Utiliser diagrams.net (draw.io) pour les diagrammes
- Stocker les diagrammes au format .drawio.png dans le dossier `diagrams/`
- Diviser les diagrammes par module pour une meilleure organisation

## Sécurité

### Bonnes pratiques

- Ne jamais stocker de secrets dans le code
- Utiliser les GitHub Secrets pour les informations sensibles
- Suivre le principe du moindre privilège
- Effectuer des revues de sécurité régulières

### Gestion des vulnérabilités

1. Signaler les vulnérabilités de sécurité à l'équipe de sécurité
2. Ne pas divulguer publiquement les vulnérabilités avant qu'elles ne soient corrigées
3. Mettre à jour régulièrement les dépendances

## Ressources

- [Documentation React Native](https://reactnative.dev/docs/getting-started)
- [Documentation Spring Boot](https://docs.spring.io/spring-boot/docs/current/reference/html/)
- [Documentation Terraform](https://www.terraform.io/docs)
- [Documentation AWS](https://docs.aws.amazon.com/)
- [Documentation Docker](https://docs.docker.com/)

---

Pour toute question ou suggestion concernant ce guide, veuillez contacter l'équipe de développement ou ouvrir une issue sur GitHub.
