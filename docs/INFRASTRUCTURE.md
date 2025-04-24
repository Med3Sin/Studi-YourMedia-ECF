# Infrastructure AWS - YourMédia

Ce document centralise toute la documentation relative à l'infrastructure AWS du projet YourMédia, gérée par Terraform.

## Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Architecture réseau](#architecture-réseau)
3. [Compute (EC2)](#compute-ec2)
   - [EC2 Java/Tomcat](#ec2-javatomcat)
   - [EC2 Monitoring](#ec2-monitoring)
4. [Base de données (RDS MySQL)](#base-de-données-rds-mysql)
5. [Stockage (S3)](#stockage-s3)
6. [Hébergement Frontend (Amplify)](#hébergement-frontend-amplify)
7. [Gestion des secrets](#gestion-des-secrets)
8. [Optimisations Free Tier](#optimisations-free-tier)
9. [Considérations sur les coûts](#considérations-sur-les-coûts)
10. [Plan d'amélioration](#plan-damélioration)

## Vue d'ensemble

L'infrastructure du projet YourMédia est entièrement gérée par Terraform et déployée via GitHub Actions. Elle est conçue pour rester dans les limites du Free Tier AWS tout en offrant une solution complète et robuste.

### Services AWS utilisés

* **Compute:** AWS EC2 (t2.micro) pour l'API backend Java et le monitoring
* **Base de données:** AWS RDS MySQL (db.t3.micro)
* **Stockage:** AWS S3 pour les médias et les artefacts de build
* **Réseau:** VPC avec sous-réseaux publics et privés
* **Hébergement Frontend:** AWS Amplify pour l'application React Native Web

### Structure des fichiers Terraform

```
infrastructure/
├── main.tf                  # Point d'entrée principal
├── variables.tf             # Variables Terraform
├── outputs.tf               # Sorties Terraform
├── providers.tf             # Configuration du provider AWS
└── modules/                 # Modules Terraform réutilisables
    ├── network/             # Gestion des Security Groups
    ├── ec2-java-tomcat/     # Instance EC2 + Java/Tomcat
    ├── rds-mysql/           # Base de données RDS MySQL
    ├── s3/                  # Bucket S3
    └── ec2-monitoring/      # Monitoring avec Docker sur EC2
```

## Architecture réseau

L'architecture réseau est basée sur un VPC avec des sous-réseaux publics et privés, configurés pour optimiser les performances tout en respectant les contraintes AWS.

### Configuration des sous-réseaux

* **Sous-réseaux publics dans eu-west-3a** : Les ressources principales (EC2 Java/Tomcat, EC2 Monitoring) sont placées dans la zone de disponibilité eu-west-3a.
* **Sous-réseaux privés dans eu-west-3a et eu-west-3b** : L'instance RDS est placée dans eu-west-3a, mais un sous-réseau supplémentaire est créé dans eu-west-3b pour satisfaire l'exigence d'AWS RDS qui nécessite des sous-réseaux dans au moins deux zones de disponibilité.

Cette configuration permet de maintenir toutes les ressources actives dans la même zone de disponibilité (eu-west-3a) pour minimiser les coûts de transfert de données, tout en respectant les contraintes techniques d'AWS.

### Groupes de sécurité

* **EC2 Java/Tomcat** :
  * Entrée : SSH (22), HTTP (8080) depuis Internet
  * Sortie : Tout le trafic

* **EC2 Monitoring** :
  * Entrée : SSH (22), Grafana (3000), Prometheus (9090) depuis Internet
  * Sortie : Tout le trafic

* **RDS MySQL** :
  * Entrée : MySQL (3306) depuis le groupe de sécurité EC2 Java/Tomcat
  * Sortie : Tout le trafic

## Compute (EC2)

### Provisionnement SSH des instances EC2

Le provisionnement SSH des instances EC2 est géré de manière flexible pour fonctionner dans différents environnements :

#### Provisionnement conditionnel

Le provisionnement SSH est conditionnel et peut être activé ou désactivé selon le contexte :

```hcl
resource "null_resource" "provision_instance" {
  # Ne créer cette ressource que si le provisionnement est activé
  count = var.enable_provisioning ? 1 : 0

  # ... reste du code ...
}
```

#### Options de clé SSH flexibles

Deux options sont disponibles pour fournir la clé SSH :

1. **Chemin du fichier** : Utilisation traditionnelle via `ssh_private_key_path`
2. **Contenu de la clé** : Fourniture directe du contenu de la clé via `ssh_private_key_content`

```hcl
connection {
  type        = "ssh"
  user        = "ec2-user"
  host        = aws_instance.instance.public_ip
  private_key = var.ssh_private_key_content != "" ? var.ssh_private_key_content : file(var.ssh_private_key_path)
}
```

#### Configuration dans GitHub Actions

Le workflow GitHub Actions est configuré pour utiliser automatiquement la clé SSH si elle est disponible dans les secrets GitHub :

1. **Configuration de la clé SSH** :
   - Le secret `EC2_SSH_PRIVATE_KEY` est utilisé pour créer un fichier de clé SSH sur le runner
   - Le provisionnement est activé automatiquement si la clé SSH est disponible (`enable_provisioning=${{ secrets.EC2_SSH_PRIVATE_KEY != '' }}`)

2. **Secrets GitHub requis** :
   - `EC2_KEY_PAIR_NAME` : Nom de la paire de clés SSH sur AWS (par exemple, "ma-cle-ssh")
   - `EC2_SSH_PRIVATE_KEY` : Contenu de la clé SSH privée

Si ces secrets ne sont pas configurés, le provisionnement est désactivé automatiquement, ce qui permet à Terraform de s'exécuter sans erreur même si aucune clé SSH n'est disponible.

### EC2 Java/Tomcat

Cette instance EC2 héberge l'application backend Java sur un serveur Tomcat.

#### Caractéristiques

* **Type d'instance** : t2.micro (Free Tier)
* **AMI** : Amazon Linux 2023 (détection automatique de la dernière version)
* **Stockage** : 8 Go gp2
* **Zone de disponibilité** : eu-west-3a
* **Accès SSH** : Via clé SSH configurée dans les secrets GitHub

#### Configuration

L'instance est configurée via un script `user_data` qui :
1. Met à jour le système avec `dnf update`
2. Installe Java 11 avec `dnf install java-11-amazon-corretto`
3. Installe et configure Tomcat
4. Configure les permissions pour le répertoire webapps
5. Installe l'AWS CLI pour interagir avec S3

#### Rôle IAM

L'instance dispose d'un rôle IAM avec les permissions suivantes :
* Accès en lecture/écriture au bucket S3 pour les médias et les artefacts de build
* Accès en lecture à CloudWatch pour les métriques

### EC2 Monitoring

Cette instance EC2 héberge Prometheus et Grafana dans des conteneurs Docker pour le monitoring de l'infrastructure et des applications.

#### Caractéristiques

* **Type d'instance** : t2.micro (Free Tier)
* **AMI** : Amazon Linux 2023 (détection automatique de la dernière version)
* **Stockage** : 8 Go gp2
* **Zone de disponibilité** : eu-west-3a
* **Accès SSH** : Via clé SSH configurée dans les secrets GitHub

#### Configuration

L'instance est configurée via une approche bootstrap optimisée pour rester sous la limite de 16 Ko du script `user_data` :

1. **Script minimal `user_data`** :
   * Met à jour le système et installe l'AWS CLI
   * Configure les clés SSH
   * Télécharge le script principal depuis S3
   * Remplace les variables dans le script principal (placeholders)
   * Exécute le script principal

2. **Script principal `setup.sh`** (stocké dans S3) :
   * Installe Docker et Docker Compose
   * Crée les répertoires pour les données Prometheus et Grafana
   * Télécharge les fichiers de configuration depuis le bucket S3
   * Remplace les variables dans les fichiers de configuration
   * Démarre les conteneurs Docker pour Prometheus et Grafana

3. **Gestion des variables entre modules** :
   * Utilisation de placeholders (ex: `PLACEHOLDER_IP`) dans les templates
   * Remplacement des placeholders par les valeurs réelles dans le script `user_data`
   * Utilisation de guillemets simples dans les commandes `sed` pour éviter l'interprétation des variables shell

#### Rôle IAM

L'instance dispose d'un rôle IAM avec les permissions suivantes :
* Accès en lecture à CloudWatch pour collecter les métriques
* Accès en lecture au bucket S3 pour récupérer les fichiers de configuration

## Base de données (RDS MySQL)

### Caractéristiques

* **Type d'instance** : db.t3.micro (Free Tier)
* **Version** : MySQL 8.0.35
* **Stockage** : 20 Go gp2
* **Zone de disponibilité** : eu-west-3a (même zone que les instances EC2)
* **Multi-AZ** : Désactivé (pour rester dans le Free Tier)

### Configuration

* **Groupe de sous-réseaux** : Sous-réseaux dans eu-west-3a et eu-west-3b (requis par RDS)
* **Groupe de sécurité** : Accès uniquement depuis l'instance EC2 Java/Tomcat
* **Backups** : Désactivés (pour rester dans le Free Tier)
* **Chiffrement** : Désactivé (pour rester dans le Free Tier)

### Notes importantes

1. **Exigence de deux zones de disponibilité** : AWS RDS exige que le groupe de sous-réseaux contienne des sous-réseaux dans au moins deux zones de disponibilité différentes, même si vous n'utilisez pas la fonctionnalité Multi-AZ.

2. **Placement dans eu-west-3a** : Bien que le groupe de sous-réseaux RDS inclue des sous-réseaux dans deux zones de disponibilité, l'instance RDS elle-même est explicitement placée dans eu-west-3a pour minimiser les coûts de transfert de données avec les instances EC2 qui sont également dans eu-west-3a.

## Stockage (S3)

### Caractéristiques

* **Versioning** : Activé
* **Chiffrement** : SSE-S3 (AES-256)
* **Accès public** : Bloqué
* **Règles de cycle de vie** : Configurées pour nettoyer automatiquement les anciens fichiers
  * **Dépendances explicites** : Configuration optimisée avec `depends_on` pour éviter les erreurs de déploiement
  * **Règle pour les builds** : Expiration après 30 jours, versions précédentes après 7 jours
  * **Règle pour les WAR** : Expiration après 60 jours, versions précédentes après 14 jours

### Utilisation

* **Stockage des médias** : Fichiers uploadés par les utilisateurs
* **Stockage des builds** : Artefacts de build temporaires (WAR, fichiers statiques)
* **Stockage des configurations** : Fichiers de configuration pour le monitoring

### Accès

* **EC2 Java/Tomcat** : Accès en lecture/écriture via rôle IAM
* **EC2 Monitoring** : Accès en lecture seule via rôle IAM

## Hébergement Frontend (Conteneur Docker)

### Caractéristiques

* **Image Docker** : Conteneur React Native pour mobile
* **Hébergement** : Instance EC2 de monitoring
* **Framework** : React Native

### Configuration

* **Environnement** : Variables d'environnement pour l'URL de l'API backend
* **Accès** : Via l'adresse IP publique de l'instance EC2 de monitoring sur le port 3000
* **Déploiement** : Via le workflow GitHub Actions `3-docker-build-deploy.yml`

## Gestion des secrets

### Secrets GitHub

Les secrets suivants doivent être configurés dans les paramètres du repository GitHub :

* `AWS_ACCESS_KEY_ID` et `AWS_SECRET_ACCESS_KEY` : Identifiants AWS
* `DB_USERNAME` et `DB_PASSWORD` : Identifiants pour la base de données RDS
* `EC2_SSH_PRIVATE_KEY` et `EC2_SSH_PUBLIC_KEY` : Clés SSH pour l'accès aux instances EC2
* `EC2_KEY_PAIR_NAME` : Nom de la paire de clés EC2 dans AWS
* `GH_PAT` : Personal Access Token GitHub pour les intégrations comme Amplify

### Secrets créés automatiquement

Les secrets suivants sont créés automatiquement par le workflow d'infrastructure :

* `EC2_PUBLIC_IP` : Adresse IP publique de l'instance EC2 Java/Tomcat
* `S3_BUCKET_NAME` : Nom du bucket S3
* `MONITORING_EC2_PUBLIC_IP` : Adresse IP publique de l'instance EC2 Monitoring

### Création d'un GH_PAT

1. Accédez à votre compte GitHub > Settings > Developer settings > Personal access tokens
2. Générez un nouveau token avec les permissions `repo` et `admin:repo_hook`
3. Copiez le token et ajoutez-le comme secret GitHub avec le nom `GH_PAT`

## Optimisations Free Tier

L'infrastructure est optimisée pour rester dans les limites du Free Tier AWS :

1. **Instances t2.micro/t3.micro** : Utilisation d'instances éligibles au Free Tier
2. **RDS Single-AZ** : Configuration mono-AZ pour RDS
3. **Placement des ressources** : Toutes les ressources qui communiquent fréquemment sont placées dans la même zone de disponibilité
4. **Conteneurs Docker sur EC2** : Alternative économique à ECS Fargate
5. **Règles de cycle de vie S3** : Nettoyage automatique des anciens fichiers

## Considérations sur les coûts

### Coûts de transfert de données

Les frais de transfert de données sont un aspect important de la facturation AWS :

* **Transfert sortant** : 100 GB gratuits par mois (Free Tier)
* **Transfert entrant** : Généralement gratuit
* **Transfert entre zones de disponibilité** : Facturé, d'où l'importance de placer les ressources dans la même zone
* **Transfert entre services AWS** : Peut être facturé selon les services

### Optimisations mises en place

1. **Placement des ressources** : EC2 et RDS dans la même zone de disponibilité
2. **Compression des données** : Les fichiers WAR sont compressés avant transfert
3. **Limitation des transferts entre régions** : Toute l'infrastructure dans une seule région
4. **Règles de cycle de vie S3** : Nettoyage automatique des anciens fichiers

## Plan d'amélioration

Pour une évolution future de l'infrastructure, les améliorations suivantes pourraient être envisagées :

1. **Auto Scaling Group** : Pour une meilleure disponibilité des instances EC2
2. **Application Load Balancer** : Pour la répartition de charge
3. **Multi-AZ pour RDS** : Pour une haute disponibilité de la base de données
4. **VPC Endpoints** : Pour un accès privé aux services AWS
5. **AWS WAF** : Pour la protection contre les attaques web
6. **AWS Certificate Manager** : Pour le HTTPS
7. **CloudFront** : Pour la distribution de contenu

Ces améliorations seraient à mettre en place progressivement, en fonction des besoins et du budget disponible.
