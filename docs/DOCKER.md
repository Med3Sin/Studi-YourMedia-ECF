# Gestion des Conteneurs Docker - YourMedia

Ce document explique comment gérer les conteneurs Docker dans le projet YourMedia.

## Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Images Docker utilisées](#images-docker-utilisées)
3. [Configuration Docker Compose](#configuration-docker-compose)
4. [Déploiement des conteneurs](#déploiement-des-conteneurs)
5. [Gestion des conteneurs](#gestion-des-conteneurs)
6. [Services Systemd](#services-systemd)
7. [Optimisations](#optimisations)

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

## 6. Services Systemd

### Configuration des Services

Les services systemd sont configurés avec les mesures de sécurité suivantes :

1. **docker-cleanup.service** :
   - Exécution avec des privilèges minimaux
   - Journalisation des actions
   - Vérification des ressources avant suppression
   - Limitation des ressources système

2. **sync-tomcat-logs.service** :
   - Accès en lecture seule aux logs
   - Chiffrement des logs en transit
   - Vérification de l'intégrité des logs
   - Rotation des logs

### Configuration Sécurisée

```ini
# docker-cleanup.service
[Unit]
Description=Docker Cleanup Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/docker-cleanup.sh
User=root
Group=root
NoNewPrivileges=yes
ProtectSystem=full
ProtectHome=yes
PrivateTmp=yes
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW
LimitNOFILE=65536
LimitNPROC=4096

[Timer]
OnCalendar=daily
AccuracySec=1h
Persistent=true

[Install]
WantedBy=timers.target

# sync-tomcat-logs.service
[Unit]
Description=Tomcat Logs Synchronization Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/sync-tomcat-logs.sh
User=root
Group=root
NoNewPrivileges=yes
ProtectSystem=full
ProtectHome=yes
PrivateTmp=yes
ReadOnlyDirectories=/
ReadWriteDirectories=/var/log/tomcat
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW
LimitNOFILE=65536
LimitNPROC=4096

[Timer]
OnCalendar=hourly
AccuracySec=1m
Persistent=true

[Install]
WantedBy=timers.target
```

### Gestion des Services

Pour vérifier le statut des services :
```bash
sudo systemctl status docker-cleanup.service
sudo systemctl status docker-cleanup.timer
sudo systemctl status sync-tomcat-logs.service
sudo systemctl status sync-tomcat-logs.timer
```

Pour redémarrer les services :
```bash
sudo systemctl restart docker-cleanup.service
sudo systemctl restart sync-tomcat-logs.service
```

Pour activer/désactiver les services :
```bash
sudo systemctl enable docker-cleanup.timer
sudo systemctl enable sync-tomcat-logs.timer
sudo systemctl disable docker-cleanup.timer
sudo systemctl disable sync-tomcat-logs.timer
```

### Surveillance

Les services sont surveillés pour :
- Tentatives d'accès non autorisées
- Modifications de configuration
- Utilisation excessive des ressources
- Erreurs d'exécution

### Maintenance

Procédures de maintenance :
1. Vérification régulière des logs
2. Rotation des logs
3. Mise à jour des scripts
4. Tests de sécurité

## 7. Optimisations

Les conteneurs Docker ont été optimisés pour le Free Tier AWS :

- Limites de ressources adaptées aux instances t2.micro
- Options de logging configurées pour éviter la saturation du disque
- Redémarrage automatique en cas de crash
