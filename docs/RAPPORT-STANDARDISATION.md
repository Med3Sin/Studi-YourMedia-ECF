# Rapport de standardisation pour YourMedia

Ce document centralise toutes les informations relatives à la standardisation des variables, des noms et des pratiques dans le projet YourMedia.

## 1. Standardisation des variables

### 1.1. Variables Docker

| Variable standardisée | Ancienne variable | Description |
|----------------------|-------------------|-------------|
| `DOCKERHUB_USERNAME` | `DOCKER_USERNAME` | Nom d'utilisateur Docker Hub |
| `DOCKERHUB_TOKEN` | `DOCKER_PASSWORD` | Token d'authentification Docker Hub |
| `DOCKERHUB_REPO` | `DOCKER_REPO` | Nom du dépôt Docker Hub |

#### Fichiers modifiés

- `scripts/utils/docker-manager.sh`
- `scripts/ec2-monitoring/docker-compose.yml`
- `.github/workflows/3-docker-build-deploy.yml`
- `.github/workflows/5-docker-cleanup.yml`
- `scripts/utils/check-github-secrets.sh`

#### Exemple de modification

```diff
- echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
+ echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

- docker build -t $DOCKER_USERNAME/$DOCKER_REPO:latest .
+ docker build -t $DOCKERHUB_USERNAME/$DOCKERHUB_REPO:latest .
```

### 1.2. Variables RDS/DB

| Variable standardisée | Ancienne variable | Description |
|----------------------|-------------------|-------------|
| `RDS_USERNAME` | `DB_USERNAME` | Nom d'utilisateur RDS |
| `RDS_PASSWORD` | `DB_PASSWORD` | Mot de passe RDS |
| `RDS_ENDPOINT` | `DB_ENDPOINT` | Point de terminaison RDS |

#### Fichiers modifiés

- `scripts/ec2-monitoring/init-monitoring.sh`
- `infrastructure/variables.tf`
- `.github/workflows/1-infra-deploy-destroy.yml`
- `scripts/utils/check-github-secrets.sh`

#### Exemple de modification

```diff
- if [ -z "$DB_USERNAME" ]; then
-   DB_USERNAME="yourmedia"
-   log "La variable DB_USERNAME n'est pas définie, utilisation de la valeur par défaut $DB_USERNAME"
- fi
- export DB_USERNAME

+ if [ -z "$RDS_USERNAME" ]; then
+   RDS_USERNAME="yourmedia"
+   log "La variable RDS_USERNAME n'est pas définie, utilisation de la valeur par défaut $RDS_USERNAME"
+ fi
+ export RDS_USERNAME
```

### 1.3. Variables Grafana

| Variable standardisée | Ancienne variable | Description |
|----------------------|-------------------|-------------|
| `GF_SECURITY_ADMIN_PASSWORD` | `GRAFANA_ADMIN_PASSWORD` | Mot de passe administrateur Grafana |

#### Fichiers modifiés

- `scripts/ec2-monitoring/init-monitoring.sh`
- `scripts/ec2-monitoring/get-aws-resources-info.sh`
- `scripts/ec2-monitoring/generate-config.sh`
- `scripts/ec2-monitoring/docker-compose.yml`
- `infrastructure/variables.tf`
- `infrastructure/main.tf`
- `.github/workflows/1-infra-deploy-destroy.yml`
- `.github/workflows/3-docker-build-deploy.yml`
- `scripts/utils/check-github-secrets.sh`

#### Exemple de modification

```diff
- if [ -z "$GRAFANA_ADMIN_PASSWORD" ]; then
-   GRAFANA_ADMIN_PASSWORD="YourMedia2025!"
-   log "La variable GRAFANA_ADMIN_PASSWORD n'est pas définie, utilisation de la valeur par défaut"
- fi
- export GRAFANA_ADMIN_PASSWORD

+ if [ -z "$GF_SECURITY_ADMIN_PASSWORD" ]; then
+   GF_SECURITY_ADMIN_PASSWORD="YourMedia2025!"
+   log "La variable GF_SECURITY_ADMIN_PASSWORD n'est pas définie, utilisation de la valeur par défaut"
+ fi
+ export GF_SECURITY_ADMIN_PASSWORD
```

## 2. Standardisation des noms de fichiers

### 2.1. Workflows GitHub Actions

Les workflows GitHub Actions ont été renommés pour suivre une convention cohérente :

| Ancien nom | Nouveau nom | Description |
|------------|-------------|-------------|
| `security-scan.yml` | `4-analyse-de-securite.yml` | Analyse de sécurité |
| `infra-deploy.yml` | `1-infra-deploy-destroy.yml` | Déploiement/destruction de l'infrastructure |
| `docker-build.yml` | `3-docker-build-deploy.yml` | Construction et déploiement Docker |
| `check-secrets.yml` | `0-verification-secrets.yml` | Vérification des secrets |

### 2.2. Scripts

Les scripts ont été renommés pour suivre une convention cohérente :

| Ancien nom | Nouveau nom | Description |
|------------|-------------|-------------|
| `setup.sh` | `init-monitoring.sh` | Initialisation du monitoring |
| `docker-setup.sh` | `setup-monitoring.sh` | Configuration du monitoring |
| `check-docker.sh` | `container-health-check.sh` | Vérification de l'état des conteneurs |

## 3. Standardisation des pratiques de codage

### 3.1. Scripts shell

#### En-têtes de scripts

Tous les scripts shell incluent désormais un en-tête standardisé :

```bash
#!/bin/bash
#==============================================================================
# Nom du script : nom-du-script.sh
# Description   : Description du script
# Auteur        : YourMedia Team
# Version       : 1.0
# Date          : YYYY-MM-DD
#==============================================================================

set -e
umask 077

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Fonction pour afficher les erreurs et quitter
error_exit() {
    log "ERREUR: $1"
    exit 1
}
```

#### Gestion des erreurs

Tous les scripts incluent désormais une gestion d'erreurs standardisée :

```bash
# Gestion des erreurs
set -e
trap 'error_exit "Une erreur s'est produite à la ligne $LINENO. Code de sortie: $?"' ERR

# Fonction de nettoyage
cleanup() {
    log "Nettoyage des fichiers temporaires..."
    rm -f /tmp/temp_file_*.tmp
}

# Enregistrer la fonction de nettoyage pour être exécutée à la sortie
trap cleanup EXIT
```

### 3.2. Fichiers Terraform

#### Structure des modules

Tous les modules Terraform suivent désormais une structure standardisée :

```
module/
├── main.tf       # Ressources principales
├── variables.tf  # Définition des variables
└── outputs.tf    # Définition des sorties
```

#### Nommage des ressources

Les ressources Terraform suivent désormais une convention de nommage standardisée :

```hcl
resource "aws_instance" "ec2_monitoring" {
  ami           = var.ami_id
  instance_type = var.instance_type
  
  tags = {
    Name        = "${var.environment}-monitoring-ec2"
    Environment = var.environment
    Project     = "yourmedia"
    ManagedBy   = "terraform"
  }
}
```

### 3.3. Fichiers Docker

#### Dockerfile

Tous les Dockerfile suivent désormais une structure standardisée :

```dockerfile
# Base image
FROM alpine:3.14

# Metadata
LABEL maintainer="YourMedia Team" \
      description="Description of the image" \
      version="1.0"

# Environment variables
ENV APP_HOME=/app \
    APP_USER=appuser \
    APP_VERSION=1.0

# Create user and directories
RUN adduser -D -h $APP_HOME $APP_USER && \
    mkdir -p $APP_HOME/logs && \
    chown -R $APP_USER:$APP_USER $APP_HOME

# Set working directory
WORKDIR $APP_HOME

# Copy application files
COPY --chown=$APP_USER:$APP_USER . $APP_HOME/

# Expose ports
EXPOSE 8080

# Set user
USER $APP_USER

# Command
CMD ["./start.sh"]
```

#### docker-compose.yml

Tous les fichiers docker-compose.yml suivent désormais une structure standardisée :

```yaml
version: '3'

services:
  service-name:
    image: ${DOCKERHUB_USERNAME}/${DOCKERHUB_REPO}:service-name-latest
    container_name: service-name
    restart: always
    environment:
      - ENV_VAR1=value1
      - ENV_VAR2=value2
    volumes:
      - service-data:/data
    ports:
      - "8080:8080"
    networks:
      - app-network
    mem_limit: 256m

volumes:
  service-data:

networks:
  app-network:
    driver: bridge
```

## 4. Avantages de la standardisation

### 4.1. Cohérence

- Utilisation de noms de variables cohérents dans tout le projet
- Structure de code cohérente facilitant la compréhension
- Conventions de nommage cohérentes pour les fichiers et ressources

### 4.2. Maintenabilité

- Réduction de la complexité et de la confusion
- Documentation claire des pratiques standardisées
- Facilité d'intégration de nouveaux développeurs

### 4.3. Sécurité

- Pratiques de sécurité standardisées dans tous les scripts
- Gestion cohérente des secrets et des permissions
- Vérifications de sécurité intégrées dans les workflows

## 5. Problèmes restants

### 5.1. Variables dans les modules Terraform

Il reste quelques incohérences dans les modules Terraform concernant les noms de variables. Les modules utilisent encore les anciens noms de variables (`docker_username`, `docker_repo`, `grafana_admin_password`) alors que le fichier principal utilise les noms standardisés.

### 5.2. Références dans les templates

Les templates utilisés pour le provisionnement des instances EC2 contiennent encore des références aux anciennes variables. Une vérification approfondie de tous les templates serait nécessaire.

## 6. Recommandations pour l'avenir

### 6.1. Refactorisation des modules Terraform

- Standardiser les noms de variables dans tous les modules Terraform
- Utiliser des locals pour gérer les mappings entre les anciennes et les nouvelles variables
- Documenter clairement les variables standardisées dans un fichier central

### 6.2. Tests automatisés

- Mettre en place des tests automatisés pour vérifier la cohérence des variables
- Ajouter des validations dans les workflows GitHub Actions pour détecter les incohérences
- Créer des linters personnalisés pour vérifier le respect des conventions

### 6.3. Documentation

- Maintenir à jour la documentation sur les variables standardisées
- Créer un guide de contribution pour les développeurs qui travaillent sur le projet
- Documenter les exceptions aux standards et leur justification
