#!/bin/bash

# Script pour déployer les conteneurs Docker sur les instances EC2
# Utilisation: ./deploy-containers.sh [monitoring|app|all]

# Variables
EC2_MONITORING_IP=${TF_MONITORING_EC2_PUBLIC_IP}
EC2_APP_IP=${TF_EC2_PUBLIC_IP}
SSH_KEY="${EC2_SSH_PRIVATE_KEY}"
DOCKER_USERNAME=${DOCKERHUB_USERNAME:-medsin}
DOCKER_TOKEN=${DOCKERHUB_TOKEN}
DOCKER_REPO=${DOCKERHUB_REPO:-yourmedia-ecf}
TARGET=${1:-all}
GF_SECURITY_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD:-admin}
DB_USERNAME=${DB_USERNAME}
DB_PASSWORD=${DB_PASSWORD}
RDS_ENDPOINT=${TF_RDS_ENDPOINT}
GITHUB_CLIENT_ID=${GITHUB_CLIENT_ID}
GITHUB_CLIENT_SECRET=${GITHUB_CLIENT_SECRET}

# Vérifier si les variables requises sont définies
if [ -z "$SSH_KEY" ]; then
    echo "La clé SSH privée n'est pas définie. Veuillez définir la variable EC2_SSH_PRIVATE_KEY."
    exit 1
fi

if [ -z "$DOCKER_TOKEN" ]; then
    echo "Le token Docker Hub n'est pas défini. Veuillez définir la variable DOCKERHUB_TOKEN."
    exit 1
fi

# Créer un fichier temporaire pour la clé SSH
echo "$SSH_KEY" > ssh_key.pem
chmod 600 ssh_key.pem

# Fonction pour déployer les conteneurs de monitoring
deploy_monitoring() {
    if [ -z "$EC2_MONITORING_IP" ]; then
        echo "L'adresse IP de l'instance EC2 de monitoring n'est pas définie. Veuillez définir la variable TF_MONITORING_EC2_PUBLIC_IP."
        exit 1
    fi

    echo "Déploiement des conteneurs de monitoring sur $EC2_MONITORING_IP..."

    # Se connecter à l'instance EC2 et déployer les conteneurs
    ssh -i ssh_key.pem -o StrictHostKeyChecking=no ec2-user@$EC2_MONITORING_IP << EOF
        # Connexion à Docker Hub
        echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

        # Créer les répertoires nécessaires
        sudo mkdir -p /opt/monitoring/prometheus-data /opt/monitoring/grafana-data /opt/monitoring/sonarqube-data /opt/monitoring/sonarqube-extensions /opt/monitoring/sonarqube-logs /opt/monitoring/sonarqube-db

        # Configurer les permissions
        sudo chown -R 1000:1000 /opt/monitoring/grafana-data
        sudo chown -R 1000:1000 /opt/monitoring/sonarqube-data /opt/monitoring/sonarqube-extensions /opt/monitoring/sonarqube-logs
        sudo chown -R 999:999 /opt/monitoring/sonarqube-db

        # Augmenter les limites système pour SonarQube
        echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
        echo "fs.file-max=65536" | sudo tee -a /etc/sysctl.conf
        sudo sysctl -p

        # Créer le fichier docker-compose.yml
        cat > /tmp/docker-compose.yml << 'EOFINNER'
version: '3'

services:
  # Prometheus pour la surveillance
  prometheus:
    image: $DOCKER_USERNAME/$DOCKER_REPO:prometheus-latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - /opt/monitoring/prometheus-data:/prometheus
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 512m
    cpu_shares: 512

  # Grafana pour la visualisation
  grafana:
    image: $DOCKER_USERNAME/$DOCKER_REPO:grafana-latest
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - /opt/monitoring/grafana-data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=$GF_SECURITY_ADMIN_PASSWORD
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer
    depends_on:
      - prometheus
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 512m
    cpu_shares: 512

  # Exportateur CloudWatch pour surveiller les services AWS
  cloudwatch-exporter:
    image: prom/cloudwatch-exporter:latest
    container_name: cloudwatch-exporter
    ports:
      - "9106:9106"
    volumes:
      - /opt/monitoring/cloudwatch-config.yml:/config/cloudwatch-config.yml
    command: "--config.file=/config/cloudwatch-config.yml"
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 256m
    cpu_shares: 256

  # Exportateur MySQL pour surveiller RDS
  mysql-exporter:
    image: prom/mysqld-exporter:latest
    container_name: mysql-exporter
    ports:
      - "9104:9104"
    environment:
      - DATA_SOURCE_NAME=$DB_USERNAME:$DB_PASSWORD@($RDS_ENDPOINT:3306)/
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 256m
    cpu_shares: 256

  # SonarQube pour l'analyse de qualité du code
  sonarqube:
    image: $DOCKER_USERNAME/$DOCKER_REPO:sonarqube-latest
    container_name: sonarqube
    depends_on:
      - sonarqube-db
    ports:
      - "9000:9000"
    environment:
      - SONAR_JDBC_URL=jdbc:postgresql://sonarqube-db:5432/sonar
      - SONAR_JDBC_USERNAME=sonar
      - SONAR_JDBC_PASSWORD=sonar
      - GITHUB_CLIENT_ID=$GITHUB_CLIENT_ID
      - GITHUB_CLIENT_SECRET=$GITHUB_CLIENT_SECRET
    volumes:
      - /opt/monitoring/sonarqube-data:/opt/sonarqube/data
      - /opt/monitoring/sonarqube-extensions:/opt/sonarqube/extensions
      - /opt/monitoring/sonarqube-logs:/opt/sonarqube/logs
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 1024m
    cpu_shares: 1024

  # Base de données PostgreSQL pour SonarQube
  sonarqube-db:
    image: postgres:13
    container_name: sonarqube-db
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_USER=sonar
      - POSTGRES_PASSWORD=sonar
      - POSTGRES_DB=sonar
    volumes:
      - /opt/monitoring/sonarqube-db:/var/lib/postgresql/data
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 512m
    cpu_shares: 512

  # Node Exporter pour la surveillance du système
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)($$|/)'
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 256m
    cpu_shares: 256
EOFINNER

        # Remplacer les variables dans le fichier docker-compose.yml
        sed -i "s/\$DOCKER_USERNAME/$DOCKER_USERNAME/g" /tmp/docker-compose.yml
        sed -i "s/\$DOCKER_REPO/$DOCKER_REPO/g" /tmp/docker-compose.yml
        sed -i "s/\$GF_SECURITY_ADMIN_PASSWORD/$GF_SECURITY_ADMIN_PASSWORD/g" /tmp/docker-compose.yml
        sed -i "s/\$DB_USERNAME/$DB_USERNAME/g" /tmp/docker-compose.yml
        sed -i "s/\$DB_PASSWORD/$DB_PASSWORD/g" /tmp/docker-compose.yml
        sed -i "s/\$RDS_ENDPOINT/$RDS_ENDPOINT/g" /tmp/docker-compose.yml
        sed -i "s/\$GITHUB_CLIENT_ID/$GITHUB_CLIENT_ID/g" /tmp/docker-compose.yml
        sed -i "s/\$GITHUB_CLIENT_SECRET/$GITHUB_CLIENT_SECRET/g" /tmp/docker-compose.yml

        # Déplacer le fichier docker-compose.yml
        sudo mv /tmp/docker-compose.yml /opt/monitoring/docker-compose.yml

        # Démarrer les conteneurs
        cd /opt/monitoring
        sudo docker-compose pull
        sudo docker-compose up -d

        # Vérifier que les conteneurs sont en cours d'exécution
        sudo docker ps
EOF

    echo "Déploiement des conteneurs de monitoring terminé."
}

# Fonction pour déployer l'application mobile
deploy_app() {
    if [ -z "$EC2_APP_IP" ]; then
        echo "L'adresse IP de l'instance EC2 de l'application n'est pas définie. Veuillez définir la variable TF_EC2_PUBLIC_IP."
        exit 1
    fi

    echo "Déploiement de l'application mobile sur $EC2_APP_IP..."

    # Se connecter à l'instance EC2 et déployer les conteneurs
    ssh -i ssh_key.pem -o StrictHostKeyChecking=no ec2-user@$EC2_APP_IP << EOF
        # Connexion à Docker Hub
        echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

        # Créer les répertoires nécessaires
        sudo mkdir -p /opt/yourmedia

        # Créer le fichier docker-compose.yml
        cat > /tmp/docker-compose.yml << 'EOFINNER'
version: '3'

services:
  # Application mobile React Native
  app-mobile:
    image: $DOCKER_USERNAME/$DOCKER_REPO:mobile-latest
    container_name: app-mobile
    ports:
      - "3000:3000"
    environment:
      - API_URL=http://$EC2_APP_IP:8080
      - NODE_ENV=production
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 512m
    cpu_shares: 512
EOFINNER

        # Remplacer les variables dans le fichier docker-compose.yml
        sed -i "s/\$DOCKER_USERNAME/$DOCKER_USERNAME/g" /tmp/docker-compose.yml
        sed -i "s/\$DOCKER_REPO/$DOCKER_REPO/g" /tmp/docker-compose.yml
        sed -i "s/\$EC2_APP_IP/$EC2_APP_IP/g" /tmp/docker-compose.yml

        # Déplacer le fichier docker-compose.yml
        sudo mv /tmp/docker-compose.yml /opt/yourmedia/docker-compose.yml

        # Démarrer les conteneurs
        cd /opt/yourmedia
        sudo docker-compose pull
        sudo docker-compose up -d

        # Vérifier que les conteneurs sont en cours d'exécution
        sudo docker ps
EOF

    echo "Déploiement de l'application mobile terminé."
}

# Exécution en fonction de la cible
case $TARGET in
    monitoring)
        deploy_monitoring
        ;;
    app)
        deploy_app
        ;;
    all)
        deploy_monitoring
        deploy_app
        ;;
    *)
        echo "Cible inconnue: $TARGET"
        echo "Utilisation: ./deploy-containers.sh [monitoring|app|all]"
        exit 1
        ;;
esac

# Supprimer le fichier temporaire de la clé SSH
rm ssh_key.pem

echo "Déploiement terminé avec succès!"
