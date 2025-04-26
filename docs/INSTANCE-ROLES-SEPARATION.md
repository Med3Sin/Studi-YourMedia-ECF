# Séparation des rôles des instances EC2

Ce document explique la séparation claire des rôles entre les différentes instances EC2 dans l'infrastructure YourMedia, en particulier la distinction entre l'instance EC2 Java Tomcat et l'instance EC2 Monitoring.

## Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Instance EC2 Java Tomcat](#instance-ec2-java-tomcat)
3. [Instance EC2 Monitoring](#instance-ec2-monitoring)
4. [Séparation des responsabilités](#séparation-des-responsabilités)
5. [Scripts spécifiques à chaque instance](#scripts-spécifiques-à-chaque-instance)
6. [Bonnes pratiques](#bonnes-pratiques)

## Vue d'ensemble

L'infrastructure YourMedia utilise deux types d'instances EC2 principales, chacune avec un rôle spécifique :

1. **Instance EC2 Java Tomcat** : Dédiée à l'exécution de l'application Java backend via Tomcat
2. **Instance EC2 Monitoring** : Dédiée à l'exécution des services de monitoring via Docker (Prometheus, Grafana, SonarQube)

Cette séparation permet une meilleure isolation des services, une gestion plus fine des ressources et une sécurité renforcée.

## Instance EC2 Java Tomcat

### Rôle principal

L'instance EC2 Java Tomcat est responsable de l'exécution de l'application backend Java via le serveur d'applications Tomcat. Elle ne contient pas Docker et n'exécute pas de conteneurs.

### Composants installés

- **Java** : Amazon Corretto 17
- **Tomcat** : Version 9.0.87
- **Node Exporter** : Pour la collecte de métriques système par Prometheus

### Processus d'initialisation

1. Le script `user_data` dans Terraform définit les variables d'environnement nécessaires
2. Le script `init-instance-env.sh` est téléchargé depuis S3 et exécuté
3. Les scripts spécifiques à Java/Tomcat sont téléchargés depuis S3
4. Le script `install_java_tomcat.sh` installe Java et Tomcat
5. Le script `deploy-war.sh` est configuré pour permettre le déploiement d'applications WAR

### Variables d'environnement

Les variables d'environnement suivantes sont définies pour l'instance EC2 Java Tomcat :

```bash
export EC2_INSTANCE_PRIVATE_IP="..."
export RDS_USERNAME="..."
export RDS_PASSWORD="..."
export RDS_ENDPOINT="..."
export DB_USERNAME="..." # Variable de compatibilité
export DB_PASSWORD="..." # Variable de compatibilité
export S3_BUCKET_NAME="..."
export TOMCAT_VERSION="9.0.87"
```

## Instance EC2 Monitoring

### Rôle principal

L'instance EC2 Monitoring est responsable de l'exécution des services de monitoring via Docker. Elle exécute plusieurs conteneurs Docker pour les différents services de monitoring.

### Composants installés

- **Docker** : Pour l'exécution des conteneurs
- **Docker Compose** : Pour la gestion des conteneurs
- **Prometheus** : Pour la collecte et le stockage des métriques
- **Grafana** : Pour la visualisation des métriques
- **SonarQube** : Pour l'analyse de la qualité du code
- **Exportateurs** : Pour la collecte de métriques spécifiques (MySQL, CloudWatch, etc.)

### Processus d'initialisation

1. Le script `user_data` dans Terraform définit les variables d'environnement nécessaires
2. Le script `init-instance-env.sh` est téléchargé depuis S3 et exécuté
3. Les scripts spécifiques au monitoring sont téléchargés depuis S3
4. Le script `install-docker.sh` installe Docker
5. Le script `docker-manager.sh` est configuré pour gérer les conteneurs Docker
6. Le script `setup.sh` configure les services de monitoring

### Variables d'environnement

Les variables d'environnement suivantes sont définies pour l'instance EC2 Monitoring :

```bash
export EC2_INSTANCE_PRIVATE_IP="..."
export DB_USERNAME="..."
export DB_PASSWORD="..."
export RDS_ENDPOINT="..."
export SONAR_JDBC_USERNAME="..."
export SONAR_JDBC_PASSWORD="..."
export SONAR_JDBC_URL="..."
export GRAFANA_ADMIN_PASSWORD="..."
export S3_BUCKET_NAME="..."
export DOCKER_USERNAME="..."
export DOCKER_REPO="..."
export DOCKERHUB_TOKEN="..."
```

## Séparation des responsabilités

La séparation des responsabilités entre les instances EC2 Java Tomcat et EC2 Monitoring est essentielle pour maintenir une architecture propre et sécurisée. Voici les principes clés de cette séparation :

### Instance EC2 Java Tomcat

- **Ne contient pas Docker** : L'instance EC2 Java Tomcat n'a pas besoin de Docker et ne doit pas l'installer
- **Exécute uniquement Tomcat** : L'instance EC2 Java Tomcat exécute uniquement le serveur d'applications Tomcat
- **Déploie des applications WAR** : Les applications sont déployées sous forme de fichiers WAR dans Tomcat

### Instance EC2 Monitoring

- **Contient Docker** : L'instance EC2 Monitoring utilise Docker pour exécuter les services de monitoring
- **Exécute plusieurs conteneurs** : L'instance EC2 Monitoring exécute plusieurs conteneurs Docker pour les différents services
- **Collecte des métriques** : L'instance EC2 Monitoring collecte des métriques de toutes les autres instances et services

## Scripts spécifiques à chaque instance

### Scripts pour l'instance EC2 Java Tomcat

Les scripts suivants sont spécifiques à l'instance EC2 Java Tomcat :

- `scripts/ec2-java-tomcat/init-instance-env.sh` : Script d'initialisation de l'instance
- `scripts/ec2-java-tomcat/install_java_tomcat.sh` : Script d'installation de Java et Tomcat
- `scripts/ec2-java-tomcat/deploy-war.sh` : Script de déploiement d'applications WAR

### Scripts pour l'instance EC2 Monitoring

Les scripts suivants sont spécifiques à l'instance EC2 Monitoring :

- `scripts/ec2-monitoring/init-instance-env.sh` : Script d'initialisation de l'instance
- `scripts/ec2-monitoring/install-docker.sh` : Script d'installation de Docker
- `scripts/ec2-monitoring/setup.sh` : Script de configuration des services de monitoring
- `scripts/docker/docker-manager.sh` : Script de gestion des conteneurs Docker

## Bonnes pratiques

Pour maintenir une séparation claire des responsabilités entre les instances EC2, suivez ces bonnes pratiques :

1. **Ne pas installer Docker sur l'instance EC2 Java Tomcat** : Docker n'est pas nécessaire sur l'instance EC2 Java Tomcat et ne doit pas y être installé.

2. **Utiliser des scripts spécifiques à chaque instance** : Chaque instance doit utiliser uniquement les scripts qui lui sont spécifiques.

3. **Définir uniquement les variables d'environnement nécessaires** : Chaque instance doit définir uniquement les variables d'environnement dont elle a besoin.

4. **Documenter clairement les rôles de chaque instance** : La documentation doit clairement indiquer le rôle de chaque instance et les composants qui y sont installés.

5. **Éviter la duplication de code** : Les fonctions communes doivent être extraites dans des scripts utilitaires partagés.

6. **Vérifier les dépendances avant l'installation** : Chaque script doit vérifier les dépendances nécessaires avant d'installer des composants.

7. **Gérer correctement les erreurs** : Chaque script doit gérer correctement les erreurs et afficher des messages clairs en cas de problème.

8. **Sécuriser les informations sensibles** : Les informations sensibles doivent être stockées de manière sécurisée et ne pas être affichées dans les logs.

---

En suivant ces principes et bonnes pratiques, vous maintiendrez une architecture propre, sécurisée et facile à maintenir pour votre infrastructure YourMedia.
