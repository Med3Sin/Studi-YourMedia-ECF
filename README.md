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

L'architecture du projet est organisée autour des services AWS suivants, tous interconnectés pour former une solution complète :

```
+------------------+     +-------------------+     +------------------+
|                  |     |                   |     |                  |
|  AWS Amplify     |     |  EC2 (t2.micro)   |     |  RDS MySQL      |
|  (Frontend)      |<--->|  (Backend)        |<--->|  (db.t2.micro)   |
|                  |     |  Tomcat/Java      |     |                  |
+------------------+     +-------------------+     +------------------+
                               ^      ^
                               |      |
                               v      v
+------------------+     +-------------------+     +------------------+
|                  |     |                   |     |                  |
|  S3 Bucket       |<--->|  ECS avec EC2     |     |  CloudWatch     |
|  (Storage)       |     |  (Monitoring)     |<--->|  (Logs)          |
|                  |     |  Prometheus/Grafana     |                  |
+------------------+     +-------------------+     +------------------+
```



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

## Infrastructure (Terraform)

L'infrastructure du projet est entièrement définie et gérée via Terraform, ce qui permet un provisionnement automatique, reproductible et versionné des ressources AWS. L'infrastructure a été conçue pour rester dans les limites du Free Tier AWS tout en offrant un environnement complet pour l'application.

Le code Terraform est organisé de manière modulaire pour faciliter la maintenance et l'évolution :

- **`main.tf`** : Point d'entrée principal qui configure le VPC par défaut et instancie les différents modules.
- **`variables.tf`** : Définit toutes les variables d'entrée utilisées par Terraform.
- **`outputs.tf`** : Définit les sorties générées après le déploiement (IP, endpoints, etc.).
- **`providers.tf`** : Configure le provider AWS et ses paramètres.

### Modules Terraform

L'infrastructure est divisée en modules réutilisables, chacun responsable d'un aspect spécifique :

1. **Module `network`** :
   - Gère les groupes de sécurité pour contrôler les flux réseau entre les différents composants.
   - Configure les règles d'accès pour EC2, RDS, et ECS.

2. **Module `ec2-java-tomcat`** :
   - Provisionne une instance EC2 t2.micro pour héberger l'application Java.
   - Configure Tomcat et Java via un script d'initialisation.
   - Crée un rôle IAM avec les permissions nécessaires pour accéder à S3.

3. **Module `rds-mysql`** :
   - Déploie une instance RDS MySQL db.t2.micro.
   - Configure les paramètres de sécurité, de sauvegarde et de performance.

4. **Module `s3`** :
   - Crée un bucket S3 pour le stockage des médias et des artefacts de build.
   - Configure les politiques d'accès et le cycle de vie des objets.

5. **Module `ecs-monitoring`** :
   - Déploie un cluster ECS avec une instance EC2 t2.micro.
   - Configure les conteneurs Prometheus et Grafana pour le monitoring.
   - Définit les tâches ECS et les volumes de données persistantes.

### Déploiement/Destruction de l'Infrastructure

Le workflow GitHub Actions `1-infra-deploy-destroy.yml` permet de gérer l'infrastructure de manière sécurisée et automatisée :

1. **Préparation** :
   - Assurez-vous que tous les [secrets requis](#configuration-des-secrets) sont configurés dans GitHub.
   - Créez une paire de clés SSH dans la console AWS EC2 (si ce n'est pas déjà fait).

2. **Déclenchement du workflow** :
   - Accédez à l'onglet "Actions" du repository GitHub.
   - Sélectionnez le workflow "1 - Deploy/Destroy Infrastructure (Terraform)".
   - Cliquez sur "Run workflow" et remplissez les champs demandés :
     - **Action** : `plan` (pour prévisualiser), `apply` (pour déployer) ou `destroy` (pour supprimer).
     - **Nom de la paire de clés EC2** : Le nom de votre paire de clés AWS.
     - **Propriétaire du repo GitHub** : Votre nom d'utilisateur ou organisation GitHub.
     - **Nom du repo GitHub** : Le nom de ce repository.

3. **Suivi de l'exécution** :
   - Le workflow affiche en temps réel les logs d'exécution de Terraform.
   - Après un déploiement réussi, les outputs Terraform sont affichés (IP publique EC2, endpoint RDS, etc.).
   - Ces informations seront nécessaires pour les étapes suivantes (déploiement backend/frontend).

## Application Backend (Java Spring Boot)

L'application backend est développée avec Java 17 et Spring Boot, packagée sous forme de fichier WAR pour être déployée sur un serveur Tomcat. Elle fournit une API REST simple et expose des métriques pour le monitoring.

### Fonctionnalités principales

- **API REST** : Expose des endpoints pour l'application frontend.
- **Spring Boot Actuator** : Fournit des endpoints de monitoring et de santé.
- **Intégration Prometheus** : Expose des métriques au format Prometheus pour le monitoring.
- **Packaging WAR** : Permet le déploiement sur un serveur Tomcat externe.

### Structure du projet

- **`src/main/java`** : Code source Java de l'application.
- **`src/main/resources`** : Fichiers de configuration (application.properties, etc.).
- **`pom.xml`** : Configuration Maven et dépendances.

### Développement local

Pour développer et tester l'application localement :

```bash
# Compilation et exécution
cd app-java
mvn spring-boot:run

# Accès à l'application
http://localhost:8080/yourmedia-backend/
```

### Déploiement du Backend

Le déploiement de l'application backend est automatisé via le workflow GitHub Actions `3-backend-deploy.yml` :

1. **Prérequis** :
   - L'infrastructure doit être déployée via le workflow `1-infra-deploy-destroy.yml`.
   - Notez l'IP publique de l'instance EC2 et le nom du bucket S3 depuis les outputs Terraform.

2. **Déclenchement du workflow** :
   - Accédez à l'onglet "Actions" du repository GitHub.
   - Sélectionnez le workflow "3 - Build and Deploy Backend (Java WAR)".
   - Cliquez sur "Run workflow" et remplissez les champs demandés :
     - **IP publique de l'EC2** : L'adresse IP de l'instance EC2 déployée.
     - **Nom du bucket S3** : Le nom du bucket S3 déployé.

3. **Processus de déploiement** :
   - Le workflow compile l'application Java avec Maven.
   - Le fichier WAR généré est uploadé sur le bucket S3.
   - Le workflow se connecte en SSH à l'instance EC2.
   - Le fichier WAR est copié depuis S3 vers le répertoire `webapps` de Tomcat.
   - Tomcat détecte automatiquement le nouveau WAR et déploie l'application.

4. **Accès à l'application** :
   - L'application est accessible à l'URL : `http://<IP_PUBLIQUE_EC2>:8080/yourmedia-backend/`
   - Les métriques Prometheus sont disponibles à : `http://<IP_PUBLIQUE_EC2>:8080/yourmedia-backend/actuator/prometheus`

## Application Frontend (React Native Web)

L'application frontend est développée avec React Native et Expo, configurée pour générer une application web. Elle est déployée sur AWS Amplify Hosting pour une distribution globale et performante.

### Fonctionnalités principales

- **Interface utilisateur réactive** : Conçue pour s'adapter à différentes tailles d'écran.
- **React Native Web** : Permet de partager le code entre applications web et mobiles.
- **Expo** : Simplifie le développement et le build de l'application.

### Structure du projet

- **`src/`** : Code source de l'application React Native.
- **`package.json`** : Configuration npm et dépendances.
- **`app.json`** : Configuration Expo.

### Développement local

Pour développer et tester l'application localement :

```bash
# Installation des dépendances
cd app-react
npm install

# Démarrage du serveur de développement
npm run web
```

### Déploiement du Frontend

Le déploiement de l'application frontend est géré par AWS Amplify Hosting, qui est configuré pour se connecter directement au repository GitHub :

1. **Prérequis** :
   - L'infrastructure doit être déployée via le workflow `1-infra-deploy-destroy.yml`.
   - Le secret `GH_PAT` doit être configuré dans GitHub pour permettre à Amplify d'accéder au code.

2. **Processus de déploiement automatique** :
   - Chaque push sur la branche `main` déclenche automatiquement un build et un déploiement sur Amplify.
   - Amplify récupère le code, exécute les commandes de build définies dans `build_spec` et déploie l'application.

3. **Vérification CI** :
   - Le workflow GitHub Actions `4-frontend-deploy.yml` s'exécute à chaque push pour vérifier que le build fonctionne.
   - Ce workflow ne déploie pas l'application, il sert uniquement de vérification d'intégration continue.

4. **Accès à l'application** :
   - L'URL de l'application est visible dans la console AWS Amplify après le déploiement.
   - Format typique : `https://<BRANCH>.<APP_ID>.amplifyapp.com`

## Monitoring (ECS avec EC2 - Prometheus & Grafana)

Le projet inclut une solution de monitoring complète basée sur Prometheus et Grafana, déployée sur Amazon ECS avec une instance EC2 pour rester dans les limites du Free Tier AWS.

### Architecture de monitoring

- **Prometheus** : Collecte et stocke les métriques de l'application backend via l'endpoint `/actuator/prometheus`.
- **Grafana** : Fournit des tableaux de bord visuels pour analyser les métriques collectées par Prometheus.
- **ECS avec EC2** : Héberge les conteneurs Prometheus et Grafana sur une instance t2.micro.

### Configuration

- Les fichiers de configuration de Prometheus et Grafana sont définis dans le module Terraform `ecs-monitoring`.
- Prometheus est configuré pour scraper les métriques de l'application backend à intervalles réguliers.
- Grafana est préconfiguré avec des tableaux de bord pour visualiser les métriques de l'application et du système.

### Accès à Grafana

Pour accéder à l'interface Grafana une fois l'infrastructure déployée :

1. **Trouver l'adresse IP** :
   - L'instance EC2 exécutant les conteneurs ECS a la même adresse IP que celle utilisée pour le déploiement backend.

2. **Accéder à Grafana** :
   - Ouvrez votre navigateur et accédez à : `http://<IP_PUBLIQUE_EC2>:3000`
   - Identifiants par défaut : `admin` / `admin`
   - Lors de la première connexion, vous serez invité à changer le mot de passe.

3. **Tableaux de bord disponibles** :
   - **JVM Metrics** : Métriques de la machine virtuelle Java (mémoire, threads, etc.).
   - **Spring Boot** : Métriques spécifiques à Spring Boot (requêtes HTTP, temps de réponse, etc.).
   - **System Metrics** : Métriques système de l'instance EC2 (CPU, mémoire, disque, etc.).

## CI/CD (GitHub Actions)

Le projet utilise GitHub Actions pour automatiser les processus de déploiement et d'intégration continue. Les workflows sont conçus pour être cohérents, bien documentés et faciles à maintenir.

### Workflows Disponibles

*   **`1-infra-deploy-destroy.yml`:** Gère l'infrastructure complète via Terraform avec Terraform Cloud.
    - Déclenchement: Manuel (workflow_dispatch)
    - Actions: plan, apply, destroy
    - Paramètres requis: Uniquement le nom de la paire de clés EC2 pour SSH
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

### Intégration avec Terraform Cloud

L'infrastructure est gérée via Terraform avec l'état stocké de manière sécurisée dans Terraform Cloud :

1. **Sécurité des données** : L'état Terraform, qui peut contenir des informations sensibles, est stocké de manière chiffrée.
2. **Workflow avec approbation** : Les modifications de l'infrastructure nécessitent une approbation manuelle avant d'être appliquées.
3. **Traçabilité** : Historique complet des modifications apportées à l'infrastructure.

### Configuration de l'environnement d'approbation GitHub

Pour utiliser le workflow avec approbations, vous devez configurer un environnement GitHub :

1. Allez dans les paramètres de votre dépôt GitHub (`Settings` > `Environments`)
2. Cliquez sur `New environment`
3. Nommez l'environnement `approval`
4. Cochez `Required reviewers` et ajoutez les personnes qui peuvent approuver les déploiements
5. Cliquez sur `Save protection rules`

Cette configuration garantit que chaque étape du workflow nécessite une approbation manuelle avant de continuer.

Pour plus de détails sur la configuration, consultez le [README de l'infrastructure](./infrastructure/README.md).

### Configuration des Secrets

Pour que les workflows fonctionnent, vous devez configurer les secrets suivants dans votre repository GitHub (`Settings` > `Secrets and variables` > `Actions`) :

*   `AWS_ACCESS_KEY_ID`: Votre Access Key ID AWS.
*   `AWS_SECRET_ACCESS_KEY`: Votre Secret Access Key AWS.
*   `DB_USERNAME`: Le nom d'utilisateur pour la base de données RDS (ex: `admin`).
*   `DB_PASSWORD`: Le mot de passe pour la base de données RDS (choisissez un mot de passe sécurisé).
*   `EC2_SSH_PRIVATE_KEY`: Le contenu de votre clé SSH privée (utilisée pour se connecter à l'EC2 lors des déploiements). Assurez-vous que la clé publique correspondante est fournie à Terraform (via une variable).
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

> **Instructions détaillées pour créer un TF_API_TOKEN** :
>
> 1. **Créez un compte Terraform Cloud** :
>    - Accédez à [Terraform Cloud](https://app.terraform.io/signup/account) et créez un compte
>    - Créez une organisation nommée `Med3Sin` (ou choisissez un autre nom et mettez à jour `backend.tf`)
>
> 2. **Créez un workspace** :
>    - Dans votre organisation, cliquez sur "New Workspace"
>    - Sélectionnez "CLI-driven workflow"
>    - Nommez le workspace `Med3Sin`
>
> 3. **Générez un token API** :
>    - Cliquez sur votre avatar en haut à droite
>    - Sélectionnez "User Settings"
>    - Cliquez sur "Tokens"
>    - Cliquez sur "Create an API token"
>    - Donnez un nom à votre token (ex: "GitHub Actions Integration")
>    - Cliquez sur "Create API token"
>
> 4. **Copiez le token** :
>    - **IMPORTANT** : Copiez immédiatement le token généré. Vous ne pourrez plus le voir après avoir quitté cette page.
>
> 5. **Configurez le secret dans GitHub Actions** :
>    - Allez sur votre dépôt GitHub
>    - Cliquez sur "Settings" (Paramètres)
>    - Dans le menu de gauche, cliquez sur "Secrets and variables" puis "Actions"
>    - Cliquez sur "New repository secret"
>    - Nom : `TF_API_TOKEN`
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

### Erreur liée aux actions dépréciées

Si vous rencontrez une erreur comme celle-ci :

```
Error: This request has been automatically failed because it uses a deprecated version of `actions/upload-artifact: v3`.
```

Cela signifie que le workflow utilise une version dépréciée d'une action GitHub. Les workflows ont été mis à jour pour utiliser les dernières versions des actions :

- `actions/upload-artifact@v4` au lieu de `actions/upload-artifact@v3`
- `actions/download-artifact@v4` au lieu de `actions/download-artifact@v3`

Si vous rencontrez cette erreur, assurez-vous d'avoir la dernière version du code.

### Erreurs lors du déploiement Terraform

Si vous rencontrez des erreurs lors du déploiement Terraform, voici quelques solutions courantes :

#### Erreur de politique IAM (MalformedPolicyDocument)

Si vous voyez une erreur comme `MalformedPolicyDocument: Resource /* must be in ARN format or "*"`, assurez-vous que toutes les ressources dans les documents de politique IAM sont correctement formatées avec des guillemets et au format ARN.

#### Erreur d'AMI introuvable (InvalidAMIID.NotFound)

Si vous voyez une erreur comme `InvalidAMIID.NotFound: The image id '[ami-xxx]' does not exist`, cela signifie que l'AMI spécifiée n'existe pas dans la région AWS que vous utilisez. Utilisez l'AMI `ami-0925eac45db11fef2` (Amazon Linux 2 AMI) qui est disponible dans la région eu-west-3 (Paris).

#### Erreur de mémoire non spécifiée pour les conteneurs ECS

Si vous voyez une erreur comme `Invalid setting for container. At least one of 'memory' or 'memoryReservation' must be specified`, assurez-vous que chaque définition de conteneur dans les tâches ECS spécifie au moins un paramètre de mémoire.

#### Erreur de description de groupe de sécurité invalide

Si vous voyez une erreur comme `Invalid security group description`, assurez-vous que les descriptions des groupes de sécurité ne contiennent que des caractères autorisés (pas d'accents ou de caractères spéciaux non supportés).

#### Erreur d'authentification AWS

Si vous voyez une erreur comme `No valid credential sources found` ou `failed to refresh cached credentials`, cela signifie que Terraform ne trouve pas d'identifiants AWS valides. Pour résoudre ce problème :

1. **Pour le développement local** : Configurez vos identifiants AWS en utilisant l'une des méthodes décrites dans le [README de l'infrastructure](./infrastructure/README.md).
2. **Pour GitHub Actions** : Assurez-vous que les secrets `AWS_ACCESS_KEY_ID` et `AWS_SECRET_ACCESS_KEY` sont correctement configurés dans les paramètres de votre dépôt GitHub.

### Nettoyage des ressources après un échec de déploiement

Si le déploiement Terraform échoue après avoir créé certaines ressources, et que la commande `terraform destroy` ne parvient pas à supprimer ces ressources, suivez ces étapes :

1. **Réinitialiser l'état Terraform** :
   ```bash
   terraform init
   ```

2. **Importer les ressources existantes dans l'état Terraform** :
   Identifiez les ressources créées dans la console AWS et importez-les dans l'état Terraform. Par exemple :
   ```bash
   terraform import module.s3.aws_s3_bucket.media_bucket nom-du-bucket
   ```

3. **Exécuter terraform destroy** :
   Une fois que toutes les ressources sont importées dans l'état, exécutez :
   ```bash
   terraform destroy
   ```

4. **Suppression manuelle en dernier recours** :
   Si terraform destroy échoue toujours, supprimez manuellement les ressources via la console AWS en respectant l'ordre de dépendance (d'abord les instances EC2, puis les groupes de sécurité, etc.).
