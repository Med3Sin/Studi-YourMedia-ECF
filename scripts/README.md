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
  - **prometheus/** : Configuration pour le conteneur Prometheus
  - **sonarqube/** : Configuration pour le conteneur SonarQube

- **ec2-java-tomcat/** : Scripts pour l'instance EC2 Java/Tomcat
  - `install_java_tomcat.sh` : Script d'installation de Java et Tomcat

- **ec2-monitoring/** : Scripts pour l'instance EC2 de monitoring
  - `setup.sh` : Script de configuration initiale de l'instance
  - `fix_permissions.sh` : Script pour corriger les permissions des fichiers
  - `generate_sonar_token.sh` : Script pour générer un token SonarQube
  - `init-instance.sh` : Script d'initialisation de l'instance
  - `docker-compose.yml` : Configuration Docker Compose pour les services de monitoring
  - `prometheus.yml` : Configuration Prometheus

- **utils/** : Scripts utilitaires
  - `fix-ssh-keys.sh` : Script pour corriger les clés SSH
  - `ssh-key-checker.service` : Service systemd pour vérifier les clés SSH
  - `ssh-key-checker.timer` : Timer systemd pour exécuter le service de vérification des clés SSH

## Utilisation

Les scripts sont référencés dans les fichiers Terraform et les workflows GitHub Actions. Ils sont également utilisés directement sur les instances EC2.

### Exemple d'utilisation

```bash
# Exécuter le script d'installation de Java et Tomcat
./scripts/ec2-java-tomcat/install_java_tomcat.sh

# Gérer les conteneurs Docker
./scripts/docker/docker-manager.sh start
./scripts/docker/docker-manager.sh stop
./scripts/docker/docker-manager.sh restart

# Configurer l'instance de monitoring
./scripts/ec2-monitoring/setup.sh
```

## Maintenance

Tous les scripts doivent être maintenus dans ce dossier centralisé. Si vous devez ajouter un nouveau script, veuillez le placer dans le sous-dossier approprié et mettre à jour ce README.md.

## Sécurité

Les scripts contenant des informations sensibles (comme des mots de passe ou des clés API) doivent utiliser des variables d'environnement ou des secrets stockés dans GitHub Secrets ou Terraform Cloud.
