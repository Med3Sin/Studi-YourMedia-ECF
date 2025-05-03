# Scripts YourMedia

Ce dossier contient tous les scripts utilisés dans le projet YourMedia, organisés par module ou fonction.

## Structure des dossiers

- **config/** : Fichiers de configuration pour les différents services
  - **grafana/** : Configuration pour le conteneur Grafana
    - **dashboards/** : Tableaux de bord Grafana
    - **datasources/** : Sources de données Grafana
  - **prometheus/** : Configuration pour le conteneur Prometheus
    - `alerts.yml` : Règles d'alerte Prometheus
    - `container-alerts.yml` : Règles d'alerte spécifiques aux conteneurs
    - `prometheus.yml` : Configuration principale de Prometheus
  - **tomcat/** : Configuration pour Tomcat
  - `cloudwatch-config.yml` : Configuration pour l'exportateur CloudWatch
  - `loki-config.yml` : Configuration pour Loki (centralisation des logs)
  - `promtail-config.yml` : Configuration pour Promtail (agent de collecte de logs)
  - `mysql-exporter-config.cnf` : Configuration pour l'exportateur MySQL

- **database/** : Scripts liés à la base de données
  - `secure-database.sh` : Script pour sécuriser la base de données MySQL
  - `secure-database.sql` : Requêtes SQL pour sécuriser la base de données

- **ec2-java-tomcat/** : Scripts pour l'instance EC2 Java/Tomcat
  - `init-java-tomcat.sh` : Script d'initialisation de l'instance Java/Tomcat
  - `setup-java-tomcat.sh` : Script de configuration de Java et Tomcat
  - `deploy-war.sh` : Script pour déployer un fichier WAR dans Tomcat

- **ec2-monitoring/** : Scripts pour l'instance EC2 de monitoring
  - `init-monitoring.sh` : Script d'initialisation de l'instance de monitoring
  - `setup-monitoring.sh` : Script de configuration des services de monitoring
  - `docker-compose.yml` : Configuration Docker Compose pour les services de monitoring
  - `container-health-check.sh` : Script pour surveiller l'état des conteneurs Docker
  - `container-health-check.service` : Service systemd pour la surveillance des conteneurs
  - `container-health-check.timer` : Timer systemd pour la surveillance des conteneurs
  - `container-tests.sh` : Script pour tester automatiquement les conteneurs Docker
  - `container-tests.service` : Service systemd pour les tests des conteneurs
  - `container-tests.timer` : Timer systemd pour les tests des conteneurs
  - `container-monitor.sh` : Script pour surveiller les conteneurs Docker
  - `generate-config.sh` : Script pour générer les fichiers de configuration
  - `get-aws-resources-info.sh` : Script pour récupérer les informations des ressources AWS
  - `restart-containers.sh` : Script pour redémarrer les conteneurs Docker

- **utils/** : Scripts utilitaires
  - `docker-manager.sh` : Script principal pour gérer les conteneurs Docker
  - `fix-ssh-keys.sh` : Script pour corriger les clés SSH
  - `ssh-key-checker.service` : Service systemd pour vérifier les clés SSH
  - `ssh-key-checker.timer` : Timer systemd pour exécuter le service de vérification des clés SSH
  - `check-github-secrets.sh` : Script pour vérifier les secrets GitHub
  - `check-scripts.sh` : Script pour vérifier la cohérence des scripts
  - `escape-special-chars.sh` : Script pour échapper les caractères spéciaux dans les variables
  - `run-sync-secrets.sh` : Script pour exécuter la synchronisation des secrets
  - `sync-github-secrets-to-terraform.sh` : Script pour synchroniser les secrets GitHub vers Terraform

## Utilisation

Les scripts sont référencés dans les fichiers Terraform et les workflows GitHub Actions. Ils sont également utilisés directement sur les instances EC2.

### Exemple d'utilisation

```bash
# Initialiser et configurer l'instance Java/Tomcat
sudo /opt/yourmedia/init-java-tomcat.sh
sudo /opt/yourmedia/setup-java-tomcat.sh

# Déployer un fichier WAR dans Tomcat
sudo /opt/yourmedia/deploy-war.sh /chemin/vers/application.war

# Initialiser et configurer l'instance de monitoring
sudo /opt/monitoring/init-monitoring.sh
sudo /opt/monitoring/setup-monitoring.sh

# Gérer les conteneurs Docker
sudo /opt/monitoring/docker-manager.sh build all
sudo /opt/monitoring/docker-manager.sh push all
sudo /opt/monitoring/docker-manager.sh deploy all
sudo /opt/monitoring/docker-manager.sh cleanup all

# Surveiller l'état des conteneurs Docker
sudo /opt/monitoring/container-health-check.sh

# Exécuter les tests automatisés des conteneurs
sudo /opt/monitoring/container-tests.sh
```

### Surveillance des conteneurs

Les scripts de surveillance des conteneurs permettent de détecter rapidement les problèmes avec les conteneurs Docker :

```bash
# Vérifier l'état des conteneurs
sudo /opt/monitoring/container-health-check.sh

# Exécuter les tests automatisés
sudo /opt/monitoring/container-tests.sh

# Consulter les rapports de test
ls -la /opt/monitoring/test-reports/
```

### Logs centralisés

Les logs des conteneurs sont centralisés avec Loki et Promtail, et peuvent être consultés via Grafana :

1. Accéder à Grafana : http://IP_INSTANCE:3000
2. Se connecter avec les identifiants par défaut (admin/admin)
3. Consulter le dashboard "Logs"

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
- **GF_SECURITY_ADMIN_PASSWORD** : Mot de passe administrateur Grafana (anciennement: GRAFANA_ADMIN_PASSWORD)



### Variables GitHub
- **GITHUB_CLIENT_ID** : ID client GitHub (non utilisé actuellement)
- **GITHUB_CLIENT_SECRET** : Secret client GitHub (non utilisé actuellement)

### Variables Tomcat
- **TOMCAT_VERSION** : Version de Tomcat à installer

## Sécurité

Les scripts contenant des informations sensibles (comme des mots de passe ou des clés API) doivent utiliser des variables d'environnement ou des secrets stockés dans GitHub Secrets ou Terraform Cloud.

Pour les variables sensibles, utilisez les conventions suivantes :
1. Stockez les variables sensibles dans GitHub Secrets
2. Transmettez les variables sensibles aux scripts via des variables d'environnement
3. Dans les scripts, stockez les variables sensibles dans des fichiers avec des permissions restreintes (600)
4. N'affichez jamais les valeurs sensibles dans les logs ou les sorties standard
