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
7.  [Monitoring (Docker sur EC2 - Prometheus & Grafana)](#monitoring-docker-sur-ec2---prometheus--grafana)
    *   [Accès à Grafana](#accès-à-grafana)
8.  [CI/CD (GitHub Actions)](#cicd-github-actions)
    *   [Workflows Disponibles](#workflows-disponibles)
    *   [Configuration des Secrets](#configuration-des-secrets)
9.  [Corrections et Améliorations](#corrections-et-améliorations)
    *   [Correction du Groupe de Sous-réseaux RDS](#correction-du-groupe-de-sous-réseaux-rds)
    *   [Mise à jour du Type d'Instance RDS](#mise-à-jour-du-type-dinstance-rds)
    *   [Problème de suppression du bucket S3 contenant des objets](#problème-de-suppression-du-bucket-s3-contenant-des-objets)

## Architecture Globale

L'architecture cible repose sur AWS et utilise les services suivants :

```
+----------------------------------+     +----------------------------------+
|            AWS Cloud            |     |          Utilisateurs           |
|                                 |     |                                 |
|  +----------------------------+ |     |                                 |
|  |         VPC par défaut     | |     |                                 |
|  |                            | |     |                                 |
|  |  +----------------------+  | |     |                                 |
|  |  |    EC2 (t2.micro)   |  | |     |                                 |
|  |  |                      |<-+-+-----+-- SSH (Port 22)                |
|  |  |    Tomcat + Java    |  | |     |                                 |
|  |  +----------+----------+  | |     |                                 |
|  |             |             | |     |                                 |
|  |             v             | |     |                                 |
|  |  +----------------------+ | |     |                                 |
|  |  |   RDS (db.t3.micro)  | | |     |                                 |
|  |  |                      | | |     |                                 |
|  |  |       MySQL 8.0      | | |     |                                 |
|  |  +----------------------+ | |     |                                 |
|  |                            | |     |                                 |
|  |  +----------------------+  | |     |                                 |
|  |  |    EC2 (t2.micro)   |  | |     |                                 |
|  |  |                      |<-+-+-----+-- HTTP (Port 3000) - Grafana   |
|  |  |    ECS + Monitoring  |  | |     |                                 |
|  |  +----------------------+  | |     |                                 |
|  |                            | |     |                                 |
|  +----------------------------+ |     |                                 |
|                                 |     |                                 |
|  +----------------------------+ |     |                                 |
|  |      Amplify Hosting      |<-+-----+-- HTTPS - Frontend            |
|  |                           | |     |                                 |
|  |     React Native Web     | |     |                                 |
|  +----------------------------+ |     |                                 |
|                                 |     |                                 |
|  +----------------------------+ |     |                                 |
|  |           S3              | |     |                                 |
|  |                           | |     |                                 |
|  |   Stockage des médias    | |     |                                 |
|  +----------------------------+ |     |                                 |
+----------------------------------+     +----------------------------------+
```

*   **Compute:**
    *   AWS EC2 (t2.micro) pour héberger l'API backend Java Spring Boot sur un serveur Tomcat.
    *   Docker sur EC2 (t2.micro) pour exécuter les conteneurs de monitoring (Prometheus, Grafana) tout en restant dans les limites du Free Tier.
*   **Base de données:** AWS RDS MySQL (db.t3.micro) en mode "Database as a Service".
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

Le déploiement du frontend est géré par AWS Amplify, qui est configuré pour déployer uniquement le répertoire `app-react` du projet. La configuration d'Amplify dans Terraform inclut :

1. **Spécification du répertoire `app-react`** : Les commandes de build sont exécutées dans ce répertoire.
2. **Configuration de build React** : Utilisation de yarn/npm pour installer les dépendances et construire l'application.
3. **Déploiement automatique** : Configuration de la branche `main` pour un déploiement automatique à chaque push.

Pour déployer manuellement le frontend, vous pouvez utiliser le workflow GitHub Actions `3-frontend-deploy.yml` qui vérifie la compilation du code React Native Web. Le déploiement réel est ensuite géré par AWS Amplify via la connexion directe au dépôt GitHub.

## Monitoring (Docker sur EC2 - Prometheus & Grafana)

Le monitoring de l'application est assuré par Prometheus et Grafana, déployés dans des conteneurs Docker sur une instance EC2 dédiée. Cette approche permet de rester dans les limites du Free Tier AWS tout en offrant une solution de monitoring complète.

La configuration est détaillée dans le document [MONITORING-CONFIGURATION.md](MONITORING-CONFIGURATION.md).

Les principales caractéristiques de cette configuration sont :

1. **Utilisation de Docker** au lieu d'ECS Fargate pour réduire les coûts
2. **Stockage local** pour les données Prometheus et Grafana sur l'instance EC2
3. **Limitation des ressources** des conteneurs pour optimiser l'utilisation de l'instance t2.micro
4. **Rotation des logs** pour éviter de consommer trop d'espace disque
5. **Rétention des données** limitée à 15 jours et 1 Go pour Prometheus

### Accès à Grafana

Une fois l'infrastructure déployée, Grafana est accessible à l'adresse suivante :

```
http://<MONITORING_IP>:3000
```

Où `<MONITORING_IP>` est l'adresse IP publique de l'instance EC2 de monitoring. Cette adresse est disponible dans les outputs Terraform et est exportée en tant que secret GitHub `TF_MONITORING_IP` par le workflow `1-terraform-outputs-to-secrets.yml`.

Les identifiants par défaut pour se connecter à Grafana sont :
- **Utilisateur** : admin
- **Mot de passe** : admin

Lors de la première connexion, Grafana vous demandera de changer le mot de passe.

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
*   `EC2_SSH_PUBLIC_KEY`: Le contenu de votre clé SSH publique (utilisée pour configurer l'accès SSH aux instances EC2 lors de leur création).

Voir le guide [SSH-CONFIGURATION-GUIDE.md](SSH-CONFIGURATION-GUIDE.md) pour plus de détails sur la configuration SSH.
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

### Configuration de la clé SSH publique pour les instances EC2

Le workflow `0-infra-deploy-destroy.yml` permet de configurer automatiquement l'accès SSH aux instances EC2 lors de leur création. Vous avez deux options :

#### Option 1 : Utiliser la clé SSH publique stockée dans GitHub Secrets (recommandé)

1. Générez une paire de clés SSH sur votre machine locale :
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/yourmedia_ec2_key -N ""
   ```

2. Copiez le contenu de la clé publique :
   ```bash
   cat ~/.ssh/yourmedia_ec2_key.pub
   ```

3. Ajoutez la clé publique en tant que secret GitHub nommé `EC2_SSH_PUBLIC_KEY` :
   - Accédez à votre dépôt GitHub > Settings > Secrets and variables > Actions
   - Cliquez sur "New repository secret"
   - Nom : `EC2_SSH_PUBLIC_KEY`
   - Valeur : (collez le contenu de votre clé publique)

4. Lors du déclenchement du workflow `0-infra-deploy-destroy.yml`, assurez-vous que l'option "Utiliser la clé SSH publique stockée dans les secrets GitHub" est activée (c'est le cas par défaut).

#### Option 2 : Spécifier une clé SSH publique lors du déclenchement du workflow

1. Générez une paire de clés SSH sur votre machine locale comme décrit ci-dessus.

2. Lors du déclenchement du workflow `0-infra-deploy-destroy.yml` :
   - Désactivez l'option "Utiliser la clé SSH publique stockée dans les secrets GitHub"
   - Collez la clé publique dans le champ "Clé SSH publique pour les instances EC2"

Dans les deux cas, la clé publique sera automatiquement ajoutée au fichier `~/.ssh/authorized_keys` de l'utilisateur `ec2-user` sur les instances EC2 créées.

Pour plus de détails sur la configuration SSH, consultez le guide [SSH-CONFIGURATION-GUIDE.md](SSH-CONFIGURATION-GUIDE.md).

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

### Erreurs liées aux ressources et optimisations

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

Cela signifie que l'URL du dépôt GitHub fournie à Amplify n'est pas valide. Ce problème a été résolu en désactivant temporairement la connexion au dépôt GitHub en définissant `repository = null`. Cela permet de créer l'application Amplify sans la connecter à un dépôt. Vous pourrez connecter le dépôt manuellement plus tard via la console AWS Amplify.

#### Erreur "Invalid setting for container" dans ECS

Si vous rencontrez des erreurs comme celle-ci :

```
Error: creating ECS Task Definition (***-grafana): operation error ECS: RegisterTaskDefinition, https response error StatusCode: 400, RequestID: 2c0dc3e6-fe03-4eef-8561-c3937860c075, ClientException: Invalid setting for container '***-grafana'. At least one of 'memory' or 'memoryReservation' must be specified.
```

Cela signifie que les définitions de conteneurs ECS ne spécifient pas les allocations de mémoire requises. Ce problème a été résolu en ajoutant des paramètres `memory` et `cpu` aux définitions de conteneurs Prometheus et Grafana.

#### Erreur "Network Configuration is not valid for the given networkMode" dans ECS

Si vous rencontrez des erreurs comme celle-ci :

```
Error: creating ECS Service (***-grafana-service): operation error ECS: CreateService, https response error StatusCode: 400, RequestID: f5777447-cd8d-4539-b3f4-7346efb716df, InvalidParameterException: Network Configuration is not valid for the given networkMode of this task definition.
```

Cela signifie que la configuration réseau spécifiée pour le service ECS n'est pas compatible avec le mode réseau défini dans la définition de tâche. Ce problème a été résolu en supprimant le bloc `network_configuration` des services ECS, car nous utilisons le mode réseau "bridge" qui ne nécessite pas de configuration réseau spécifique.

#### Erreur "InvalidParameterCombination" avec RDS MySQL

Si vous rencontrez des erreurs comme celle-ci :

```
Error: creating RDS DB Instance (***-mysql-db): operation error RDS: CreateDBInstance, https response error StatusCode: 400, RequestID: fa1a8c8d-749d-42de-af17-d99f9ddd938f, api error InvalidParameterCombination: RDS does not support creating a DB instance with the following combination: DBInstanceClass=db.t3.micro, Engine=mysql, EngineVersion=8.0.40, LicenseModel=general-public-license.
```

Cela signifie que la combinaison de classe d'instance, de moteur et de version n'est pas prise en charge. Ce problème peut être résolu en utilisant une version de MySQL compatible avec le type d'instance choisi. Pour db.t3.micro, MySQL 8.0 est généralement compatible avec le Free Tier AWS.

**Note** : Voir la section [Mise à jour du Type d'Instance RDS](#mise-à-jour-du-type-dinstance-rds) pour plus de détails sur le changement de db.t2.micro à db.t3.micro.

#### Problème de suppression du groupe d'auto-scaling EC2

Si vous rencontrez des difficultés lors de la destruction de l'infrastructure, notamment avec le groupe d'auto-scaling EC2, c'est probablement parce que cette ressource a des dépendances complexes qui ne sont pas correctement gérées par Terraform lors de la destruction.

Ce problème a été résolu en supprimant complètement le groupe d'auto-scaling factice et le fournisseur de capacité ECS associé. Ces ressources n'étaient pas strictement nécessaires pour notre cas d'utilisation simple, car nous utilisons déjà une instance EC2 dédiée pour exécuter les conteneurs ECS. Les services ECS sont configurés pour utiliser directement cette instance via le type de lancement "EC2".

Cette simplification de l'architecture facilite la destruction de l'infrastructure et réduit la complexité globale.

### Problème de suppression du bucket S3 contenant des objets

Si vous rencontrez des erreurs comme celle-ci lors de la destruction de l'infrastructure :

```
Error: error deleting S3 Bucket (***-media-***): BucketNotEmpty: The bucket you tried to delete is not empty
```

Cela signifie que le bucket S3 contient encore des objets et ne peut pas être supprimé automatiquement par Terraform.

Ce problème a été résolu en ajoutant les configurations suivantes au module S3 :

1. L'attribut `force_destroy = true` sur la ressource `aws_s3_bucket`, qui permet à Terraform de supprimer le bucket même s'il contient des objets.

2. Une configuration de cycle de vie (`aws_s3_bucket_lifecycle_configuration`) qui :
   - Supprime automatiquement les anciennes versions des objets après 1 jour
   - Supprime les marqueurs de suppression expirés

Ces configurations permettent un nettoyage complet et automatique du bucket S3 lors de la destruction de l'infrastructure, évitant ainsi les erreurs de type "BucketNotEmpty".

#### Erreur "Some input subnets are invalid" pour RDS

Si vous rencontrez des erreurs comme celle-ci :

```
Error: creating RDS DB Subnet Group (***-rds-subnet-group-20250410175302): operation error RDS: CreateDBSubnetGroup, https response error StatusCode: 400, RequestID: c9b9ae0e-2f98-4677-801c-a2b5aa46ce6c, api error InvalidParameterValue: Some input subnets in :[subnet-089180afcefd3b923] are invalid.
```

Cela signifie que les sous-réseaux spécifiés pour le groupe de sous-réseaux RDS ne sont pas valides. Ce problème a été résolu en ajoutant l'attribut `map_public_ip_on_launch = true` aux sous-réseaux créés, ce qui les rend compatibles avec RDS.

## Corrections et Améliorations

Cette section centralise toutes les corrections et améliorations apportées au projet pour faciliter la maintenance et le suivi des modifications.

### Table des matières des corrections

- [Correction du Groupe de Sous-réseaux RDS](#correction-du-groupe-de-sous-réseaux-rds) (2023-04-11)
- [Mise à jour du Type d'Instance RDS](#mise-à-jour-du-type-dinstance-rds) (2023-04-11)
- [Vidage automatique du bucket S3](#vidage-automatique-du-bucket-s3) (2023-04-12)
- [Adaptation des scripts pour Amazon Linux 2](#adaptation-des-scripts-pour-amazon-linux-2) (2023-04-12)
- [Problèmes connus](#problèmes-connus)
- [Améliorations futures](#améliorations-futures)

### Historique des versions

- **v1.0.0** (2023-04-10) : Version initiale de l'infrastructure
- **v1.0.1** (2023-04-11) : Correction du groupe de sous-réseaux RDS et mise à jour du type d'instance RDS
- **v1.0.2** (2023-04-12) : Ajout du vidage automatique du bucket S3 pour faciliter la destruction de l'infrastructure
- **v1.0.3** (2023-04-12) : Adaptation des scripts pour Amazon Linux 2 HVM
- **v1.0.4** (2023-04-13) : Remplacement d'ECS Fargate par Docker sur EC2 pour le monitoring
- **v1.0.5** (2023-04-13) : Ajout de la configuration SSH automatique pour les instances EC2

### Correction du Groupe de Sous-réseaux RDS

**Problème** : Lors de la mise à jour de l'infrastructure, l'erreur suivante se produisait :

```
Error: updating RDS DB Instance (***-mysql-db): operation error RDS: ModifyDBInstance, https response error StatusCode: 400, RequestID: 29922280-5375-4639-a2b0-03b5a87ce841, InvalidVPCNetworkStateFault: You cannot move DB instance ***-mysql-db to subnet group ***-rds-subnet-group-20250411122617. The specified DB subnet group and DB instance are in the same VPC. Choose a DB subnet group in different VPC than the specified DB instance and try again.
```

**Cause** :
- Le nom du groupe de sous-réseaux RDS incluait un timestamp (`formatdate("YYYYMMDDhhmmss", timestamp())`)
- À chaque exécution de Terraform, un nouveau groupe de sous-réseaux était créé avec un nom différent
- Terraform essayait ensuite de mettre à jour l'instance RDS pour utiliser ce nouveau groupe
- AWS ne permet pas de changer le groupe de sous-réseaux d'une instance RDS pour un autre groupe dans le même VPC

**Solution** :
1. Utilisation d'un nom fixe pour le groupe de sous-réseaux (sans timestamp)
2. Suppression du bloc `lifecycle { create_before_destroy = true }` qui créerait un nouveau groupe avant de détruire l'ancien

**Fichiers modifiés** :
- `infrastructure/modules/rds-mysql/main.tf`

**Limitation** : Si vous devez modifier les sous-réseaux utilisés par RDS, vous devrez recréer complètement l'instance RDS (ce qui implique une perte de données si vous n'avez pas de sauvegarde).

### Mise à jour du Type d'Instance RDS

**Modification** : Le type d'instance RDS a été mis à jour de `db.t2.micro` à `db.t3.micro`.

**Raison** : Les instances db.t3.micro offrent de meilleures performances et sont également éligibles au Free Tier AWS.

**Fichiers modifiés** :
- `infrastructure/variables.tf` : Modification de la valeur par défaut de la variable `instance_type_rds`
- `infrastructure/modules/rds-mysql/main.tf` : Utilisation de la variable au lieu d'une valeur codée en dur
- `infrastructure/modules/rds-mysql/README.md` : Mise à jour de la documentation

**Compatibilité** : Le type d'instance db.t3.micro est compatible avec MySQL 8.0 dans le Free Tier AWS.

### Vidage automatique du bucket S3

**Problème** : Lors de la destruction de l'infrastructure, l'erreur suivante se produisait si le bucket S3 contenait des objets :

```
Error: error deleting S3 Bucket (***-media-***): BucketNotEmpty: The bucket you tried to delete is not empty
```

Cela empêchait la destruction complète de l'infrastructure, nécessitant une intervention manuelle pour vider le bucket avant de réessayer la destruction.

**Solution** :
1. Ajout de l'attribut `force_destroy = true` à la ressource `aws_s3_bucket` pour permettre à Terraform de supprimer le bucket même s'il contient des objets.
2. Ajout d'une configuration de cycle de vie (`aws_s3_bucket_lifecycle_configuration`) pour :
   - Supprimer automatiquement les anciennes versions des objets après 1 jour
   - Supprimer les marqueurs de suppression expirés

**Fichiers modifiés** :
- `infrastructure/modules/s3/main.tf` : Ajout de l'attribut `force_destroy` et de la configuration de cycle de vie
- `infrastructure/modules/s3/README.md` : Mise à jour de la documentation

**Avantages** :
- Destruction complète et automatique de l'infrastructure sans intervention manuelle
- Nettoyage automatique des anciennes versions des objets pour éviter l'accumulation de données inutiles
- Simplification du processus de développement et de test

### Adaptation des scripts pour Amazon Linux 2

**Problème** : Les scripts d'installation et de déploiement étaient configurés pour Ubuntu, alors que l'AMI utilisée est Amazon Linux 2 HVM (`ami-0925eac45db11fef2`). Cela causait des erreurs lors de l'installation de Java, Tomcat et AWS CLI.

**Solution** :
1. Modification du script d'installation Java/Tomcat pour utiliser :
   - `yum` au lieu de `apt-get` comme gestionnaire de paquets
   - Amazon Corretto 11 au lieu d'OpenJDK 17
   - Le chemin Java correct pour Amazon Linux 2 (`/usr/lib/jvm/java-11-amazon-corretto`)

2. Modification du workflow de déploiement backend pour :
   - Se connecter avec l'utilisateur `ec2-user` au lieu de `ubuntu`
   - Utiliser `yum` au lieu de `apt-get` pour installer AWS CLI

**Fichiers modifiés** :
- `infrastructure/modules/ec2-java-tomcat/scripts/install_java_tomcat.sh` : Adaptation pour Amazon Linux 2
- `.github/workflows/2-backend-deploy.yml` : Modification de l'utilisateur SSH et des commandes d'installation

**Avantages** :
- Compatibilité avec l'AMI Amazon Linux 2 spécifiée
- Installation correcte de Java, Tomcat et AWS CLI
- Déploiement fonctionnel de l'application backend

### Problèmes connus

Cette section liste les problèmes connus qui n'ont pas encore été résolus :

1. **Destruction de l'infrastructure** : Malgré la suppression du groupe d'auto-scaling EC2, la destruction complète de l'infrastructure peut encore échouer dans certains cas. Solution temporaire : supprimer manuellement les ressources problématiques via la console AWS avant d'exécuter `terraform destroy`.

2. **Connexion à RDS depuis l'extérieur** : L'instance RDS n'est pas accessible depuis l'extérieur du VPC pour des raisons de sécurité. Pour se connecter à la base de données depuis un outil externe, il faut passer par un tunnel SSH via l'instance EC2.

### Améliorations futures

Cette section liste les améliorations planifiées pour les futures versions :

1. **Mise en place d'un bastion host** : Ajouter une instance EC2 dédiée (bastion host) pour sécuriser l'accès SSH aux instances.

2. **Implémentation de backups automatisés** : Configurer des backups automatisés pour RDS et les données critiques.

3. **Migration vers des sous-réseaux privés** : Déplacer les instances EC2 et RDS dans des sous-réseaux privés pour améliorer la sécurité.

4. **Implémentation d'un système de monitoring plus complet** : Ajouter des dashboards et des alertes plus détaillés dans Grafana.

5. **Optimisation des coûts** : Analyser et optimiser l'utilisation des ressources pour minimiser les coûts tout en restant dans les limites du Free Tier.

## Limites du Free Tier AWS

Cette section détaille les limites du Free Tier AWS pour chaque service utilisé dans ce projet :

### EC2 (Elastic Compute Cloud)
- **Limite Free Tier** : 750 heures d'utilisation par mois d'instances t2.micro ou t3.micro (Linux)
- **Notre utilisation** : 2 instances (1 pour l'application Java, 1 pour ECS) = 1440 heures par mois si elles fonctionnent 24/7
- **Recommandation** : Arrêter les instances lorsqu'elles ne sont pas utilisées pour rester dans les limites du Free Tier

### RDS (Relational Database Service)
- **Limite Free Tier** : 750 heures d'utilisation par mois d'instances db.t2.micro ou db.t3.micro, 20 Go de stockage SSD (gp2)
- **Notre utilisation** : 1 instance db.t3.micro avec 20 Go de stockage = 720 heures par mois si elle fonctionne 24/7
- **Recommandation** : Rester dans les limites du Free Tier, mais attention aux backups qui peuvent générer des coûts supplémentaires

### S3 (Simple Storage Service)
- **Limite Free Tier** : 5 Go de stockage standard, 20 000 requêtes GET, 2 000 requêtes PUT
- **Recommandation** : Surveiller l'utilisation du stockage et le nombre de requêtes

### Amplify Hosting
- **Limite Free Tier** : 1 000 minutes de build par mois, 5 Go de stockage
- **Recommandation** : Limiter le nombre de déploiements pour éviter de dépasser les minutes de build

### CloudWatch
- **Limite Free Tier** : 10 métriques personnalisées, 1 million d'API requests, 5 Go de logs ingestion et archivage
- **Recommandation** : Limiter le nombre de métriques et de logs pour éviter des coûts supplémentaires

### Autres services
- **Transfert de données** : 1 Go de données sortantes par mois (tous services confondus)
- **Recommandation** : Surveiller le transfert de données sortantes qui peut rapidement générer des coûts

## Guide de dépannage complet

Cette section fournit des solutions aux problèmes courants que vous pourriez rencontrer lors du déploiement ou de l'utilisation de l'infrastructure.

### Problèmes de déploiement Terraform

#### Erreur : "No valid credential sources found"

**Problème** : Terraform ne trouve pas les identifiants AWS.

**Solution** :
1. Vérifiez que les secrets GitHub `AWS_ACCESS_KEY_ID` et `AWS_SECRET_ACCESS_KEY` sont correctement configurés.
2. Assurez-vous que les variables d'environnement AWS sont passées aux commandes Terraform dans le workflow GitHub Actions.
3. Vérifiez que l'utilisateur IAM associé aux identifiants a les permissions nécessaires.

#### Erreur : "Error acquiring the state lock"

**Problème** : Le verrou d'état Terraform est déjà acquis par une autre exécution.

**Solution** :
1. Attendez que l'autre exécution se termine.
2. Si vous êtes sûr qu'aucune autre exécution n'est en cours, vous pouvez forcer la libération du verrou avec `terraform force-unlock [ID]`.

### Problèmes de connexion aux instances

#### Impossible de se connecter à l'instance EC2 via SSH

**Problème** : Impossible d'établir une connexion SSH à l'instance EC2.

**Solution** :
1. Vérifiez que le groupe de sécurité autorise le trafic SSH (port 22) depuis votre adresse IP.
2. Assurez-vous que la paire de clés SSH est correctement configurée et que vous utilisez la bonne clé privée.
3. Vérifiez que l'instance est en état "running".

#### Impossible de se connecter à la base de données RDS

**Problème** : Impossible d'établir une connexion à la base de données RDS.

**Solution** :
1. La base de données n'est pas accessible directement depuis l'extérieur du VPC. Utilisez un tunnel SSH via l'instance EC2 :
   ```
   ssh -i votre-cle.pem -L 3306:endpoint-rds:3306 ubuntu@ip-ec2
   ```
2. Vérifiez que le groupe de sécurité RDS autorise le trafic depuis le groupe de sécurité EC2.

### Problèmes de déploiement d'applications

#### Erreur lors du déploiement du backend Java

**Problème** : Le déploiement du backend Java échoue.

**Solution** :
1. Vérifiez que Tomcat est correctement installé et en cours d'exécution sur l'instance EC2.
2. Assurez-vous que les identifiants AWS utilisés ont accès au bucket S3.
3. Vérifiez les logs Tomcat pour identifier l'erreur spécifique.

#### Erreur lors du déploiement du frontend sur Amplify

**Problème** : Le déploiement du frontend sur Amplify échoue.

**Solution** :
1. Vérifiez que le token GitHub est correctement configuré.
2. Assurez-vous que le répertoire `app-react` existe et contient une application React valide.
3. Vérifiez les logs de build Amplify pour identifier l'erreur spécifique.
