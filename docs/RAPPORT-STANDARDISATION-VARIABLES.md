# Rapport de standardisation des variables du projet YourMedia

## 1. Introduction

Ce rapport documente les modifications effectuées pour standardiser les variables d'environnement et les secrets dans le projet YourMedia. L'objectif était d'éliminer les variables de compatibilité et d'utiliser uniquement les variables standardisées dans tous les fichiers du projet.

## 2. Variables standardisées

### 2.1. Variables Docker

| Variable standardisée | Ancienne variable | Description |
|----------------------|-------------------|-------------|
| `DOCKERHUB_USERNAME` | `DOCKER_USERNAME` | Nom d'utilisateur Docker Hub |
| `DOCKERHUB_TOKEN` | `DOCKER_PASSWORD` | Token d'authentification Docker Hub |
| `DOCKERHUB_REPO` | `DOCKER_REPO` | Nom du dépôt Docker Hub |

### 2.2. Variables RDS/DB

| Variable standardisée | Ancienne variable | Description |
|----------------------|-------------------|-------------|
| `RDS_USERNAME` | `DB_USERNAME` | Nom d'utilisateur RDS |
| `RDS_PASSWORD` | `DB_PASSWORD` | Mot de passe RDS |
| `RDS_ENDPOINT` | `DB_ENDPOINT` | Point de terminaison RDS |

### 2.3. Variables Grafana

| Variable standardisée | Ancienne variable | Description |
|----------------------|-------------------|-------------|
| `GF_SECURITY_ADMIN_PASSWORD` | `GRAFANA_ADMIN_PASSWORD` | Mot de passe administrateur Grafana |

## 3. Fichiers modifiés

### 3.1. Workflows GitHub Actions

- `.github/workflows/0-verification-secrets.yml`
- `.github/workflows/1-infra-deploy-destroy.yml`
- `.github/workflows/3-docker-build-deploy.yml`
- `.github/workflows/4-analyse-de-securite.yml`
- `.github/workflows/5-docker-cleanup.yml`

### 3.2. Scripts

- `scripts/ec2-monitoring/init-monitoring.sh`
- `scripts/ec2-monitoring/get-aws-resources-info.sh`
- `scripts/ec2-monitoring/generate-config.sh`
- `scripts/ec2-monitoring/docker-compose.yml`
- `scripts/utils/docker-manager.sh`
- `scripts/utils/check-github-secrets.sh`
- `scripts/utils/sync-github-secrets-to-terraform.sh`

### 3.3. Fichiers Terraform

- `infrastructure/variables.tf`
- `infrastructure/main.tf`
- `infrastructure/modules/ec2-monitoring/variables.tf`

## 4. Modifications effectuées

### 4.1. Suppression des variables de compatibilité

Les variables de compatibilité ont été supprimées des fichiers suivants :
- `infrastructure/variables.tf`
- `scripts/ec2-monitoring/init-monitoring.sh`
- `.github/workflows/1-infra-deploy-destroy.yml`

### 4.2. Mise à jour des références aux variables

Toutes les références aux anciennes variables ont été remplacées par des références aux nouvelles variables standardisées dans les fichiers mentionnés ci-dessus.

### 4.3. Mise à jour des scripts de vérification des secrets

Le script `scripts/utils/check-github-secrets.sh` a été mis à jour pour vérifier les nouvelles variables standardisées et pour maintenir la compatibilité avec les anciennes variables pendant la période de transition.

## 5. Avantages de la standardisation

- **Cohérence** : Utilisation de noms de variables cohérents dans tout le projet
- **Maintenabilité** : Réduction de la complexité et de la confusion liées à l'utilisation de plusieurs noms pour la même variable
- **Sécurité** : Meilleure gestion des secrets avec des noms standardisés
- **Documentation** : Documentation claire des variables utilisées dans le projet

## 6. Recommandations pour l'avenir

- **Suppression complète des variables de compatibilité** : Une fois que tous les systèmes et scripts ont été migrés vers les nouvelles variables standardisées, les variables de compatibilité devraient être complètement supprimées.
- **Mise à jour de la documentation** : Tous les documents de référence devraient être mis à jour pour refléter uniquement les nouvelles variables standardisées.
- **Tests automatisés** : Des tests automatisés devraient être mis en place pour vérifier que toutes les variables sont correctement utilisées dans tous les fichiers du projet.

## 7. Conclusion

La standardisation des variables dans le projet YourMedia a permis d'améliorer la cohérence, la maintenabilité et la sécurité du code. Les modifications effectuées ont éliminé les références aux anciennes variables dans la plupart des fichiers, mais quelques références subsistent dans certains scripts et workflows pour assurer la compatibilité pendant la période de transition.
