#!/bin/bash
# Script d'installation et de configuration des conteneurs Docker pour le monitoring

# Variables
ec2_java_tomcat_ip="PLACEHOLDER_IP"
db_username="PLACEHOLDER_USERNAME"
db_password="PLACEHOLDER_PASSWORD"
db_endpoint="PLACEHOLDER_ENDPOINT"
sonar_jdbc_username="SONAR_JDBC_USERNAME"
sonar_jdbc_password="SONAR_JDBC_PASSWORD"
sonar_jdbc_url="SONAR_JDBC_URL"
grafana_admin_password="GRAFANA_ADMIN_PASSWORD"

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Installation des dépendances
log "Installation des dépendances..."
sudo yum update -y
sudo amazon-linux-extras install docker -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# Installation de Docker Compose
log "Installation de Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Création des répertoires pour les données persistantes
log "Création des répertoires pour les données persistantes..."
sudo mkdir -p /opt/monitoring/prometheus-data /opt/monitoring/grafana-data /opt/monitoring/sonarqube-data /opt/monitoring/sonarqube-db-data
sudo chown -R ec2-user:ec2-user /opt/monitoring

# Création du fichier docker-compose.yml
log "Création du fichier docker-compose.yml..."
cat > /opt/monitoring/docker-compose.yml << 'EOL'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
    ports:
      - "9090:9090"
    restart: unless-stopped
    networks:
      - monitoring-network

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    ports:
      - "9100:9100"
    restart: unless-stopped
    networks:
      - monitoring-network

  mysql-exporter:
    image: prom/mysqld-exporter:latest
    container_name: mysql-exporter
    environment:
      - DATA_SOURCE_NAME=MYSQL_USER:MYSQL_PASSWORD@(MYSQL_HOST:3306)/
    ports:
      - "9104:9104"
    restart: unless-stopped
    networks:
      - monitoring-network

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    volumes:
      - ./grafana-data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=GRAFANA_PASSWORD
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer
    ports:
      - "3001:3000"
    restart: unless-stopped
    networks:
      - monitoring-network
    depends_on:
      - prometheus

  sonarqube-db:
    image: postgres:13
    container_name: sonarqube-db
    environment:
      - POSTGRES_USER=SONAR_DB_USER
      - POSTGRES_PASSWORD=SONAR_DB_PASSWORD
      - POSTGRES_DB=sonar
    volumes:
      - ./sonarqube-db-data:/var/lib/postgresql/data
    networks:
      - monitoring-network
    restart: unless-stopped

  sonarqube:
    image: sonarqube:9.9-community
    container_name: sonarqube
    depends_on:
      - sonarqube-db
    environment:
      - SONAR_JDBC_URL=SONAR_JDBC_URL
      - SONAR_JDBC_USERNAME=SONAR_DB_USER
      - SONAR_JDBC_PASSWORD=SONAR_DB_PASSWORD
    volumes:
      - ./sonarqube-data/data:/opt/sonarqube/data
      - ./sonarqube-data/logs:/opt/sonarqube/logs
      - ./sonarqube-data/extensions:/opt/sonarqube/extensions
    ports:
      - "9000:9000"
    networks:
      - monitoring-network
    restart: unless-stopped

networks:
  monitoring-network:
    driver: bridge
EOL

# Création du fichier prometheus.yml
log "Création du fichier prometheus.yml..."
cat > /opt/monitoring/prometheus.yml << EOL
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          # - alertmanager:9093

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'mysql-exporter'
    static_configs:
      - targets: ['mysql-exporter:9104']

  - job_name: 'tomcat'
    metrics_path: '/metrics'
    static_configs:
      - targets: ['${ec2_java_tomcat_ip}:8080']
EOL

# Remplacement des variables dans le fichier docker-compose.yml
log "Remplacement des variables dans le fichier docker-compose.yml..."
sed -i "s/MYSQL_USER/${db_username}/g" /opt/monitoring/docker-compose.yml
sed -i "s/MYSQL_PASSWORD/${db_password}/g" /opt/monitoring/docker-compose.yml
sed -i "s/MYSQL_HOST/${db_endpoint}/g" /opt/monitoring/docker-compose.yml
sed -i "s/GRAFANA_PASSWORD/${grafana_admin_password}/g" /opt/monitoring/docker-compose.yml
sed -i "s/SONAR_DB_USER/${sonar_jdbc_username}/g" /opt/monitoring/docker-compose.yml
sed -i "s/SONAR_DB_PASSWORD/${sonar_jdbc_password}/g" /opt/monitoring/docker-compose.yml
sed -i "s|SONAR_JDBC_URL|${sonar_jdbc_url}|g" /opt/monitoring/docker-compose.yml

# Démarrage des conteneurs avec docker-manager.sh
log "Démarrage des conteneurs avec docker-manager.sh..."
if [ -f "/tmp/docker-manager.sh" ]; then
    chmod +x /tmp/docker-manager.sh
    /tmp/docker-manager.sh deploy monitoring
else
    log "Le script docker-manager.sh n'est pas disponible. Utilisation de docker-compose..."
    cd /opt/monitoring
    docker-compose up -d
fi

# Vérification du statut des conteneurs
log "Vérification du statut des conteneurs..."
docker ps

log "Installation et configuration terminées avec succès."
log "Grafana est accessible à l'adresse http://localhost:3001"
log "Prometheus est accessible à l'adresse http://localhost:9090"
log "SonarQube est accessible à l'adresse http://localhost:9000"

exit 0
