# Guide de Monitoring avec Prometheus et Grafana

Ce document explique comment configurer et utiliser le système de monitoring basé sur Prometheus et Grafana pour surveiller les instances EC2, l'application Java/Tomcat et les conteneurs Docker.

## Architecture du système de monitoring

Le système de monitoring est composé des éléments suivants :

- **Prometheus** : Collecte et stocke les métriques
- **Grafana** : Visualise les métriques collectées par Prometheus
- **Node Exporter** : Expose les métriques système (CPU, mémoire, disque, réseau)
- **JMX Exporter** : Expose les métriques Java/Tomcat
- **cAdvisor** : Expose les métriques des conteneurs Docker

## Ports utilisés

| Service | Port | Description |
|---------|------|-------------|
| Prometheus | 9090 | Interface web de Prometheus |
| Grafana | 3000 | Interface web de Grafana |
| Node Exporter | 9100 | Métriques système |
| JMX Exporter | 9404 | Métriques Java/Tomcat |
| cAdvisor | 8081 | Métriques des conteneurs Docker |

## Configuration des instances

### Instance EC2 de monitoring

Cette instance héberge Prometheus et Grafana, ainsi que Node Exporter et cAdvisor pour son auto-monitoring.

#### Conteneurs Docker

- **prometheus** : Collecte et stocke les métriques
- **grafana** : Visualise les métriques
- **node-exporter** : Expose les métriques système
- **cadvisor** : Expose les métriques des conteneurs Docker
- **loki** : Collecte et stocke les logs (optionnel)
- **promtail** : Envoie les logs à Loki (optionnel)

#### Volumes Docker

- **prometheus_data** : Stocke les données de Prometheus
- **grafana-storage** : Stocke les données de Grafana
- **loki_data** : Stocke les données de Loki (optionnel)

#### Réseau Docker

- **monitoring_network** : Réseau Docker pour la communication entre les conteneurs

### Instance EC2 Java/Tomcat

Cette instance héberge l'application Java/Tomcat, ainsi que Node Exporter et JMX Exporter pour exposer les métriques.

#### Services systemd

- **node_exporter** : Expose les métriques système
- **tomcat** : Application Java/Tomcat avec JMX Exporter configuré

## Installation et configuration

### Sur l'instance EC2 de monitoring

1. Créer les répertoires nécessaires :
```bash
sudo mkdir -p /opt/monitoring/config/grafana/provisioning/datasources
sudo mkdir -p /opt/monitoring/config/grafana/provisioning/dashboards
sudo mkdir -p /opt/monitoring/config/prometheus/rules
```

2. Copier les fichiers de configuration :
```bash
# Pour Prometheus
sudo cp /path/to/scripts/config/prometheus/prometheus.yml /opt/monitoring/prometheus.yml
sudo cp /path/to/scripts/config/prometheus/alerts.yml /opt/monitoring/config/prometheus/rules/
sudo cp /path/to/scripts/config/prometheus/container-alerts.yml /opt/monitoring/config/prometheus/rules/

# Pour Grafana
sudo cp /path/to/scripts/config/grafana/datasources/prometheus.yml /opt/monitoring/config/grafana/provisioning/datasources/
sudo cp /path/to/scripts/config/grafana/datasources/loki.yml /opt/monitoring/config/grafana/provisioning/datasources/
sudo cp /path/to/scripts/config/grafana/dashboards/default.yml /opt/monitoring/config/grafana/provisioning/dashboards/
sudo cp /path/to/scripts/config/grafana/*.json /opt/monitoring/config/grafana/dashboards/
```

3. Configurer les permissions :
```bash
sudo chown -R 472:472 /opt/monitoring/config/grafana
```

4. Démarrer les conteneurs :
```bash
# Créer le réseau Docker
sudo docker network create monitoring_network

# Créer les volumes Docker
sudo docker volume create prometheus_data
sudo docker volume create grafana-storage
sudo docker volume create loki_data

# Démarrer Prometheus
sudo docker run -d \
  --name=prometheus \
  --restart=always \
  --network=monitoring_network \
  -p 9090:9090 \
  -v prometheus_data:/prometheus \
  -v /opt/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml \
  -v /opt/monitoring/config/prometheus/rules:/etc/prometheus/rules \
  prom/prometheus:latest

# Démarrer Node Exporter
sudo docker run -d \
  --name=node-exporter \
  --restart=always \
  --network=monitoring_network \
  -p 9100:9100 \
  -v /:/rootfs:ro \
  -v /var/run:/var/run:ro \
  -v /sys:/sys:ro \
  -v /var/lib/docker/:/var/lib/docker:ro \
  prom/node-exporter:latest

# Démarrer cAdvisor
sudo docker run -d \
  --name=cadvisor \
  --restart=always \
  --network=monitoring_network \
  -p 8081:8080 \
  -v /:/rootfs:ro \
  -v /var/run:/var/run:ro \
  -v /sys:/sys:ro \
  -v /var/lib/docker/:/var/lib/docker:ro \
  -v /dev/disk/:/dev/disk:ro \
  --privileged \
  --device=/dev/kmsg \
  gcr.io/cadvisor/cadvisor:latest

# Démarrer Grafana
sudo docker run -d \
  --name=grafana \
  --restart=always \
  --network=monitoring_network \
  -p 3000:3000 \
  -v /opt/monitoring/config/grafana/provisioning:/etc/grafana/provisioning \
  -v grafana-storage:/var/lib/grafana \
  -e "GF_SECURITY_ADMIN_PASSWORD=admin" \
  -e "GF_USERS_ALLOW_SIGN_UP=false" \
  -e "GF_SERVER_DOMAIN=localhost" \
  -e "GF_SERVER_ROOT_URL=http://localhost:3000/" \
  -e "GF_SERVER_SERVE_FROM_SUB_PATH=false" \
  grafana/grafana:9.5.2
```

5. Configurer le script de surveillance :
```bash
sudo bash -c 'cat > /tmp/check-grafana.sh << EOF
#!/bin/bash
if ! docker ps | grep -q grafana; then
  echo "$(date) - Grafana container is not running. Attempting to restart..." >> /var/log/grafana-monitor.log
  docker start grafana
  sleep 10
  if docker ps | grep -q grafana; then
    echo "$(date) - Grafana container successfully restarted." >> /var/log/grafana-monitor.log
  else
    echo "$(date) - Failed to restart Grafana container." >> /var/log/grafana-monitor.log
  fi
fi
EOF'

sudo chmod +x /tmp/check-grafana.sh
sudo mkdir -p /etc/cron.d
echo "*/5 * * * * /tmp/check-grafana.sh" | sudo tee /etc/cron.d/check-grafana
```

### Sur l'instance EC2 Java/Tomcat

1. Installer Node Exporter :
```bash
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvfz node_exporter-1.7.0.linux-amd64.tar.gz
sudo mv node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
sudo useradd -rs /bin/false node_exporter

# Créer un service systemd pour Node Exporter
sudo bash -c 'cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF'

# Démarrer et activer Node Exporter
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter
```

2. Installer JMX Exporter pour Java/Tomcat :
```bash
sudo mkdir -p /opt/jmx_exporter
cd /opt/jmx_exporter
sudo wget https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.20.0/jmx_prometheus_javaagent-0.20.0.jar
sudo wget https://raw.githubusercontent.com/prometheus/jmx_exporter/master/example_configs/tomcat.yml -O config.yml

# Configurer Tomcat pour utiliser JMX Exporter
sudo bash -c 'cat > $CATALINA_HOME/bin/setenv.sh << EOF
export CATALINA_OPTS="$CATALINA_OPTS -javaagent:/opt/jmx_exporter/jmx_prometheus_javaagent-0.20.0.jar=9404:/opt/jmx_exporter/config.yml"
EOF'

sudo chmod +x $CATALINA_HOME/bin/setenv.sh
sudo systemctl restart tomcat
```

## Utilisation

### Accès aux interfaces web

- **Prometheus** : http://<IP_PUBLIQUE_EC2_MONITORING>:9090
- **Grafana** : http://<IP_PUBLIQUE_EC2_MONITORING>:3000 (login: admin, mot de passe: admin)
- **cAdvisor** : http://<IP_PUBLIQUE_EC2_MONITORING>:8081

### Dashboards Grafana recommandés

- **Node Exporter Full** (ID: 1860) : Métriques système complètes
- **JVM Micrometer** (ID: 4701) : Métriques JVM
- **Tomcat Exporter Dashboard** (ID: 12860) : Métriques Tomcat
- **Docker and System Monitoring** (ID: 193) : Métriques Docker

## Dépannage

### Problèmes courants

1. **Grafana ne démarre pas** :
   - Vérifier les logs : `sudo docker logs grafana`
   - Vérifier les permissions : `sudo chown -R 472:472 /opt/monitoring/config/grafana`
   - Recréer le volume : `sudo docker volume rm grafana-storage && sudo docker volume create grafana-storage`

2. **Prometheus ne peut pas accéder aux cibles** :
   - Vérifier les règles de sécurité AWS pour s'assurer que les ports sont ouverts
   - Vérifier que les services sont en cours d'exécution sur les cibles
   - Vérifier la configuration dans `/opt/monitoring/prometheus.yml`

3. **JMX Exporter ne fonctionne pas** :
   - Vérifier que le fichier JAR est accessible
   - Vérifier que le fichier de configuration est correct
   - Vérifier les logs Tomcat pour les erreurs liées à JMX Exporter

## Maintenance

### Sauvegarde des données

- **Prometheus** : Les données sont stockées dans le volume Docker `prometheus_data`
- **Grafana** : Les données sont stockées dans le volume Docker `grafana-storage`

Pour sauvegarder ces données, vous pouvez utiliser la commande suivante :
```bash
sudo docker run --rm -v prometheus_data:/source -v /backup:/backup alpine tar -czf /backup/prometheus_data_$(date +%Y%m%d).tar.gz /source
sudo docker run --rm -v grafana-storage:/source -v /backup:/backup alpine tar -czf /backup/grafana_storage_$(date +%Y%m%d).tar.gz /source
```

### Mise à jour des conteneurs

Pour mettre à jour les conteneurs, vous pouvez utiliser les commandes suivantes :
```bash
sudo docker pull prom/prometheus:latest
sudo docker pull grafana/grafana:latest
sudo docker pull prom/node-exporter:latest
sudo docker pull gcr.io/cadvisor/cadvisor:latest

sudo docker stop prometheus grafana node-exporter cadvisor
sudo docker rm prometheus grafana node-exporter cadvisor

# Redémarrer les conteneurs avec les mêmes commandes que lors de l'installation
```

## Références

- [Documentation Prometheus](https://prometheus.io/docs/introduction/overview/)
- [Documentation Grafana](https://grafana.com/docs/)
- [Documentation Node Exporter](https://github.com/prometheus/node_exporter)
- [Documentation JMX Exporter](https://github.com/prometheus/jmx_exporter)
- [Documentation cAdvisor](https://github.com/google/cadvisor)
