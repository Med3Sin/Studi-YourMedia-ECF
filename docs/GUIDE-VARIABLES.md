# Guide de gestion des variables pour YourMedia

Ce document centralise toutes les informations relatives à la gestion des variables d'environnement et des secrets dans le projet YourMedia.

## 1. Variables standardisées

### 1.1. Variables Docker

| Variable standardisée | Ancienne variable | Description |
|----------------------|-------------------|-------------|
| `DOCKERHUB_USERNAME` | `DOCKER_USERNAME` | Nom d'utilisateur Docker Hub |
| `DOCKERHUB_TOKEN` | `DOCKER_PASSWORD` | Token d'authentification Docker Hub |
| `DOCKERHUB_REPO` | `DOCKER_REPO` | Nom du dépôt Docker Hub |

### 1.2. Variables RDS/DB

| Variable standardisée | Ancienne variable | Description |
|----------------------|-------------------|-------------|
| `RDS_USERNAME` | `DB_USERNAME` | Nom d'utilisateur RDS |
| `RDS_PASSWORD` | `DB_PASSWORD` | Mot de passe RDS |
| `RDS_ENDPOINT` | `DB_ENDPOINT` | Point de terminaison RDS |

### 1.3. Variables Grafana

| Variable standardisée | Ancienne variable | Description |
|----------------------|-------------------|-------------|
| `GF_SECURITY_ADMIN_PASSWORD` | `GRAFANA_ADMIN_PASSWORD` | Mot de passe administrateur Grafana |

## 2. Gestion des secrets GitHub

### 2.1. Secrets requis

Les secrets suivants doivent être configurés dans GitHub Actions :

| Secret | Description | Obligatoire |
|--------|-------------|-------------|
| `AWS_ACCESS_KEY_ID` | Clé d'accès AWS | Oui |
| `AWS_SECRET_ACCESS_KEY` | Clé secrète AWS | Oui |
| `RDS_USERNAME` | Nom d'utilisateur RDS | Oui |
| `RDS_PASSWORD` | Mot de passe RDS | Oui |
| `EC2_SSH_PRIVATE_KEY` | Clé SSH privée pour EC2 | Oui |
| `EC2_SSH_PUBLIC_KEY` | Clé SSH publique pour EC2 | Oui |
| `EC2_KEY_PAIR_NAME` | Nom de la paire de clés EC2 | Oui |
| `DOCKERHUB_USERNAME` | Nom d'utilisateur Docker Hub | Oui |
| `DOCKERHUB_TOKEN` | Token Docker Hub | Oui |
| `DOCKERHUB_REPO` | Nom du dépôt Docker Hub | Oui |
| `GF_SECURITY_ADMIN_PASSWORD` | Mot de passe admin Grafana | Oui |
| `TF_API_TOKEN` | Token API Terraform Cloud | Oui |
| `TF_WORKSPACE_ID` | ID du workspace Terraform Cloud | Oui |
| `GH_PAT` | Token d'accès personnel GitHub | Oui |

### 2.2. Configuration des secrets

Pour configurer les secrets dans GitHub :

1. Accédez à votre dépôt GitHub
2. Cliquez sur "Settings" > "Secrets and variables" > "Actions"
3. Cliquez sur "New repository secret"
4. Entrez le nom et la valeur du secret
5. Cliquez sur "Add secret"

### 2.3. Vérification des secrets

Le projet inclut un script pour vérifier que tous les secrets requis sont configurés :

```bash
# Vérifier les secrets GitHub
./scripts/utils/check-github-secrets.sh
```

## 3. Synchronisation avec Terraform Cloud

### 3.1. Script de synchronisation

Le projet inclut un script pour synchroniser les secrets GitHub avec Terraform Cloud :

```bash
# Synchroniser les secrets GitHub avec Terraform Cloud
./scripts/utils/sync-github-secrets-to-terraform.sh
```

### 3.2. Variables Terraform

Les variables suivantes sont synchronisées avec Terraform Cloud :

| Variable Terraform | Variable d'environnement | Sensible |
|-------------------|--------------------------|----------|
| `aws_access_key` | `AWS_ACCESS_KEY_ID` | Oui |
| `aws_secret_key` | `AWS_SECRET_ACCESS_KEY` | Oui |
| `db_username` | `RDS_USERNAME` | Oui |
| `db_password` | `RDS_PASSWORD` | Oui |
| `dockerhub_username` | `DOCKERHUB_USERNAME` | Oui |
| `dockerhub_token` | `DOCKERHUB_TOKEN` | Oui |
| `dockerhub_repo` | `DOCKERHUB_REPO` | Non |
| `grafana_admin_password` | `GF_SECURITY_ADMIN_PASSWORD` | Oui |

## 4. Utilisation des variables dans les scripts

### 4.1. Scripts shell

Dans les scripts shell, utilisez les variables standardisées comme suit :

```bash
# Vérifier si les variables sont définies
if [ -z "$RDS_USERNAME" ]; then
    RDS_USERNAME="yourmedia"
    echo "La variable RDS_USERNAME n'est pas définie, utilisation de la valeur par défaut $RDS_USERNAME"
fi

# Exporter les variables
export RDS_USERNAME
export RDS_PASSWORD
export RDS_ENDPOINT
```

### 4.2. Fichiers docker-compose.yml

Dans les fichiers docker-compose.yml, utilisez les variables standardisées comme suit :

```yaml
version: '3'
services:
  grafana:
    image: ${DOCKERHUB_USERNAME}/${DOCKERHUB_REPO}:grafana-latest
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD}
```

### 4.3. Workflows GitHub Actions

Dans les workflows GitHub Actions, utilisez les variables standardisées comme suit :

```yaml
- name: Login to Docker Hub
  uses: docker/login-action@v3
  with:
    username: ${{ secrets.DOCKERHUB_USERNAME }}
    password: ${{ secrets.DOCKERHUB_TOKEN }}

- name: Build and push Docker image
  uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: |
      ${{ secrets.DOCKERHUB_USERNAME }}/${{ secrets.DOCKERHUB_REPO || 'yourmedia-ecf' }}:latest
```

## 5. Bonnes pratiques

### 5.1. Sécurité des variables

- Ne stockez jamais de secrets en clair dans le code
- Utilisez des variables d'environnement pour les secrets
- Utilisez des gestionnaires de secrets comme GitHub Secrets ou AWS Secrets Manager
- Limitez l'accès aux secrets aux personnes qui en ont besoin

### 5.2. Standardisation

- Utilisez toujours les variables standardisées dans les nouveaux scripts
- Mettez à jour les anciens scripts pour utiliser les variables standardisées
- Documentez clairement les variables utilisées dans chaque script

### 5.3. Valeurs par défaut

- Fournissez des valeurs par défaut raisonnables pour les variables non sensibles
- Vérifiez toujours si les variables sensibles sont définies avant d'exécuter des opérations critiques
- Affichez des messages d'erreur clairs si des variables requises ne sont pas définies
