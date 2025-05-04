# Workflows GitHub Actions - YourMedia

Ce document centralise toutes les informations relatives aux workflows GitHub Actions dans le projet YourMedia.

## Table des matières

1. [Vue d'ensemble des workflows](#1-vue-densemble-des-workflows)
2. [Workflows disponibles](#2-workflows-disponibles)
   - [Vérification des secrets](#21-vérification-des-secrets)
   - [Déploiement/Destruction de l'infrastructure](#22-déploiementdestruction-de-linfrastructure)
   - [Déploiement du backend](#23-déploiement-du-backend)
   - [Construction et déploiement Docker](#24-construction-et-déploiement-docker)
   - [Analyse de sécurité](#25-analyse-de-sécurité)
   - [Nettoyage des images Docker](#26-nettoyage-des-images-docker)
3. [Configuration des secrets GitHub](#3-configuration-des-secrets-github)
   - [Secrets requis](#31-secrets-requis)
   - [Configuration des secrets](#32-configuration-des-secrets)
   - [Variables de compatibilité](#33-variables-de-compatibilité)
4. [Améliorations et bonnes pratiques](#4-améliorations-et-bonnes-pratiques)
   - [Centralisation de la configuration](#41-centralisation-de-la-configuration)
   - [Tests de santé](#42-tests-de-santé)
   - [Mise à jour des actions GitHub](#43-mise-à-jour-des-actions-github)
   - [Workflows supprimés](#44-workflows-supprimés)

## 1. Vue d'ensemble des workflows

Le projet YourMedia utilise plusieurs workflows GitHub Actions pour automatiser le déploiement et la gestion de l'infrastructure et des applications. Ces workflows sont conçus pour être simples, fiables et faciles à maintenir.

| Workflow | Fichier | Description |
|----------|---------|-------------|
| 0 - Vérification des secrets | `0-verification-secrets.yml` | Vérifie que tous les secrets GitHub nécessaires sont configurés |
| 1 - Déploiement/Destruction de l'infrastructure | `1-infra-deploy-destroy.yml` | Déploie ou détruit l'infrastructure AWS via Terraform |
| 2 - Déploiement du backend | `2-backend-deploy.yml` | Déploie l'application Java sur l'instance EC2 Tomcat |
| 3 - Construction et déploiement Docker | `3-docker-build-deploy.yml` | Construit et déploie les images Docker |
| 4 - Analyse de sécurité | `4-analyse-de-securite.yml` | Analyse la sécurité des images Docker et du code |
| 5 - Nettoyage des images Docker | `5-docker-cleanup.yml` | Nettoie les images Docker obsolètes |

## 2. Workflows disponibles

### 2.1. Vérification des secrets

**Fichier :** `0-verification-secrets.yml`

**Description :** Ce workflow vérifie que tous les secrets GitHub nécessaires sont configurés. Il est exécuté manuellement ou avant les autres workflows pour s'assurer que tous les secrets requis sont disponibles.

**Paramètres :**
- `mode` : Mode de vérification (`verification` ou `rapport`)

**Étapes principales :**
1. Vérification des secrets AWS
2. Vérification des secrets Docker Hub
3. Vérification des secrets SSH
4. Vérification des secrets RDS
5. Génération d'un rapport

### 2.2. Déploiement/Destruction de l'infrastructure

**Fichier :** `1-infra-deploy-destroy.yml`

**Description :** Ce workflow déploie ou détruit l'infrastructure AWS via Terraform. Il utilise Terraform Cloud pour stocker l'état de l'infrastructure.

**Paramètres :**
- `action` : Action à effectuer (`apply`, `destroy`, `plan`)
- `environment` : Environnement cible (`dev`, `staging`, `prod`)

**Étapes principales :**
1. Vérification des secrets
2. Configuration de Terraform
3. Déploiement ou destruction de l'infrastructure
4. Synchronisation des secrets GitHub vers Terraform Cloud
5. Nettoyage des ressources persistantes (si destruction)

**Améliorations apportées :**
- Centralisation de la configuration des variables d'environnement
- Simplification de la configuration SSH
- Mise à jour des versions des actions GitHub
- Amélioration de la gestion des erreurs

### 2.3. Déploiement du backend

**Fichier :** `2-backend-deploy.yml`

**Description :** Ce workflow déploie l'application Java sur l'instance EC2 Tomcat. Il compile l'application Java, crée un fichier WAR et le déploie sur l'instance EC2.

**Paramètres :**
- `ec2_public_ip` : IP publique de l'instance EC2 (optionnel)
- `s3_bucket_name` : Nom du bucket S3 (optionnel)

**Étapes principales :**
1. Compilation de l'application Java
2. Création du fichier WAR
3. Téléchargement du fichier WAR sur S3
4. Déploiement du fichier WAR sur l'instance EC2 Tomcat

**Améliorations apportées :**
- Utilisation de variables d'environnement pour les paramètres
- Amélioration de la gestion des erreurs
- Simplification du processus de déploiement

### 2.4. Construction et déploiement Docker

**Fichier :** `3-docker-build-deploy.yml`

**Description :** Ce workflow construit et déploie les images Docker pour l'application mobile React et les outils de monitoring (Grafana, Prometheus).

**Paramètres :**
- `action` : Action à effectuer (`build`, `deploy`, `both`)
- `target` : Cible à construire/déployer (`all`, `mobile`, `monitoring`)

**Étapes principales :**
1. Construction des images Docker
2. Test des images Docker avec Trivy
3. Publication des images sur Docker Hub
4. Déploiement des conteneurs sur les instances EC2

**Améliorations apportées :**
- Ajout de tests de santé pour les conteneurs Docker
- Amélioration de la gestion des erreurs
- Optimisation du processus de construction des images

### 2.5. Analyse de sécurité

**Fichier :** `4-analyse-de-securite.yml`

**Description :** Ce workflow analyse la sécurité des images Docker et du code source. Il utilise Trivy pour scanner les images Docker et OWASP Dependency Check pour analyser les dépendances Java.

**Étapes principales :**
1. Construction des images Docker
2. Scan des images Docker avec Trivy
3. Analyse des dépendances Java avec OWASP Dependency Check
4. Génération de rapports de sécurité

**Options de scan optimisées :**
```bash
# Limiter le scan aux vulnérabilités uniquement
trivy image --scanners vuln <image>

# Filtrer par niveau de sévérité
trivy image --severity HIGH,CRITICAL <image>

# Combiner les options
trivy image --scanners vuln --severity HIGH,CRITICAL <image>
```

### 2.6. Nettoyage des images Docker

**Fichier :** `5-docker-cleanup.yml`

**Description :** Ce workflow nettoie les images Docker obsolètes sur Docker Hub.

**Paramètres :**
- `repository` : Nom du dépôt Docker Hub
- `tag_pattern` : Motif de tag à supprimer
- `dry_run` : Mode simulation (true/false)

**Étapes principales :**
1. Authentification auprès de Docker Hub
2. Récupération de la liste des images
3. Filtrage des images selon le motif de tag
4. Suppression des images obsolètes

## 3. Configuration des secrets GitHub

### 3.1. Secrets requis

Les secrets suivants sont nécessaires pour exécuter les workflows GitHub Actions :

| Secret | Description | Utilisation |
|--------|-------------|-------------|
| `DOCKERHUB_USERNAME` | Nom d'utilisateur Docker Hub | Authentification auprès de Docker Hub |
| `DOCKERHUB_TOKEN` | Token d'authentification Docker Hub | Authentification auprès de Docker Hub |
| `DOCKERHUB_REPO` | Nom du dépôt Docker Hub | Référence aux images Docker |
| `AWS_ACCESS_KEY_ID` | Clé d'accès AWS | Authentification auprès d'AWS |
| `AWS_SECRET_ACCESS_KEY` | Clé secrète AWS | Authentification auprès d'AWS |
| `AWS_DEFAULT_REGION` | Région AWS par défaut | Configuration AWS |
| `RDS_USERNAME` | Nom d'utilisateur RDS | Connexion à la base de données |
| `RDS_PASSWORD` | Mot de passe RDS | Connexion à la base de données |
| `EC2_SSH_PRIVATE_KEY` | Clé SSH privée pour EC2 | Connexion SSH aux instances EC2 |
| `EC2_SSH_PUBLIC_KEY` | Clé SSH publique pour EC2 | Configuration des instances EC2 |
| `GF_SECURITY_ADMIN_PASSWORD` | Mot de passe administrateur Grafana | Authentification Grafana |
| `TF_API_TOKEN` | Token d'API Terraform Cloud | Authentification Terraform Cloud |
| `TF_WORKSPACE_ID` | ID de l'espace de travail Terraform Cloud | Configuration Terraform Cloud |
| `GH_PAT` | Token d'accès personnel GitHub | Téléchargement des scripts depuis GitHub |

### 3.2. Configuration des secrets

Pour configurer les secrets GitHub, suivez ces étapes :

1. Accédez aux paramètres de votre dépôt GitHub
2. Cliquez sur "Settings" > "Secrets and variables" > "Actions"
3. Cliquez sur "New repository secret"
4. Ajoutez chaque secret avec son nom et sa valeur
5. Cliquez sur "Add secret" pour enregistrer

### 3.3. Variables de compatibilité

Pour maintenir la compatibilité avec les scripts existants, les variables suivantes sont également supportées :

| Variable | Alias pour | Contexte d'utilisation |
|----------|------------|------------------------|
| `DOCKER_USERNAME` | `DOCKERHUB_USERNAME` | Scripts anciens, workflows GitHub Actions |
| `DOCKER_PASSWORD` | `DOCKERHUB_TOKEN` | Scripts anciens |
| `DOCKER_REPO` | `DOCKERHUB_REPO` | Scripts anciens, workflows GitHub Actions |
| `DB_USERNAME` | `RDS_USERNAME` | Scripts anciens |
| `DB_PASSWORD` | `RDS_PASSWORD` | Scripts anciens |
| `DB_ENDPOINT` | `RDS_ENDPOINT` | Scripts anciens |

## 4. Améliorations et bonnes pratiques

### 4.1. Centralisation de la configuration

La configuration des variables d'environnement et des clés SSH est centralisée dans une seule étape au début du workflow, ce qui évite les duplications et les incohérences.

```yaml
- name: Set up environment variables
  run: |
    echo "AWS_REGION=${{ secrets.AWS_DEFAULT_REGION || 'eu-west-3' }}" >> $GITHUB_ENV
    echo "DOCKERHUB_USERNAME=${{ secrets.DOCKERHUB_USERNAME }}" >> $GITHUB_ENV
    echo "DOCKERHUB_TOKEN=${{ secrets.DOCKERHUB_TOKEN }}" >> $GITHUB_ENV
    echo "DOCKERHUB_REPO=${{ secrets.DOCKERHUB_REPO || 'yourmedia-ecf' }}" >> $GITHUB_ENV
```

### 4.2. Tests de santé

Des tests de santé sont effectués pour tous les conteneurs Docker, ce qui permet de détecter les problèmes avant le déploiement :

```yaml
- name: Test container health
  run: |
    # Test de santé pour Grafana
    docker run -d --name grafana-test -p 3001:3000 ${{ env.DOCKERHUB_USERNAME }}/yourmedia-ecf:grafana-${{ env.VERSION }}
    sleep 10
    curl -f http://localhost:3001/api/health || (echo "::warning::Le health check de l'image Grafana a échoué" && docker logs grafana-test)
    docker stop grafana-test
    docker rm grafana-test
```

### 4.3. Mise à jour des actions GitHub

Les versions des actions GitHub ont été mises à jour pour utiliser les dernières versions disponibles, ce qui permet de bénéficier des dernières fonctionnalités et corrections de bugs.

**Problème identifié :** GitHub a déprécié la commande `set-output` utilisée par certaines actions.

**Solution mise en œuvre :** Remplacement de l'action `gliech/create-github-secret-action@v1` par une implémentation personnalisée utilisant directement l'API GitHub pour créer des secrets.

```yaml
- name: Update S3 Bucket Name Secret
  env:
    GH_TOKEN: ${{ secrets.GH_PAT }}
    SECRET_NAME: TF_S3_BUCKET_NAME
    SECRET_VALUE: ${{ env.S3_BUCKET_NAME }}
    REPO: ${{ github.repository }}
  run: |
    # Récupérer la clé publique du dépôt
    PUBLIC_KEY_RESPONSE=$(curl -s -X GET \
      -H "Authorization: token $GH_TOKEN" \
      -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/repos/$REPO/actions/secrets/public-key")
    
    # Extraire la clé publique et l'ID
    PUBLIC_KEY=$(echo $PUBLIC_KEY_RESPONSE | jq -r .key)
    PUBLIC_KEY_ID=$(echo $PUBLIC_KEY_RESPONSE | jq -r .key_id)
    
    # Créer le secret
    curl -s -X PUT \
      -H "Authorization: token $GH_TOKEN" \
      -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/repos/$REPO/actions/secrets/$SECRET_NAME" \
      -d @- << EOF
    {
      "encrypted_value": "$(echo -n "$SECRET_VALUE" | openssl base64 -A)",
      "key_id": "$PUBLIC_KEY_ID"
    }
    EOF
```

### 4.4. Workflows supprimés

Les workflows suivants ont été supprimés car ils étaient redondants ou inutiles :

1. **`sync-secrets-to-terraform.yml`** : Redondant car le workflow principal `1-infra-deploy-destroy.yml` gère déjà la synchronisation des secrets avec Terraform Cloud.

2. **`upload-scripts-to-s3.yml`** : Supprimé car les scripts sont téléchargés directement depuis GitHub au lieu d'être stockés dans un bucket S3.

3. **`view-secret-securely.yml`** : Présentait un risque de sécurité car il affichait les secrets en clair dans les logs.

4. **`3.1-canary-deployment.yml`** : Workflow complexe pour le déploiement canary, inutile pour un projet simple.
