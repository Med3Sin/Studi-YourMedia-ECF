# Guide de monitoring pour YourMedia

Ce document centralise toutes les informations relatives au monitoring dans le projet YourMedia.

## 1. Vue d'ensemble

Le projet YourMedia utilise une stack de monitoring complète basée sur Prometheus, Grafana, Loki et divers exporters pour surveiller l'infrastructure et les applications. Cette stack est déployée sur une instance EC2 dédiée.

## 2. Architecture de monitoring

```
┌─────────────────────────────────────────────────────────────┐
│                   Instance EC2 Monitoring                    │
│                                                             │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────────┐    │
│  │  Prometheus  │   │   Grafana   │   │      Loki       │    │
│  └─────────────┘   └─────────────┘   └─────────────────┘    │
│         │                │                    │              │
│         └────────────────┼────────────────────┘              │
│                          │                                   │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────────┐    │
│  │Node Exporter │   │MySQL Exporter│   │    Promtail     │    │
│  └─────────────┘   └─────────────┘   └─────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────┐   ┌─────────────┐   ┌─────────────────┐
│  EC2 Java/Tomcat │   │  RDS MySQL  │   │  Autres services │
└─────────────────┘   └─────────────┘   └─────────────────┘
```

## 3. Composants de monitoring

### 3.1. Prometheus

Prometheus est utilisé pour collecter et stocker les métriques de l'infrastructure et des applications.

#### Configuration

Le fichier de configuration principal de Prometheus se trouve dans `scripts/config/prometheus/prometheus.yml`. Voici un extrait :

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
      - targets: ['node-exporter:9100']

  - job_name: 'mysql'
    static_configs:
      - targets: ['mysql-exporter:9104']
```

#### Alertes

Les règles d'alerte sont définies dans `scripts/config/prometheus/alerts.yml` et `scripts/config/prometheus/container-alerts.yml`.

### 3.2. Grafana

Grafana est utilisé pour visualiser les métriques collectées par Prometheus et les logs collectés par Loki.

#### Configuration

La configuration de Grafana se trouve dans `scripts/config/grafana/`. Les datasources sont configurées dans `scripts/config/grafana/datasources/`.

#### Dashboards

Les dashboards Grafana sont stockés dans `scripts/config/grafana/dashboards/` et incluent :
- `system-overview.json` : Vue d'ensemble du système
- `logs-dashboard.json` : Visualisation des logs

### 3.3. Loki

Loki est utilisé pour collecter et stocker les logs de l'infrastructure et des applications.

#### Configuration

La configuration de Loki se trouve dans `scripts/config/loki-config.yml`.

### 3.4. Exporters

#### Node Exporter

Node Exporter collecte les métriques système (CPU, mémoire, disque, réseau) des instances EC2.

#### MySQL Exporter

MySQL Exporter collecte les métriques de la base de données RDS MySQL.

#### Promtail

Promtail collecte les logs et les envoie à Loki.

## 4. Déploiement

### 4.1. Déploiement via Terraform

La stack de monitoring est déployée automatiquement lors du déploiement de l'infrastructure via Terraform. Le module `ec2-monitoring` dans `infrastructure/modules/ec2-monitoring/` gère le déploiement de l'instance EC2 de monitoring.

### 4.2. Déploiement manuel

Pour déployer manuellement la stack de monitoring :

```bash
# Se connecter à l'instance EC2 de monitoring
ssh -i ~/.ssh/your-key.pem ec2-user@<MONITORING_EC2_PUBLIC_IP>

# Cloner le dépôt
git clone https://github.com/Med3Sin/Studi-YourMedia-ECF.git
cd Studi-YourMedia-ECF

# Exécuter le script d'initialisation
sudo ./scripts/ec2-monitoring/init-monitoring.sh
```

### 4.3. Déploiement via GitHub Actions

La stack de monitoring peut également être déployée via le workflow GitHub Actions `3-docker-build-deploy.yml` avec le paramètre `target` défini sur `monitoring` ou `all`.

## 5. Configuration

### 5.1. Variables d'environnement

Les variables d'environnement suivantes sont utilisées pour configurer la stack de monitoring :

| Variable | Description | Valeur par défaut |
|----------|-------------|-------------------|
| `DOCKERHUB_USERNAME` | Nom d'utilisateur Docker Hub | - |
| `DOCKERHUB_TOKEN` | Token Docker Hub | - |
| `DOCKERHUB_REPO` | Nom du dépôt Docker Hub | `yourmedia-ecf` |
| `GF_SECURITY_ADMIN_PASSWORD` | Mot de passe administrateur Grafana | `YourMedia2025!` |
| `RDS_USERNAME` | Nom d'utilisateur RDS | `yourmedia` |
| `RDS_PASSWORD` | Mot de passe RDS | - |
| `RDS_ENDPOINT` | Point de terminaison RDS | - |

### 5.2. Fichier docker-compose.yml

Le fichier `scripts/ec2-monitoring/docker-compose.yml` définit tous les services de monitoring. Voici un extrait :

```yaml
version: '3'
services:
  prometheus:
    image: ${DOCKERHUB_USERNAME}/${DOCKERHUB_REPO}:prometheus-latest
    volumes:
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"
    restart: always
    mem_limit: 256m

  grafana:
    image: ${DOCKERHUB_USERNAME}/${DOCKERHUB_REPO}:grafana-latest
    volumes:
      - grafana_data:/var/lib/grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD}
    restart: always
    mem_limit: 256m
```

## 6. Utilisation

### 6.1. Accès aux interfaces

- **Prometheus** : http://<MONITORING_EC2_PUBLIC_IP>:9090
- **Grafana** : http://<MONITORING_EC2_PUBLIC_IP>:3000
  - Nom d'utilisateur : `admin`
  - Mot de passe : Valeur de `GF_SECURITY_ADMIN_PASSWORD`

### 6.2. Dashboards Grafana

Les dashboards suivants sont disponibles dans Grafana :

- **System Overview** : Vue d'ensemble du système (CPU, mémoire, disque, réseau)
- **Logs Dashboard** : Visualisation des logs collectés par Loki

### 6.3. Requêtes Prometheus

Voici quelques exemples de requêtes Prometheus utiles :

- Utilisation CPU : `100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)`
- Utilisation mémoire : `100 * (1 - ((node_memory_MemFree_bytes + node_memory_Cached_bytes + node_memory_Buffers_bytes) / node_memory_MemTotal_bytes))`
- Espace disque disponible : `node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100`

## 7. Maintenance

### 7.1. Vérification de l'état des services

```bash
# Se connecter à l'instance EC2 de monitoring
ssh -i ~/.ssh/your-key.pem ec2-user@<MONITORING_EC2_PUBLIC_IP>

# Vérifier l'état des conteneurs Docker
docker ps

# Vérifier les logs des conteneurs
docker logs prometheus
docker logs grafana
docker logs loki
```

### 7.2. Redémarrage des services

```bash
# Redémarrer tous les services
cd /opt/monitoring
docker-compose restart

# Redémarrer un service spécifique
docker-compose restart prometheus
```

### 7.3. Mise à jour des images Docker

```bash
# Mettre à jour les images Docker
cd /opt/monitoring
docker-compose pull
docker-compose up -d
```

## 8. Dépannage

### 8.1. Problèmes courants

- **Prometheus ne collecte pas de données** : Vérifiez la configuration des targets dans Prometheus
- **Grafana ne se connecte pas à Prometheus** : Vérifiez la configuration des datasources dans Grafana
- **Loki ne collecte pas de logs** : Vérifiez la configuration de Promtail

### 8.2. Logs des conteneurs

```bash
# Voir les logs de Prometheus
docker logs prometheus

# Voir les logs de Grafana
docker logs grafana

# Voir les logs de Loki
docker logs loki
```

### 8.3. Scripts de diagnostic

Le projet inclut plusieurs scripts de diagnostic pour vérifier l'état des conteneurs :

- `scripts/ec2-monitoring/container-health-check.sh` : Vérifie l'état des conteneurs
- `scripts/ec2-monitoring/container-tests.sh` : Exécute des tests sur les conteneurs
- `scripts/ec2-monitoring/restart-containers.sh` : Redémarre les conteneurs en cas de problème

## 9. Optimisations pour le free tier AWS

### 9.1. Limites de ressources

Les limites de ressources des conteneurs Docker ont été optimisées pour s'adapter aux contraintes du Free Tier :

- Prometheus : 256 Mo de RAM (au lieu de 512 Mo)
- Grafana : 256 Mo de RAM (au lieu de 512 Mo)
- MySQL Exporter : 128 Mo de RAM (au lieu de 256 Mo)
- Node Exporter : 128 Mo de RAM
- Loki : 256 Mo de RAM (au lieu de 512 Mo)
- Promtail : 128 Mo de RAM (au lieu de 256 Mo)

### 9.2. Rétention des données

La rétention des données a été configurée pour limiter l'utilisation du disque :

- Prometheus : 15 jours
- Loki : 7 jours
