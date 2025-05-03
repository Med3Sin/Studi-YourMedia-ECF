# Guide GitHub Actions pour YourMedia

Ce document centralise toutes les informations relatives aux workflows GitHub Actions dans le projet YourMedia.

## 1. Vue d'ensemble des workflows

Le projet YourMedia utilise plusieurs workflows GitHub Actions pour automatiser le déploiement et la gestion de l'infrastructure et des applications. Voici la liste des workflows disponibles :

| Workflow | Fichier | Description |
|----------|---------|-------------|
| 0 - Vérification des secrets | `0-verification-secrets.yml` | Vérifie que tous les secrets GitHub nécessaires sont configurés |
| 1 - Déploiement/Destruction de l'infrastructure | `1-infra-deploy-destroy.yml` | Déploie ou détruit l'infrastructure AWS via Terraform |
| 2 - Déploiement du backend | `2-backend-deploy.yml` | Déploie l'application Java sur l'instance EC2 Tomcat |
| 2.5 - Tests des applications | `2.5-application-tests.yml` | Exécute les tests des applications Java et React |
| 3 - Construction et déploiement Docker | `3-docker-build-deploy.yml` | Construit et déploie les images Docker |
| 4 - Analyse de sécurité | `4-analyse-de-securite.yml` | Analyse la sécurité des images Docker et du code |
| 5 - Nettoyage des images Docker | `5-docker-cleanup.yml` | Nettoie les images Docker obsolètes |

## 2. Workflow 0 : Vérification des secrets

### 2.1. Description

Ce workflow vérifie que tous les secrets GitHub nécessaires sont configurés. Il est exécuté manuellement ou avant les autres workflows pour s'assurer que tous les secrets requis sont disponibles.

### 2.2. Paramètres

| Paramètre | Description | Valeurs possibles |
|-----------|-------------|-------------------|
| `mode` | Mode de vérification | `verification` (échoue si des secrets manquent), `rapport` (affiche les secrets manquants sans échouer) |

### 2.3. Secrets requis

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `RDS_USERNAME`
- `RDS_PASSWORD`
- `EC2_SSH_PRIVATE_KEY`
- `EC2_SSH_PUBLIC_KEY`
- `EC2_KEY_PAIR_NAME`
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`
- `DOCKERHUB_REPO`
- `GF_SECURITY_ADMIN_PASSWORD`
- `TF_API_TOKEN`
- `TF_WORKSPACE_ID`
- `GH_PAT`

## 3. Workflow 1 : Déploiement/Destruction de l'infrastructure

### 3.1. Description

Ce workflow déploie ou détruit l'infrastructure AWS via Terraform. Il peut être utilisé pour créer une nouvelle infrastructure ou pour détruire une infrastructure existante.

### 3.2. Paramètres

| Paramètre | Description | Valeurs possibles |
|-----------|-------------|-------------------|
| `action` | Action à effectuer | `apply` (déployer), `destroy` (détruire), `plan` (planifier) |
| `environment` | Environnement cible | `dev`, `staging`, `prod` |

### 3.3. Étapes principales

1. Vérification des secrets
2. Configuration de Terraform
3. Déploiement ou destruction de l'infrastructure
4. Synchronisation des secrets GitHub vers Terraform Cloud
5. Nettoyage des ressources persistantes (si destruction)

## 4. Workflow 2 : Déploiement du backend

### 4.1. Description

Ce workflow déploie l'application Java sur l'instance EC2 Tomcat. Il compile l'application Java, crée un fichier WAR et le déploie sur l'instance EC2.

### 4.2. Paramètres

| Paramètre | Description | Valeurs possibles |
|-----------|-------------|-------------------|
| `ec2_public_ip` | IP publique de l'instance EC2 | IP valide (optionnel, utilise TF_EC2_PUBLIC_IP si non spécifié) |
| `s3_bucket_name` | Nom du bucket S3 | Nom valide (optionnel, utilise TF_S3_BUCKET_NAME si non spécifié) |

### 4.3. Étapes principales

1. Compilation de l'application Java
2. Création du fichier WAR
3. Téléchargement du fichier WAR sur S3
4. Déploiement du fichier WAR sur l'instance EC2 Tomcat

## 5. Workflow 3 : Construction et déploiement Docker

### 5.1. Description

Ce workflow construit et déploie les images Docker pour l'application mobile React et les outils de monitoring (Grafana, Prometheus).

### 5.2. Paramètres

| Paramètre | Description | Valeurs possibles |
|-----------|-------------|-------------------|
| `action` | Action à effectuer | `build` (construire), `deploy` (déployer), `both` (les deux) |
| `target` | Cible à construire/déployer | `all`, `mobile`, `monitoring` |

### 5.3. Étapes principales

1. Construction des images Docker
2. Test des images Docker avec Trivy
3. Publication des images sur Docker Hub
4. Déploiement des conteneurs sur les instances EC2

## 6. Workflow 4 : Analyse de sécurité

### 6.1. Description

Ce workflow analyse la sécurité des images Docker et du code source. Il utilise Trivy pour scanner les images Docker et OWASP Dependency Check pour analyser les dépendances Java.

### 6.2. Étapes principales

1. Construction des images Docker
2. Scan des images Docker avec Trivy
3. Analyse des dépendances Java avec OWASP Dependency Check
4. Analyse des dépendances npm pour React
5. Publication des rapports de sécurité

## 7. Workflow 5 : Nettoyage des images Docker

### 7.1. Description

Ce workflow nettoie les images Docker obsolètes sur Docker Hub. Il peut être utilisé pour supprimer des images spécifiques ou toutes les images.

### 7.2. Paramètres

| Paramètre | Description | Valeurs possibles |
|-----------|-------------|-------------------|
| `repository` | Dépôt Docker Hub à nettoyer | Nom valide (ex: `medsin/yourmedia-ecf`) |
| `tag_pattern` | Motif de tag à supprimer | `*-latest`, `grafana-*`, `all` |
| `dry_run` | Mode simulation | `true` (ne supprime pas réellement), `false` (supprime) |

### 7.3. Étapes principales

1. Connexion à Docker Hub
2. Récupération de la liste des tags
3. Suppression des images correspondant au motif
4. Génération d'un rapport de nettoyage

## 8. Variables standardisées

### 8.1. Variables Docker

| Variable | Description |
|----------|-------------|
| `DOCKERHUB_USERNAME` | Nom d'utilisateur Docker Hub |
| `DOCKERHUB_TOKEN` | Token Docker Hub |
| `DOCKERHUB_REPO` | Nom du dépôt Docker Hub |

### 8.2. Variables AWS

| Variable | Description |
|----------|-------------|
| `AWS_ACCESS_KEY_ID` | Clé d'accès AWS |
| `AWS_SECRET_ACCESS_KEY` | Clé secrète AWS |
| `AWS_DEFAULT_REGION` | Région AWS par défaut |

### 8.3. Variables RDS

| Variable | Description |
|----------|-------------|
| `RDS_USERNAME` | Nom d'utilisateur RDS |
| `RDS_PASSWORD` | Mot de passe RDS |
| `TF_RDS_ENDPOINT` | Point de terminaison RDS |

### 8.4. Variables EC2

| Variable | Description |
|----------|-------------|
| `TF_EC2_PUBLIC_IP` | IP publique de l'instance EC2 Java/Tomcat |
| `TF_MONITORING_EC2_PUBLIC_IP` | IP publique de l'instance EC2 de monitoring |
| `EC2_SSH_PRIVATE_KEY` | Clé SSH privée pour EC2 |
| `EC2_SSH_PUBLIC_KEY` | Clé SSH publique pour EC2 |
| `EC2_KEY_PAIR_NAME` | Nom de la paire de clés EC2 |

## 9. Bonnes pratiques

### 9.1. Sécurité

- Utilisez des secrets GitHub pour stocker les informations sensibles
- Ne stockez jamais de secrets en clair dans les workflows
- Utilisez des actions officielles ou bien maintenues
- Limitez les permissions des workflows

### 9.2. Organisation

- Utilisez des noms descriptifs pour les workflows
- Documentez les paramètres des workflows
- Utilisez des étapes conditionnelles pour éviter les duplications
- Utilisez des variables d'environnement pour les valeurs réutilisables

### 9.3. Optimisation

- Utilisez des caches pour accélérer les builds
- Utilisez des runners auto-hébergés pour les tâches intensives
- Limitez le nombre d'actions pour réduire le temps d'exécution
- Utilisez des timeouts pour éviter les exécutions infinies
