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

SonarQube nécessite certaines configurations système spécifiques qui sont automatiquement appliquées par le script `setup.sh` :

```bash
# Augmenter la limite de mmap count (nécessaire pour Elasticsearch)
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

# Augmenter la limite de fichiers ouverts
sudo sysctl -w fs.file-max=65536
echo "fs.file-max=65536" | sudo tee -a /etc/sysctl.conf

# Configurer les limites de ressources pour l'utilisateur ec2-user
echo "ec2-user soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "ec2-user hard nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "ec2-user soft nproc 4096" | sudo tee -a /etc/security/limits.conf
echo "ec2-user hard nproc 4096" | sudo tee -a /etc/security/limits.conf
```

### Configuration de la mémoire pour SonarQube

SonarQube et Elasticsearch nécessitent une configuration de mémoire spécifique pour éviter les erreurs OOM (Out Of Memory). Cette configuration est définie dans le fichier `docker-compose.yml` :

```yaml
environment:
  # Limiter la mémoire utilisée par Elasticsearch
  - SONAR_ES_JAVA_OPTS=-Xms512m -Xmx512m
  # Limiter la mémoire globale de SonarQube
  - SONAR_WEB_JAVA_OPTS=-Xmx512m -Xms256m
  - SONAR_CE_JAVA_OPTS=-Xmx512m -Xms256m
mem_limit: 1536m
```

### Déploiement avec Docker

SonarQube est déployé en tant que conteneur Docker sur l'instance EC2 de monitoring. Le déploiement est géré par les scripts suivants :

1. **`scripts/ec2-monitoring/setup.sh`** : Script principal d'installation et de configuration qui configure les prérequis système et déploie les conteneurs Docker.
2. **`scripts/ec2-monitoring/get-aws-resources-info.sh`** : Script qui récupère automatiquement les informations RDS et S3 pour configurer SonarQube.
3. **`scripts/ec2-monitoring/restart-containers.sh`** : Script pour redémarrer les conteneurs Docker après avoir récupéré les informations RDS et S3.
4. **`scripts/ec2-monitoring/check-containers.sh`** : Script pour vérifier l'état des conteneurs et afficher les informations de connexion.

La configuration de SonarQube se trouve dans le fichier `scripts/ec2-monitoring/docker-compose.yml` qui définit les conteneurs Docker pour SonarQube et sa base de données PostgreSQL.

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
2. Sélectionnez le workflow "4 - SonarQube Analysis"
3. Cliquez sur "Run workflow"
4. Sélectionnez le projet à analyser (all, backend ou mobile)
5. Cliquez sur "Run workflow"

### Analyse automatique

Une analyse est automatiquement déclenchée à chaque push sur la branche main qui modifie les fichiers dans les répertoires `app-java` ou `app-react`.

### Configuration de l'analyse

L'analyse est configurée dans les fichiers suivants :

- `.github/workflows/4-sonarqube-analysis.yml` : Configuration du workflow GitHub Actions
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

## Utilisation des scripts

### Récupération des informations RDS et S3

Pour récupérer automatiquement les informations RDS et S3 et configurer SonarQube, utilisez le script `get-aws-resources-info.sh` :

```bash
sudo /opt/monitoring/get-aws-resources-info.sh
```

Ce script :
1. Récupère les informations de la base de données RDS (endpoint, nom d'utilisateur, mot de passe)
2. Récupère les informations du bucket S3 (nom, région)
3. Crée un fichier de configuration pour CloudWatch Exporter
4. Applique les prérequis système pour SonarQube (limites de mmap count et de fichiers ouverts)
5. Configure les permissions appropriées pour les volumes SonarQube

### Redémarrage des conteneurs

Pour redémarrer les conteneurs Docker après avoir récupéré les informations RDS et S3, utilisez le script `restart-containers.sh` :

```bash
sudo /opt/monitoring/restart-containers.sh
```

Ce script :
1. Exécute le script `get-aws-resources-info.sh` pour récupérer les informations RDS et S3
2. Arrête les conteneurs existants
3. Démarre les conteneurs avec les nouvelles informations
4. Vérifie que tous les conteneurs sont en cours d'exécution

### Vérification et correction automatique des conteneurs

Pour vérifier l'état des conteneurs, afficher les informations de connexion et corriger automatiquement les problèmes courants, utilisez le script `check-containers.sh` :

```bash
sudo /opt/monitoring/check-containers.sh
```

Ce script :
1. Vérifie que tous les conteneurs sont en cours d'exécution
2. Redémarre automatiquement les conteneurs arrêtés
3. Corrige automatiquement les problèmes courants :
   - Pour SonarQube : vérifie et ajuste les limites système (vm.max_map_count)
   - Pour MySQL Exporter : vérifie et corrige la configuration de connexion à la base de données
4. Affiche les informations de connexion (URL, utilisateur, mot de passe)
5. Affiche les informations sur les ressources AWS (RDS, S3)
6. Affiche l'utilisation des ressources (CPU, mémoire, disque)

Le script est également configuré pour s'exécuter automatiquement toutes les 15 minutes via une tâche cron, ce qui permet de maintenir les conteneurs en état de fonctionnement sans intervention manuelle.

## Résolution des problèmes

### Problèmes courants

#### SonarQube ne démarre pas

Si SonarQube ne démarre pas malgré l'exécution automatique du script `check-containers.sh`, suivez ces étapes :

1. Vérifiez les logs : `docker logs sonarqube`
2. Recherchez spécifiquement les erreurs liées à Elasticsearch (code d'erreur 137, qui indique un problème de mémoire)
3. Vérifiez que les limites système sont correctement configurées :
   ```bash
   sysctl -a | grep -E "vm.max_map_count|fs.file-max"
   ```
4. Vérifiez que les volumes ont les bonnes permissions :
   ```bash
   ls -la /opt/monitoring/sonarqube-data/
   ```
5. Appliquez manuellement les prérequis système :
   ```bash
   sudo sysctl -w vm.max_map_count=262144
   sudo sysctl -w fs.file-max=65536
   ```
6. Vérifiez la mémoire disponible sur le système :
   ```bash
   free -h
   ```
7. Si la mémoire est insuffisante, augmentez la taille de l'instance EC2 ou ajustez les limites de mémoire dans le fichier `docker-compose.yml`
8. Redémarrez les conteneurs :
   ```bash
   cd /opt/monitoring
   sudo docker-compose down
   sudo docker-compose up -d
   ```

#### L'analyse échoue
1. Vérifiez les logs du workflow GitHub Actions
2. Vérifiez que le token SonarQube est correctement configuré
3. Vérifiez que l'URL de SonarQube est correcte
4. Vérifiez que SonarQube est accessible avec `curl -I http://<EC2_MONITORING_IP>:9000`

#### Problèmes d'authentification GitHub
1. Vérifiez que les identifiants client GitHub sont correctement configurés
2. Vérifiez que l'utilisateur GitHub a les permissions nécessaires
3. Vérifiez les logs de SonarQube pour les erreurs d'authentification

#### Problèmes de base de données PostgreSQL (SonarQube)
1. Vérifiez que la base de données PostgreSQL est en cours d'exécution avec `docker ps | grep sonarqube-db`
2. Vérifiez les logs de la base de données avec `docker logs sonarqube-db`
3. Vérifiez que les volumes de la base de données ont les bonnes permissions

#### Problèmes avec MySQL Exporter

Si MySQL Exporter ne démarre pas ou ne collecte pas de métriques :

1. Vérifiez les logs : `docker logs mysql-exporter`
2. Recherchez les erreurs liées à la configuration de la connexion, comme "no user specified" ou "connection refused"
3. Vérifiez que les variables d'environnement RDS sont correctement définies :
   ```bash
   cat /opt/monitoring/env.sh | grep RDS
   ```
4. Vérifiez que l'endpoint RDS est accessible depuis l'instance EC2 :
   ```bash
   telnet <RDS_HOST> <RDS_PORT>
   ```
5. Créez manuellement un fichier de configuration .my.cnf :
   ```bash
   cat > /tmp/.my.cnf << EOF
   [client]
   user=<RDS_USERNAME>
   password=<RDS_PASSWORD>
   host=<RDS_HOST>
   port=<RDS_PORT>
   EOF
   chmod 600 /tmp/.my.cnf
   ```
6. Redémarrez le conteneur MySQL Exporter :
   ```bash
   cd /opt/monitoring
   sudo docker-compose restart mysql-exporter
   ```
7. Si le problème persiste, vérifiez les règles de sécurité RDS pour vous assurer que l'instance EC2 est autorisée à se connecter à la base de données
