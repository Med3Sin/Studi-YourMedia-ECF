# Projet YourMédia - Migration Cloud AWS

Bienvenue dans la documentation du projet de migration vers le cloud AWS pour l'application YourMédia. Ce document a pour but de vous guider à travers l'architecture mise en place, les choix technologiques, et les procédures de déploiement et de gestion de l'infrastructure et des applications.

Ce projet a été conçu pour être simple, utiliser les services gratuits (Free Tier) d'AWS autant que possible, et être entièrement automatisé via Terraform et GitHub Actions.

## Table des Matières

1.  [Architecture Globale](#architecture-globale)
2.  [Prérequis](#prérequis)
3.  [Structure du Projet](#structure-du-projet)
4.  [Infrastructure (Terraform)](#infrastructure-terraform)
    *   [Modules Terraform](#modules-terraform)
    *   [Déploiement/Destruction de l'Infrastructure](#déploiementdestruction-de-linfrastructure)
5.  [Application Backend (Java Spring Boot)](#application-backend-java-spring-boot)
    *   [Déploiement du Backend](#déploiement-du-backend)
6.  [Application Frontend (React Native Web)](#application-frontend-react-native-web)
    *   [Déploiement du Frontend](#déploiement-du-frontend)
7.  [Monitoring (ECS avec EC2 - Prometheus & Grafana)](#monitoring-ecs-avec-ec2---prometheus--grafana)
    *   [Accès à Grafana](#accès-à-grafana)
8.  [CI/CD (GitHub Actions)](#cicd-github-actions)
    *   [Workflows Disponibles](#workflows-disponibles)
    *   [Configuration des Secrets](#configuration-des-secrets)

## Architecture Globale

L'architecture cible repose sur AWS et utilise les services suivants :

*   **Compute:**
    *   AWS EC2 (t2.micro) pour héberger l'API backend Java Spring Boot sur un serveur Tomcat.
    *   AWS ECS avec EC2 (t2.micro) pour exécuter les conteneurs de monitoring (Prometheus, Grafana) tout en restant dans les limites du Free Tier.
*   **Base de données:** AWS RDS MySQL (db.t2.micro) en mode "Database as a Service".
*   **Stockage:** AWS S3 pour le stockage des médias uploadés par les utilisateurs et pour le stockage temporaire des artefacts de build.
*   **Réseau:** Utilisation du VPC par défaut pour la simplicité, avec des groupes de sécurité spécifiques pour contrôler les flux.
*   **Hébergement Frontend:** AWS Amplify Hosting pour déployer la version web de l'application React Native de manière simple et scalable.
*   **IaC:** Terraform pour décrire et provisionner l'ensemble de l'infrastructure AWS de manière automatisée et reproductible.
*   **CI/CD:** GitHub Actions pour automatiser les builds, les tests (basiques) et les déploiements des applications backend et frontend, ainsi que la gestion de l'infrastructure Terraform.

**Schéma d'Architecture :**

[Voir le schéma d'architecture](aws-architecture-project-yourmedia-updated.html)



## Prérequis

Avant de commencer, assurez-vous d'avoir :

1.  **Un compte AWS :** Si vous n'en avez pas, créez-en un [ici](https://aws.amazon.com/).
2.  **AWS CLI configuré :** Installez et configurez l'AWS CLI avec vos identifiants (Access Key ID et Secret Access Key). Voir la [documentation AWS](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html). Ces identifiants seront utilisés par Terraform localement si besoin, mais surtout dans les secrets GitHub Actions.
3.  **Terraform installé :** Installez Terraform sur votre machine locale. Voir la [documentation Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli).
4.  **Un compte GitHub :** Pour héberger le code et utiliser GitHub Actions.
5.  **Git installé :** Pour cloner le repository et gérer les versions.
6.  **Node.js et npm/yarn :** Pour le développement et le build de l'application React Native.
7.  **Java JDK et Maven :** Pour le développement et le build de l'application Spring Boot.
8.  **Une paire de clés SSH :** Une clé publique sera ajoutée à l'instance EC2 pour permettre la connexion SSH (utilisée par GitHub Actions pour le déploiement). La clé privée correspondante devra être ajoutée aux secrets GitHub.

## Structure du Projet

```
.
├── .github/
│   └── workflows/              # Workflows GitHub Actions
│       ├── 1-infra-deploy-destroy.yml
│       ├── 3-backend-deploy.yml
│       └── 4-frontend-deploy.yml
├── app-java/                    # Code source Backend Spring Boot
│   ├── src/
│   ├── pom.xml
│   └── README.md
├── app-react/                   # Code source Frontend React Native (Web)
│   ├── src/
│   ├── package.json
│   └── README.md
├── infrastructure/              # Code Terraform pour l'infrastructure AWS
│   ├── main.tf                  # Point d'entrée principal (inclut Amplify)
│   ├── variables.tf             # Variables Terraform
│   ├── outputs.tf               # Sorties Terraform (IPs, Endpoints, etc.)
│   ├── providers.tf             # Configuration du provider AWS
│   ├── README.md                # Documentation Terraform
│   └── modules/                 # Modules Terraform réutilisables
│       ├── network/             # Gestion des Security Groups
│       │   └── ... (main.tf, variables.tf, outputs.tf, README.md)
│       ├── ec2-java-tomcat/     # Instance EC2 + Java/Tomcat
│       │   └── ... (main.tf, variables.tf, outputs.tf, scripts/, README.md)
│       ├── rds-mysql/           # Base de données RDS MySQL
│       │   └── ... (main.tf, variables.tf, outputs.tf, README.md)
│       ├── s3/                  # Bucket S3
│       │   └── ... (main.tf, variables.tf, outputs.tf, README.md)
│       └── ecs-monitoring/      # Monitoring ECS avec EC2
│           └── ... (main.tf, variables.tf, outputs.tf, task-definitions/, config/, README.md)
├── scripts/                     # Scripts utilitaires
│   └── deploy_backend.sh        # Script pour déployer le .war sur Tomcat
└── README.md                    # Ce fichier - Documentation principale
```

*(Sections suivantes à compléter au fur et à mesure)*

## Infrastructure (Terraform)

*(Détails sur la configuration Terraform, les modules, etc.)*

### Modules Terraform

*(Description de chaque module)*

### Déploiement/Destruction de l'Infrastructure

*(Instructions pour utiliser le workflow `1-infra-deploy-destroy.yml`)*

## Application Backend (Java Spring Boot)

*(Détails sur l'application Java)*

### Déploiement du Backend

*(Instructions pour utiliser le workflow `3-backend-deploy.yml`)*

## Application Frontend (React Native Web)

*(Détails sur l'application React Native pour le web)*

### Déploiement du Frontend

*(Instructions pour utiliser le workflow `4-frontend-deploy.yml` et accéder à Amplify)*

## Monitoring (ECS avec EC2 - Prometheus & Grafana)

*(Détails sur la configuration du monitoring)*

### Accès à Grafana

*(Comment accéder à l'interface Grafana une fois déployée)*

## CI/CD (GitHub Actions)

Le projet utilise GitHub Actions pour automatiser les processus de déploiement et d'intégration continue. Les workflows sont conçus pour être cohérents, bien documentés et faciles à maintenir.

### Workflows Disponibles

*   **`1-infra-deploy-destroy.yml`:** Gère l'infrastructure complète via Terraform avec Terraform Cloud.
    - Déclenchement: Manuel (workflow_dispatch)
    - Actions: plan, apply, destroy
    - Paramètres requis: Aucun (toutes les variables sont stockées dans les secrets GitHub)
    - Fonctionnalités:
      - Stockage sécurisé de l'état Terraform dans Terraform Cloud (organisation Med3Sin)
      - Workflow en plusieurs étapes avec approbation obligatoire à chaque étape
      - Planification, validation et application/destruction de l'infrastructure AWS
      - Utilisation des dernières versions des actions GitHub (v4 pour les artefacts)
    - Sécurité: Requiert une approbation manuelle avant toute modification de l'infrastructure
    - Résumé d'exécution: Fournit un récapitulatif détaillé des actions effectuées à chaque étape

*   **`3-backend-deploy.yml`:** Compile et déploie l'application Java sur l'instance EC2.
    - Déclenchement: Manuel (workflow_dispatch)
    - Processus: Compilation Maven, téléversement sur S3, déploiement sur Tomcat via SSH
    - Paramètres requis: IP publique de l'EC2, nom du bucket S3

*   **`4-frontend-deploy.yml`:** Vérifie la compilation de l'application React Native Web.
    - Déclenchement: Automatique (push sur main) ou manuel
    - Processus: Installation des dépendances, compilation du code
    - Note: Le déploiement réel est géré par AWS Amplify via la connexion directe au repo GitHub

### Configuration des Secrets

Pour que les workflows fonctionnent, vous devez configurer les secrets suivants dans votre repository GitHub (`Settings` > `Secrets and variables` > `Actions`) :

*   `AWS_ACCESS_KEY_ID`: Votre Access Key ID AWS.
*   `AWS_SECRET_ACCESS_KEY`: Votre Secret Access Key AWS.
*   `DB_USERNAME`: Le nom d'utilisateur pour la base de données RDS (ex: `admin`).
*   `DB_PASSWORD`: Le mot de passe pour la base de données RDS (choisissez un mot de passe sécurisé).
*   `EC2_KEY_PAIR_NAME`: Le nom de la paire de clés EC2 existante dans AWS pour l'accès SSH.
*   `EC2_SSH_PRIVATE_KEY`: Le contenu de votre clé SSH privée (utilisée pour se connecter à l'EC2 lors des déploiements).
*   `GH_PAT`: Un Personal Access Token GitHub pour les intégrations comme Amplify. **Important**: Les noms de secrets ne doivent pas commencer par `GITHUB_` car ce préfixe est réservé aux variables d'environnement intégrées de GitHub Actions.
*   `TF_API_TOKEN`: Un token API Terraform Cloud pour l'authentification et le stockage sécurisé de l'état Terraform.

> **Instructions détaillées pour créer un GH_PAT** :
>
> 1. **Accédez à votre compte GitHub** :
>    - Connectez-vous à votre compte GitHub
>    - Cliquez sur votre photo de profil en haut à droite
>    - Sélectionnez "Settings" (Paramètres)
>
> 2. **Accédez aux paramètres développeur** :
>    - Dans le menu de gauche, faites défiler vers le bas et cliquez sur "Developer settings" (Paramètres développeur)
>
> 3. **Créez un nouveau token** :
>    - Cliquez sur "Personal access tokens" (Tokens d'accès personnels)
>    - Sélectionnez "Tokens (classic)"
>    - Cliquez sur "Generate new token" (Générer un nouveau token)
>    - Sélectionnez "Generate new token (classic)"
>
> 4. **Configurez le token** :
>    - Donnez un nom descriptif à votre token (par exemple "YourMedia Terraform Amplify")
>    - Définissez une date d'expiration (recommandé : 90 jours)
>    - Sélectionnez les autorisations nécessaires :
>      - `repo` (accès complet au dépôt)
>      - `admin:repo_hook` (pour les webhooks Amplify)
>    - Faites défiler vers le bas et cliquez sur "Generate token" (Générer le token)
>
> 5. **Copiez le token** :
>    - **IMPORTANT** : Copiez immédiatement le token généré. Vous ne pourrez plus le voir après avoir quitté cette page.
>
> 6. **Configurez le secret dans GitHub Actions** :
>    - Allez sur votre dépôt GitHub
>    - Cliquez sur "Settings" (Paramètres)
>    - Dans le menu de gauche, cliquez sur "Secrets and variables" puis "Actions"
>    - Cliquez sur "New repository secret"
>    - Nom : `GH_PAT`
>    - Valeur : collez le token que vous avez copié
>    - Cliquez sur "Add secret"

## Résolution des problèmes courants

### Workflow GitHub Actions bloqué sur `terraform plan`

Si le workflow GitHub Actions est bloqué à l'étape `terraform plan` avec un message comme celui-ci :

```
Started at 1744048310000
Run terraform plan \
var.github_token
  Token GitHub (PAT) pour connecter Amplify au repository.
```

Cela signifie que le secret `GH_PAT` n'est pas correctement configuré ou n'est pas accessible par le workflow. Pour résoudre ce problème :

1. Vérifiez que le secret `GH_PAT` est correctement configuré dans les paramètres de votre dépôt GitHub (voir les instructions détaillées ci-dessus).
2. Assurez-vous que le workflow a les permissions nécessaires pour accéder aux secrets.
3. Si le problème persiste, vous pouvez annuler le workflow en cours et le relancer après avoir vérifié la configuration des secrets.

### Erreur "Context access might be invalid: GH_PAT"

Cette erreur peut apparaître dans l'IDE lors de l'édition du workflow, mais elle n'affecte pas son exécution. C'est simplement un avertissement indiquant que l'IDE ne peut pas vérifier si le secret `GH_PAT` existe.
