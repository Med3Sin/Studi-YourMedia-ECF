# Standardisation des Variables Docker Hub

Ce document explique la standardisation des variables Docker Hub utilisées dans le projet YourMedia.

## Variables standardisées

Les variables suivantes sont considérées comme les variables standard pour Docker Hub :

| Variable | Description | Utilisation |
|----------|-------------|-------------|
| `DOCKERHUB_USERNAME` | Nom d'utilisateur Docker Hub | Authentification auprès de Docker Hub |
| `DOCKERHUB_TOKEN` | Token d'authentification Docker Hub | Authentification auprès de Docker Hub |
| `DOCKERHUB_REPO` | Nom du dépôt Docker Hub | Référence aux images Docker |

## Variables de compatibilité

Pour maintenir la compatibilité avec les scripts existants, les variables suivantes sont également supportées :

| Variable | Alias pour | Contexte d'utilisation |
|----------|------------|------------------------|
| `DOCKER_USERNAME` | `DOCKERHUB_USERNAME` | Scripts anciens, workflows GitHub Actions |
| `DOCKER_PASSWORD` | `DOCKERHUB_TOKEN` | Scripts anciens |
| `DOCKER_REPO` | `DOCKERHUB_REPO` | Scripts anciens, workflows GitHub Actions |
| `dockerhub_username` | `DOCKERHUB_USERNAME` | Variables Terraform (minuscules) |
| `dockerhub_token` | `DOCKERHUB_TOKEN` | Variables Terraform (minuscules) |
| `dockerhub_repo` | `DOCKERHUB_REPO` | Variables Terraform (minuscules) |

## Configuration des secrets GitHub

Pour configurer correctement les secrets GitHub, suivez ces étapes :

1. Accédez aux paramètres de votre dépôt GitHub
2. Cliquez sur "Secrets and variables" > "Actions"
3. Ajoutez les secrets suivants :
   - `DOCKERHUB_USERNAME` : Votre nom d'utilisateur Docker Hub
   - `DOCKERHUB_TOKEN` : Votre token d'accès personnel Docker Hub
   - `DOCKERHUB_REPO` : Le nom de votre dépôt Docker Hub (par défaut : "yourmedia-ecf")

## Synchronisation avec Terraform Cloud

Le script `scripts/utils/sync-github-secrets-to-terraform.sh` synchronise automatiquement ces variables entre GitHub et Terraform Cloud. Il crée également les variables de compatibilité nécessaires.

## Utilisation dans les workflows GitHub Actions

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

## Utilisation dans les scripts shell

Dans les scripts shell, utilisez les variables standardisées comme suit :

```bash
# Connexion à Docker Hub
echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

# Construction et publication d'une image
docker build -t $DOCKERHUB_USERNAME/$DOCKERHUB_REPO:latest .
docker push $DOCKERHUB_USERNAME/$DOCKERHUB_REPO:latest
```

## Migration des anciens scripts

Pour migrer les anciens scripts vers les nouvelles variables standardisées, remplacez :

- `DOCKER_USERNAME` par `DOCKERHUB_USERNAME`
- `DOCKER_PASSWORD` par `DOCKERHUB_TOKEN`
- `DOCKER_REPO` par `DOCKERHUB_REPO`

Ou utilisez les variables de compatibilité comme indiqué ci-dessus.
