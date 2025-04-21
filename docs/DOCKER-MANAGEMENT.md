# Gestion des Conteneurs Docker - YourMedia

Ce document explique comment gérer les conteneurs Docker dans le projet YourMedia, y compris la construction, le déploiement et le nettoyage des conteneurs.

> **Note** : Ce document remplace les anciens documents `DOCKER-CONTAINERS.md` et `DOCKER-MANAGEMENT.md` qui ont été fusionnés pour centraliser toutes les informations sur la gestion des conteneurs Docker.

## Table des matières

1. [Introduction](#introduction)
2. [Script de gestion Docker](#script-de-gestion-docker)
3. [Construction des images Docker](#construction-des-images-docker)
4. [Déploiement des conteneurs](#déploiement-des-conteneurs)
5. [Nettoyage des conteneurs](#nettoyage-des-conteneurs)
6. [Variables d'environnement](#variables-denvironnement)
7. [Dépannage](#dépannage)

## Introduction

Le projet YourMedia utilise Docker pour conteneuriser les applications et services suivants :

### Application
- **app-mobile** : Application React Native pour mobile (remplace l'ancien frontend React sur Amplify)

### Monitoring et qualité du code
- **prometheus** : Collecte et stockage des métriques
- **grafana** : Visualisation des métriques
- **sonarqube** : Analyse de la qualité du code
- **sonarqube-db** : Base de données PostgreSQL pour SonarQube
- **node-exporter** : Collecte des métriques système
- **mysql-exporter** : Collecte des métriques MySQL
- **cloudwatch-exporter** : Collecte des métriques AWS CloudWatch

Ces conteneurs sont déployés sur des instances EC2 dédiées :
- Instance EC2 pour l'application mobile
- Instance EC2 pour les services de monitoring

## Images Docker

Toutes les images Docker sont stockées dans un dépôt privé sur Docker Hub :
- https://hub.docker.com/r/medsin/yourmedia-ecf

Les images suivantes sont disponibles :
- `medsin/yourmedia-ecf:mobile-latest` - Application mobile React Native
- `medsin/yourmedia-ecf:grafana-latest` - Grafana avec dashboards préconfigurés
- `medsin/yourmedia-ecf:prometheus-latest` - Prometheus avec configuration personnalisée
- `medsin/yourmedia-ecf:sonarqube-latest` - SonarQube avec plugins supplémentaires

## Script de gestion Docker

Le script `scripts/docker/docker-manager.sh` est l'outil principal pour gérer les conteneurs Docker dans le projet. Il permet de :

- Construire et pousser les images Docker vers Docker Hub
- Déployer les conteneurs sur les instances EC2
- Gérer les différentes cibles (application mobile, services de monitoring)

### Utilisation

```bash
./scripts/docker/docker-manager.sh [build|deploy|all] [mobile|monitoring|all]
```

### Options

- **Actions** :
  - `build` : Construit et pousse les images Docker vers Docker Hub
  - `deploy` : Déploie les conteneurs Docker sur les instances EC2
  - `all` : Exécute les actions build et deploy

- **Cibles** :
  - `mobile` : Application mobile React Native
  - `monitoring` : Services de monitoring (Grafana, Prometheus, SonarQube)
  - `all` : Toutes les cibles

### Exemples

```bash
# Construire et pousser l'image de l'application mobile
./scripts/docker/docker-manager.sh build mobile

# Déployer les services de monitoring
./scripts/docker/docker-manager.sh deploy monitoring

# Construire, pousser et déployer toutes les images
./scripts/docker/docker-manager.sh all all
```

## Construction des images Docker

La construction des images Docker est gérée par le script `scripts/docker/docker-manager.sh` avec l'action `build`. Le script :

1. Se connecte à Docker Hub avec les identifiants fournis
2. Construit les images Docker pour les cibles spécifiées
3. Pousse les images vers Docker Hub avec les tags appropriés (version et latest)

### Images construites

- **Application mobile** : `$DOCKER_USERNAME/$DOCKER_REPO:mobile-latest`
- **Grafana** : `$DOCKER_USERNAME/$DOCKER_REPO:grafana-latest`
- **Prometheus** : `$DOCKER_USERNAME/$DOCKER_REPO:prometheus-latest`
- **SonarQube** : `$DOCKER_USERNAME/$DOCKER_REPO:sonarqube-latest`

## Déploiement des conteneurs

Le déploiement des conteneurs est géré par le script `scripts/docker/docker-manager.sh` avec l'action `deploy`. Le script :

1. Se connecte aux instances EC2 via SSH
2. Crée les répertoires nécessaires pour les volumes Docker
3. Génère les fichiers docker-compose.yml avec les variables appropriées
4. Tire les images Docker depuis Docker Hub
5. Démarre les conteneurs avec docker-compose

### Conteneurs déployés

- **Instance EC2 de l'application** :
  - Application mobile React Native

- **Instance EC2 de monitoring** :
  - Grafana
  - Prometheus
  - SonarQube
  - Base de données PostgreSQL pour SonarQube
  - Exportateur CloudWatch
  - Exportateur MySQL
  - Exportateur Node

## Nettoyage des conteneurs

Le nettoyage des conteneurs est géré par le script `scripts/docker/cleanup-containers.sh`. Ce script permet de :

1. Arrêter et supprimer les conteneurs Docker
2. Supprimer les images Docker
3. Supprimer les volumes Docker
4. Nettoyer les réseaux Docker
5. Effectuer un nettoyage complet du système Docker

### Utilisation

```bash
./scripts/docker/cleanup-containers.sh <EC2_MONITORING_IP> <EC2_APP_IP> <SSH_KEY_PATH> [CLEANUP_TYPE]
```

### Options de nettoyage

- `all` : Nettoie tout (conteneurs, images, volumes, réseaux, fichiers) - par défaut
- `containers` : Arrête et supprime uniquement les conteneurs
- `images` : Supprime uniquement les images Docker
- `volumes` : Supprime uniquement les volumes Docker
- `networks` : Supprime uniquement les réseaux Docker personnalisés
- `prune` : Exécute docker system prune -af --volumes

### Exemple

```bash
# Nettoyer tous les conteneurs, images, volumes, etc.
./scripts/docker/cleanup-containers.sh 192.168.1.10 192.168.1.11 ~/.ssh/id_rsa all

# Nettoyer uniquement les conteneurs
./scripts/docker/cleanup-containers.sh 192.168.1.10 192.168.1.11 ~/.ssh/id_rsa containers
```

## Variables d'environnement

Les scripts de gestion Docker utilisent les variables d'environnement suivantes :

### Variables Docker Hub

- `DOCKERHUB_USERNAME` : Nom d'utilisateur Docker Hub
- `DOCKERHUB_TOKEN` : Token d'accès Docker Hub
- `DOCKERHUB_REPO` : Nom du dépôt Docker Hub (par défaut : yourmedia-ecf)

### Variables EC2

- `TF_EC2_PUBLIC_IP` : Adresse IP publique de l'instance EC2 de l'application
- `TF_MONITORING_EC2_PUBLIC_IP` : Adresse IP publique de l'instance EC2 de monitoring
- `EC2_SSH_PRIVATE_KEY` : Clé SSH privée pour se connecter aux instances EC2

### Variables de configuration

- `GF_SECURITY_ADMIN_PASSWORD` : Mot de passe administrateur Grafana (par défaut : admin)
- `DB_USERNAME` : Nom d'utilisateur de la base de données
- `DB_PASSWORD` : Mot de passe de la base de données
- `TF_RDS_ENDPOINT` : Point de terminaison RDS
- `GITHUB_CLIENT_ID` : ID client GitHub pour SonarQube
- `GITHUB_CLIENT_SECRET` : Secret client GitHub pour SonarQube

## Dépannage

### Problèmes courants

#### Erreur de connexion à Docker Hub

```
Error response from daemon: Get "https://registry-1.docker.io/v2/": unauthorized: incorrect username or password
```

**Solution** : Vérifiez que les variables `DOCKERHUB_USERNAME` et `DOCKERHUB_TOKEN` sont correctement définies.

#### Erreur de connexion SSH

```
Permission denied (publickey,gssapi-keyex,gssapi-with-mic)
```

**Solution** : Vérifiez que la variable `EC2_SSH_PRIVATE_KEY` est correctement définie et que la clé SSH est valide.

#### Erreur de déploiement des conteneurs

```
ERROR: Couldn't connect to Docker daemon at http+docker://localhost - is it running?
```

**Solution** : Vérifiez que Docker est installé et en cours d'exécution sur les instances EC2.

### Logs des conteneurs

Pour consulter les logs des conteneurs, connectez-vous à l'instance EC2 et exécutez :

```bash
# Logs de l'application mobile
sudo docker logs app-mobile

# Logs de Grafana
sudo docker logs grafana

# Logs de Prometheus
sudo docker logs prometheus

# Logs de SonarQube
sudo docker logs sonarqube
```
