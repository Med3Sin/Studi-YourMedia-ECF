# Projet YourMédia - Migration Cloud AWS

Bienvenue dans la documentation du projet de migration vers le cloud AWS pour l'application YourMédia.
Ce document a pour but de vous guider à travers l'architecture mise en place, les choix technologiques, et les procédures de déploiement et de gestion de l'infrastructure et des applications.
Ce projet a été conçu pour être simple, utiliser les services gratuits (Free Tier) d'AWS autant que possible, et être entièrement automatisé via Terraform et GitHub Actions.

## Documentation Centralisée

Toute la documentation du projet est maintenant centralisée dans le dossier `docs/` :

### Documentation principale

- [Infrastructure AWS](docs/INFRASTRUCTURE.md) : Documentation complète de l'infrastructure AWS (VPC, EC2, RDS, S3, etc.)
- [Applications](docs/APPLICATIONS.md) : Documentation des applications backend (Java) et frontend (React)
- [Opérations](docs/OPERATIONS.md) : Documentation sur le déploiement, le monitoring et la maintenance

### Documentation spécifique

- [Architecture détaillée](docs/ARCHITECTURE.md) : Description détaillée de l'architecture technique
- [Guide des secrets Terraform](docs/TERRAFORM-SECRETS-GUIDE.md) : Guide d'utilisation des secrets GitHub avec Terraform Cloud
- [Guide des variables sensibles](docs/SENSITIVE-VARIABLES.md) : Guide de gestion des variables sensibles
- [Plan d'amélioration](docs/ARCHITECTURE-IMPROVEMENT-PLAN.md) : Plan d'amélioration de l'architecture
- [Guide de monitoring](docs/MONITORING-SETUP-GUIDE.md) : Guide de configuration du monitoring
- [Guide de résolution des problèmes](docs/TROUBLESHOOTING.md) : Solutions aux problèmes courants
- [Guide des conteneurs Docker](docs/DOCKER-MANAGEMENT.md) : Guide d'utilisation des conteneurs Docker
- [Guide de configuration SonarQube](docs/SONARQUBE-SETUP.md) : Guide de configuration de SonarQube
- [Guide de nettoyage](docs/CLEANUP-GUIDE.md) : Guide de nettoyage complet de l'infrastructure
- [Guide de gestion des clés SSH](docs/SSH-KEYS-MANAGEMENT.md) : Guide de gestion des clés SSH

## Table des Matières

1.  [Architecture Globale](#architecture-globale)
2.  [Prérequis](#prérequis)
3.  [Structure du Projet](#structure-du-projet)
4.  [Infrastructure (Terraform)](#infrastructure-terraform)
    * [Modules Terraform](#modules-terraform)
    * [Déploiement/Destruction de l'Infrastructure](#déploiementdestruction-de-linfrastructure)
5.  [Application Backend (Java Spring Boot)](#application-backend-java-spring-boot)
    * [Déploiement du Backend](#déploiement-du-backend)
6.  [Application Frontend (React Native Web)](#application-frontend-react-native-web)
    * [Déploiement du Frontend](#déploiement-du-frontend)
7.  [Monitoring (Docker sur EC2 - Prometheus & Grafana)](#monitoring-docker-sur-ec2---prometheus--grafana)
    * [Accès à Grafana](#accès-à-grafana)
8.  [CI/CD (GitHub Actions)](#cicd-github-actions)
    * [Workflows Disponibles](#workflows-disponibles)
    * [Configuration SSH](#configuration-ssh)
    * [Configuration des Secrets](#configuration-des-secrets)
9.  [Utilisation des Secrets GitHub avec Terraform](docs/TERRAFORM-SECRETS-GUIDE.md)
10. [Résolution des problèmes courants](docs/TROUBLESHOOTING.md)
11. [Configuration des sous-réseaux](#configuration-des-sous-réseaux)
12. [Considérations sur les coûts AWS](#considérations-sur-les-coûts-aws)
    * [Coûts de transfert de données AWS](#coûts-de-transfert-de-données-aws)
13. [Plan d'amélioration de l'architecture](docs/ARCHITECTURE-IMPROVEMENT-PLAN.md)
14. [Corrections et Améliorations Récentes](#corrections-et-améliorations-récentes)

## Architecture Globale

L'architecture cible repose sur AWS et utilise les services suivants :

* **Compute:**
    * AWS EC2 (t2.micro) pour héberger l'API backend Java Spring Boot sur un serveur Tomcat.
    * AWS EC2 (t2.micro) pour exécuter les conteneurs Docker de monitoring (Prometheus, Grafana, SonarQube) et l'application mobile React Native tout en restant dans les limites du Free Tier.
* **Base de données:** AWS RDS MySQL (db.t3.micro) en mode "Database as a Service".
* **Stockage:** AWS S3 pour le stockage des médias uploadés par les utilisateurs et pour le stockage temporaire des artefacts de build.
* **Réseau:** Utilisation d'un VPC dédié avec des groupes de sécurité spécifiques pour contrôler les flux.
* **Conteneurs Docker:** Utilisation de conteneurs Docker pour déployer l'application mobile React Native (remplaçant l'ancienne approche basée sur AWS Amplify) et les services de monitoring (Prometheus, Grafana, SonarQube).
* **IaC:** Terraform pour décrire et provisionner l'ensemble de l'infrastructure AWS de manière automatisée et reproductible.
* **CI/CD:** GitHub Actions pour automatiser les builds, les tests (basiques), l'analyse de qualité du code avec SonarQube, et les déploiements des applications, ainsi que la gestion de l'infrastructure Terraform.
* **Gestion des scripts:** Tous les scripts sont centralisés dans un dossier unique et organisés par module ou fonction pour faciliter la maintenance et éviter la duplication.

**Schéma d'Architecture :**

![Schéma d'Architecture YourMédia](YourMedia_AWS_Architecture.drawio.png)

**Note sur les diagrammes d'architecture :**

Les diagrammes d'architecture sont organisés en plusieurs couches pour faciliter la compréhension :

1. **Vue d'ensemble** - Vue globale de l'architecture AWS
2. **Couche réseau** - VPC, sous-réseaux, groupes de sécurité
3. **Couche calcul** - EC2, conteneurs Docker
4. **Couche stockage** - S3, RDS
5. **Couche CI/CD** - GitHub Actions, Terraform Cloud
6. **Couche monitoring** - Prometheus, Grafana, SonarQube
7. **Organisation des scripts** - Structure des scripts centralisés

Ces diagrammes sont disponibles localement dans le dossier `docs/diagrams/` mais ne sont pas inclus dans le dépôt Git (ignorés via .gitignore).

## Prérequis

Avant de commencer, assurez-vous d'avoir :

1.  **Un compte AWS :** Si vous n'en avez pas, créez-en un [ici](https://aws.amazon.com/).
2.  **GitHub Secrets configurés :** Les identifiants AWS sont stockés dans les secrets GitHub pour les workflows CI/CD. Voir la section [Configuration des Secrets](#configuration-des-secrets).
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
│       ├── 3-docker-build-deploy.yml
│       ├── 4-sonarqube-analysis.yml
│       └── 5-docker-cleanup.yml
├── app-java/                    # Code source Backend Spring Boot
│   ├── src/
│   ├── pom.xml
│   └── README.md
├── app-react/                   # Code source Frontend React Native
│   ├── src/
│   ├── package.json
│   └── README.md
├── docs/                        # Documentation centralisée
│   ├── APPLICATIONS.md          # Documentation des applications
│   ├── ARCHITECTURE-IMPROVEMENT-PLAN.md # Plan d'amélioration
│   ├── ARCHITECTURE.md          # Description détaillée de l'architecture technique
│   ├── CLEANUP-GUIDE.md         # Guide de nettoyage complet
│   ├── DOCKER-MANAGEMENT.md     # Guide d'utilisation des conteneurs Docker
│   ├── INFRASTRUCTURE.md        # Documentation de l'infrastructure
│   ├── MONITORING-SETUP-GUIDE.md # Guide de monitoring
│   ├── OPERATIONS.md            # Documentation des opérations
│   ├── SENSITIVE-VARIABLES.md   # Guide de gestion des variables sensibles
│   ├── SONARQUBE-SETUP.md       # Guide de configuration de SonarQube
│   ├── SSH-KEYS-MANAGEMENT.md   # Guide de gestion des clés SSH
│   ├── TERRAFORM-SECRETS-GUIDE.md # Guide des secrets GitHub avec Terraform Cloud
│   └── TROUBLESHOOTING.md       # Solutions aux problèmes courants
├── infrastructure/              # Code Terraform pour l'infrastructure AWS
│   ├── main.tf                  # Point d'entrée principal
│   ├── variables.tf             # Variables Terraform
│   ├── outputs.tf               # Sorties Terraform (IPs, Endpoints, etc.)
│   ├── providers.tf             # Configuration du provider AWS
│   └── modules/                 # Modules Terraform réutilisables
│       ├── network/             # Gestion des Security Groups
│       │   └── ... (main.tf, variables.tf, outputs.tf)
│       ├── ec2-java-tomcat/     # Instance EC2 + Java/Tomcat
│       │   ├── scripts/          # Scripts d'initialisation et de configuration
│       │   └── ... (main.tf, variables.tf, outputs.tf)
│       ├── rds-mysql/           # Base de données RDS MySQL
│       │   └── ... (main.tf, variables.tf, outputs.tf)
│       ├── s3/                  # Bucket S3
│       │   ├── files/            # Fichiers à stocker dans le bucket S3
│       │   └── ... (main.tf, variables.tf, outputs.tf)
│       ├── secrets-management/  # Gestion des secrets
│       │   └── ... (main.tf, variables.tf, outputs.tf)
│       └── ec2-monitoring/      # Monitoring avec Docker sur EC2
│           ├── scripts/          # Scripts pour Prometheus, Grafana, SonarQube et React Native
│           └── ... (main.tf, variables.tf, outputs.tf)
├── scripts/                     # Scripts utilitaires organisés par catégorie
│   ├── database/                # Scripts liés à la base de données
│   │   └── secure-database.sh   # Script de sécurisation de la base de données
│   ├── docker/                  # Scripts liés à Docker
│   │   ├── docker-manager.sh    # Script de gestion des conteneurs Docker (construction, publication, déploiement)
│   │   ├── cleanup-containers.sh # Script de nettoyage des conteneurs Docker
│   │   └── backup-restore-containers.sh # Script de sauvegarde et restauration des conteneurs Docker
│   ├── ec2-java-tomcat/         # Scripts liés à l'instance EC2 Java/Tomcat
│   │   └── install_java_tomcat.sh # Script d'installation de Java et Tomcat
│   ├── ec2-monitoring/          # Scripts liés à l'instance EC2 de monitoring
│   │   ├── setup.sh             # Script principal d'installation et de configuration
│   │   ├── fix_permissions.sh   # Script de correction des permissions des volumes
│   │   ├── generate_sonar_token.sh # Script de génération du token SonarQube
│   │   ├── init-instance.sh     # Script d'initialisation de l'instance
│   │   ├── docker-compose.yml   # Configuration des conteneurs Docker
│   │   ├── prometheus.yml       # Configuration de Prometheus
│   │   └── cloudwatch-config.yml # Configuration de CloudWatch Exporter
│   └── utils/                   # Scripts utilitaires génériques
│       ├── fix-ssh-keys.sh      # Script de correction des clés SSH
│       ├── ssh-key-checker.service # Service systemd pour vérifier les clés SSH
│       └── ssh-key-checker.timer # Timer systemd pour exécuter le service périodiquement
├── .gitignore                   # Fichier d'exclusion Git
├── YourMedia_AWS_Architecture.drawio.png # Schéma d'architecture AWS principal
│   └── docs/diagrams/                # Diagrammes d'architecture détaillés (non suivis par Git)
└── README.md                    # Ce fichier - Documentation principale
```

## Infrastructure (Terraform)

Cette section décrit la configuration Terraform utilisée pour provisionner l'infrastructure AWS du projet YourMédia.

### Modules Terraform

L'infrastructure est organisée en modules réutilisables pour faciliter la maintenance et l'évolution :

- **network** : Gère les groupes de sécurité et les règles de trafic réseau.
- **ec2-java-tomcat** : Provisionne l'instance EC2 pour le backend Java/Tomcat.
- **rds-mysql** : Crée et configure la base de données RDS MySQL.
- **s3** : Gère le bucket S3 pour le stockage des médias et des artefacts.
- **ec2-monitoring** : Déploie l'instance EC2 pour le monitoring et les conteneurs Docker (Prometheus, Grafana, SonarQube, React Native).
- **secrets-management** : Gère les secrets de l'application via Terraform Cloud.

### Déploiement/Destruction de l'Infrastructure

Pour déployer ou détruire l'infrastructure, utilisez le workflow GitHub Actions `1-infra-deploy-destroy.yml`. Ce workflow vous permet d'exécuter les commandes Terraform (`plan`, `apply`, `destroy`) de manière sécurisée et automatisée.

1.  Accédez à l'onglet "Actions" de votre dépôt GitHub
2.  Sélectionnez le workflow "1 - Deploy/Destroy Infrastructure (Terraform)"
3.  Cliquez sur "Run workflow"
4.  Sélectionnez l'action à exécuter (`plan`, `apply` ou `destroy`)
5.  Cliquez sur "Run workflow"

**Note importante :** Lors de l'exécution de l'action `apply`, le workflow stocke automatiquement les outputs Terraform (adresse IP de l'EC2, nom du bucket S3, etc.) dans les secrets GitHub. Ces secrets seront utilisés par les workflows de déploiement des applications, ce qui vous évitera de saisir manuellement ces informations.

## Application Backend (Java Spring Boot)

L'application backend est développée en Java avec le framework Spring Boot. Elle expose une API REST pour l'application frontend et utilise MySQL comme base de données.

### Déploiement du Backend

Pour déployer l'application backend, utilisez le workflow GitHub Actions `2-backend-deploy.yml`. Ce workflow compile l'application Java, téléverse le fichier WAR sur S3, puis le déploie sur l'instance EC2 via SSH.

1.  Assurez-vous que l'infrastructure est déjà déployée via le workflow `1-infra-deploy-destroy.yml`
2.  Accédez à l'onglet "Actions" de votre dépôt GitHub
3.  Sélectionnez le workflow "2 - Build and Deploy Backend (Java WAR)"
4.  Cliquez sur "Run workflow"
5.  Cliquez sur "Run workflow" sans paramètres supplémentaires (les informations d'infrastructure sont automatiquement récupérées depuis les secrets GitHub)

**Note :** Si les secrets GitHub ne sont pas disponibles (par exemple, si vous n'avez pas exécuté le workflow d'infrastructure ou si vous souhaitez déployer sur une infrastructure différente), vous pouvez toujours fournir manuellement l'adresse IP de l'EC2 et le nom du bucket S3 dans les champs prévus à cet effet.

Une fois le déploiement terminé, l'application sera accessible à l'URL : `http://<IP_PUBLIQUE_EC2>:8080/yourmedia-backend/`

## Application Mobile (React Native en conteneur Docker)

L'application mobile est développée avec React Native, permettant une expérience utilisateur fluide et réactive sur les appareils mobiles. Elle communique avec le backend via des appels API REST et est déployée dans un conteneur Docker.

### Construction et Déploiement de l'Application Mobile

La construction et le déploiement de l'application mobile sont gérés par le workflow GitHub Actions `3-docker-build-deploy.yml`. Ce workflow construit l'image Docker de l'application mobile et la déploie sur l'instance EC2.

Pour construire et déployer l'application mobile :

1.  Accédez à l'onglet "Actions" de votre dépôt GitHub
2.  Sélectionnez le workflow "3 - Docker Build and Deploy"
3.  Cliquez sur "Run workflow"
4.  Sélectionnez la cible "mobile" ou "all"
5.  Sélectionnez "true" pour déployer après la construction
6.  Cliquez sur "Run workflow"

Pour accéder à l'application mobile déployée :

1.  Utilisez l'URL `http://<IP_PUBLIQUE_EC2>:3000` dans votre navigateur
2.  L'application est optimisée pour les appareils mobiles mais peut être utilisée sur n'importe quel appareil

## Monitoring (Docker sur EC2 - Prometheus & Grafana)

Le système de monitoring est basé sur Prometheus et Grafana, exécutés dans des conteneurs Docker sur une instance EC2 dédiée. Cette approche permet de rester dans les limites du Free Tier AWS tout en offrant une solution de monitoring complète.

### Structure des fichiers de configuration

Les fichiers de configuration pour le monitoring sont maintenant centralisés dans le répertoire `scripts/ec2-monitoring/`. Ces fichiers sont :

-   `docker-compose.yml` : Configuration des conteneurs Docker pour Prometheus, Grafana, et les exportateurs
-   `prometheus.yml` : Configuration de Prometheus pour collecter les métriques
-   `cloudwatch-config.yml` : Configuration de CloudWatch Exporter pour collecter les métriques AWS
-   `setup.sh` : Script principal d'installation et de configuration
-   `fix_permissions.sh` : Script pour corriger les permissions des volumes
-   `generate_sonar_token.sh` : Script de génération du token SonarQube
-   `init-instance.sh` : Script d'initialisation de l'instance

Les scripts Docker sont centralisés dans le répertoire `scripts/docker/` :

-   `docker-manager.sh` : Script pour gérer les conteneurs Docker (construction, publication, déploiement)
-   `backup-restore-containers.sh` : Script pour sauvegarder et restaurer les conteneurs Docker
-   `cleanup-containers.sh` : Script pour nettoyer les conteneurs Docker

Les Dockerfiles et fichiers de configuration pour les conteneurs sont organisés dans les sous-répertoires de `scripts/docker/` :

-   `prometheus/` : Dockerfile et configuration pour Prometheus
-   `grafana/` : Dockerfile et configuration pour Grafana
-   `sonarqube/` : Dockerfile et configuration pour SonarQube

Les scripts utilitaires génériques sont dans le répertoire `scripts/utils/` :

-   `fix-ssh-keys.sh` : Script pour corriger les clés SSH
-   `ssh-key-checker.service` : Service systemd pour vérifier les clés SSH
-   `ssh-key-checker.timer` : Timer systemd pour exécuter le service périodiquement

Ces fichiers sont utilisés de deux façons :

1.  **Générés directement dans l'instance EC2** : Les fichiers sont générés directement dans l'instance EC2 lors de son initialisation via le script `user_data`. Les variables comme l'adresse IP de l'instance EC2 Java/Tomcat sont substituées automatiquement.
2.  **Disponibles dans le bucket S3** : Les mêmes fichiers sont également téléversés dans le bucket S3 pour permettre une récupération manuelle si nécessaire. Le module S3 référence les fichiers depuis le dossier scripts centralisé pour éviter la duplication.

**Composants :**

* **Prometheus** : Collecte les métriques de l'application backend via l'endpoint `/actuator/prometheus` exposé par Spring Boot Actuator.
* **Grafana** : Visualise les métriques collectées par Prometheus via des tableaux de bord personnalisables.

Ces services sont déployés automatiquement lors de l'application de l'infrastructure via le workflow `1-infra-deploy-destroy.yml`.

### Accès à Grafana

Pour accéder à l'interface Grafana :

1.  Récupérez l'adresse IP publique de l'instance EC2 de monitoring depuis les outputs Terraform
2.  Accédez à `http://<IP_PUBLIQUE_EC2_MONITORING>:3001` dans votre navigateur
3.  Connectez-vous avec les identifiants par défaut :
    * Utilisateur : `admin`
    * Mot de passe : celui défini dans le secret GitHub `GF_SECURITY_ADMIN_PASSWORD`
4.  Si c'est votre première connexion, Grafana vous demandera de changer le mot de passe

Pour accéder à l'interface Prometheus :

1.  Récupérez l'adresse IP publique de l'instance EC2 de monitoring depuis les outputs Terraform
2.  Accédez à `http://<IP_PUBLIQUE_EC2_MONITORING>:9090` dans votre navigateur

## CI/CD (GitHub Actions)

Le projet utilise GitHub Actions pour automatiser les processus de déploiement et d'intégration continue. Les workflows sont conçus pour être cohérents, bien documentés et faciles à maintenir.

### Workflows Disponibles

-   **`1-infra-deploy-destroy.yml`:** Gère l'infrastructure complète via Terraform.
    -   Déclenchement: Manuel (`workflow_dispatch`)
    -   Actions: `plan`, `apply`, `destroy`
    -   Fonctionnalités: Initialisation, validation, planification et application/destruction de l'infrastructure AWS
    -   Résumé d'exécution: Fournit un récapitulatif détaillé des actions effectuées
-   **`2-backend-deploy.yml`:** Compile et déploie l'application Java sur l'instance EC2.
    -   Déclenchement: Manuel (`workflow_dispatch`)
    -   Processus: Compilation Maven, téléversement sur S3, déploiement sur Tomcat via SSH
    -   Paramètres requis: IP publique de l'EC2, nom du bucket S3 (récupérés automatiquement des secrets)
-   **`3-docker-build-deploy.yml`:** Construit et déploie les conteneurs Docker.
    -   Déclenchement: Manuel (`workflow_dispatch`)
    -   Actions: `mobile`, `monitoring`, `all`
    -   Processus: Construction des images Docker, publication sur Docker Hub, déploiement sur les instances EC2
    -   Paramètres requis: Identifiants Docker Hub, clés SSH (récupérés des secrets GitHub)
-   **`4-sonarqube-analysis.yml`:** Analyse la qualité du code avec SonarQube.
    -   Déclenchement: Automatique (`push` sur `main`) ou manuel
    -   Actions: `backend`, `mobile`, `all`
    -   Processus: Analyse du code source, publication des résultats sur SonarQube
    -   Paramètres requis: Token SonarQube, URL SonarQube (récupérés des secrets GitHub)
-   **`5-docker-cleanup.yml`:** Nettoie les images Docker Hub obsolètes ou inutilisées.
    -   Déclenchement: Manuel (`workflow_dispatch`)
    -   Paramètres: Dépôt Docker Hub, motif de tag, mode simulation
    -   Processus: Suppression des images Docker Hub selon le motif spécifié
    -   Paramètres requis: Identifiants Docker Hub (récupérés des secrets GitHub)


### Configuration SSH

La configuration SSH est nécessaire pour permettre aux workflows GitHub Actions de se connecter aux instances EC2 pour le déploiement des applications. Voici comment configurer les clés SSH :

#### Génération d'une paire de clés SSH

**Sur Windows :**

1.  Ouvrez Git Bash ou PowerShell
2.  Exécutez la commande suivante pour générer une nouvelle paire de clés :
    ```bash
    ssh-keygen -t rsa -b 4096 -C "votre.email@exemple.com"
    ```
3.  Appuyez sur Entrée pour accepter l'emplacement par défaut (`~/.ssh/id_rsa`)
4.  Entrez une phrase de passe (ou laissez vide pour une clé sans phrase de passe)

**Sur macOS ou Linux :**

1.  Ouvrez un terminal
2.  Exécutez la commande suivante :
    ```bash
    ssh-keygen -t rsa -b 4096 -C "votre.email@exemple.com"
    ```
3.  Appuyez sur Entrée pour accepter l'emplacement par défaut (`~/.ssh/id_rsa`)
4.  Entrez une phrase de passe (ou laissez vide pour une clé sans phrase de passe)

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

* `AWS_ACCESS_KEY_ID`: Votre Access Key ID AWS.
* `AWS_SECRET_ACCESS_KEY`: Votre Secret Access Key AWS.
* `DB_USERNAME`: Le nom d'utilisateur pour la base de données RDS (ex: `admin`).
* `DB_PASSWORD`: Le mot de passe pour la base de données RDS (choisissez un mot de passe sécurisé).
* `EC2_SSH_PRIVATE_KEY`: Le contenu de votre clé SSH privée (utilisée pour se connecter à l'EC2 lors des déploiements).
* `EC2_SSH_PUBLIC_KEY`: Le contenu de votre clé SSH publique (utilisée pour configurer l'accès SSH aux instances EC2).
* `EC2_KEY_PAIR_NAME`: Le nom de la paire de clés EC2 dans AWS (utilisé par Terraform pour configurer les instances EC2).
* `DOCKERHUB_USERNAME`: Votre nom d'utilisateur Docker Hub.
* `DOCKERHUB_TOKEN`: Votre token d'accès Docker Hub.
* `SONAR_TOKEN`: Token d'accès pour SonarQube.
* `GH_PAT`: Un Personal Access Token GitHub pour les intégrations.

**Important**: Les noms de secrets ne doivent pas commencer par `GITHUB_` car ce préfixe est réservé aux variables d'environnement intégrées de GitHub Actions.

#### Secrets créés automatiquement par le workflow d'infrastructure

Les secrets suivants sont créés automatiquement lors de l'exécution du workflow d'infrastructure avec l'action `apply` :

* `EC2_PUBLIC_IP`: L'adresse IP publique de l'instance EC2 hébergeant le backend Java.
* `S3_BUCKET_NAME`: Le nom du bucket S3 pour le stockage des médias et des builds.
* `MONITORING_EC2_PUBLIC_IP`: L'adresse IP publique de l'instance EC2 hébergeant Grafana et Prometheus.

Ces secrets sont utilisés par les workflows de déploiement des applications pour accéder aux ressources d'infrastructure sans avoir à saisir manuellement ces informations.

Pour plus de détails sur la configuration et l'utilisation des secrets GitHub avec Terraform, consultez le [Guide d'utilisation des secrets GitHub avec Terraform](docs/TERRAFORM-SECRETS-GUIDE.md).

#### Instructions détaillées pour créer un GH_PAT

1. **Accédez à votre compte GitHub :**
   - Connectez-vous à votre compte GitHub
   - Cliquez sur votre photo de profil en haut à droite
   - Sélectionnez "Settings" (Paramètres)

2. **Accédez aux paramètres développeur :**
   - Dans le menu de gauche, faites défiler vers le bas et cliquez sur "Developer settings" (Paramètres développeur)

3. **Créez un nouveau token :**
   - Cliquez sur "Personal access tokens" (Tokens d'accès personnels)
   - Sélectionnez "Tokens (classic)"
   - Cliquez sur "Generate new token" (Générer un nouveau token)
   - Sélectionnez "Generate new token (classic)"

4. **Configurez le token :**
   - Donnez un nom descriptif à votre token (par exemple "YourMedia Terraform")
   - Définissez une date d'expiration (recommandé : 90 jours)
   - Sélectionnez les autorisations nécessaires :
     - `repo` (accès complet au dépôt)
     - `admin:repo_hook` (pour les webhooks)
   - Faites défiler vers le bas et cliquez sur "Generate token" (Générer le token)

5. **Copiez le token :**
   - **IMPORTANT** : Copiez immédiatement le token généré. Vous ne pourrez plus le voir après avoir quitté cette page.

6. **Configurez le secret dans GitHub Actions :**
   - Allez sur votre dépôt GitHub
   - Cliquez sur "Settings" (Paramètres)
   - Dans le menu de gauche, cliquez sur "Secrets and variables" puis "Actions"
   - Cliquez sur "New repository secret"
   - Nom : `GH_PAT`
   - Valeur : collez le token que vous avez copié
   - Cliquez sur "Add secret"

## Résolution des problèmes courants

### Erreurs liées aux variables Terraform

Si vous rencontrez des erreurs du type "Error: No value for required variable" lors de l'exécution de Terraform, cela signifie qu'une variable requise n'a pas été fournie. Consultez le [Guide d'utilisation des secrets GitHub avec Terraform](docs/TERRAFORM-SECRETS-GUIDE.md) pour plus d'informations sur la configuration des variables sensibles.

### Erreurs de déploiement du backend

Si le déploiement du backend échoue avec des erreurs SSH, vérifiez que :

1. La clé SSH privée est correctement configurée dans les secrets GitHub (`EC2_SSH_PRIVATE_KEY`)
2. L'instance EC2 est en cours d'exécution et accessible
3. Le groupe de sécurité de l'instance EC2 autorise les connexions SSH (port 22)

### Erreurs de compilation du frontend

Si la compilation du frontend échoue, vérifiez que :

1. Les dépendances sont correctement installées (`npm install`)
2. Le code source ne contient pas d'erreurs de syntaxe
3. Les variables d'environnement nécessaires sont correctement configurées

### Erreurs de connexion à Grafana ou Prometheus

Si vous ne pouvez pas accéder à Grafana ou Prometheus, vérifiez que :

1. L'instance EC2 de monitoring est en cours d'exécution
2. Les conteneurs Docker sont en cours d'exécution (`docker ps`)
3. Les ports 3000 (Grafana) et 9090 (Prometheus) sont ouverts dans le groupe de sécurité

Pour plus d'informations sur la résolution des problèmes, consultez la [documentation AWS](https://docs.aws.amazon.com/fr_fr/) ou ouvrez une issue dans ce dépôt GitHub.

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

### Erreurs lors de la destruction de l'infrastructure

Si vous rencontrez des erreurs lors de la destruction de l'infrastructure, notamment concernant le bucket S3, vérifiez que :

1. Le bucket S3 est vide avant la destruction (le workflow inclut maintenant une étape pour vider automatiquement le bucket)
2. Les profils IAM sont correctement nettoyés (le workflow inclut une étape pour nettoyer les profils IAM persistants)
3. Toutes les ressources dépendantes ont été correctement supprimées

## Configuration des sous-réseaux

L'architecture utilise une configuration spécifique de sous-réseaux pour optimiser les performances tout en respectant les contraintes AWS :

- **Sous-réseaux principaux dans eu-west-3a** : Les ressources principales (EC2, monitoring) sont placées dans la même zone de disponibilité (eu-west-3a) pour minimiser les coûts de transfert de données entre zones.

- **Sous-réseau RDS secondaire dans eu-west-3b** : Un sous-réseau supplémentaire est créé dans une seconde zone de disponibilité uniquement pour satisfaire l'exigence d'AWS RDS qui nécessite des sous-réseaux dans au moins deux zones de disponibilité différentes, même pour une instance mono-AZ.

Cette configuration permet de maintenir toutes les ressources actives dans la même zone de disponibilité tout en respectant les contraintes techniques d'AWS.

## Considérations sur les coûts AWS

### Coûts de transfert de données AWS

Les frais de transfert de données sont un aspect important de la facturation AWS à prendre en compte :

#### Principaux types de transferts de données facturés

- **Transfert sortant (Outbound)** : Données sortant d'AWS vers Internet
  - C'est généralement le transfert le plus coûteux
  - Les tarifs varient selon les régions et le volume

- **Transfert entrant (Inbound)** : Données entrantes dans AWS depuis Internet
  - Généralement gratuit dans la plupart des services

- **Transfert entre régions AWS** : Données transférées entre différentes régions AWS
  - Facturé dans les deux régions (source et destination)

- **Transfert entre zones de disponibilité** : Données transférées entre AZ d'une même région
  - Moins coûteux que le transfert entre régions, mais toujours facturé

- **Transfert entre services AWS** : Dans certains cas, le transfert entre services AWS peut être facturé

#### Points à considérer pour le Free Tier

Dans le cadre du Free Tier AWS :

- 100 Go de transfert de données sortant est généralement gratuit par mois
- Le transfert entrant est généralement gratuit
- Le transfert entre instances EC2 dans la même zone de disponibilité via adresse IP privée est gratuit

#### Optimisations dans notre architecture

Pour optimiser les coûts de transfert de données dans notre projet YourMedia :

1. **Placement des ressources** : Toutes les ressources qui communiquent fréquemment (EC2, RDS) sont placées dans la même zone de disponibilité
2. **Utilisation de S3** : Le bucket S3 est utilisé principalement pour le stockage des fichiers de configuration et des artefacts de build
3. **Règles de cycle de vie S3** : Configuration de règles pour nettoyer automatiquement les anciens fichiers
4. **Limitation des transferts entre régions** : Toute l'infrastructure est déployée dans une seule région AWS
5. **Compression des données** : Les fichiers WAR sont compressés avant d'être transférés vers S3

## Plan d'amélioration de l'architecture

Un plan détaillé d'amélioration de l'architecture a été élaboré pour optimiser l'infrastructure tout en restant dans les limites du Free Tier AWS. Ce plan couvre plusieurs aspects :

- **Optimisation de l'infrastructure AWS** : Amélioration de la résilience avec Auto Scaling, ALB, optimisation du stockage S3 et de RDS
- **Sécurisation de l'architecture** : Renforcement de la sécurité réseau, mise en place de WAF, Secrets Manager et Certificate Manager
- **Amélioration des applications** : Optimisation du backend Java et du frontend React
- **Amélioration du monitoring** : Extension de Prometheus/Grafana et implémentation de la traçabilité
- **Optimisation des coûts** : Mise en place d'une gouvernance des coûts et optimisation de l'infrastructure as code
- **Amélioration du CI/CD** : Optimisation des workflows GitHub Actions et amélioration de la gestion des environnements

Pour plus de détails, consultez le [Plan d'amélioration de l'architecture](docs/ARCHITECTURE-IMPROVEMENT-PLAN.md).

## Corrections et Améliorations Récentes

### Correction de la vulnérabilité MySQL Connector/J

Le connecteur MySQL a été mis à jour pour corriger une vulnérabilité de sécurité critique :

- Mise à jour de `mysql-connector-java:8.0.33` vers `mysql-connector-j:8.0.34`
- Correction de la vulnérabilité CVE-2023-22095 qui permettait potentiellement la prise de contrôle des connecteurs MySQL
- Maintien de la compatibilité avec l'infrastructure existante

### Amélioration de la gestion du bucket S3

La gestion du bucket S3 a été améliorée pour faciliter les opérations de destruction de l'infrastructure :

- Ajout de l'option `force_destroy = true` pour permettre la suppression du bucket même s'il contient des objets
- Implémentation d'une étape de vidage automatique du bucket avant la destruction dans le workflow GitHub Actions
- Configuration de règles de cycle de vie pour nettoyer automatiquement les anciens fichiers (builds, WAR)

### Monitoring complet de l'infrastructure AWS

Le système de monitoring a été considérablement amélioré pour surveiller l'ensemble de l'infrastructure :

- Ajout de CloudWatch Exporter pour surveiller les services AWS (S3, RDS, Amplify, EC2)
- Ajout de MySQL Exporter pour surveiller spécifiquement la base de données RDS
- Configuration automatique de Prometheus pour collecter les métriques de tous les composants
- Optimisation des ressources des conteneurs pour rester dans les limites du Free Tier AWS

### Configuration SSH automatisée avec les secrets GitHub

La configuration SSH a été entièrement automatisée :

- Utilisation directe des secrets GitHub `EC2_SSH_PUBLIC_KEY` et `EC2_SSH_PRIVATE_KEY` pour configurer l'accès SSH
- Installation automatique des clés SSH via les scripts d'initialisation des instances EC2
- Mise à jour des workflows GitHub Actions pour passer les clés SSH à Terraform
- Utilisation de l'utilisateur `ec2-user` pour toutes les instances Amazon Linux 2 (harmonisation)

### Harmonisation des instances EC2

Les instances EC2 ont été harmonisées pour utiliser la même AMI Amazon Linux 2 (amzn2-ami-kernel-5.10-hvm-2.0) pour les raisons suivantes :

- Cohérence entre les environnements de production et de monitoring
- Meilleure compatibilité avec les outils de monitoring
- Simplification de la maintenance et des mises à jour

### Mise à jour du type d'instance RDS

Le type d'instance RDS a été mis à jour de `db.t2.micro` à `db.t3.micro` pour les raisons suivantes :

- Meilleure compatibilité avec MySQL 8.0.28
- Performances améliorées tout en restant dans les limites du Free Tier AWS
- Stabilité accrue pour les opérations de base de données

### Mise à jour de la version MySQL

La version de MySQL a été mise à jour de 8.0.35 à 8.0.28 pour assurer une compatibilité optimale avec le type d'instance `db.t3.micro`.

### Nettoyage des fichiers temporaires

Les fichiers temporaires suivants ont été supprimés pour maintenir la propreté du code source :

- Fichiers `main.tf.new2` et `main.tf.new3` dans le module RDS MySQL

Ces modifications améliorent la stabilité, la performance et la sécurité de l'infrastructure tout en maintenant la compatibilité avec le Free Tier AWS.