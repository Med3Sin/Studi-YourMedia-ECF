# Corrections et Améliorations des Applications

Ce document recense les corrections et améliorations apportées aux différentes applications et composants du projet YourMédia. Il sert de référence pour comprendre les modifications effectuées et les problèmes résolus.

## Versions des outils utilisés

- Node.js: v18.20.8
- npm: 10.8.2
- yarn: 1.22.22

## Table des matières

1. [Workflows GitHub Actions](#workflows-github-actions)
   - [Correction de la numérotation des workflows](#correction-de-la-numérotation-des-workflows)
   - [Mise à jour des références aux workflows dans la documentation](#mise-à-jour-des-références-aux-workflows-dans-la-documentation)
   - [Correction des paramètres d'entrée du workflow d'infrastructure](#correction-des-paramètres-dentrée-du-workflow-dinfrastructure)
   - [Mise à jour des instructions détaillées pour chaque workflow](#mise-à-jour-des-instructions-détaillées-pour-chaque-workflow)
   - [Automatisation du stockage des outputs Terraform dans les secrets GitHub](#automatisation-du-stockage-des-outputs-terraform-dans-les-secrets-github)
   - [Correction du problème de cache des dépendances dans le workflow frontend](#correction-du-problème-de-cache-des-dépendances-dans-le-workflow-frontend)

2. [Backend (Java)](#backend-java)
   - [Configuration de l'utilisateur SSH pour le déploiement](#configuration-de-lutilisateur-ssh-pour-le-déploiement)

3. [Frontend (React Native Web)](#frontend-react-native-web)
   - [Correction du problème de dépendances](#correction-du-problème-de-dépendances)

4. [Infrastructure](#infrastructure)
   - [Correction des erreurs de déploiement Terraform](#correction-des-erreurs-de-déploiement-terraform)
   - [Correction des erreurs de validation Terraform](#correction-des-erreurs-de-validation-terraform)
   - [Correction du fichier main.tf du module RDS MySQL corrompu et utilisation du secret DB_NAME](#correction-du-fichier-maintf-du-module-rds-mysql-corrompu-et-utilisation-du-secret-db_name)
   - [Correction du script d'installation Docker pour le monitoring](#correction-du-script-dinstallation-docker-pour-le-monitoring)
   - [Correction de la configuration du cycle de vie du bucket S3](#correction-de-la-configuration-du-cycle-de-vie-du-bucket-s3)
   - [Configuration de Grafana/Prometheus dans des conteneurs Docker sur EC2](#configuration-de-grafanaprometheus-dans-des-conteneurs-docker-sur-ec2)
   - [Correction de l'erreur de référence à ECS dans le module de monitoring](#correction-de-lerreur-de-référence-à-ecs-dans-le-module-de-monitoring)
   - [Suppression du fichier docker-compose.yml.tpl redondant](#suppression-du-fichier-docker-composeyml-tpl-redondant)
   - [Correction des variables manquantes dans le module de monitoring](#correction-des-variables-manquantes-dans-le-module-de-monitoring)
   - [Création d'un VPC et de sous-réseaux dédiés](#création-dun-vpc-et-de-sous-réseaux-dédiés)

5. [Documentation](#documentation)
   - [Mise à jour de la documentation du module de monitoring](#mise-à-jour-de-la-documentation-du-module-de-monitoring)
   - [Ajout de la documentation sur la configuration SSH](#ajout-de-la-documentation-sur-la-configuration-ssh)
   - [Mise à jour des références à ECS dans la documentation](#mise-à-jour-des-références-à-ecs-dans-la-documentation)

## Workflows GitHub Actions

### Correction de la numérotation des workflows

#### Problème identifié
Les workflows GitHub Actions avaient une numérotation incohérente, avec des fichiers nommés `0-infra-deploy-destroy.yml`, `3-backend-deploy.yml` et `3-frontend-deploy.yml`.

#### Solution mise en œuvre
Renommage des fichiers de workflow pour avoir une numérotation cohérente et logique :
1. `0-infra-deploy-destroy.yml` → `1-infra-deploy-destroy.yml`
2. `3-backend-deploy.yml` → `2-backend-deploy.yml`
3. `3-frontend-deploy.yml` → `3-frontend-deploy.yml`

#### Avantages de cette solution
- **Cohérence** : Numérotation logique et séquentielle des workflows
- **Clarté** : Meilleure compréhension de l'ordre d'exécution recommandé
- **Maintenabilité** : Facilite l'ajout de nouveaux workflows à l'avenir

### Mise à jour des références aux workflows dans la documentation

#### Problème identifié
Les références aux workflows dans la documentation (README.md et autres fichiers) ne correspondaient pas aux nouveaux noms des fichiers de workflow.

#### Solution mise en œuvre
Mise à jour de toutes les références aux workflows dans la documentation pour refléter la nouvelle numérotation :
- Remplacement de `0-infra-deploy-destroy.yml` par `1-infra-deploy-destroy.yml`
- Remplacement de `3-backend-deploy.yml` par `2-backend-deploy.yml`
- Remplacement de `3-frontend-deploy.yml` par `3-frontend-deploy.yml`

#### Avantages de cette solution
- **Cohérence** : Documentation alignée avec le code réel
- **Clarté** : Instructions précises pour les utilisateurs
- **Évite la confusion** : Prévient les erreurs lors de l'utilisation des workflows

### Correction des paramètres d'entrée du workflow d'infrastructure

#### Problème identifié
Le workflow d'infrastructure (`1-infra-deploy-destroy.yml`) avait des paramètres d'entrée redondants et incohérents. Certains paramètres étaient demandés à l'utilisateur alors qu'ils pouvaient être récupérés automatiquement.

#### Solution mise en œuvre
1. Suppression des paramètres d'entrée redondants (`repo_owner` et `repo_name`)
2. Utilisation des variables contextuelles GitHub (`github.repository_owner` et `github.repository`)
3. Simplification des variables d'environnement AWS en utilisant l'action `aws-actions/configure-aws-credentials`

#### Avantages de cette solution
- **Simplicité** : Moins de paramètres à saisir pour l'utilisateur
- **Fiabilité** : Utilisation des valeurs correctes garantie par GitHub
- **Sécurité** : Meilleure gestion des identifiants AWS

### Mise à jour des instructions détaillées pour chaque workflow

#### Problème identifié
La documentation ne contenait pas d'instructions détaillées et à jour pour l'utilisation des workflows GitHub Actions. Les sections correspondantes étaient marquées comme "*(Instructions pour utiliser le workflow `X-workflow.yml`)*" sans contenu réel.

#### Solution mise en œuvre
1. Ajout d'instructions détaillées pour le workflow d'infrastructure (`1-infra-deploy-destroy.yml`)
   - Étapes précises pour déployer ou détruire l'infrastructure
   - Explication des paramètres d'entrée
   - Ordre logique des étapes à suivre

2. Ajout d'instructions détaillées pour le workflow de déploiement backend (`2-backend-deploy.yml`)
   - Prérequis pour le déploiement
   - Étapes précises pour déployer l'application Java
   - Informations sur l'accès à l'application déployée

3. Ajout d'instructions détaillées pour le workflow de déploiement frontend (`3-frontend-deploy.yml`)
   - Explication du rôle du workflow (vérification CI uniquement)
   - Clarification sur le déploiement automatique via AWS Amplify
   - Instructions pour accéder à l'application déployée

#### Avantages de cette solution
- **Clarté** : Instructions précises et détaillées pour chaque workflow
- **Facilité d'utilisation** : Réduction des erreurs lors de l'utilisation des workflows
- **Autonomie** : Permet aux utilisateurs de déployer l'application sans assistance

### Automatisation du stockage des outputs Terraform dans les secrets GitHub

#### Problème identifié
Les workflows de déploiement des applications nécessitaient la saisie manuelle des informations d'infrastructure (adresse IP de l'EC2, nom du bucket S3, etc.) à chaque exécution. Ces informations étaient disponibles dans les outputs Terraform, mais n'étaient pas automatiquement accessibles aux autres workflows.

#### Solution mise en œuvre
1. **Modification du workflow d'infrastructure** (`1-infra-deploy-destroy.yml`) :
   - Ajout d'une étape pour récupérer les outputs Terraform après l'application de l'infrastructure
   - Stockage de ces outputs dans des variables d'environnement GitHub Actions
   - Création de secrets GitHub à partir de ces variables d'environnement

2. **Modification du workflow de déploiement backend** (`2-backend-deploy.yml`) :
   - Rendus optionnels les paramètres d'entrée (adresse IP de l'EC2, nom du bucket S3)
   - Ajout d'une étape pour récupérer les informations depuis les secrets GitHub si disponibles
   - Utilisation d'une logique de fallback : utiliser les secrets s'ils existent, sinon utiliser les paramètres d'entrée

3. **Mise à jour de la documentation** :
   - Ajout d'informations sur les secrets créés automatiquement
   - Mise à jour des instructions de déploiement pour refléter cette automatisation

#### Avantages de cette solution
- **Automatisation** : Réduction des étapes manuelles pour le déploiement des applications
- **Fiabilité** : Élimination des erreurs de saisie lors du déploiement
- **Cohérence** : Utilisation des mêmes valeurs dans tous les workflows
- **Flexibilité** : Possibilité de fournir manuellement les paramètres si nécessaire

### Correction du problème de cache des dépendances dans le workflow frontend

#### Problème identifié
Le workflow GitHub Actions pour le frontend échouait avec l'erreur suivante :
```
Error: Dependencies lock file is not found in /home/runner/work/Studi-YourMedia-ECF/Studi-YourMedia-ECF. Supported file patterns: package-lock.json,npm-shrinkwrap.json,yarn.lock
```

Cette erreur se produisait car l'action setup-node tentait d'utiliser le cache des dépendances, mais ne trouvait pas de fichier de verrouillage à la racine du projet.

#### Solution mise en œuvre
Désactivation de la fonctionnalité de cache dans l'action setup-node en commentant la ligne `cache: ${{ env.PACKAGE_MANAGER }}` dans le workflow.

#### Avantages de cette solution
- **Fiabilité** : Évite les erreurs liées au cache des dépendances
- **Simplicité** : Solution simple qui ne nécessite pas de modifier la structure du projet
- **Compatibilité** : Fonctionne avec la configuration actuelle du projet

## Backend (Java)

### Configuration de l'utilisateur SSH pour le déploiement

#### Problème identifié
Le workflow de déploiement du backend (`2-backend-deploy.yml`) utilisait l'utilisateur `ubuntu` pour se connecter à l'instance EC2, alors que l'AMI Amazon Linux 2 utilise l'utilisateur `ec2-user`.

#### Solution mise en œuvre
Modification du workflow pour utiliser l'utilisateur `ec2-user` au lieu de `ubuntu` dans la commande SSH :
```yaml
ssh ec2-user@${{ github.event.inputs.ec2_public_ip }} << EOF
```

#### Avantages de cette solution
- **Compatibilité** : Fonctionne correctement avec l'AMI Amazon Linux 2
- **Fiabilité** : Évite les erreurs de connexion SSH
- **Cohérence** : Alignement avec la configuration de l'instance EC2

## Frontend (React Native Web)

### Correction du problème de dépendances

#### Problème identifié
Lors de l'exécution du workflow GitHub Actions pour le frontend, l'erreur suivante était rencontrée :
```
Error: Dependencies lock file is not found in /home/runner/work/Studi-YourMedia-ECF/Studi-YourMedia-ECF. Supported file patterns: package-lock.json,npm-shrinkwrap.json,yarn.lock
```

Cette erreur indique que le fichier de verrouillage des dépendances (package-lock.json ou yarn.lock) n'a pas été trouvé dans le répertoire du projet.

#### Solution mise en œuvre
1. **Génération du fichier package-lock.json** en exécutant `npm install` dans le répertoire app-react
2. **Commit du fichier package-lock.json** dans le dépôt Git
3. **Désactivation du cache** dans le workflow GitHub Actions pour éviter les erreurs liées au chemin du fichier de verrouillage

#### Avantages de cette solution
- **Fiabilité** : Garantit que les mêmes versions de dépendances sont utilisées dans tous les environnements
- **Reproductibilité** : Assure que les builds sont reproductibles
- **Stabilité** : Évite les problèmes liés aux mises à jour automatiques de dépendances

### Ajout de la dépendance manquante pour la compilation web

#### Problème identifié
Lors de la compilation de l'application React pour le web, l'erreur suivante était rencontrée :
```
CommandError: It looks like you're trying to use web support but don't have the required dependencies installed.
Please install @expo/metro-runtime@~4.0.1 by running:
npx expo install @expo/metro-runtime
```

Cette erreur indique qu'il manque la dépendance `@expo/metro-runtime` qui est nécessaire pour la compilation web de l'application Expo.

#### Solution mise en œuvre
1. **Installation de la dépendance manquante** en exécutant `npm install @expo/metro-runtime@~4.0.1` dans le répertoire app-react
2. **Création du fichier App.js** pour fournir un composant React de base
3. **Création du fichier app.json** pour configurer correctement Expo pour le web
4. **Mise à jour du fichier package.json** pour inclure un script d'installation spécifique pour Amplify
5. **Mise à jour du build_spec d'Amplify** dans le fichier Terraform pour utiliser le script d'installation spécifique

#### Avantages de cette solution
- **Compatibilité** : Permet la compilation de l'application pour le web
- **Conformité** : Utilise la version recommandée de la dépendance
- **Complétude** : Fournit tous les fichiers nécessaires pour une application Expo fonctionnelle
- **Intégration Amplify** : Assure que le déploiement sur AWS Amplify fonctionne correctement

## Infrastructure

### Correction des erreurs de déploiement Terraform

#### Problème identifié
Lors de l'exécution de `terraform apply`, plusieurs erreurs ont été rencontrées :

1. **Incompatibilité entre MySQL 8.0 et l'instance db.t2.micro** :
```
Error: creating RDS DB Instance: InvalidParameterCombination: RDS does not support creating a DB instance with the following combination: DBInstanceClass=db.t2.micro, Engine=mysql, EngineVersion=8.0.40, LicenseModel=general-public-license.
```

2. **Profils IAM déjà existants** :
```
Error: creating IAM Instance Profile: EntityAlreadyExists: Instance Profile ***-dev-ec2-profile already exists.
```

#### Solution mise en œuvre
1. **Correction de l'incompatibilité RDS** :
   - Spécification explicite de la version MySQL 8.0.35
   - Mise à jour du type d'instance de `db.t2.micro` à `db.t3.micro` (compatible avec MySQL 8.0)

2. **Gestion des profils IAM existants** :
   - Ajout de blocs `lifecycle { create_before_destroy = true }` aux ressources `aws_iam_instance_profile` pour éviter les conflits

#### Avantages de cette solution
- **Compatibilité** : Utilisation d'une combinaison compatible entre la version MySQL et le type d'instance
- **Robustesse** : Meilleure gestion des ressources existantes pour éviter les conflits
- **Conformité AWS** : Utilisation de types d'instances recommandés (db.t2.micro est en fin de support depuis juin 2024)
- **Déploiement réussi** : L'infrastructure peut maintenant être déployée sans erreurs

#### Amélioration supplémentaire 1 : Nettoyage automatique des profils IAM persistants

Pour résoudre définitivement le problème des profils IAM qui persistent après la destruction de l'infrastructure, nous avons ajouté une étape de nettoyage automatique dans le workflow GitHub Actions :

1. **Modification du workflow `1-infra-deploy-destroy.yml`** :
   - Ajout d'une étape de nettoyage qui s'exécute après `terraform destroy`
   - Utilisation de l'AWS CLI pour détacher les rôles des profils et supprimer les profils IAM persistants

2. **Documentation détaillée** :
   - Création d'un document `infrastructure/docs/IAM-PROFILES-MANAGEMENT.md` expliquant la solution

Cette amélioration permet de garantir que les profils IAM sont correctement supprimés, même si `terraform destroy` échoue à les supprimer, évitant ainsi les erreurs lors des déploiements ultérieurs.

#### Amélioration supplémentaire 2 : Gestion du provisionnement SSH dans les environnements CI/CD

Pour résoudre le problème de la fonction `file()` qui échoue à lire la clé SSH privée dans les environnements CI/CD, nous avons mis en place un mécanisme de provisionnement conditionnel :

1. **Provisionnement conditionnel** :
   - Ajout d'une variable `enable_provisioning` (désactivée par défaut) pour contrôler le provisionnement SSH
   - Utilisation de `count = var.enable_provisioning ? 1 : 0` pour créer conditionnellement la ressource de provisionnement

2. **Options de clé SSH flexibles** :
   - Ajout d'une variable `ssh_private_key_content` pour fournir directement le contenu de la clé SSH
   - Utilisation de `private_key = var.ssh_private_key_content != "" ? var.ssh_private_key_content : file(var.ssh_private_key_path)`

3. **Instructions de configuration manuelle** :
   - Ajout d'un output avec des instructions détaillées pour configurer manuellement l'instance si le provisionnement automatique est désactivé

4. **Documentation détaillée** :
   - Création d'un document `infrastructure/docs/SSH-PROVISIONING.md` expliquant la solution

Cette amélioration permet de déployer l'infrastructure même sans accès SSH, tout en fournissant des instructions claires pour la configuration manuelle après le déploiement.

### Correction des erreurs de validation Terraform

#### Problème identifié
Lors de l'exécution de `terraform validate`, plusieurs erreurs ont été identifiées :

1. Dans le module `ec2-monitoring`, des variables non déclarées étaient référencées :
```
Error: Reference to undeclared input variable
  on modules/ec2-monitoring/main.tf line 52, in resource "aws_instance" "monitoring_instance":
  52:   ami                    = var.ecs_ami_id
```

2. Dans le module `rds-mysql`, les outputs faisaient référence à une ressource inexistante :
```
Error: Reference to undeclared resource
  on modules/rds-mysql/outputs.tf line 7, in output "db_instance_endpoint":
   7:   value       = aws_db_instance.mysql_db.endpoint
```

#### Solution mise en œuvre
1. **Correction des références de variables dans le module `ec2-monitoring`** :
   - Remplacement de `var.ecs_ami_id` par `var.monitoring_ami_id`
   - Remplacement de `var.ecs_security_group_id` par `var.monitoring_security_group_id`

2. **Correction des références dans les outputs du module `rds-mysql`** :
   - Remplacement de `aws_db_instance.mysql_db` par `aws_db_instance.mysql` dans tous les outputs

#### Avantages de cette solution
- **Cohérence** : Les références correspondent maintenant aux variables et ressources déclarées
- **Validation réussie** : La configuration Terraform passe maintenant la validation
- **Prévention des erreurs** : Évite les erreurs lors de l'exécution de `terraform apply`

### Correction du fichier main.tf du module RDS MySQL corrompu et utilisation du secret DB_NAME

#### Problème identifié
Le fichier `infrastructure/modules/rds-mysql/main.tf` était corrompu avec des caractères non valides, ce qui empêchait Terraform de le traiter correctement. Lors de l'exécution de `terraform fmt -check -recursive`, de nombreuses erreurs étaient signalées :
```
Error: Invalid character encoding
All input files must be UTF-8 encoded. Ensure that UTF-8 encoding is selected in your editor.
```

Même après une première tentative de correction, le problème persistait, indiquant que le fichier était toujours corrompu avec des caractères non valides.

De plus, le nom de la base de données était codé en dur dans le fichier, ce qui ne permettait pas de le configurer via un secret GitHub.

#### Solution mise en œuvre
1. **Suppression complète du fichier corrompu**
2. **Création d'un nouveau fichier** avec un encodage UTF-8 correct
3. **Reconstruction complète du contenu** du module RDS MySQL
4. **Vérification du formatage** avec `terraform fmt -check -recursive` pour confirmer la correction
5. **Ajout d'une variable `db_name`** dans le module RDS MySQL pour permettre la configuration du nom de la base de données
6. **Modification du fichier principal** pour passer la variable `db_name` au module
7. **Mise à jour des workflows GitHub Actions** pour utiliser le secret `DB_NAME`

#### Avantages de cette solution
- **Encodage correct** : Le fichier est maintenant correctement encodé en UTF-8
- **Conformité** : Le fichier respecte les conventions de formatage Terraform
- **Lisibilité** : Le code est maintenant lisible et maintenable
- **Compatibilité Free Tier** : Configuration optimisée pour rester dans les limites du Free Tier AWS
- **Flexibilité** : Le nom de la base de données peut maintenant être configuré via un secret GitHub
- **Sécurité** : Le nom de la base de données n'est plus codé en dur dans le code

### Correction du script d'installation Docker pour le monitoring

#### Problème identifié
Le fichier `install_docker.sh` dans le module `ec2-monitoring` était corrompu et ne contenait que des caractères spéciaux et des espaces, ce qui empêchait son exécution correcte. De plus, le script d'initialisation était défini directement dans le fichier Terraform au lieu d'utiliser des scripts externes, ce qui rendait la maintenance difficile.

#### Solution mise en œuvre
1. **Création d'un nouveau script `install_docker.sh`** avec le contenu approprié pour installer Docker et Docker Compose sur Amazon Linux 2
2. **Création d'un script `deploy_containers.sh`** pour déployer les conteneurs Prometheus et Grafana
3. **Création d'un fichier `prometheus.yml`** pour configurer Prometheus
4. **Modification du fichier `main.tf`** pour utiliser ces scripts externes au lieu d'un script inline
5. **Simplification du script d'initialisation** dans le `user_data` de l'instance EC2

#### Avantages de cette solution
- **Modularité** : Séparation des préoccupations en scripts distincts pour une meilleure maintenabilité
- **Fiabilité** : Scripts correctement formatés et testés
- **Flexibilité** : Possibilité de modifier les scripts sans avoir à modifier le code Terraform
- **Lisibilité** : Code Terraform plus propre et plus facile à comprendre

### Correction de la configuration du cycle de vie du bucket S3

#### Problème identifié
Lors de l'application de l'infrastructure avec Terraform, l'erreur suivante était rencontrée :
```
Error: "filter" or "prefix" is required in rule[0] of lifecycle_rule
```

Cette erreur indique que la configuration du cycle de vie du bucket S3 nécessite soit un filtre, soit un préfixe pour chaque règle.

#### Solution mise en œuvre
Nous avons mis à jour la configuration du cycle de vie du bucket S3 pour inclure un filtre vide, ce qui applique la règle à tous les objets du bucket :

```hcl
lifecycle_rule {
  id      = "expire-all-objects"
  enabled = true

  filter {} # Filtre vide = s'applique à tous les objets

  expiration {
    days = 1
  }
}
```

Cette modification satisfait l'exigence du provider AWS Terraform tout en maintenant le comportement d'origine (application de la règle à tous les objets).

#### Avantages de cette solution
- **Conformité** : Satisfait les exigences du provider AWS Terraform
- **Compatibilité future** : Assure la compatibilité avec les futures versions du provider
- **Maintien du comportement** : Conserve le comportement d'origine (application de la règle à tous les objets)

### Configuration de Grafana/Prometheus dans des conteneurs Docker sur EC2

#### Problème identifié
La configuration initiale utilisait ECS Fargate pour déployer Grafana et Prometheus, ce qui n'était pas optimal pour rester dans les limites du Free Tier AWS. De plus, les services Grafana et Prometheus n'étaient pas accessibles aux URLs attendues.

#### Solution mise en œuvre
Nous avons modifié l'infrastructure pour déployer Grafana et Prometheus dans des conteneurs Docker sur une instance EC2 dédiée au monitoring :

1. **Création d'un script d'initialisation** pour l'instance EC2 qui installe Docker et configure les conteneurs Grafana et Prometheus
2. **Modification du module ecs-monitoring** pour utiliser une instance EC2 au lieu de ECS Fargate
3. **Exposition des ports** 3000 (Grafana) et 9090 (Prometheus) sur l'instance EC2
4. **Mise à jour des outputs Terraform** pour exposer les URLs de Grafana et Prometheus

#### Avantages de cette solution
- **Économie de coûts** : Utilisation d'une seule instance EC2 au lieu de services ECS Fargate, ce qui est plus économique et reste dans les limites du Free Tier AWS
- **Simplicité** : Configuration plus simple et plus directe avec Docker
- **Flexibilité** : Possibilité de personnaliser facilement la configuration des conteneurs
- **Performances** : Meilleure performance pour les services de monitoring

### Correction de l'erreur de référence à ECS dans le module de monitoring

#### Problème identifié
Après la migration de ECS Fargate vers Docker sur EC2 pour le monitoring, une erreur était rencontrée lors de l'application de l'infrastructure :

```
Error: Reference to undeclared resource
  on modules/ecs-monitoring/ec2-capacity.tf line 60, in resource "aws_instance" "ecs_instance":
  60:     echo ECS_CLUSTER=${aws_ecs_cluster.monitoring_cluster.name} >> /etc/ecs/ecs.config
A managed resource "aws_ecs_cluster" "monitoring_cluster" has not been
declared in module.ecs-monitoring.
```

Cette erreur indique qu'il y avait encore des références à des ressources ECS qui n'existaient plus dans le module de monitoring.

#### Solution mise en œuvre
Nous avons nettoyé le module de monitoring en supprimant les fichiers et références obsolètes :

1. **Suppression du fichier `ec2-capacity.tf`** qui contenait des références à ECS
2. **Suppression des fichiers de définition de tâches ECS** qui n'étaient plus nécessaires
3. **Mise à jour du README du module** pour refléter la nouvelle architecture Docker

#### Avantages de cette solution
- **Cohérence** : Élimination des références obsolètes pour éviter les erreurs
- **Clarté** : Documentation mise à jour pour refléter l'architecture actuelle
- **Simplicité** : Réduction du nombre de fichiers et de ressources pour une meilleure maintenabilité

### Suppression du fichier docker-compose.yml.tpl redondant

#### Problème identifié
Le module de monitoring contenait deux fichiers docker-compose quasiment identiques : `docker-compose.yml` et `docker-compose.yml.tpl`. Cette redondance créait de la confusion et des erreurs lors du déploiement.

#### Solution mise en œuvre
1. **Analyse des fichiers** pour confirmer qu'ils étaient identiques en contenu
2. **Vérification du code Terraform** pour identifier quel fichier était réellement utilisé
3. **Suppression du fichier redondant** `docker-compose.yml.tpl`
4. **Mise à jour des références** dans le code Terraform pour utiliser uniquement `docker-compose.yml`

#### Avantages de cette solution
- **Réduction de la complexité** : Moins de fichiers à maintenir
- **Élimination de la confusion** : Un seul fichier docker-compose à modifier
- **Cohérence** : Assure que les modifications futures seront appliquées au bon fichier

### Correction des variables manquantes dans le module de monitoring

#### Problème identifié
Après la migration de ECS vers Docker sur EC2, le module `ecs-monitoring` nécessitait de nouvelles variables qui n'étaient pas fournies dans l'appel du module, ce qui provoquait l'erreur suivante lors de la validation Terraform :

```
Error: Missing required argument
  on main.tf line 78, in module "ecs-monitoring":
  78: module "ecs-monitoring" {
The argument "key_pair_name" is required, but no definition was found.
```

#### Solution mise en œuvre
1. **Ajout des variables manquantes** dans l'appel au module `ecs-monitoring` dans le fichier `main.tf` :
   - `key_pair_name` : Nom de la paire de clés SSH pour l'instance EC2 de monitoring
   - `ssh_private_key_path` : Chemin vers la clé privée SSH pour se connecter à l'instance EC2

2. **Ajout d'une nouvelle variable** dans le fichier `variables.tf` principal :
   - `ssh_private_key_path` : Chemin vers la clé privée SSH

3. **Mise à jour du workflow GitHub Actions** pour fournir la valeur de `ssh_private_key_path` lors de l'exécution de Terraform

4. **Mise à jour des outputs** dans le fichier `outputs.tf` pour refléter la nouvelle architecture Docker sur EC2 :
   - Remplacement de `ecs_cluster_name` par `monitoring_ec2_public_ip`, `grafana_url` et `prometheus_url`

5. **Correction du script d'initialisation** pour éviter les problèmes d'encodage UTF-8 en utilisant un template Terraform local au lieu d'un fichier externe

#### Avantages de cette solution
- **Cohérence** : Toutes les variables nécessaires sont maintenant fournies
- **Fiabilité** : Évite les erreurs lors de l'exécution de Terraform
- **Simplicité** : Utilisation d'un template local pour le script d'initialisation, évitant les problèmes d'encodage
- **Clarté** : Outputs plus descriptifs et cohérents avec l'architecture actuelle

### Création d'un VPC et de sous-réseaux dédiés

#### Problème identifié
Lors de l'exécution de `terraform plan`, des erreurs apparaissaient concernant l'impossibilité de trouver les sous-réseaux spécifiés :

```
Error: no matching EC2 Subnet found

  with data.aws_subnet.default_az1,
  on main.tf line 11, in data "aws_subnet" "default_az1":
  11: data "aws_subnet" "default_az1" {


Error: no matching EC2 Subnet found

  with data.aws_subnet.default_az2,
  on main.tf line 17, in data "aws_subnet" "default_az2":
  17: data "aws_subnet" "default_az2" {
```

Ces erreurs étaient dues au fait que la configuration tentait de trouver des sous-réseaux spécifiques dans le VPC par défaut, mais ces sous-réseaux n'existaient pas ou ne correspondaient pas aux critères spécifiés.

#### Solution mise en œuvre
1. **Création d'un VPC dédié au projet** :
   - Création d'un nouveau VPC avec un bloc CIDR `10.0.0.0/16`
   - Activation du support DNS et des noms d'hôtes DNS

2. **Création de sous-réseaux dans une seule zone de disponibilité** :
   - Création de deux sous-réseaux dans la même zone de disponibilité (`eu-west-3a`)
   - Configuration des sous-réseaux pour attribuer automatiquement des adresses IP publiques

3. **Configuration de l'accès Internet** :
   - Création d'une Internet Gateway
   - Création d'une table de routage avec une route par défaut vers Internet
   - Association de la table de routage aux deux sous-réseaux

4. **Mise à jour des références dans les modules** :
   - Modification de toutes les références au VPC par défaut pour utiliser le nouveau VPC
   - Modification de toutes les références aux sous-réseaux par défaut pour utiliser les nouveaux sous-réseaux

#### Avantages de cette solution
- **Contrôle total** : Contrôle complet sur la configuration du VPC et des sous-réseaux
- **Isolation** : Isolation des ressources du projet dans un VPC dédié
- **Optimisation des coûts** : Utilisation d'une seule zone de disponibilité pour rester dans les limites du Free Tier AWS
- **Simplicité** : Configuration claire et explicite sans dépendance aux ressources par défaut d'AWS
- **Reproductibilité** : Infrastructure entièrement définie dans le code, facilitant la reproduction dans différents environnements

## Documentation

### Mise à jour de la documentation du module de monitoring

#### Problème identifié
La documentation du module de monitoring (`infrastructure/modules/ecs-monitoring/README.md`) faisait référence à l'ancienne architecture basée sur ECS Fargate, ce qui ne correspondait plus à la nouvelle implémentation basée sur Docker sur EC2.

#### Solution mise en œuvre
Mise à jour complète du README du module de monitoring pour refléter la nouvelle architecture :
1. **Mise à jour de la description** du module
2. **Mise à jour de la liste des ressources créées**
3. **Mise à jour des fichiers de configuration**
4. **Mise à jour des variables d'entrée**
5. **Mise à jour des sorties**
6. **Mise à jour des instructions d'accès** à Grafana et Prometheus
7. **Ajout d'une section sur les optimisations Free Tier**

#### Avantages de cette solution
- **Clarté** : Documentation précise et à jour
- **Facilité d'utilisation** : Instructions claires pour accéder aux services
- **Transparence** : Explication des choix d'optimisation pour le Free Tier

### Ajout de la documentation sur la configuration SSH

#### Problème identifié
La documentation ne contenait pas d'instructions claires sur la configuration des clés SSH pour le déploiement du backend sur l'instance EC2.

#### Solution mise en œuvre
Ajout d'une nouvelle section dans la documentation principale (README.md) sur la configuration SSH :
1. **Instructions pour générer une paire de clés SSH** sur différents systèmes d'exploitation
2. **Instructions pour extraire une clé publique** à partir d'une clé privée existante
3. **Instructions pour configurer les clés SSH** dans GitHub et AWS
4. **Explication des secrets GitHub** liés à SSH (`EC2_SSH_PRIVATE_KEY`, `EC2_SSH_PUBLIC_KEY`, `EC2_KEY_PAIR_NAME`)
5. **Mise à jour de la table des matières** pour inclure la nouvelle section

#### Avantages de cette solution
- **Complétude** : Documentation couvrant tous les aspects du déploiement
- **Clarté** : Instructions étape par étape pour la configuration SSH
- **Facilité d'utilisation** : Réduction des erreurs lors du déploiement

### Mise à jour des références à ECS dans la documentation

#### Problème identifié
La documentation faisait encore référence à ECS pour le monitoring, alors que l'architecture avait été modifiée pour utiliser Docker sur EC2.

#### Solution mise en œuvre
1. **Mise à jour du titre de la section** de "Monitoring (ECS avec EC2 - Prometheus & Grafana)" à "Monitoring (Docker sur EC2 - Prometheus & Grafana)"
2. **Mise à jour de la description de l'architecture** pour mentionner les conteneurs Docker sur EC2 au lieu d'ECS
3. **Mise à jour des instructions d'accès** à Grafana et Prometheus
4. **Mise à jour des liens dans la table des matières**

#### Avantages de cette solution
- **Cohérence** : Documentation alignée avec l'architecture réelle
- **Précision** : Évite la confusion sur la technologie utilisée
- **Clarté** : Instructions correctes pour accéder aux services
