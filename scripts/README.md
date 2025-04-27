# Scripts YourMedia

Ce dossier contient tous les scripts utilisés dans le projet YourMedia, organisés par module ou fonction.

## Structure des dossiers

- **database/** : Scripts liés à la base de données
  - `secure-database.sh` : Script pour sécuriser la base de données MySQL

- **docker/** : Scripts et configurations Docker
  - `docker-manager.sh` : Script principal pour gérer les conteneurs Docker
  - `cleanup-containers.sh` : Script pour nettoyer les conteneurs Docker inutilisés
  - `backup-restore-containers.sh` : Script pour sauvegarder et restaurer les conteneurs Docker
  - **grafana/** : Configuration pour le conteneur Grafana
    - **dashboards/** : Tableaux de bord Grafana
    - **provisioning/** : Configuration de provisionnement Grafana
  - **prometheus/** : Configuration pour le conteneur Prometheus
    - **rules/** : Règles d'alerte Prometheus
  - **sonarqube/** : Configuration pour le conteneur SonarQube
  - **monitoring/** : Configuration Docker Compose pour les services de monitoring

- **ec2-java-tomcat/** : Scripts pour l'instance EC2 Java/Tomcat
  - `install_java_tomcat.sh` : Script d'installation de Java et Tomcat
  - `deploy-war.sh` : Script pour déployer un fichier WAR dans Tomcat
  - `fix_permissions.sh` : Script pour corriger les permissions des fichiers
  - `init-instance-env.sh` : Script d'initialisation de l'instance avec les variables d'environnement

- **ec2-monitoring/** : Scripts pour l'instance EC2 de monitoring
  - `setup.sh` : Script de configuration initiale de l'instance
  - `fix_permissions.sh` : Script pour corriger les permissions des fichiers
  - `generate_sonar_token.sh` : Script pour générer un token SonarQube
  - `init-instance-env.sh` : Script d'initialisation de l'instance avec les variables d'environnement
  - `docker-compose.yml` : Configuration Docker Compose pour les services de monitoring
  - `prometheus.yml` : Configuration Prometheus
  - `fix-containers.sh` : Script pour corriger les problèmes des conteneurs Docker
  - `container-health-check.sh` : Script pour surveiller l'état des conteneurs Docker
  - `container-tests.sh` : Script pour tester automatiquement les conteneurs Docker
  - `setup-monitoring-improvements.sh` : Script pour configurer les améliorations de surveillance
  - `loki-config.yml` : Configuration pour Loki (centralisation des logs)
  - `promtail-config.yml` : Configuration pour Promtail (agent de collecte de logs)
  - **prometheus-rules/** : Règles d'alerte Prometheus

- **utils/** : Scripts utilitaires
  - `fix-ssh-keys.sh` : Script pour corriger les clés SSH
  - `ssh-key-checker.service` : Service systemd pour vérifier les clés SSH
  - `ssh-key-checker.timer` : Timer systemd pour exécuter le service de vérification des clés SSH
  - `check-scripts.sh` : Script pour vérifier la cohérence des scripts
  - `escape-special-chars.sh` : Script pour échapper les caractères spéciaux dans les variables

## Utilisation

Les scripts sont référencés dans les fichiers Terraform et les workflows GitHub Actions. Ils sont également utilisés directement sur les instances EC2.

### Exemple d'utilisation

```bash
# Exécuter le script d'installation de Java et Tomcat
sudo ./scripts/ec2-java-tomcat/install_java_tomcat.sh

# Déployer un fichier WAR dans Tomcat
sudo ./scripts/ec2-java-tomcat/deploy-war.sh /chemin/vers/application.war

# Gérer les conteneurs Docker
sudo ./scripts/docker/docker-manager.sh start
sudo ./scripts/docker/docker-manager.sh stop
sudo ./scripts/docker/docker-manager.sh restart

# Configurer l'instance de monitoring
sudo ./scripts/ec2-monitoring/setup.sh

# Surveiller l'état des conteneurs Docker
sudo ./scripts/ec2-monitoring/container-health-check.sh

# Exécuter les tests automatisés des conteneurs
sudo ./scripts/ec2-monitoring/container-tests.sh

# Configurer les améliorations de surveillance
sudo ./scripts/ec2-monitoring/setup-monitoring-improvements.sh
```

### Surveillance des conteneurs

Les scripts de surveillance des conteneurs permettent de détecter rapidement les problèmes avec les conteneurs Docker :

```bash
# Vérifier l'état des conteneurs
sudo ./scripts/ec2-monitoring/container-health-check.sh

# Exécuter les tests automatisés
sudo ./scripts/ec2-monitoring/container-tests.sh

# Consulter les rapports de test
ls -la /opt/monitoring/test-reports/
```

### Logs centralisés

Les logs des conteneurs sont centralisés avec Loki et Promtail, et peuvent être consultés via Grafana :

1. Accéder à Grafana : http://IP_INSTANCE:3000
2. Se connecter avec les identifiants par défaut (admin/YourMedia2025!)
3. Consulter le dashboard "Container Logs"

## Maintenance

Tous les scripts doivent être maintenus dans ce dossier centralisé. Si vous devez ajouter un nouveau script, veuillez le placer dans le sous-dossier approprié et mettre à jour ce README.md.

## Modèle de documentation standard pour les scripts

Tous les scripts doivent suivre le modèle de documentation standard suivant :

```bash
#!/bin/bash
#==============================================================================
# Nom du script : nom_du_script.sh
# Description   : Description détaillée du script et de son objectif
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : YYYY-MM-DD
#==============================================================================
# Utilisation   : ./nom_du_script.sh [options] [arguments]
#
# Options       :
#   -h, --help  : Affiche l'aide
#   -v, --verbose : Mode verbeux
#
# Arguments     :
#   arg1        : Description du premier argument
#   arg2        : Description du deuxième argument
#
# Exemples      :
#   ./nom_du_script.sh arg1 arg2
#   ./nom_du_script.sh --verbose arg1
#==============================================================================
# Dépendances   :
#   - dépendance1 : Description de la dépendance
#   - dépendance2 : Description de la dépendance
#==============================================================================
# Variables d'environnement :
#   - ENV_VAR1  : Description de la variable d'environnement
#   - ENV_VAR2  : Description de la variable d'environnement
#==============================================================================
# Droits requis : Ce script doit être exécuté avec des privilèges sudo ou en tant que root.
#==============================================================================
```

Ce modèle de documentation permet de comprendre rapidement l'objectif du script, comment l'utiliser, ses dépendances et les variables d'environnement qu'il utilise.

## Conventions de nommage des variables

Pour assurer la cohérence et la maintenabilité du code, les variables d'environnement suivent les conventions de nommage suivantes :

### Variables Docker
- **DOCKERHUB_USERNAME** : Nom d'utilisateur Docker Hub (alias: DOCKER_USERNAME)
- **DOCKERHUB_REPO** : Nom du dépôt Docker Hub (alias: DOCKER_REPO)
- **DOCKERHUB_TOKEN** : Token d'authentification Docker Hub

### Variables EC2
- **EC2_INSTANCE_ID** : ID de l'instance EC2
- **EC2_INSTANCE_PRIVATE_IP** : Adresse IP privée de l'instance EC2
- **EC2_INSTANCE_PUBLIC_IP** : Adresse IP publique de l'instance EC2
- **EC2_INSTANCE_REGION** : Région AWS de l'instance EC2
- **EC2_MONITORING_IP** : Adresse IP publique de l'instance EC2 de monitoring (alias: TF_MONITORING_EC2_PUBLIC_IP)
- **EC2_APP_IP** : Adresse IP publique de l'instance EC2 de l'application (alias: TF_EC2_PUBLIC_IP)
- **EC2_SSH_KEY** : Clé SSH privée pour se connecter aux instances EC2 (alias: EC2_SSH_PRIVATE_KEY)

### Variables RDS
- **RDS_USERNAME** : Nom d'utilisateur RDS (alias: DB_USERNAME)
- **RDS_PASSWORD** : Mot de passe RDS (alias: DB_PASSWORD)
- **RDS_ENDPOINT** : Point de terminaison RDS (alias: DB_ENDPOINT, TF_RDS_ENDPOINT)
- **RDS_HOST** : Hôte RDS (extrait de RDS_ENDPOINT)
- **RDS_PORT** : Port RDS (extrait de RDS_ENDPOINT)

### Variables S3
- **S3_BUCKET_NAME** : Nom du bucket S3 (alias: TF_S3_BUCKET_NAME)

### Variables Grafana
- **GRAFANA_ADMIN_PASSWORD** : Mot de passe administrateur Grafana (alias: GF_SECURITY_ADMIN_PASSWORD)

### Variables SonarQube
- **SONAR_JDBC_USERNAME** : Nom d'utilisateur pour la base de données SonarQube
- **SONAR_JDBC_PASSWORD** : Mot de passe pour la base de données SonarQube
- **SONAR_JDBC_URL** : URL JDBC pour la base de données SonarQube

### Variables GitHub
- **GITHUB_CLIENT_ID** : ID client GitHub pour SonarQube
- **GITHUB_CLIENT_SECRET** : Secret client GitHub pour SonarQube

### Variables Tomcat
- **TOMCAT_VERSION** : Version de Tomcat à installer

## Sécurité

Les scripts contenant des informations sensibles (comme des mots de passe ou des clés API) doivent utiliser des variables d'environnement ou des secrets stockés dans GitHub Secrets ou Terraform Cloud.

Pour les variables sensibles, utilisez les conventions suivantes :
1. Stockez les variables sensibles dans GitHub Secrets
2. Transmettez les variables sensibles aux scripts via des variables d'environnement
3. Dans les scripts, stockez les variables sensibles dans des fichiers avec des permissions restreintes (600)
4. N'affichez jamais les valeurs sensibles dans les logs ou les sorties standard
