# Monitoring - YourMédia

Ce document décrit la configuration du système de monitoring pour le projet YourMédia.

## Table des matières

1. [Architecture](#architecture)
2. [Composants](#composants)
3. [Configuration](#configuration)
4. [Tableaux de bord](#tableaux-de-bord)
5. [Logs](#logs)
6. [Maintenance](#maintenance)

## Architecture

Le système de monitoring est déployé sur une instance EC2 dédiée et comprend les composants suivants :

- Prometheus : Collecte et stockage des métriques
- Grafana : Visualisation des métriques et logs
- Loki : Collecte et stockage des logs
- Promtail : Agent de collecte des logs
- cAdvisor : Métriques des conteneurs Docker
- Node Exporter : Métriques système

## Composants

### Prometheus

- Port : 9090
- Configuration : `scripts/config/prometheus/prometheus.yml`
- Métriques collectées :
  - Java/Tomcat (JMX Exporter)
  - Node Exporter
  - cAdvisor
  - Métriques système

### Grafana

- Port : 3000
- Configuration : `scripts/config/grafana/`
- Tableaux de bord :
  - Vue d'ensemble système
  - Métriques Java/Tomcat
  - Métriques Docker
  - Logs applicatifs

### Loki

- Port : 3100
- Configuration : `scripts/config/loki/loki-config.yml`
- Rétention : 7 jours
- Sources de logs :
  - Tomcat
  - Applications Docker
  - Système

### Promtail

- Port : 9080
- Configuration : `scripts/config/promtail/promtail-config.yml`
- Sources de logs :
  - `/var/log/tomcat/`
  - `/var/log/docker/`
  - `/var/log/syslog`

### cAdvisor

- Port web : 8081
- Port métriques : 8080
- Métriques collectées :
  - CPU
  - Mémoire
  - Réseau
  - Disque
  - Conteneurs

### Node Exporter

- Port : 9100
- Métriques collectées :
  - CPU
  - Mémoire
  - Disque
  - Réseau
  - Système de fichiers

## Configuration

### Prometheus

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['localhost:8080']

  - job_name: 'tomcat'
    static_configs:
      - targets: ['localhost:8080']
```

### Grafana

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
```

### Loki

```yaml
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 5m
  chunk_retain_period: 30s

schema_config:
  configs:
    - from: 2020-05-15
      store: boltdb
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb:
    directory: /tmp/loki/index

  filesystem:
    directory: /tmp/loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
```

### Promtail

```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*log

  - job_name: tomcat
    static_configs:
      - targets:
          - localhost
        labels:
          job: tomcat
          __path__: /var/log/tomcat/*.log

  - job_name: docker
    static_configs:
      - targets:
          - localhost
        labels:
          job: docker
          __path__: /var/log/docker/*.log
```

## Tableaux de bord

### Vue d'ensemble système

- CPU, mémoire, disque
- État des conteneurs
- Métriques réseau
- Alertes système

### Métriques Java/Tomcat

- JVM (heap, threads, GC)
- Requêtes HTTP
- Sessions
- Performance

### Métriques Docker

- État des conteneurs
- Utilisation des ressources
- Logs des conteneurs
- Performance

### Logs applicatifs

- Logs Tomcat
- Logs des applications
- Erreurs système
- Alertes

## Logs

### Configuration des logs

1. **Tomcat**
   - Format : JSON
   - Rotation : quotidienne
   - Rétention : 7 jours

2. **Docker**
   - Driver : json-file
   - Rotation : 100MB
   - Rétention : 7 jours

3. **Système**
   - Rotation : quotidienne
   - Rétention : 7 jours

### Collecte des logs

1. **Promtail**
   - Collecte des logs système
   - Collecte des logs Tomcat
   - Collecte des logs Docker

2. **Loki**
   - Stockage des logs
   - Indexation
   - Requêtes

## Maintenance

### Nettoyage

1. **Métriques**
   - Rétention : 15 jours
   - Nettoyage automatique

2. **Logs**
   - Rétention : 7 jours
   - Rotation automatique

### Surveillance

1. **Système**
   - CPU > 80%
   - Mémoire > 80%
   - Disque > 80%

2. **Applications**
   - Erreurs HTTP > 5%
   - Latence > 1s
   - Erreurs JVM

### Mises à jour

1. **Procédure**
   - Backup des configurations
   - Test en staging
   - Déploiement progressif

2. **Vérification**
   - Métriques
   - Logs
   - Tableaux de bord

## Améliorations futures

1. **Haute disponibilité**
   - Cluster Prometheus
   - Réplication Loki
   - Cluster Grafana

2. **Performance**
   - Optimisation des requêtes
   - Compression des données
   - Cache

3. **Sécurité**
   - Authentification
   - Chiffrement
   - Audit

4. **Fonctionnalités**
   - Alertes avancées
   - Anomalies
   - ML

## Ressources

- [Documentation Prometheus](https://prometheus.io/docs)
- [Documentation Grafana](https://grafana.com/docs)
- [Documentation Loki](https://grafana.com/docs/loki/latest)
- [Documentation cAdvisor](https://github.com/google/cadvisor)
- [Documentation Node Exporter](https://prometheus.io/docs/guides/node-exporter)
