# Migration d'AWS Amplify vers des conteneurs Docker

Ce document explique la migration de l'application frontend React Native Web depuis AWS Amplify vers des conteneurs Docker.

## Raisons de la migration

La migration d'AWS Amplify vers des conteneurs Docker a été réalisée pour les raisons suivantes :

1. **Uniformisation des déploiements** : Utilisation de conteneurs Docker pour tous les composants de l'application
2. **Contrôle accru** : Meilleur contrôle sur l'environnement d'exécution et les configurations
3. **Portabilité** : Possibilité de déployer l'application sur n'importe quelle plateforme supportant Docker
4. **Optimisation des coûts** : Utilisation des instances EC2 existantes pour héberger l'application mobile
5. **Intégration avec le monitoring** : Facilité d'intégration avec Prometheus et Grafana pour la surveillance

## Changements effectués

### Suppression des ressources AWS Amplify

Les ressources AWS Amplify suivantes ont été supprimées :

- Application Amplify pour le frontend React Native Web
- Configuration de build Amplify
- Webhooks GitHub pour Amplify

### Création des conteneurs Docker

Les conteneurs Docker suivants ont été créés :

- **app-mobile** : Application React Native pour mobile
- **prometheus** : Collecte et stockage des métriques
- **grafana** : Visualisation des métriques
- **sonarqube** : Analyse de la qualité du code
- **sonarqube-db** : Base de données PostgreSQL pour SonarQube
- **node-exporter** : Collecte des métriques système
- **mysql-exporter** : Collecte des métriques MySQL
- **cloudwatch-exporter** : Collecte des métriques AWS CloudWatch

### Mise à jour des workflows GitHub Actions

Les workflows GitHub Actions suivants ont été mis à jour ou créés :

- **3-docker-build-deploy.yml** : Construction et déploiement des conteneurs Docker
- **4-sonarqube-analysis.yml** : Analyse de la qualité du code avec SonarQube

Le workflow suivant a été supprimé :

- **3-frontend-deploy.yml** : Déploiement du frontend sur AWS Amplify (remplacé par le workflow Docker)

### Mise à jour de la documentation

La documentation a été mise à jour pour refléter les changements :

- **README.md** : Mise à jour de l'architecture et des instructions de déploiement
- **DOCKER-CONTAINERS.md** : Guide d'utilisation des conteneurs Docker
- **SONARQUBE-SETUP.md** : Guide de configuration de SonarQube

## Accès à l'application

L'application mobile est maintenant accessible à l'URL suivante :

```
http://<IP_PUBLIQUE_EC2>:3000
```

## Avantages de la nouvelle architecture

1. **Simplicité** : Une seule méthode de déploiement pour tous les composants
2. **Flexibilité** : Facilité de mise à jour et de modification des configurations
3. **Scalabilité** : Possibilité de déployer plusieurs instances de l'application
4. **Monitoring intégré** : Surveillance complète de l'application et de l'infrastructure
5. **Qualité du code** : Analyse continue de la qualité du code avec SonarQube
