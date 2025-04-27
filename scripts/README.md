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

## Sécurité

Les scripts contenant des informations sensibles (comme des mots de passe ou des clés API) doivent utiliser des variables d'environnement ou des secrets stockés dans GitHub Secrets ou Terraform Cloud.
