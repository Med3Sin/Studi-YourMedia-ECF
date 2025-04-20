# Guide des conteneurs Docker - YourMédia

Ce document explique comment utiliser les conteneurs Docker pour déployer l'application YourMédia et ses services associés.

## Table des matières

1. [Architecture des conteneurs](#architecture-des-conteneurs)
2. [Images Docker](#images-docker)
3. [Construction des images](#construction-des-images)
4. [Déploiement des conteneurs](#déploiement-des-conteneurs)
5. [Configuration des conteneurs](#configuration-des-conteneurs)
6. [Surveillance des conteneurs](#surveillance-des-conteneurs)
7. [Résolution des problèmes](#résolution-des-problèmes)

## Architecture des conteneurs

L'architecture de YourMédia basée sur des conteneurs Docker comprend les composants suivants :

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

## Images Docker

Toutes les images Docker sont stockées dans un dépôt privé sur Docker Hub :
- https://hub.docker.com/r/medsin/yourmedia-ecf

Les images suivantes sont disponibles :
- `medsin/yourmedia-ecf:mobile-latest` - Application mobile React Native
- `medsin/yourmedia-ecf:grafana-latest` - Grafana avec dashboards préconfigurés
- `medsin/yourmedia-ecf:prometheus-latest` - Prometheus avec configuration personnalisée
- `medsin/yourmedia-ecf:sonarqube-latest` - SonarQube avec plugins supplémentaires

## Construction des images

### Prérequis
- Docker installé localement
- Accès au dépôt Docker Hub privé

### Construction manuelle

Vous pouvez construire les images manuellement en utilisant le script `scripts/build-push-docker.sh` :

```bash
# Construire et pousser toutes les images
./scripts/build-push-docker.sh all

# Construire et pousser uniquement l'image de l'application mobile
./scripts/build-push-docker.sh mobile

# Construire et pousser uniquement les images de monitoring
./scripts/build-push-docker.sh monitoring
```

### Construction automatisée

Un workflow GitHub Actions est configuré pour construire et pousser les images automatiquement :
- `.github/workflows/3-docker-build-deploy.yml`

Vous pouvez déclencher ce workflow manuellement depuis l'interface GitHub Actions en sélectionnant les options suivantes :
- **Target** : all, mobile ou monitoring
- **Deploy** : true ou false

## Déploiement des conteneurs

### Prérequis
- Instances EC2 configurées (application et monitoring)
- Docker et docker-compose installés sur les instances
- Accès SSH aux instances

### Déploiement manuel

Vous pouvez déployer les conteneurs manuellement en utilisant le script `scripts/deploy-containers.sh` :

```bash
# Déployer tous les conteneurs
./scripts/deploy-containers.sh all

# Déployer uniquement les conteneurs de monitoring
./scripts/deploy-containers.sh monitoring

# Déployer uniquement le conteneur de l'application mobile
./scripts/deploy-containers.sh app
```

### Déploiement automatisé

Le workflow GitHub Actions mentionné précédemment peut également déployer les conteneurs automatiquement si l'option **Deploy** est définie sur `true`.

## Configuration des conteneurs

### Variables d'environnement

Les conteneurs utilisent les variables d'environnement suivantes :

#### Application mobile
- `API_URL` : URL de l'API backend
- `NODE_ENV` : Environnement (production, development)

#### Grafana
- `GF_SECURITY_ADMIN_PASSWORD` : Mot de passe administrateur Grafana
- `GF_USERS_ALLOW_SIGN_UP` : Autoriser l'inscription des utilisateurs
- `GF_AUTH_ANONYMOUS_ENABLED` : Activer l'accès anonyme
- `GF_AUTH_ANONYMOUS_ORG_ROLE` : Rôle pour l'accès anonyme

#### SonarQube
- `SONAR_JDBC_URL` : URL de connexion à la base de données
- `SONAR_JDBC_USERNAME` : Nom d'utilisateur pour la base de données
- `SONAR_JDBC_PASSWORD` : Mot de passe pour la base de données
- `GITHUB_CLIENT_ID` : ID client GitHub pour l'authentification
- `GITHUB_CLIENT_SECRET` : Secret client GitHub pour l'authentification

### Volumes persistants

Les données persistantes sont stockées dans les volumes suivants :

#### Monitoring
- `/opt/monitoring/prometheus-data` : Données Prometheus
- `/opt/monitoring/grafana-data` : Données Grafana
- `/opt/monitoring/sonarqube-data` : Données SonarQube
- `/opt/monitoring/sonarqube-extensions` : Extensions SonarQube
- `/opt/monitoring/sonarqube-logs` : Logs SonarQube
- `/opt/monitoring/sonarqube-db` : Données PostgreSQL pour SonarQube

## Surveillance des conteneurs

### Accès aux interfaces web

- **Application mobile** : http://<EC2_APP_IP>:3000
- **Grafana** : http://<EC2_MONITORING_IP>:3000
- **Prometheus** : http://<EC2_MONITORING_IP>:9090
- **SonarQube** : http://<EC2_MONITORING_IP>:9000

### Logs des conteneurs

Vous pouvez consulter les logs des conteneurs en utilisant les commandes suivantes :

```bash
# Logs de l'application mobile
docker logs app-mobile

# Logs de Grafana
docker logs grafana

# Logs de Prometheus
docker logs prometheus

# Logs de SonarQube
docker logs sonarqube
```

## Résolution des problèmes

### Problèmes courants

#### Conteneur qui ne démarre pas
1. Vérifiez les logs du conteneur : `docker logs <nom_conteneur>`
2. Vérifiez que les volumes sont correctement montés et ont les bonnes permissions
3. Vérifiez que les variables d'environnement sont correctement définies

#### Problèmes de connexion à Docker Hub
1. Vérifiez que vous êtes correctement authentifié : `docker login`
2. Vérifiez que vous avez accès au dépôt privé
3. Vérifiez que les secrets GitHub sont correctement configurés

#### Problèmes de mémoire avec SonarQube
1. Vérifiez que les limites système sont correctement configurées : `sysctl -a | grep vm.max_map_count`
2. Augmentez les limites si nécessaire : `echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf && sudo sysctl -p`

### Commandes utiles

```bash
# Vérifier l'état des conteneurs
docker ps

# Redémarrer un conteneur
docker restart <nom_conteneur>

# Voir les logs d'un conteneur
docker logs <nom_conteneur>

# Exécuter une commande dans un conteneur
docker exec -it <nom_conteneur> <commande>

# Arrêter tous les conteneurs
docker-compose down

# Démarrer tous les conteneurs
docker-compose up -d
```
