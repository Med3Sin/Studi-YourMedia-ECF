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
    *   [Configuration SSH](#configuration-ssh)
    *   [Configuration des Secrets](#configuration-des-secrets)
9.  [Résolution des problèmes courants](#résolution-des-problèmes-courants)

## Architecture Globale

L'architecture cible repose sur AWS et utilise les services suivants :

*   **Compute:**
    *   AWS EC2 (t2.micro) pour héberger l'API backend Java Spring Boot sur un serveur Tomcat.
    *   AWS EC2 (t2.micro) pour exécuter les conteneurs Docker de monitoring (Prometheus, Grafana) tout en restant dans les limites du Free Tier.
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
8.  **Une paire de clés SSH :** Une clé publique sera ajoutée à l'instance EC2 pour permettre la connexion SSH (utilisée par GitHub Actions pour le déploiement). La clé privée correspondante devra être ajoutée aux secrets GitHub. Voir la section [Configuration SSH](#configuration-ssh) pour plus de détails.

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

Pour déployer ou détruire l'infrastructure, utilisez le workflow GitHub Actions `1-infra-deploy-destroy.yml`. Ce workflow vous permet d'exécuter les commandes Terraform (`plan`, `apply`, `destroy`) de manière sécurisée et automatisée.

1. Accédez à l'onglet "Actions" de votre dépôt GitHub
2. Sélectionnez le workflow "1 - Deploy/Destroy Infrastructure (Terraform)"
3. Cliquez sur "Run workflow"
4. Sélectionnez l'action à exécuter (`plan`, `apply` ou `destroy`)
5. Entrez le nom de votre paire de clés SSH EC2
6. Cliquez sur "Run workflow"

**Note importante :** Lors de l'exécution de l'action `apply`, le workflow stocke automatiquement les outputs Terraform (adresse IP de l'EC2, nom du bucket S3, etc.) dans les secrets GitHub. Ces secrets seront utilisés par les workflows de déploiement des applications, ce qui vous évitera de saisir manuellement ces informations.

## Application Backend (Java Spring Boot)

*(Détails sur l'application Java)*

### Déploiement du Backend

Pour déployer l'application backend, utilisez le workflow GitHub Actions `2-backend-deploy.yml`. Ce workflow compile l'application Java, téléverse le fichier WAR sur S3, puis le déploie sur l'instance EC2 via SSH.

1. Assurez-vous que l'infrastructure est déjà déployée via le workflow `1-infra-deploy-destroy.yml`
2. Accédez à l'onglet "Actions" de votre dépôt GitHub
3. Sélectionnez le workflow "2 - Build and Deploy Backend (Java WAR)"
4. Cliquez sur "Run workflow"
5. Cliquez sur "Run workflow" sans paramètres supplémentaires (les informations d'infrastructure sont automatiquement récupérées depuis les secrets GitHub)

**Note :** Si les secrets GitHub ne sont pas disponibles (par exemple, si vous n'avez pas exécuté le workflow d'infrastructure ou si vous souhaitez déployer sur une infrastructure différente), vous pouvez toujours fournir manuellement l'adresse IP de l'EC2 et le nom du bucket S3 dans les champs prévus à cet effet.

Une fois le déploiement terminé, l'application sera accessible à l'URL : `http://<IP_PUBLIQUE_EC2>:8080/yourmedia-backend/`

## Application Frontend (React Native Web)

*(Détails sur l'application React Native pour le web)*

### Déploiement du Frontend

Le déploiement du frontend est géré automatiquement par AWS Amplify, qui est configuré pour surveiller les changements sur la branche `main` du dépôt GitHub. Le workflow GitHub Actions `3-frontend-deploy.yml` sert uniquement à vérifier que le code frontend peut être compilé correctement.

Pour vérifier la compilation du frontend :

1. Accédez à l'onglet "Actions" de votre dépôt GitHub
2. Sélectionnez le workflow "3 - Build Frontend (React Native Web CI)"
3. Cliquez sur "Run workflow"
4. Cliquez sur "Run workflow" sans paramètres supplémentaires

Pour accéder à l'application déployée sur Amplify :

1. Connectez-vous à la console AWS
2. Accédez au service Amplify
3. Sélectionnez l'application `yourmedia-frontend`
4. Cliquez sur l'URL fournie dans la section "Domain"

## Monitoring (Docker sur EC2 - Prometheus & Grafana)

Le système de monitoring est basé sur Prometheus et Grafana, exécutés dans des conteneurs Docker sur une instance EC2 dédiée. Cette approche permet de rester dans les limites du Free Tier AWS tout en offrant une solution de monitoring complète.

**Composants :**

* **Prometheus** : Collecte les métriques de l'application backend via l'endpoint `/actuator/prometheus` exposé par Spring Boot Actuator.
* **Grafana** : Visualise les métriques collectées par Prometheus via des tableaux de bord personnalisables.

Ces services sont déployés automatiquement lors de l'application de l'infrastructure via le workflow `1-infra-deploy-destroy.yml`.

### Accès à Grafana

Pour accéder à l'interface Grafana :

1. Récupérez l'adresse IP publique de l'instance EC2 de monitoring depuis les outputs Terraform
2. Accédez à `http://<IP_PUBLIQUE_EC2_MONITORING>:3000` dans votre navigateur
3. Connectez-vous avec les identifiants par défaut :
   - Utilisateur : `admin`
   - Mot de passe : `admin`
4. Lors de la première connexion, Grafana vous demandera de changer le mot de passe

Pour accéder à l'interface Prometheus :

1. Récupérez l'adresse IP publique de l'instance EC2 de monitoring depuis les outputs Terraform
2. Accédez à `http://<IP_PUBLIQUE_EC2_MONITORING>:9090` dans votre navigateur

## CI/CD (GitHub Actions)

Le projet utilise GitHub Actions pour automatiser les processus de déploiement et d'intégration continue. Les workflows sont conçus pour être cohérents, bien documentés et faciles à maintenir.

### Workflows Disponibles

*   **`1-infra-deploy-destroy.yml`:** Gère l'infrastructure complète via Terraform.
    - Déclenchement: Manuel (workflow_dispatch)
    - Actions: plan, apply, destroy
    - Fonctionnalités: Initialisation, validation, planification et application/destruction de l'infrastructure AWS
    - Résumé d'exécution: Fournit un récapitulatif détaillé des actions effectuées

*   **`2-backend-deploy.yml`:** Compile et déploie l'application Java sur l'instance EC2.
    - Déclenchement: Manuel (workflow_dispatch)
    - Processus: Compilation Maven, téléversement sur S3, déploiement sur Tomcat via SSH
    - Paramètres requis: IP publique de l'EC2, nom du bucket S3

*   **`3-frontend-deploy.yml`:** Vérifie la compilation de l'application React Native Web.
    - Déclenchement: Automatique (push sur main) ou manuel
    - Processus: Installation des dépendances, compilation du code
    - Note: Le déploiement réel est géré par AWS Amplify via la connexion directe au repo GitHub

### Configuration SSH

La configuration SSH est nécessaire pour permettre aux workflows GitHub Actions de se connecter aux instances EC2 pour le déploiement des applications. Voici comment configurer les clés SSH :

#### Génération d'une paire de clés SSH

**Sur Windows :**

1. Ouvrez Git Bash ou PowerShell
2. Exécutez la commande suivante pour générer une nouvelle paire de clés :
   ```bash
   ssh-keygen -t rsa -b 4096 -C "votre.email@exemple.com"
   ```
3. Appuyez sur Entrée pour accepter l'emplacement par défaut (`~/.ssh/id_rsa`)
4. Entrez une phrase de passe (ou laissez vide pour une clé sans phrase de passe)

**Sur macOS ou Linux :**

1. Ouvrez un terminal
2. Exécutez la commande suivante :
   ```bash
   ssh-keygen -t rsa -b 4096 -C "votre.email@exemple.com"
   ```
3. Appuyez sur Entrée pour accepter l'emplacement par défaut (`~/.ssh/id_rsa`)
4. Entrez une phrase de passe (ou laissez vide pour une clé sans phrase de passe)

#### Extraction de la clé publique à partir d'une clé privée existante

Si vous avez déjà une clé privée mais pas la clé publique correspondante :

**Sur Windows (Git Bash ou PowerShell avec OpenSSH) :**

```bash
ssh-keygen -y -f /chemin/vers/votre/cle_privee > /chemin/vers/votre/cle_privee.pub
```

**Sur macOS ou Linux :**

```bash
ssh-keygen -y -f /chemin/vers/votre/cle_privee > /chemin/vers/votre/cle_privee.pub
```

#### Configuration des clés SSH dans GitHub et AWS

1. **Ajout de la clé privée aux secrets GitHub :**
   - Accédez à votre dépôt GitHub > Settings > Secrets and variables > Actions
   - Cliquez sur "New repository secret"
   - Nom : `EC2_SSH_PRIVATE_KEY`
   - Valeur : (collez le contenu complet de votre clé privée, y compris les lignes `-----BEGIN RSA PRIVATE KEY-----` et `-----END RSA PRIVATE KEY-----`)
   - Cliquez sur "Add secret"

2. **Ajout de la clé publique aux secrets GitHub :**
   - Accédez à votre dépôt GitHub > Settings > Secrets and variables > Actions
   - Cliquez sur "New repository secret"
   - Nom : `EC2_SSH_PUBLIC_KEY`
   - Valeur : (collez le contenu de votre clé publique)
   - Cliquez sur "Add secret"

3. **Création d'une paire de clés dans AWS :**
   - Accédez à la console AWS > EC2 > Key Pairs
   - Cliquez sur "Create key pair"
   - Nom : (choisissez un nom, par exemple `yourmedia-keypair`)
   - Type : RSA
   - Format : .pem
   - Cliquez sur "Create key pair"
   - Téléchargez et conservez le fichier .pem en lieu sûr

4. **Ajout du nom de la paire de clés AWS aux secrets GitHub :**
   - Accédez à votre dépôt GitHub > Settings > Secrets and variables > Actions
   - Cliquez sur "New repository secret"
   - Nom : `EC2_KEY_PAIR_NAME`
   - Valeur : (entrez le nom de la paire de clés créée dans AWS, par exemple `yourmedia-keypair`)
   - Cliquez sur "Add secret"

### Configuration des Secrets

Pour que les workflows fonctionnent, vous devez configurer les secrets suivants dans votre repository GitHub (`Settings` > `Secrets and variables` > `Actions`) :

#### Secrets à configurer manuellement

*   `AWS_ACCESS_KEY_ID`: Votre Access Key ID AWS.
*   `AWS_SECRET_ACCESS_KEY`: Votre Secret Access Key AWS.
*   `DB_USERNAME`: Le nom d'utilisateur pour la base de données RDS (ex: `admin`).
*   `DB_PASSWORD`: Le mot de passe pour la base de données RDS (choisissez un mot de passe sécurisé).
*   `EC2_SSH_PRIVATE_KEY`: Le contenu de votre clé SSH privée (utilisée pour se connecter à l'EC2 lors des déploiements).
*   `EC2_SSH_PUBLIC_KEY`: Le contenu de votre clé SSH publique (utilisée pour configurer l'accès SSH aux instances EC2).
*   `EC2_KEY_PAIR_NAME`: Le nom de la paire de clés EC2 dans AWS (utilisé par Terraform pour configurer les instances EC2).
*   `GH_PAT`: Un Personal Access Token GitHub pour les intégrations comme Amplify. **Important**: Les noms de secrets ne doivent pas commencer par `GITHUB_` car ce préfixe est réservé aux variables d'environnement intégrées de GitHub Actions.

#### Secrets créés automatiquement par le workflow d'infrastructure

Les secrets suivants sont créés automatiquement lors de l'exécution du workflow d'infrastructure avec l'action `apply` :

*   `EC2_PUBLIC_IP`: L'adresse IP publique de l'instance EC2 hébergeant le backend Java.
*   `S3_BUCKET_NAME`: Le nom du bucket S3 pour le stockage des médias et des builds.
*   `MONITORING_EC2_PUBLIC_IP`: L'adresse IP publique de l'instance EC2 hébergeant Grafana et Prometheus.

Ces secrets sont utilisés par les workflows de déploiement des applications pour accéder aux ressources d'infrastructure sans avoir à saisir manuellement ces informations.

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
