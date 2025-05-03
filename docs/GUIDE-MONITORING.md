# Guide de monitoring pour YourMedia

Ce document centralise toutes les informations relatives au monitoring dans le projet YourMedia.

## 1. Vue d'ensemble

Le projet YourMedia utilise une stack de monitoring simplifiée basée sur Prometheus, Grafana, Loki et Node Exporter pour surveiller l'infrastructure. Cette stack est déployée sur une instance EC2 dédiée.

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
│  ┌─────────────┐                       ┌─────────────────┐    │
│  │Node Exporter │                       │    Promtail     │    │
│  └─────────────┘                       └─────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────┐                     ┌─────────────────┐
│  EC2 Java/Tomcat │                     │  Autres services │
└─────────────────┘                     └─────────────────┘
```

## 3. Composants de monitoring

### 3.1. Prometheus

Prometheus est utilisé pour collecter et stocker les métriques de l'infrastructure et des applications.

#### Configuration

Le fichier de configuration principal de Prometheus se trouve dans `/opt/monitoring/prometheus.yml`. Voici un extrait :

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
```

#### Alertes

Les règles d'alerte sont définies dans `/opt/monitoring/prometheus/rules/container-alerts.yml`.

### 3.2. Grafana

Grafana est utilisé pour visualiser les métriques collectées par Prometheus et les logs collectés par Loki.

#### Configuration

La configuration de Grafana se trouve dans `/opt/monitoring/config/grafana/`. Les datasources sont configurées dans `/opt/monitoring/config/grafana/datasources/`.

#### Dashboards

Les dashboards Grafana sont configurés dans `/opt/monitoring/config/grafana/dashboards/`.

### 3.3. Loki

Loki est utilisé pour collecter et stocker les logs de l'infrastructure et des applications.

#### Configuration

La configuration de Loki se trouve dans `/opt/monitoring/loki-config.yml`.

### 3.4. Exporters

#### Node Exporter

Node Exporter collecte les métriques système (CPU, mémoire, disque, réseau) des instances EC2.

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
| `GF_SECURITY_ADMIN_PASSWORD` | Mot de passe administrateur Grafana | `admin` |
| `AWS_REGION` | Région AWS | `eu-west-3` |
| `EC2_INSTANCE_ID` | ID de l'instance EC2 | Détecté automatiquement |
| `EC2_INSTANCE_PUBLIC_IP` | IP publique de l'instance EC2 | Détecté automatiquement |

### 5.2. Fichier docker-compose.yml

Le fichier `/opt/monitoring/docker-compose.yml` définit tous les services de monitoring. Voici un extrait :

```yaml
version: '3'
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - /opt/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - /opt/monitoring/prometheus/rules:/etc/prometheus/rules
    restart: always
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
      - '--web.enable-lifecycle'

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    restart: always
    volumes:
      - /opt/monitoring/config/grafana/datasources:/etc/grafana/provisioning/datasources
      - /opt/monitoring/config/grafana/dashboards:/etc/grafana/provisioning/dashboards
      - /var/lib/grafana:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_DOMAIN=localhost
      - GF_SMTP_ENABLED=false
```

## 6. Utilisation

### 6.1. Accès aux interfaces

- **Prometheus** : http://<MONITORING_EC2_PUBLIC_IP>:9090
- **Grafana** : http://<MONITORING_EC2_PUBLIC_IP>:3000
  - Nom d'utilisateur : `admin`
  - Mot de passe : `admin` (par défaut)

### 6.2. Dashboards Grafana

Vous pouvez créer vos propres dashboards dans Grafana pour visualiser les métriques collectées par Prometheus et les logs collectés par Loki.

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

## 9. Simplifications apportées

Pour améliorer la fiabilité et la simplicité du système de monitoring, les modifications suivantes ont été apportées :

### 9.1. Suppression des exporters problématiques

Les exporters suivants ont été supprimés car ils causaient des problèmes de stabilité :

- MySQL Exporter : Supprimé car il nécessitait une configuration complexe pour se connecter à RDS
- CloudWatch Exporter : Supprimé car il nécessitait des permissions AWS spécifiques

### 9.2. Simplification de la configuration

- Les fichiers de configuration sont maintenant générés directement lors de l'initialisation de l'instance
- Les chemins de fichiers ont été standardisés pour éviter les problèmes de liens symboliques
- Les permissions des répertoires ont été ajustées pour éviter les problèmes d'accès

### 9.3. Optimisation pour le free tier AWS

- Utilisation d'images Docker officielles pour une meilleure compatibilité
- Configuration simplifiée pour réduire la consommation de ressources
- Réduction du nombre de conteneurs pour limiter l'utilisation de la mémoire
