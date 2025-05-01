# Architecture YourMedia

Ce document décrit l'architecture technique du projet YourMedia, en détaillant les différents composants, leurs interactions et les flux de données.

## Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Architecture applicative](#architecture-applicative)
3. [Architecture d'infrastructure](#architecture-dinfrastructure)
4. [Sécurité](#sécurité)
5. [Monitoring et observabilité](#monitoring-et-observabilité)
6. [Déploiement et CI/CD](#déploiement-et-cicd)
7. [Gestion des données](#gestion-des-données)
8. [Évolution et maintenance](#évolution-et-maintenance)

## Vue d'ensemble

YourMedia est une application de gestion de médias qui utilise une architecture moderne basée sur des conteneurs Docker. L'application est déployée sur AWS et utilise une approche DevOps pour le développement, le déploiement et la maintenance.

### Principes architecturaux

- **Architecture en microservices** : Séparation des responsabilités en composants indépendants
- **Infrastructure as Code (IaC)** : Toute l'infrastructure est définie en code avec Terraform
- **Conteneurisation** : Utilisation de Docker pour l'empaquetage et le déploiement des applications
- **CI/CD automatisé** : Intégration et déploiement continus avec GitHub Actions
- **Observabilité** : Monitoring complet avec Prometheus et Grafana
- **Sécurité by design** : Sécurité intégrée à toutes les étapes du développement

### Diagramme d'architecture globale

Le diagramme d'architecture globale se trouve dans le fichier `diagrams/architecture-overview.drawio.png`.

## Architecture applicative

### Frontend (React Native)

L'application mobile est développée avec React Native et Expo, ce qui permet de créer une application mobile qui fonctionne à la fois sur iOS, Android et Web.

**Composants principaux :**
- **Interface utilisateur** : Composants React Native
- **Gestion d'état** : Context API et hooks React
- **Navigation** : React Navigation
- **Communication API** : Axios pour les requêtes HTTP

### Backend (Java Spring Boot)

Le backend est développé avec Java Spring Boot et expose une API REST pour la logique métier.

**Composants principaux :**
- **API REST** : Contrôleurs Spring MVC
- **Logique métier** : Services Spring
- **Accès aux données** : Spring Data JPA
- **Sécurité** : Spring Security
- **Documentation API** : Swagger/OpenAPI

### Communication entre les composants

La communication entre le frontend et le backend se fait via des appels API REST. Les données sont échangées au format JSON.

**Flux de données :**
1. L'utilisateur interagit avec l'application mobile
2. L'application mobile envoie des requêtes HTTP au backend
3. Le backend traite les requêtes et interagit avec la base de données
4. Le backend renvoie les réponses au format JSON
5. L'application mobile affiche les données à l'utilisateur

## Architecture d'infrastructure

### AWS

L'infrastructure est déployée sur AWS et comprend les services suivants :

- **EC2** : Instances pour l'hébergement des applications
- **RDS** : Base de données MySQL
- **S3** : Stockage des médias et des sauvegardes
- **CloudWatch** : Monitoring et logs
- **IAM** : Gestion des accès et des permissions
- **VPC** : Réseau virtuel isolé
- **Route 53** : Gestion DNS

### Instances EC2 et conteneurisation

L'infrastructure utilise deux types d'instances EC2 distinctes, chacune avec un rôle spécifique :

1. **Instance EC2 Java Tomcat** : Dédiée à l'exécution de l'application Java backend via Tomcat
   - Exécute Java 17 (Amazon Corretto) et Tomcat 9.0.87
   - Ne contient pas Docker et n'exécute pas de conteneurs
   - Déploie les applications sous forme de fichiers WAR

2. **Instance EC2 Monitoring** : Dédiée à l'exécution des services de monitoring via Docker
   - Exécute Docker et Docker Compose
   - Contient les conteneurs pour les services de monitoring

**Images Docker** (uniquement sur l'instance EC2 Monitoring) :
- **app-react** : Application mobile React Native
- **grafana** : Visualisation des métriques
- **prometheus** : Collecte des métriques

- **mysql-exporter** : Collecte des métriques MySQL
- **cloudwatch-exporter** : Collecte des métriques CloudWatch

### Terraform

L'infrastructure est définie en code avec Terraform, ce qui permet une gestion cohérente et reproductible.

**Modules Terraform :**
- **ec2-java-tomcat** : Instance EC2 pour le backend Java/Tomcat
- **ec2-monitoring** : Instance EC2 pour le monitoring (Prometheus, Grafana)
- **rds-mysql** : Base de données MySQL
- **s3** : Buckets S3 pour le stockage des médias et des artefacts
- **network** : Configuration du VPC, des sous-réseaux et des groupes de sécurité


### Scripts

Les scripts sont centralisés dans un dossier unique et organisés par module ou fonction pour faciliter la maintenance et éviter la duplication. Chaque instance EC2 utilise uniquement les scripts qui lui sont spécifiques.

**Catégories de scripts :**
- **database** : Scripts liés à la base de données (sécurisation, migration, etc.)
- **docker** : Scripts de gestion des conteneurs Docker (construction, déploiement, nettoyage) - *utilisés uniquement sur l'instance EC2 Monitoring*
- **ec2-java-tomcat** : Scripts d'installation et de configuration de Java et Tomcat - *utilisés uniquement sur l'instance EC2 Java Tomcat*
- **ec2-monitoring** : Scripts de configuration du monitoring (Prometheus, Grafana) - *utilisés uniquement sur l'instance EC2 Monitoring*
- **utils** : Scripts utilitaires génériques (correction des clés SSH, installation de dépendances, etc.)

**Scripts spécifiques à l'instance EC2 Java Tomcat :**
- `init-instance-env.sh` : Initialisation de l'environnement
- `install_java_tomcat.sh` : Installation de Java et Tomcat
- `deploy-war.sh` : Déploiement d'applications WAR

**Scripts spécifiques à l'instance EC2 Monitoring :**
- `init-instance-env.sh` : Initialisation de l'environnement
- `install-docker.sh` : Installation de Docker
- `docker-manager.sh` : Gestion des conteneurs Docker
- `setup.sh` : Configuration des services de monitoring

**Ordre d'exécution des scripts :**
1. Les scripts sont téléchargés dans S3 par le workflow GitHub Actions avant le déploiement de l'infrastructure
2. Les instances EC2 téléchargent les scripts depuis S3 lors de leur initialisation
3. Les scripts vérifient les dépendances nécessaires avant leur exécution
4. Les scripts de configuration sont exécutés dans un ordre précis pour garantir le bon fonctionnement de l'infrastructure

## Sécurité

### Authentification et autorisation

- **Utilisateurs** : Authentification basée sur JWT
- **API** : Sécurisation avec Spring Security
- **Infrastructure** : IAM pour la gestion des accès AWS

### Gestion des secrets

- **GitHub Secrets** : Stockage des secrets pour les workflows GitHub Actions
- **Terraform Cloud** : Stockage des secrets pour l'infrastructure
- **Rotation automatique** : Rotation périodique des secrets sensibles

### Sécurité réseau

- **VPC** : Isolation réseau
- **Security Groups** : Contrôle des accès réseau
- **HTTPS** : Communication chiffrée

## Monitoring et observabilité

### Métriques

- **Prometheus** : Collecte des métriques
- **Grafana** : Visualisation des métriques
- **Dashboards** : Tableaux de bord pour les différents composants

### Logs

- **CloudWatch Logs** : Centralisation des logs
- **Log Rotation** : Gestion de la rétention des logs

### Alertes

- **Grafana Alerting** : Alertes basées sur les métriques
- **CloudWatch Alarms** : Alertes basées sur les métriques AWS
- **Notifications** : Envoi d'alertes par email et SNS

## Déploiement et CI/CD

### GitHub Actions

Les workflows GitHub Actions automatisent l'intégration et le déploiement continus.

**Workflows principaux :**
- **1-infra-deploy-destroy.yml** : Déploiement et destruction de l'infrastructure
- **2-backend-deploy.yml** : Déploiement du backend
- **2.1-application-tests.yml** : Tests automatisés des applications
- **3-docker-build-deploy.yml** : Construction et déploiement des images Docker
- **3.1-canary-deployment.yml** : Déploiement canary pour réduire les risques

- **5-docker-cleanup.yml** : Nettoyage des images Docker
- **4-analyse-de-securite.yml** : Analyse de sécurité

**Actions personnalisées :**
- **update-github-secret** : Action personnalisée pour mettre à jour les secrets GitHub de manière sécurisée, en utilisant les fichiers d'environnement au lieu de la commande `set-output` dépréciée.

### Déploiement canary

Le déploiement canary permet de réduire les risques en déployant progressivement les nouvelles versions.

**Processus :**
1. Déploiement de la nouvelle version pour un pourcentage limité du trafic
2. Surveillance des métriques et des logs
3. Augmentation progressive du pourcentage ou rollback en cas de problème
4. Promotion à 100% si tout fonctionne correctement

## Gestion des données

### Base de données

- **MySQL** : Base de données relationnelle
- **Schéma** : Structure des tables et des relations
- **Migrations** : Gestion des évolutions du schéma

### Stockage des médias

- **S3** : Stockage des fichiers médias
- **CDN** : Distribution des contenus statiques

### Sauvegardes

- **RDS Automated Backups** : Sauvegardes automatiques de la base de données
- **S3 Versioning** : Versionnement des fichiers dans S3
- **Scripts de sauvegarde** : Sauvegarde des configurations et des données des conteneurs

## Évolution et maintenance

### Gestion des versions

- **Semantic Versioning** : Versionnement sémantique des applications
- **Git Flow** : Workflow de développement basé sur Git

### Mise à jour des dépendances

- **Dependabot** : Mise à jour automatique des dépendances
- **Analyse de sécurité** : Vérification des vulnérabilités dans les dépendances

### Documentation

- **Documentation technique** : Architecture, API, etc.
- **Documentation utilisateur** : Guides d'utilisation
- **Diagrammes** : Représentation visuelle de l'architecture

---

Pour plus de détails sur chaque composant, veuillez consulter les diagrammes d'architecture dans le dossier `diagrams/` et la documentation spécifique à chaque module.
