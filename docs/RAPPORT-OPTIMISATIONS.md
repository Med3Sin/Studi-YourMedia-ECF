# Rapport d'optimisations pour YourMedia

Ce document centralise toutes les optimisations effectuées et recommandées pour le projet YourMedia.

## 1. Optimisations pour le Free Tier AWS

### 1.1. Instances EC2

#### Type d'instance

Les instances EC2 ont été standardisées sur le type `t2.micro` qui est éligible au Free Tier AWS :

- 1 vCPU
- 1 Go de RAM
- Jusqu'à 30 Go de stockage EBS

#### Volumes EBS

La taille des volumes EBS a été optimisée pour rester dans le cadre du Free Tier :

- Volume racine : 8 Go (au lieu de 20 Go)
- Pas de volumes supplémentaires

#### Politique d'arrêt automatique

Pour réduire davantage les coûts, une politique d'arrêt automatique des instances EC2 en dehors des heures de travail a été mise en place :

```bash
aws events put-rule \
  --name "StopEC2Instances" \
  --schedule-expression "cron(0 19 ? * MON-FRI *)" \
  --state ENABLED

aws events put-targets \
  --rule "StopEC2Instances" \
  --targets "Id"="1","Arn"="arn:aws:ssm:eu-west-3::automation-definition/AWS-StopEC2Instance","Input"="{\"InstanceId\":[\"i-INSTANCE_ID_1\",\"i-INSTANCE_ID_2\"]}"
```

### 1.2. Base de données RDS

#### Type d'instance

La base de données RDS a été configurée pour utiliser le type d'instance `db.t3.micro` qui est éligible au Free Tier AWS :

- 1 vCPU
- 1 Go de RAM
- Jusqu'à 20 Go de stockage

#### Optimisations supplémentaires

- Multi-AZ désactivé (économie de 100% sur le coût de la seconde instance)
- Période de rétention des sauvegardes réduite à 0 jour (minimum pour le Free Tier)
- Stockage alloué limité à 20 Go

### 1.3. Stockage S3

#### Règles de cycle de vie

Des règles de cycle de vie ont été configurées pour optimiser les coûts de stockage S3 :

- Transition vers Glacier après 7 jours pour les fichiers de build
- Transition vers Glacier après 14 jours pour les fichiers WAR
- Expiration des objets après 15 jours pour les fichiers de build
- Expiration des objets après 30 jours pour les fichiers WAR
- Suppression des versions précédentes après 3-7 jours

#### Versioning

Le versioning est activé pour permettre la récupération de fichiers, mais avec des règles strictes d'expiration pour limiter les coûts.

### 1.4. Conteneurs Docker

#### Limites de ressources

Les limites de ressources des conteneurs Docker ont été optimisées pour s'adapter aux contraintes du Free Tier :

- Prometheus : 256 Mo de RAM (au lieu de 512 Mo)
- Grafana : 256 Mo de RAM (au lieu de 512 Mo)
- MySQL Exporter : 128 Mo de RAM (au lieu de 256 Mo)
- Node Exporter : 128 Mo de RAM
- Loki : 256 Mo de RAM (au lieu de 512 Mo)
- Promtail : 128 Mo de RAM (au lieu de 256 Mo)

## 2. Optimisations de performance

### 2.1. Application Java

#### Optimisations JVM

- Paramètres JVM optimisés pour les instances t2.micro :
  ```
  -Xms256m -Xmx512m -XX:+UseG1GC -XX:+UseStringDeduplication
  ```

#### Mise en cache

- Mise en cache des requêtes fréquentes
- Utilisation de Hibernate second-level cache
- Configuration du pool de connexions pour optimiser les performances

### 2.2. Application React

#### Optimisations de build

- Utilisation de la compression gzip pour les fichiers statiques
- Minification du code JavaScript et CSS
- Utilisation de code splitting pour réduire la taille du bundle initial

#### Optimisations d'exécution

- Utilisation de React.memo pour éviter les rendus inutiles
- Lazy loading des composants non critiques
- Optimisation des images avec compression et redimensionnement

### 2.3. Base de données

#### Optimisations de requêtes

- Création d'index pour les requêtes fréquentes
- Optimisation des requêtes SQL complexes
- Utilisation de procédures stockées pour les opérations complexes

#### Configuration

- Paramètres MySQL optimisés pour les instances t3.micro :
  ```
  innodb_buffer_pool_size = 256M
  innodb_log_file_size = 64M
  max_connections = 50
  ```

## 3. Optimisations de sécurité

### 3.1. Permissions minimales

- Application du principe du moindre privilège pour tous les rôles IAM
- Utilisation de politiques IAM spécifiques pour chaque service
- Limitation des accès réseau avec des groupes de sécurité restrictifs

### 3.2. Sécurisation des scripts

- Ajout de `umask 077` au début des scripts pour sécuriser les fichiers créés
- Utilisation de `trap` pour nettoyer les fichiers temporaires
- Vérification des permissions après création de fichiers sensibles

### 3.3. Sécurisation des conteneurs

- Scan des vulnérabilités avec Trivy
- Utilisation d'images de base officielles et à jour
- Limitation des privilèges des conteneurs

## 4. Standardisation des variables

### 4.1. Variables Docker

| Variable standardisée | Ancienne variable | Description |
|----------------------|-------------------|-------------|
| `DOCKERHUB_USERNAME` | `DOCKER_USERNAME` | Nom d'utilisateur Docker Hub |
| `DOCKERHUB_TOKEN` | `DOCKER_PASSWORD` | Token d'authentification Docker Hub |
| `DOCKERHUB_REPO` | `DOCKER_REPO` | Nom du dépôt Docker Hub |

### 4.2. Variables RDS/DB

| Variable standardisée | Ancienne variable | Description |
|----------------------|-------------------|-------------|
| `RDS_USERNAME` | `DB_USERNAME` | Nom d'utilisateur RDS |
| `RDS_PASSWORD` | `DB_PASSWORD` | Mot de passe RDS |
| `RDS_ENDPOINT` | `DB_ENDPOINT` | Point de terminaison RDS |

### 4.3. Variables Grafana

| Variable standardisée | Ancienne variable | Description |
|----------------------|-------------------|-------------|
| `GF_SECURITY_ADMIN_PASSWORD` | `GRAFANA_ADMIN_PASSWORD` | Mot de passe administrateur Grafana |

## 5. Optimisations des workflows GitHub Actions

### 5.1. Réduction des temps d'exécution

- Utilisation de caches pour les dépendances
- Exécution conditionnelle des étapes
- Parallélisation des tâches indépendantes

### 5.2. Optimisation des builds Docker

- Utilisation de buildx pour des builds multi-plateformes efficaces
- Mise en cache des couches Docker
- Construction d'images légères avec multi-stage builds

### 5.3. Réduction des coûts

- Limitation du nombre de workflows exécutés
- Utilisation de timeouts pour éviter les exécutions infinies
- Nettoyage régulier des artefacts et des caches

## 6. Recommandations pour l'avenir

### 6.1. Infrastructure

- Utilisation d'Auto Scaling pour adapter automatiquement la capacité à la demande
- Mise en place d'une architecture multi-AZ pour améliorer la disponibilité
- Utilisation de CloudFront pour la distribution de contenu statique

### 6.2. Monitoring et alerting

- Configuration d'alertes pour l'utilisation des ressources
- Mise en place d'un dashboard de coûts AWS
- Automatisation des réponses aux incidents

### 6.3. CI/CD

- Mise en place de tests automatisés plus complets
- Utilisation de déploiements bleu/vert ou canary
- Intégration de l'analyse de qualité de code dans le pipeline
