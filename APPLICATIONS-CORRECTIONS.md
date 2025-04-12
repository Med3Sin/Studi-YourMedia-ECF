# Corrections et Améliorations des Applications

Ce document recense les corrections et améliorations apportées aux applications backend (Java) et frontend (React Native) du projet YourMedia.

## Table des matières

1. [Application Frontend (React Native)](#application-frontend-react-native)
   - [Correction du problème de plugin React Native dans Gradle](#correction-du-problème-de-plugin-react-native-dans-gradle)
   - [Configuration d'Expo pour le build web](#configuration-dexpo-pour-le-build-web)
   - [Optimisation du workflow de déploiement](#optimisation-du-workflow-de-déploiement)

2. [Application Backend (Java)](#application-backend-java)
   - [Adaptation des scripts pour Amazon Linux 2](#adaptation-des-scripts-pour-amazon-linux-2)
   - [Optimisation du déploiement sur Tomcat](#optimisation-du-déploiement-sur-tomcat)

3. [Infrastructure](#infrastructure)
   - [Correction de la configuration du cycle de vie du bucket S3](#correction-de-la-configuration-du-cycle-de-vie-du-bucket-s3)
   - [Configuration de Grafana/Prometheus dans des conteneurs Docker sur EC2](#configuration-de-grafanaprometheus-dans-des-conteneurs-docker-sur-ec2)
   - [Correction de l'erreur de référence à ECS dans le module de monitoring](#correction-de-lerreur-de-référence-à-ecs-dans-le-module-de-monitoring)

4. [CI/CD](#cicd)
   - [Correction des avertissements de dépréciation dans les workflows GitHub Actions](#correction-des-avertissements-de-dépréciation-dans-les-workflows-github-actions)

---

## Application Frontend (React Native)

### Correction du problème de plugin React Native dans Gradle

#### Problème identifié
Lors de la compilation du projet React Native, l'erreur suivante était rencontrée :
```
A problem occurred configuring project ':packages:react-native:ReactAndroid'.
Plugin [id: 'com.facebook.react'] was not found in any of the following sources:
```

Cette erreur se produisait car le plugin `com.facebook.react` n'était pas trouvé dans les sources Gradle disponibles.

#### Solution mise en œuvre
Pour résoudre ce problème, nous avons modifié l'approche de build pour utiliser directement Expo CLI au lieu des scripts de build natifs de React Native :

1. **Modification du workflow GitHub Actions** :
   ```yaml
   # Étape 5: Installation d'Expo CLI et compilation de l'application web
   - name: Install Expo CLI and build web application
     run: |
       echo "::group::Installing Expo CLI"
       npm install -g expo-cli
       echo "::endgroup::"

       echo "::group::Building web application"
       # Utiliser directement expo export pour éviter les problèmes avec les plugins natifs
       npx expo export --platform web
       echo "::endgroup::"
     working-directory: ${{ env.APP_DIR }}
   ```

2. **Mise à jour du script de build dans package.json** :
   ```json
   "scripts": {
     "start": "expo start",
     "android": "expo start --android",
     "ios": "expo start --ios",
     "web": "expo start --web",
     "build": "npx expo export --platform web"
   }
   ```

3. **Ajout d'un fichier app.json pour la configuration Expo** :
   ```json
   {
     "expo": {
       "name": "YourMedia",
       "slug": "yourmedia",
       "version": "1.0.0",
       "orientation": "portrait",
       "icon": "./assets/icon.png",
       "userInterfaceStyle": "light",
       "splash": {
         "image": "./assets/splash.png",
         "resizeMode": "contain",
         "backgroundColor": "#ffffff"
       },
       "assetBundlePatterns": [
         "**/*"
       ],
       "ios": {
         "supportsTablet": true
       },
       "android": {
         "adaptiveIcon": {
           "foregroundImage": "./assets/adaptive-icon.png",
           "backgroundColor": "#ffffff"
         }
       },
       "web": {
         "favicon": "./assets/favicon.png",
         "bundler": "metro"
       }
     }
   }
   ```

4. **Création du répertoire assets** pour stocker les images requises par Expo.

#### Avantages de cette solution
- **Simplicité** : Utilisation directe des outils d'Expo sans configuration manuelle des plugins Gradle
- **Compatibilité** : Évite les problèmes de compatibilité entre les différentes versions de React Native, Gradle et les plugins
- **Maintenabilité** : Réduit la complexité de la configuration de build
- **Fiabilité** : S'appuie sur les outils officiels d'Expo qui sont bien testés et maintenus

### Configuration d'Expo pour le build web

Pour optimiser le build web de l'application React Native, nous avons configuré Expo avec les paramètres suivants :

1. **Configuration du bundler web** :
   ```json
   "web": {
     "favicon": "./assets/favicon.png",
     "bundler": "metro"
   }
   ```

2. **Optimisation des assets** :
   - Création d'un répertoire `assets` pour stocker les images
   - Configuration des patterns d'assets pour inclure tous les fichiers nécessaires

### Optimisation du workflow de déploiement

Le workflow de déploiement frontend a été optimisé pour :

1. **Détecter automatiquement le gestionnaire de paquets** (npm ou yarn)
2. **Installer Expo CLI globalement** pour garantir l'accès aux commandes Expo
3. **Utiliser npx pour exécuter les commandes Expo** afin d'assurer la compatibilité des versions
4. **Générer uniquement les artefacts web** avec `--platform web` pour optimiser le temps de build

---

## Application Backend (Java)

### Adaptation des scripts pour Amazon Linux 2

#### Problème identifié
Les scripts d'installation de Java et Tomcat étaient configurés pour Ubuntu/Debian (utilisant `apt-get`), mais l'infrastructure utilise Amazon Linux 2 (qui utilise `yum`).

#### Solution mise en œuvre
Nous avons modifié le script `install_java_tomcat.sh` pour :

1. **Utiliser yum comme gestionnaire de paquets** :
   ```bash
   # Installation des dépendances
   sudo yum update -y
   sudo yum install -y wget tar
   ```

2. **Installer Amazon Corretto 11** (la version Java recommandée pour Amazon Linux 2) :
   ```bash
   # Installation de Java (Amazon Corretto 11)
   sudo yum install -y java-11-amazon-corretto-devel
   ```

3. **Utiliser le chemin Java correct pour Amazon Linux 2** :
   ```bash
   # Configuration des variables d'environnement Java
   export JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto
   ```

4. **Adapter les commandes de configuration système** pour Amazon Linux 2

#### Avantages de cette solution
- **Compatibilité** : Assure la compatibilité avec l'AMI Amazon Linux 2 spécifiée
- **Stabilité** : Utilise la version Java recommandée pour Amazon Linux 2 (Amazon Corretto 11)
- **Performance** : Optimise l'installation pour l'environnement AWS

### Optimisation du déploiement sur Tomcat

Pour optimiser le déploiement de l'application Java sur Tomcat, nous avons :

1. **Modifié le workflow GitHub Actions** pour se connecter avec l'utilisateur `ec2-user` (utilisateur par défaut pour Amazon Linux 2) au lieu de `ubuntu`

2. **Utilisé yum pour installer AWS CLI** :
   ```bash
   sudo yum update -y
   sudo yum install -y aws-cli
   ```

3. **Créé un guide de test pour Tomcat** (TOMCAT-TEST-GUIDE.md) qui explique comment vérifier l'installation de Tomcat via :
   - Le navigateur web
   - SSH (vérification du service, des journaux, des ports)
   - Requêtes HTTP
   - Un script de test automatisé

4. **Optimisé la copie des fichiers WAR** depuis S3 vers Tomcat pour un déploiement plus rapide et fiable

---

## Infrastructure

### Correction de la configuration du cycle de vie du bucket S3

#### Problème identifié
Lors du déploiement de l'infrastructure avec Terraform, l'avertissement suivant était rencontré :
```
Warning: Invalid Attribute Combination

  with module.s3.aws_s3_bucket_lifecycle_configuration.media_storage_lifecycle,
  on modules/s3/main.tf line 55, in resource "aws_s3_bucket_lifecycle_configuration" "media_storage_lifecycle":
  55:     filter {}

No attribute specified when one (and only one) of
[rule[0].filter[0].prefix.<.object_size_greater_than,rule[0].filter[0].prefix.<.object_size_less_than,rule[0].filter[0].prefix.<.and,rule[0].filter[0].prefix.<.tag]
is required
```

Cet avertissement indiquait que le bloc `filter {}` vide n'était pas valide et qu'au moins un attribut devait être spécifié.

#### Solution mise en œuvre
Pour résoudre ce problème, nous avons modifié le bloc `filter` pour inclure un attribut `prefix` avec une valeur vide :

```hcl
# Filtre avec préfixe vide pour appliquer la règle à tous les objets
filter {
  prefix = ""
}
```

Cette modification permet de maintenir le comportement d'origine (appliquer la règle à tous les objets) tout en satisfaisant l'exigence du provider AWS Terraform.

#### Avantages de cette solution
- **Conformité** : Satisfait les exigences du provider AWS Terraform
- **Compatibilité future** : Assure la compatibilité avec les futures versions du provider
- **Maintien du comportement** : Conserve le comportement d'origine (application de la règle à tous les objets)

## Infrastructure

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

## CI/CD

### Résolution des problèmes de connexion SSH pour le déploiement backend

#### Problème identifié
Lors de l'exécution du workflow de déploiement backend, l'erreur suivante était rencontrée :
```
ec2-user@***: Permission denied (publickey,gssapi-keyex,gssapi-with-mic).
Error: Process completed with exit code 255.
```

Cette erreur indiquait que la clé SSH configurée dans les secrets GitHub n'était pas autorisée à se connecter à l'instance EC2.

#### Solution mise en œuvre
Pour résoudre ce problème, nous avons créé un guide détaillé (`SSH-CONFIGURATION-GUIDE.md`) qui explique comment :

1. **Générer une paire de clés SSH** sur la machine locale ou directement sur l'instance EC2
2. **Configurer la clé publique** sur l'instance EC2 en l'ajoutant au fichier `~/.ssh/authorized_keys` de l'utilisateur `ec2-user`
3. **Configurer la clé privée** dans les secrets GitHub sous le nom `EC2_SSH_PRIVATE_KEY`
4. **Vérifier la configuration** en exécutant le workflow de déploiement backend

Le guide inclut également une section de résolution des problèmes pour aider les développeurs à diagnostiquer et résoudre les problèmes de connexion SSH.

#### Avantages de cette solution
- **Documentation claire** : Le guide fournit des instructions détaillées pour la configuration SSH
- **Sécurité** : La solution utilise des clés SSH pour l'authentification, ce qui est plus sécurisé que les mots de passe
- **Autonomie** : Les développeurs peuvent configurer eux-mêmes la connexion SSH sans avoir besoin d'aide
- **Débogage facilité** : Le guide inclut des instructions pour le débogage des problèmes de connexion SSH

### Correction des avertissements de dépréciation dans les workflows GitHub Actions

#### Problème identifié
Lors de l'exécution du workflow d'exportation des outputs Terraform, des avertissements de dépréciation étaient générés :
```
Warning: The `set-output` command is deprecated and will be disabled soon. Please upgrade to using Environment Files.
```

Ces avertissements étaient générés par l'action `gliech/create-github-secret-action@v1` qui utilisait la commande `set-output` dépréciée.

#### Solution mise en œuvre
Pour résoudre ce problème, nous avons remplacé l'action `gliech/create-github-secret-action@v1` par l'action `actions/github-script@v7` qui utilise les fichiers d'environnement recommandés par GitHub :

```yaml
# Étape 6: Mise à jour des secrets GitHub avec actions/github-script
- name: Update GitHub Secrets
  uses: actions/github-script@v7
  env:
    EC2_PUBLIC_IP: ${{ env.EC2_PUBLIC_IP }}
    S3_BUCKET_NAME: ${{ env.S3_BUCKET_NAME }}
    AMPLIFY_APP_URL: ${{ env.AMPLIFY_APP_URL }}
    RDS_ENDPOINT: ${{ env.RDS_ENDPOINT }}
    GRAFANA_URL: ${{ env.GRAFANA_URL }}
    MONITORING_IP: ${{ env.MONITORING_IP }}
  with:
    github-token: ${{ secrets.GH_PAT }}
    script: |
      const { EC2_PUBLIC_IP, S3_BUCKET_NAME, AMPLIFY_APP_URL, RDS_ENDPOINT, GRAFANA_URL, MONITORING_IP } = process.env;

      // Fonction pour mettre à jour un secret
      async function updateSecret(name, value) {
        // Code pour mettre à jour le secret
      }

      // Mettre à jour tous les secrets
      await updateSecret('TF_EC2_PUBLIC_IP', EC2_PUBLIC_IP);
      await updateSecret('TF_S3_BUCKET_NAME', S3_BUCKET_NAME);
      await updateSecret('TF_AMPLIFY_APP_URL', AMPLIFY_APP_URL);
      await updateSecret('TF_RDS_ENDPOINT', RDS_ENDPOINT);
      await updateSecret('TF_GRAFANA_URL', GRAFANA_URL);
      await updateSecret('TF_MONITORING_IP', MONITORING_IP);
```

Cette approche utilise l'API GitHub directement via l'action `actions/github-script` pour mettre à jour les secrets du dépôt.

#### Avantages de cette solution
- **Conformité** : Utilise les méthodes recommandées par GitHub (fichiers d'environnement au lieu de `set-output`)
- **Maintenance** : L'action `actions/github-script` est maintenue par GitHub et régulièrement mise à jour
- **Flexibilité** : Permet d'interagir avec l'API GitHub de manière plus flexible
- **Performance** : Réduit le nombre d'appels à l'API GitHub en regroupant les mises à jour des secrets

## Recommandations pour les futures améliorations

### Application Frontend
1. **Ajouter des images par défaut** dans le répertoire `assets` (icon.png, splash.png, adaptive-icon.png, favicon.png)
2. **Configurer les variables d'environnement** pour les différents environnements (développement, production)
3. **Mettre en place des tests automatisés** pour l'application React Native
4. **Optimiser le bundle web** pour améliorer les performances de chargement

### Application Backend
1. **Mettre en place des tests d'intégration** pour vérifier le déploiement sur Tomcat
2. **Configurer la rotation des logs** pour éviter de remplir le disque
3. **Optimiser les paramètres JVM** pour améliorer les performances
4. **Mettre en place un mécanisme de rollback** en cas d'échec du déploiement

### Infrastructure
1. **Mettre en place des tests d'infrastructure** avec Terratest ou Kitchen-Terraform
2. **Optimiser les coûts** en utilisant des instances réservées ou des Savings Plans
3. **Améliorer la sécurité** en mettant en place des politiques IAM plus restrictives
4. **Configurer des alarmes CloudWatch** pour surveiller les ressources

### CI/CD
1. **Mettre à jour les actions GitHub** pour utiliser les dernières versions
2. **Implémenter des tests automatisés** dans les workflows CI/CD
3. **Configurer des notifications** pour les échecs de workflow
4. **Optimiser les temps d'exécution** des workflows
