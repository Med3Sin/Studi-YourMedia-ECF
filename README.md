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
7.  [Monitoring (ECS Fargate - Prometheus & Grafana)](#monitoring-ecs-fargate---prometheus--grafana)
    *   [Accès à Grafana](#accès-à-grafana)
8.  [CI/CD (GitHub Actions)](#cicd-github-actions)
    *   [Workflows Disponibles](#workflows-disponibles)
    *   [Configuration des Secrets](#configuration-des-secrets)

## Architecture Globale

L'architecture cible repose sur AWS et utilise les services suivants :

*   **Compute:**
    *   AWS EC2 (t2.micro) pour héberger l'API backend Java Spring Boot sur un serveur Tomcat.
    *   AWS ECS Fargate pour exécuter les conteneurs de monitoring (Prometheus, Grafana) sans gestion de serveur.
*   **Base de données:** AWS RDS MySQL (db.t2.micro) en mode "Database as a Service".
*   **Stockage:** AWS S3 pour le stockage des médias uploadés par les utilisateurs et pour le stockage temporaire des artefacts de build.
*   **Réseau:** Utilisation du VPC par défaut pour la simplicité, avec des groupes de sécurité spécifiques pour contrôler les flux.
*   **Hébergement Frontend:** AWS Amplify Hosting pour déployer la version web de l'application React Native de manière simple et scalable.
*   **IaC:** Terraform pour décrire et provisionner l'ensemble de l'infrastructure AWS de manière automatisée et reproductible.
*   **CI/CD:** GitHub Actions pour automatiser les builds, les tests (basiques) et les déploiements des applications backend et frontend, ainsi que la gestion de l'infrastructure Terraform.

**Schéma d'Architecture :**

```mermaid
graph TD
    subgraph "GitHub Actions (CI/CD)"
        direction LR
        GHA1[1. Infra Deploy/Destroy\n(Terraform: EC2, RDS, S3, ECS, Amplify)]
        GHA3[3. Backend Deploy\n(Build -> S3 -> EC2)]
        GHA4[4. Frontend Deploy\n(Build -> S3 -> Amplify)]
    end

    subgraph "AWS Cloud (Free Tier)"
        direction LR
        subgraph "Default VPC"
            direction TB
            subgraph "Public Subnet(s)"
                EC2[VM ec2-java-tomcat\n(t2.micro)\n- Java\n- Tomcat]

                subgraph "ECS Fargate (ecs-monitoring)"
                    PrometheusTask[Prometheus Task (Fargate)]
                    GrafanaTask[Grafana Task (Fargate)]
                end
            end
            subgraph "Private Subnet(s)"
                RDS[DBaaS rds-mysql\n(db.t2.micro)]
            end
            S3[Stockage s3\n(Médias, Builds)]
            Amplify[Amplify Hosting\n(Frontend Web)]

        end
    end

    UserMobile[Utilisateur Mobile] --> AppRN[App React Native\n(sur appareil)]
    AppRN --> API[API Spring Boot\n(app-java @ EC2:8080)]

    UserWeb[Utilisateur Web] -- HTTPS --> Amplify

    API -- JDBC --> RDS
    API -- AWS SDK --> S3

    GHA1 -- Terraform --> EC2
    GHA1 -- Terraform --> RDS
    GHA1 -- Terraform --> S3
    GHA1 -- Terraform --> ECS Fargate
    GHA1 -- Terraform --> Amplify

    PrometheusTask -- Scrape --> API[:8080/actuator/prometheus]
    Admin[Admin/Dev] -- HTTPS --> GrafanaTask[:3000]

    GHA3 -- Build --> WarS3(app.war @ S3)
    WarS3 -- SSH Copy --> EC2

    GHA4 -- Build --> StaticFilesS3(Static Files @ S3)
    StaticFilesS3 -- Deploy Trigger --> Amplify


    %% Style
    classDef default fill:#f9f,stroke:#333,stroke-width:2px;
    classDef cloud fill:#D3E5FF,stroke:#007bff;
    classDef cicd fill:#E5D3FF,stroke:#6f42c1;
    classDef app fill:#D4EDDA,stroke:#28a745;
    classDef db fill:#F8D7DA,stroke:#dc3545;
    classDef storage fill:#FFF3CD,stroke:#ffc107;
    classDef monitoring fill:#CCE5FF,stroke:#007bff;
    classDef compute fill:#E2E3E5,stroke:#6c757d;
    classDef hosting fill:#F0E68C,stroke:#BDB76B;


    class UserMobile,UserWeb,Admin default;
    class AppRN,API app;
    class EC2 compute;
    class RDS db;
    class S3,WarS3,StaticFilesS3 storage;
    class Amplify hosting;
    class Default VPC,Public Subnet(s),Private Subnet(s) cloud;
    class GHA1,GHA3,GHA4 cicd;
    class ECS Fargate,PrometheusTask,GrafanaTask monitoring;

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
│       └── ecs-monitoring/      # Monitoring ECS Fargate
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

## Monitoring (ECS Fargate - Prometheus & Grafana)

*(Détails sur la configuration du monitoring)*

### Accès à Grafana

*(Comment accéder à l'interface Grafana une fois déployée)*

## CI/CD (GitHub Actions)

*(Explication du fonctionnement des workflows)*

### Workflows Disponibles

*   **`1-infra-deploy-destroy.yml`:** Gère l'infrastructure complète via Terraform.
*   **`3-backend-deploy.yml`:** Build et déploie l'application Java.
*   **`4-frontend-deploy.yml`:** Build et déploie l'application React Native Web sur Amplify.

### Configuration des Secrets

Pour que les workflows fonctionnent, vous devez configurer les secrets suivants dans votre repository GitHub (`Settings` > `Secrets and variables` > `Actions`) :

*   `AWS_ACCESS_KEY_ID`: Votre Access Key ID AWS.
*   `AWS_SECRET_ACCESS_KEY`: Votre Secret Access Key AWS.
*   `DB_USERNAME`: Le nom d'utilisateur pour la base de données RDS (ex: `admin`).
*   `DB_PASSWORD`: Le mot de passe pour la base de données RDS (choisissez un mot de passe sécurisé).
*   `EC2_SSH_PRIVATE_KEY`: Le contenu de votre clé SSH privée (utilisée pour se connecter à l'EC2 lors des déploiements). Assurez-vous que la clé publique correspondante est fournie à Terraform (via une variable).

---
*Documentation générée par Cline, Ingénieur Logiciel.*
