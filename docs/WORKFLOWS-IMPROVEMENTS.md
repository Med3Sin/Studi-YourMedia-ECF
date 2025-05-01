# Améliorations des Workflows GitHub Actions

Ce document décrit les améliorations apportées aux workflows GitHub Actions du projet YourMédia.

## Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Améliorations du workflow `1-infra-deploy-destroy.yml`](#améliorations-du-workflow-1-infra-deploy-destroyyml)
3. [Améliorations du workflow `2-backend-deploy.yml`](#améliorations-du-workflow-2-backend-deployyml)
4. [Améliorations du workflow `3-docker-build-deploy.yml`](#améliorations-du-workflow-3-docker-build-deployyml)
5. [Workflows supprimés](#workflows-supprimés)
6. [Bonnes pratiques](#bonnes-pratiques)

## Vue d'ensemble

Les workflows GitHub Actions du projet YourMédia ont été améliorés pour les rendre plus efficaces, plus fiables et plus faciles à maintenir. Les principales améliorations sont les suivantes :

- Centralisation de la configuration des variables d'environnement
- Simplification de la configuration SSH
- Mise à jour des versions des actions GitHub
- Amélioration des tests de santé pour les conteneurs Docker
- Suppression des workflows redondants
- Factorisation du code pour éviter les duplications

## Améliorations du workflow `1-infra-deploy-destroy.yml`

Le workflow principal d'infrastructure a été amélioré de la manière suivante :

### 1. Centralisation de la configuration des variables d'environnement et des clés SSH

La configuration des variables d'environnement AWS et des clés SSH a été centralisée dans une seule étape au début du workflow, ce qui évite les duplications et les incohérences.

```yaml
# Étape 4: Configuration des variables d'environnement et des clés SSH
- name: Configure Environment Variables and SSH Keys
  id: config
  run: |
    # Définir les variables d'environnement AWS
    echo "AWS_ACCESS_KEY_ID=${{ secrets.AWS_ACCESS_KEY_ID }}" >> $GITHUB_ENV
    echo "AWS_SECRET_ACCESS_KEY=${{ secrets.AWS_SECRET_ACCESS_KEY }}" >> $GITHUB_ENV
    echo "AWS_DEFAULT_REGION=${{ env.AWS_REGION }}" >> $GITHUB_ENV

    # Configuration de la clé SSH si disponible
    if [ ! -z "${{ secrets.EC2_SSH_PRIVATE_KEY }}" ]; then
      mkdir -p ~/.ssh
      echo "${{ secrets.EC2_SSH_PRIVATE_KEY }}" > ~/.ssh/id_rsa
      chmod 600 ~/.ssh/id_rsa
      echo "SSH_KEY_CONFIGURED=true" >> $GITHUB_ENV
      echo "Clé SSH privée configurée."
    else
      echo "SSH_KEY_CONFIGURED=false" >> $GITHUB_ENV
      echo "Aucune clé SSH privée configurée."
    fi
```

### 2. Utilisation de variables pour les chemins de fichiers

Les chemins de fichiers sont maintenant stockés dans des variables, ce qui facilite leur modification et évite les erreurs.

### 3. Amélioration de la synchronisation des secrets

La synchronisation des secrets GitHub vers Terraform Cloud a été améliorée pour gérer correctement les caractères spéciaux et les sauts de ligne :

```yaml
# Amélioration de la gestion des secrets avec jq
JSON_PAYLOAD=$(jq -n \
  --arg id "$VAR_ID" \
  --arg key "$SECRET_NAME" \
  --arg value "$SECRET_VALUE" \
  --arg desc "Synchronisé depuis GitHub Secrets" \
  --argjson sensitive $IS_SENSITIVE \
  '{
    "data": {
      "id": $id,
      "type": "vars",
      "attributes": {
        "key": $key,
        "value": $value,
        "description": $desc,
        "sensitive": $sensitive
      }
    }
  }')
```

Cette approche utilise `jq` pour créer les payloads JSON, ce qui évite les problèmes d'échappement et permet de gérer correctement tous les types de valeurs de secrets.

## Améliorations du workflow `2-backend-deploy.yml`

Le workflow de déploiement du backend a été amélioré de la manière suivante :

### 1. Simplification de la configuration SSH

La configuration SSH a été simplifiée pour utiliser une approche plus directe et plus fiable :

```yaml
# Étape 7: Configuration de SSH simplifiée
- name: Setup SSH
  run: |
    # Créer le répertoire SSH et configurer la clé
    mkdir -p ~/.ssh
    echo "${{ secrets.EC2_SSH_PRIVATE_KEY }}" > ~/.ssh/id_rsa
    chmod 600 ~/.ssh/id_rsa

    # Ajouter la clé d'hôte EC2 aux known_hosts pour éviter les prompts
    ssh-keyscan -H ${{ env.EC2_IP }} >> ~/.ssh/known_hosts

    echo "Configuration SSH terminée."
```

### 2. Amélioration du déploiement du WAR

Le déploiement du WAR a été amélioré pour être plus robuste et flexible, avec une vérification de l'existence du script de déploiement et une option pour le télécharger depuis GitHub si nécessaire :

```yaml
# Étape 8: Déploiement du WAR sur l'instance EC2
- name: Deploy WAR from S3 to EC2 Tomcat
  run: |
    # Déploiement du WAR sur l'instance EC2
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ec2-user@${{ env.EC2_IP }} << EOF
      # Configuration d'AWS CLI avec les informations d'identification temporaires
      mkdir -p ~/.aws
      cat > ~/.aws/credentials << EOC
      [default]
      aws_access_key_id=${{ secrets.AWS_ACCESS_KEY_ID }}
      aws_secret_access_key=${{ secrets.AWS_SECRET_ACCESS_KEY }}
      region=${{ env.AWS_REGION }}
      EOC

      # Télécharger le WAR depuis S3
      sudo aws s3 cp s3://${{ env.S3_BUCKET }}/builds/backend/${{ env.DEPLOY_WAR_NAME }} /tmp/${{ env.DEPLOY_WAR_NAME }}

      # Vérifier si le script deploy-war.sh existe
      if [ -f "/opt/yourmedia/deploy-war.sh" ]; then
          # Utiliser le script dans /opt/yourmedia
          sudo /opt/yourmedia/deploy-war.sh /tmp/${{ env.DEPLOY_WAR_NAME }}
      elif [ -f "/usr/local/bin/deploy-war.sh" ]; then
          # Utiliser le script dans /usr/local/bin
          sudo /usr/local/bin/deploy-war.sh /tmp/${{ env.DEPLOY_WAR_NAME }}
      else
          # Télécharger le script depuis GitHub
          sudo curl -s -o /tmp/deploy-war.sh "https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main/scripts/ec2-java-tomcat/deploy-war.sh"
          sudo chmod +x /tmp/deploy-war.sh
          sudo /tmp/deploy-war.sh /tmp/${{ env.DEPLOY_WAR_NAME }}
          sudo rm /tmp/deploy-war.sh
      fi

      # Nettoyer les informations d'identification AWS
      rm -rf ~/.aws
    EOF
```

### 3. Suppression des étapes de débogage excessives

Les étapes de débogage SSH excessives ont été supprimées pour simplifier le workflow et éviter d'exposer des informations sensibles.

## Améliorations du workflow `3-docker-build-deploy.yml`

Le workflow de déploiement Docker a été amélioré de la manière suivante :

### 1. Mise à jour des versions des actions GitHub

Les versions des actions GitHub ont été mises à jour pour utiliser les dernières versions disponibles :

```yaml
- name: Checkout code
  uses: actions/checkout@v4

- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3

- name: Login to Docker Hub
  uses: docker/login-action@v3
```

### 2. Standardisation des noms de variables Docker

Les noms de variables Docker ont été standardisés pour utiliser `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN` et `DOCKERHUB_REPO` partout dans le workflow, ce qui améliore la cohérence et facilite la maintenance.

### 3. Téléchargement des scripts depuis GitHub

Le workflow a été amélioré pour vérifier l'existence du script `docker-manager.sh` et le télécharger depuis GitHub si nécessaire :

```yaml
# Vérifier si le script docker-manager.sh existe
if [ -f "./scripts/utils/docker-manager.sh" ]; then
  chmod +x ./scripts/utils/docker-manager.sh
  ./scripts/utils/docker-manager.sh deploy monitoring
else
  # Télécharger le script depuis GitHub
  echo "Script docker-manager.sh non trouvé, téléchargement depuis GitHub..."
  curl -s -o ./docker-manager.sh "https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main/scripts/utils/docker-manager.sh"
  chmod +x ./docker-manager.sh
  ./docker-manager.sh deploy monitoring
fi
```

### 4. Amélioration des tests de santé pour tous les conteneurs

Les tests de santé ont été améliorés pour tester tous les conteneurs Docker, pas seulement l'application mobile :

```yaml
# Test de santé pour l'application mobile
if [[ "${{ github.event.inputs.target }}" == "all" || "${{ github.event.inputs.target }}" == "mobile" ]]; then
  echo "Testing mobile app health check..."
  docker run -d --name mobile-test -p 3000:3000 ${{ secrets.DOCKERHUB_USERNAME }}/yourmedia-ecf:mobile-${{ env.VERSION }}
  sleep 10
  curl -f http://localhost:3000/ || (echo "::warning::Le health check de l'image mobile a échoué" && docker logs mobile-test)
  docker stop mobile-test
  docker rm mobile-test
fi

# Test de santé pour Grafana
if [[ "${{ github.event.inputs.target }}" == "all" || "${{ github.event.inputs.target }}" == "monitoring" ]]; then
  echo "Testing Grafana health check..."
  docker run -d --name grafana-test -p 3001:3000 ${{ secrets.DOCKERHUB_USERNAME }}/yourmedia-ecf:grafana-${{ env.VERSION }}
  sleep 10
  curl -f http://localhost:3001/api/health || (echo "::warning::Le health check de l'image Grafana a échoué" && docker logs grafana-test)
  docker stop grafana-test
  docker rm grafana-test

  # Test de santé pour Prometheus
  echo "Testing Prometheus health check..."
  docker run -d --name prometheus-test -p 9090:9090 ${{ secrets.DOCKERHUB_USERNAME }}/yourmedia-ecf:prometheus-${{ env.VERSION }}
  sleep 10
  curl -f http://localhost:9090/-/healthy || (echo "::warning::Le health check de l'image Prometheus a échoué" && docker logs prometheus-test)
  docker stop prometheus-test
  docker rm prometheus-test
fi
```

## Workflows supprimés

Les workflows suivants ont été supprimés car ils étaient redondants ou inutiles :

### 1. `sync-secrets-to-terraform.yml`

Ce workflow était redondant car le workflow principal `1-infra-deploy-destroy.yml` gère déjà la synchronisation des secrets avec Terraform Cloud.

### 2. `upload-scripts-to-s3.yml`

Ce workflow a été supprimé car, depuis la version 2.0 du projet, les scripts sont téléchargés directement depuis GitHub au lieu d'être stockés dans un bucket S3. Pour plus de détails sur cette nouvelle approche, consultez le document [SCRIPTS-GITHUB-APPROACH.md](SCRIPTS-GITHUB-APPROACH.md).

### 3. `view-secret-securely.yml`

Ce workflow présentait un risque de sécurité car il affichait les secrets en clair dans les logs.

### 4. `3.1-canary-deployment.yml`

Ce workflow complexe pour le déploiement canary semblait inutile pour un projet simple.

## Bonnes pratiques

Les améliorations apportées aux workflows GitHub Actions suivent les bonnes pratiques suivantes :

### 1. Centralisation de la configuration

La configuration des variables d'environnement et des clés SSH est centralisée dans une seule étape au début du workflow, ce qui évite les duplications et les incohérences.

### 2. Utilisation des dernières versions des actions GitHub

Les versions des actions GitHub sont mises à jour pour utiliser les dernières versions disponibles, ce qui permet de bénéficier des dernières fonctionnalités et corrections de bugs.

### 3. Tests de santé complets

Les tests de santé sont effectués pour tous les conteneurs Docker, ce qui permet de détecter les problèmes avant le déploiement.

### 4. Simplification des workflows

Les workflows sont simplifiés pour être plus faciles à comprendre et à maintenir, en supprimant les étapes inutiles et en factorisant le code.

### 5. Sécurité

Les informations sensibles sont gérées de manière sécurisée, en évitant de les exposer dans les logs et en nettoyant les informations d'identification temporaires après utilisation.
