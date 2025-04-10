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
*   **Réseau:** Utilisation du VPC par défaut pour la simplicité, avec détection automatique des sous-réseaux disponibles ou création automatique de sous-réseaux si nécessaire, et des groupes de sécurité spécifiques pour contrôler les flux. Les accès SSH et Grafana sont ouverts à toutes les adresses IP pour simplifier le développement, mais cette configuration devrait être restreinte en production.
*   **Hébergement Frontend:** AWS Amplify Hosting pour déployer la version web de l'application React Native de manière simple et scalable.
*   **IaC:** Terraform pour décrire et provisionner l'ensemble de l'infrastructure AWS de manière automatisée et reproductible.
*   **CI/CD:** GitHub Actions pour automatiser les builds, les tests (basiques) et les déploiements des applications backend et frontend, ainsi que la gestion de l'infrastructure Terraform.

**Schéma d'Architecture :**

[Voir le schéma d'architecture](aws-architecture-project-yourmedia.html)



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
│       ├── 2-backend-deploy.yml
│       └── 3-frontend-deploy.yml
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

*(Instructions pour utiliser le workflow `2-backend-deploy.yml`)*

## Application Frontend (React Native Web)

*(Détails sur l'application React Native pour le web)*

### Déploiement du Frontend

*(Instructions pour utiliser le workflow `3-frontend-deploy.yml` et accéder à Amplify)*

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
    - Paramètres requis: Aucun (toutes les variables sont stockées dans les secrets GitHub ou récupérées automatiquement)
    - Fonctionnalités:
      - Stockage sécurisé de l'état Terraform dans Terraform Cloud (organisation Med3Sin)
      - Workflow en plusieurs étapes avec approbation obligatoire à chaque étape
      - Planification, validation et application/destruction de l'infrastructure AWS
      - Utilisation des dernières versions des actions GitHub (v4 pour les artefacts)
      - Récupération automatique du propriétaire et du nom du repo GitHub
    - Sécurité: Requiert une approbation manuelle avant toute modification de l'infrastructure
    - Résumé d'exécution: Fournit un récapitulatif détaillé des actions effectuées à chaque étape

*   **`2-backend-deploy.yml`:** Compile et déploie l'application Java sur l'instance EC2.
    - Déclenchement: Manuel (workflow_dispatch)
    - Processus: Compilation Maven, téléversement sur S3, déploiement sur Tomcat via SSH
    - Paramètres requis: IP publique de l'EC2, nom du bucket S3

*   **`3-frontend-deploy.yml`:** Vérifie la compilation de l'application React Native Web.
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
*   `TF_API_TOKEN`: Un token API Terraform Cloud pour l'authentification et le stockage sécurisé de l'état Terraform. **Ce secret est obligatoire pour que le workflow fonctionne.**

> **Instructions détaillées pour créer un TF_API_TOKEN** :
>
> 1. **Accédez à Terraform Cloud** :
>    - Connectez-vous à [Terraform Cloud](https://app.terraform.io/)
>    - Cliquez sur votre avatar en haut à droite
>    - Sélectionnez "User Settings"
>
> 2. **Créez un token API** :
>    - Cliquez sur "Tokens" dans le menu de gauche
>    - Cliquez sur "Create an API token"
>    - Donnez un nom à votre token (par exemple "GitHub Actions")
>    - Copiez le token généré (vous ne pourrez plus le voir après avoir quitté cette page)
>
> 3. **Configurez le secret dans GitHub Actions** :
>    - Allez sur votre dépôt GitHub
>    - Cliquez sur "Settings" > "Secrets and variables" > "Actions"
>    - Cliquez sur "New repository secret"
>    - Nom : `TF_API_TOKEN`
>    - Valeur : collez le token que vous avez copié
>    - Cliquez sur "Add secret"
>
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

### Erreurs liées aux ressources

#### Erreur "no matching EC2 Subnet found"

Si vous rencontrez une erreur comme celle-ci :

```
Error: no matching EC2 Subnet found

  with data.aws_subnet.default_az1,
  on main.tf line 11, in data "aws_subnet" "default_az1":
  11: data "aws_subnet" "default_az1" {
```

Cela signifie que Terraform ne trouve pas les sous-réseaux spécifiés dans le VPC par défaut. Ce problème a été résolu en modifiant le code pour récupérer automatiquement tous les sous-réseaux disponibles dans le VPC par défaut, plutôt que de rechercher des sous-réseaux spécifiques avec des critères qui pourraient ne pas correspondre à votre configuration AWS.

#### Erreur "Invalid index" avec sous-réseaux vides

Si vous rencontrez une erreur comme celle-ci :

```
Error: Invalid index

  on main.tf line 20, in locals:
  20:   subnet_id_az1 = tolist(data.aws_subnets.default.ids)[0]
    ├──────────────────
    │ data.aws_subnets.default.ids is empty list of string

The given key does not identify an element in this collection value: the
collection has no elements.
```

Cela signifie qu'aucun sous-réseau n'a été trouvé dans le VPC par défaut. Ce problème a été résolu en modifiant le code pour créer automatiquement des sous-réseaux si aucun n'est trouvé dans le VPC par défaut. Cette approche garantit que l'infrastructure peut être déployée même si le VPC par défaut n'a pas de sous-réseaux préconfigurés.

#### Erreur "EntityAlreadyExists" pour les rôles IAM et autres ressources

Si vous rencontrez des erreurs comme celle-ci :

```
Error: creating IAM Role (***-ecs-task-exec-role): operation error IAM: CreateRole, https response error StatusCode: 409, RequestID: e42e1e36-b1a0-45e3-867c-8e450c48769b, EntityAlreadyExists: Role with name ***-ecs-task-exec-role already exists.
```

Cela signifie que des ressources avec les mêmes noms existent déjà dans votre compte AWS. Ce problème a été résolu en ajoutant un timestamp aux noms des ressources et en utilisant l'option `create_before_destroy = true` dans le bloc `lifecycle`. Cette approche garantit que de nouvelles ressources avec des noms uniques sont créées à chaque déploiement.

#### Erreur "Invalid security group description"

Si vous rencontrez des erreurs comme celle-ci :

```
Error: creating Security Group (***-rds-sg): operation error EC2: CreateSecurityGroup, https response error StatusCode: 400, RequestID: c3b66fed-0b61-4ea8-b3ba-3d184cb50d2a, api error InvalidParameterValue: Invalid security group description. Valid descriptions are strings less than 256 characters from the following set:  a-zA-Z0-9. _-:/()#,@[]+=&;{}!$*
```

Cela signifie que les descriptions des groupes de sécurité contiennent des caractères non valides (comme les apostrophes). Ce problème a été résolu en supprimant les caractères non valides des descriptions des groupes de sécurité.

#### Erreur "The repository url is not valid" pour Amplify

Si vous rencontrez des erreurs comme celle-ci :

```
Error: creating Amplify App (***-frontend): operation error Amplify: CreateApp, https response error StatusCode: 400, RequestID: 5368ec58-c0b0-405e-aaa9-888f3670045e, BadRequestException: The repository url is not valid.
```

Cela signifie que l'URL du dépôt GitHub fournie à Amplify n'est pas valide. Ce problème a été résolu en vérifiant si les variables `repo_owner` et `repo_name` sont définies et en utilisant une URL par défaut si elles ne le sont pas.
