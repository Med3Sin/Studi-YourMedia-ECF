# Guide de configuration de Grafana et Prometheus sur EC2

Ce guide explique comment Grafana et Prometheus sont configurés dans des conteneurs Docker sur une instance EC2 dédiée au monitoring.

## Table des matières

1. [Architecture](#architecture)
2. [Configuration de l'instance EC2](#configuration-de-linstance-ec2)
3. [Configuration de Docker](#configuration-de-docker)
4. [Configuration de Grafana](#configuration-de-grafana)
5. [Configuration de Prometheus](#configuration-de-prometheus)
6. [Accès aux services](#accès-aux-services)
7. [Résolution des problèmes](#résolution-des-problèmes)

## Architecture

L'architecture de monitoring est composée des éléments suivants :

- **Instance EC2** : Une instance EC2 dédiée au monitoring (t2.micro pour rester dans le Free Tier AWS)
- **Docker** : Installé sur l'instance EC2 pour exécuter les conteneurs
- **Grafana** : Exécuté dans un conteneur Docker, accessible sur le port 3000
- **Prometheus** : Exécuté dans un conteneur Docker, accessible sur le port 9090

Cette architecture permet de collecter des métriques sur les applications déployées et de les visualiser dans des tableaux de bord Grafana.

## Configuration de l'instance EC2

L'instance EC2 est configurée avec les éléments suivants :

- **AMI** : Amazon Linux 2
- **Type d'instance** : t2.micro (Free Tier AWS)
- **Groupe de sécurité** : Autorise le trafic entrant sur les ports 22 (SSH), 3000 (Grafana) et 9090 (Prometheus)
- **Rôle IAM** : Permet à l'instance d'accéder à ECR (si nécessaire)

Le script d'initialisation de l'instance EC2 installe Docker et configure les conteneurs Grafana et Prometheus.

## Configuration de Docker

Docker est installé sur l'instance EC2 avec les commandes suivantes :

```bash
# Mettre à jour le système
yum update -y

# Installer Docker
amazon-linux-extras enable docker
yum install -y docker
systemctl enable docker
systemctl start docker

# Ajouter l'utilisateur ec2-user au groupe docker
usermod -a -G docker ec2-user

# Installer Docker Compose
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

## Configuration de Grafana

Grafana est configuré dans un conteneur Docker avec les paramètres suivants :

```yaml
grafana:
  image: grafana/grafana:latest
  container_name: grafana
  ports:
    - "3000:3000"
  volumes:
    - grafana_data:/var/lib/grafana
  environment:
    - GF_SECURITY_ADMIN_PASSWORD=admin
    - GF_USERS_ALLOW_SIGN_UP=false
  depends_on:
    - prometheus
  restart: always
```

Les identifiants par défaut pour accéder à Grafana sont :
- **Utilisateur** : admin
- **Mot de passe** : admin

Lors de la première connexion, Grafana vous demandera de changer le mot de passe.

## Configuration de Prometheus

Prometheus est configuré dans un conteneur Docker avec les paramètres suivants :

```yaml
prometheus:
  image: prom/prometheus:latest
  container_name: prometheus
  ports:
    - "9090:9090"
  volumes:
    - /opt/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
    - prometheus_data:/prometheus
  command:
    - '--config.file=/etc/prometheus/prometheus.yml'
    - '--storage.tsdb.path=/prometheus'
    - '--web.console.libraries=/usr/share/prometheus/console_libraries'
    - '--web.console.templates=/usr/share/prometheus/consoles'
  restart: always
```

Le fichier de configuration Prometheus (`prometheus.yml`) est configuré pour collecter des métriques à partir de :
- Prometheus lui-même (localhost:9090)
- L'instance EC2 Java/Tomcat (EC2_INSTANCE_PRIVATE_IP:8080)

## Accès aux services

Les services sont accessibles aux URLs suivantes :

- **Grafana** : http://MONITORING_IP:3000
- **Prometheus** : http://MONITORING_IP:9090

Où `MONITORING_IP` est l'adresse IP publique de l'instance EC2 de monitoring.

Ces URLs sont exportées en tant qu'outputs Terraform et stockées dans les secrets GitHub pour être utilisées dans les workflows de déploiement.

## Résolution des problèmes

### Problème : Grafana n'est pas accessible

1. Vérifiez que l'instance EC2 est en cours d'exécution
2. Vérifiez que le groupe de sécurité autorise le trafic entrant sur le port 3000
3. Vérifiez que le conteneur Grafana est en cours d'exécution :
   ```bash
   docker ps | grep grafana
   ```
4. Vérifiez les logs du conteneur Grafana :
   ```bash
   docker logs grafana
   ```

### Problème : Prometheus n'est pas accessible

1. Vérifiez que l'instance EC2 est en cours d'exécution
2. Vérifiez que le groupe de sécurité autorise le trafic entrant sur le port 9090
3. Vérifiez que le conteneur Prometheus est en cours d'exécution :
   ```bash
   docker ps | grep prometheus
   ```
4. Vérifiez les logs du conteneur Prometheus :
   ```bash
   docker logs prometheus
   ```

### Problème : Prometheus ne collecte pas de métriques

1. Vérifiez que le fichier de configuration Prometheus est correctement configuré :
   ```bash
   cat /opt/monitoring/prometheus.yml
   ```
2. Vérifiez que les cibles Prometheus sont accessibles :
   ```bash
   curl http://EC2_INSTANCE_PRIVATE_IP:8080/metrics
   ```
3. Vérifiez les logs du conteneur Prometheus :
   ```bash
   docker logs prometheus
   ```
