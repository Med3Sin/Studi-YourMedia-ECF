# Gestion des Conteneurs Docker - YourMedia

Ce document explique comment gérer les conteneurs Docker dans le projet YourMedia.

## 1. Vue d'ensemble

Le projet YourMedia utilise Docker pour :

- Déployer l'application React Native Web (frontend)
- Exécuter les services de monitoring (Prometheus, Grafana, Loki)
- Collecter et visualiser les logs (Promtail)

## 2. Images Docker utilisées

### Images officielles

- **prometheus:latest** - Collecte et stocke les métriques
- **grafana:latest** - Visualisation des métriques et des logs
- **node-exporter:latest** - Collecte des métriques système

### Images personnalisées

- **${DOCKERHUB_USERNAME}/yourmedia-ecf:mobile-latest** - Application React Native Web
- **${DOCKERHUB_USERNAME}/yourmedia-ecf:loki-latest** - Système de gestion de logs
- **${DOCKERHUB_USERNAME}/yourmedia-ecf:promtail-latest** - Collecteur de logs

## 3. Configuration Docker Compose

Le fichier `scripts/ec2-monitoring/docker-compose.yml` définit tous les services Docker :

- **prometheus** - Port 9090, configuration dans /opt/monitoring/prometheus.yml
- **node-exporter** - Port 9100, accès au système hôte en lecture seule
- **grafana** - Port 3000, configuration dans /opt/monitoring/config/grafana
- **loki** - Port 3100, stockage dans /opt/monitoring/loki
- **promtail** - Accès aux logs système dans /var/log
- **app-mobile** - Port 8080, application React Native Web

## 4. Déploiement des conteneurs

### Via GitHub Actions

Le workflow `3-docker-build-deploy.yml` permet de :

1. Construire les images Docker
2. Les pousser vers Docker Hub
3. Les déployer sur l'instance EC2 de monitoring

### Manuellement

Pour déployer manuellement les conteneurs :

```bash
cd /opt/monitoring
sudo docker-compose up -d
```

## 5. Gestion des conteneurs

### Vérification de l'état

```bash
sudo docker ps
```

### Redémarrage des conteneurs

```bash
sudo docker-compose restart
```

### Logs des conteneurs

```bash
sudo docker logs [nom_du_conteneur]
```

## 6. Optimisations

Les conteneurs Docker ont été optimisés pour le Free Tier AWS :

- Limites de ressources adaptées aux instances t2.micro
- Options de logging configurées pour éviter la saturation du disque
- Redémarrage automatique en cas de crash
