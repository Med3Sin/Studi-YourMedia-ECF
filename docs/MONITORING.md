# Monitoring YourMédia

## Vue d'ensemble

Le système de monitoring de YourMédia est basé sur une stack moderne et complète :
- **Prometheus** : Collecte et stockage des métriques
- **Grafana** : Visualisation et alerting
- **cAdvisor** : Monitoring des conteneurs Docker
- **Loki** : Gestion des logs
- **Promtail** : Collecte des logs

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Prometheus │◄────┤   Grafana   │◄────┤   cAdvisor  │
└─────────────┘     └─────────────┘     └─────────────┘
       ▲                   ▲                   ▲
       │                   │                   │
       ▼                   ▼                   ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Loki      │◄────┤  Promtail   │◄────┤  Docker     │
└─────────────┘     └─────────────┘     └─────────────┘
```

## Dashboards

### 1. Vue d'ensemble du système
- Métriques système (CPU, RAM, disque)
- État des services
- Alertes actives

### 2. Application Java
- Métriques JVM
- Logs d'application
- Performance des requêtes

### 3. Conteneurs Docker
- Utilisation des ressources par conteneur
- État des conteneurs
- Logs des conteneurs

### 4. Application React
- Métriques de performance
- Erreurs côté client
- Temps de chargement

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
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
```

### Grafana
- Port : 3000
- Credentials par défaut : admin/admin
- Sources de données :
  - Prometheus
  - Loki

### cAdvisor
- Port : 8081
- Métriques Docker :
  - CPU usage
  - Memory usage
  - Network I/O
  - Disk I/O

## Maintenance

### Mise à jour des dashboards
1. Les dashboards sont stockés dans `scripts/config/grafana/dashboards/`
2. Pour ajouter un nouveau dashboard :
   - Créer le fichier JSON dans le dossier approprié
   - Ajouter la référence dans `dashboards.yml`

### Nettoyage des données
- Prometheus : 15 jours de rétention
- Loki : 7 jours de rétention
- Grafana : Pas de limite de rétention

## Dépannage

### Problèmes courants
1. **Prometheus ne collecte pas de métriques**
   - Vérifier les logs : `docker logs prometheus`
   - Vérifier la configuration : `prometheus.yml`

2. **Grafana ne peut pas se connecter à Prometheus**
   - Vérifier le réseau Docker
   - Vérifier les credentials

3. **cAdvisor ne montre pas les conteneurs**
   - Vérifier les permissions Docker
   - Vérifier les logs : `docker logs cadvisor`

## Sécurité

### Bonnes pratiques
1. Changer le mot de passe par défaut de Grafana
2. Limiter l'accès aux ports de monitoring
3. Utiliser HTTPS pour l'accès à Grafana
4. Configurer les alertes pour les problèmes de sécurité

### Configuration des alertes
```yaml
groups:
  - name: example
    rules:
      - alert: HighCPUUsage
        expr: cpu_usage_percent > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "CPU usage is high"
```

## Ressources

- [Documentation Prometheus](https://prometheus.io/docs/)
- [Documentation Grafana](https://grafana.com/docs/)
- [Documentation cAdvisor](https://github.com/google/cadvisor)
- [Documentation Loki](https://grafana.com/docs/loki/latest/)
