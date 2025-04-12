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
