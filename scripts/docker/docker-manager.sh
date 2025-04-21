#!/bin/bash

# Script pour gérer les images Docker et les conteneurs
# Utilisation: ./docker-manager.sh [build|deploy|all] [mobile|monitoring|all]

# Variables
DOCKER_USERNAME=${DOCKERHUB_USERNAME:-medsin}
DOCKER_REPO=${DOCKERHUB_REPO:-yourmedia-ecf}
VERSION=$(date +%Y%m%d%H%M%S)
ACTION=${1:-all}
TARGET=${2:-all}
EC2_MONITORING_IP=${TF_MONITORING_EC2_PUBLIC_IP}
EC2_APP_IP=${TF_EC2_PUBLIC_IP}
SSH_KEY="${EC2_SSH_PRIVATE_KEY}"
GF_SECURITY_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD:-admin}
DB_USERNAME=${DB_USERNAME}
DB_PASSWORD=${DB_PASSWORD}
RDS_ENDPOINT=${TF_RDS_ENDPOINT}
GITHUB_CLIENT_ID=${GITHUB_CLIENT_ID}
GITHUB_CLIENT_SECRET=${GITHUB_CLIENT_SECRET}

# Vérification des mots de passe par défaut
if [ "$GF_SECURITY_ADMIN_PASSWORD" = "admin" ]; then
    echo "[WARNING] Le mot de passe administrateur Grafana est défini sur la valeur par défaut 'admin'."
    echo "[WARNING] Il est fortement recommandé de définir un mot de passe plus sécurisé via la variable GF_SECURITY_ADMIN_PASSWORD."
    read -p "Voulez-vous continuer avec ce mot de passe par défaut? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "[INFO] Opération annulée. Veuillez définir un mot de passe plus sécurisé."
        exit 1
    fi
fi

# Afficher la bannière
echo "========================================================="
echo "=== Script de gestion Docker pour YourMedia ==="
echo "========================================================="

# Fonction d'aide
show_help() {
    echo "Usage: $0 [build|deploy|all] [mobile|monitoring|all]"
    echo ""
    echo "Actions:"
    echo "  build      - Construit et pousse les images Docker vers Docker Hub"
    echo "  deploy     - Déploie les conteneurs Docker sur les instances EC2"
    echo "  all        - Exécute les actions build et deploy"
    echo ""
    echo "Cibles:"
    echo "  mobile     - Application mobile React Native"
    echo "  monitoring - Services de monitoring (Grafana, Prometheus, SonarQube)"
    echo "  all        - Toutes les cibles"
    echo ""
    echo "Exemples:"
    echo "  $0 build mobile     # Construit et pousse l'image de l'application mobile"
    echo "  $0 deploy monitoring # Déploie les services de monitoring"
    echo "  $0 all all          # Construit, pousse et déploie toutes les images"
    echo ""
    exit 1
}

# Vérifier si Docker est installé
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "[ERROR] Docker n'est pas installé. Veuillez l'installer avant d'exécuter ce script."
        exit 1
    fi
}

# Vérifier les variables requises pour le déploiement
check_deploy_vars() {
    # Vérifier les variables essentielles
    if [ -z "$SSH_KEY" ]; then
        echo "[ERROR] La clé SSH privée n'est pas définie. Veuillez définir la variable EC2_SSH_PRIVATE_KEY."
        exit 1
    fi

    if [ -z "$DOCKERHUB_TOKEN" ]; then
        echo "[ERROR] Le token Docker Hub n'est pas défini. Veuillez définir la variable DOCKERHUB_TOKEN."
        exit 1
    fi

    # Vérifier les variables spécifiques à la cible
    if [ "$TARGET" = "mobile" ] || [ "$TARGET" = "all" ]; then
        if [ -z "$EC2_APP_IP" ]; then
            echo "[ERROR] L'adresse IP de l'instance EC2 de l'application n'est pas définie. Veuillez définir la variable TF_EC2_PUBLIC_IP."
            exit 1
        fi
    fi

    if [ "$TARGET" = "monitoring" ] || [ "$TARGET" = "all" ]; then
        if [ -z "$EC2_MONITORING_IP" ]; then
            echo "[ERROR] L'adresse IP de l'instance EC2 de monitoring n'est pas définie. Veuillez définir la variable TF_MONITORING_EC2_PUBLIC_IP."
            exit 1
        fi

        # Vérifier les variables de base de données pour le monitoring
        if [ -z "$DB_USERNAME" ] || [ -z "$DB_PASSWORD" ] || [ -z "$RDS_ENDPOINT" ]; then
            echo "[ERROR] Les informations de connexion à la base de données ne sont pas complètes."
            echo "[ERROR] Veuillez définir les variables DB_USERNAME, DB_PASSWORD et TF_RDS_ENDPOINT."
            exit 1
        fi

        # Vérifier les variables GitHub pour SonarQube
        if [ -z "$GITHUB_CLIENT_ID" ] || [ -z "$GITHUB_CLIENT_SECRET" ]; then
            echo "[WARNING] Les informations d'authentification GitHub pour SonarQube ne sont pas définies."
            echo "[WARNING] L'intégration GitHub avec SonarQube ne sera pas disponible."
            echo "[WARNING] Veuillez définir les variables GITHUB_CLIENT_ID et GITHUB_CLIENT_SECRET pour activer cette fonctionnalité."
            read -p "Voulez-vous continuer sans l'intégration GitHub? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "[INFO] Opération annulée. Veuillez définir les variables GitHub."
                exit 1
            fi
        fi
    fi
}

# Connexion à Docker Hub
docker_login() {
    echo "[INFO] Connexion à Docker Hub..."
    echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKER_USERNAME" --password-stdin
}

# Fonction pour construire et pousser l'image mobile
build_push_mobile() {
    echo "[INFO] Construction de l'image Docker pour l'application mobile..."
    cd ../app-react
    docker build -t $DOCKER_USERNAME/$DOCKER_REPO:mobile-$VERSION -t $DOCKER_USERNAME/$DOCKER_REPO:mobile-latest .

    echo "[INFO] Publication de l'image mobile sur Docker Hub..."
    docker push $DOCKER_USERNAME/$DOCKER_REPO:mobile-$VERSION
    docker push $DOCKER_USERNAME/$DOCKER_REPO:mobile-latest

    echo "[SUCCESS] Image mobile publiée avec succès!"
    cd -
}

# Fonction pour construire et pousser les images de monitoring
build_push_monitoring() {
    echo "[INFO] Construction de l'image Docker pour Grafana..."
    cd ../scripts/docker/grafana
    docker build -t $DOCKER_USERNAME/$DOCKER_REPO:grafana-$VERSION -t $DOCKER_USERNAME/$DOCKER_REPO:grafana-latest .

    echo "[INFO] Publication de l'image Grafana sur Docker Hub..."
    docker push $DOCKER_USERNAME/$DOCKER_REPO:grafana-$VERSION
    docker push $DOCKER_USERNAME/$DOCKER_REPO:grafana-latest

    echo "[INFO] Construction de l'image Docker pour Prometheus..."
    cd ../prometheus
    docker build -t $DOCKER_USERNAME/$DOCKER_REPO:prometheus-$VERSION -t $DOCKER_USERNAME/$DOCKER_REPO:prometheus-latest .

    echo "[INFO] Publication de l'image Prometheus sur Docker Hub..."
    docker push $DOCKER_USERNAME/$DOCKER_REPO:prometheus-$VERSION
    docker push $DOCKER_USERNAME/$DOCKER_REPO:prometheus-latest

    echo "[INFO] Construction de l'image Docker pour SonarQube..."
    cd ../sonarqube
    docker build -t $DOCKER_USERNAME/$DOCKER_REPO:sonarqube-$VERSION -t $DOCKER_USERNAME/$DOCKER_REPO:sonarqube-latest .

    echo "[INFO] Publication de l'image SonarQube sur Docker Hub..."
    docker push $DOCKER_USERNAME/$DOCKER_REPO:sonarqube-$VERSION
    docker push $DOCKER_USERNAME/$DOCKER_REPO:sonarqube-latest

    echo "[SUCCESS] Images de monitoring publiées avec succès!"
    cd -
}

# Fonction pour déployer les conteneurs de monitoring
deploy_monitoring() {
    echo "[INFO] Déploiement des conteneurs de monitoring sur $EC2_MONITORING_IP..."

    # Créer un fichier temporaire pour la clé SSH
    # Supprimer les guillemets simples qui pourraient être présents dans la clé
    CLEAN_SSH_KEY=$(echo "$SSH_KEY" | sed "s/'//g")
    echo "$CLEAN_SSH_KEY" > ssh_key.pem
    chmod 600 ssh_key.pem

    # Se connecter à l'instance EC2 et déployer les conteneurs
    ssh -i ssh_key.pem -o StrictHostKeyChecking=no ec2-user@$EC2_MONITORING_IP << EOF
        # Connexion à Docker Hub
        echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKER_USERNAME" --password-stdin

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

    # Supprimer le fichier temporaire de la clé SSH
    rm ssh_key.pem

    echo "[SUCCESS] Déploiement des conteneurs de monitoring terminé."
}

# Fonction pour déployer l'application mobile
deploy_mobile() {
    echo "[INFO] Déploiement de l'application mobile sur $EC2_APP_IP..."

    # Créer un fichier temporaire pour la clé SSH
    # Supprimer les guillemets simples qui pourraient être présents dans la clé
    CLEAN_SSH_KEY=$(echo "$SSH_KEY" | sed "s/'//g")
    echo "$CLEAN_SSH_KEY" > ssh_key.pem
    chmod 600 ssh_key.pem

    # Se connecter à l'instance EC2 et déployer les conteneurs
    ssh -i ssh_key.pem -o StrictHostKeyChecking=no ec2-user@$EC2_APP_IP << EOF
        # Connexion à Docker Hub
        echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKER_USERNAME" --password-stdin

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

    # Supprimer le fichier temporaire de la clé SSH
    rm ssh_key.pem

    echo "[SUCCESS] Déploiement de l'application mobile terminé."
}

# Vérifier les arguments
if [ "$ACTION" != "build" ] && [ "$ACTION" != "deploy" ] && [ "$ACTION" != "all" ]; then
    echo "[ERROR] Action inconnue: $ACTION"
    show_help
fi

if [ "$TARGET" != "mobile" ] && [ "$TARGET" != "monitoring" ] && [ "$TARGET" != "all" ]; then
    echo "[ERROR] Cible inconnue: $TARGET"
    show_help
fi

# Exécution en fonction de l'action et de la cible
case $ACTION in
    build)
        check_docker
        docker_login
        case $TARGET in
            mobile)
                build_push_mobile
                ;;
            monitoring)
                build_push_monitoring
                ;;
            all)
                build_push_mobile
                build_push_monitoring
                ;;
        esac
        ;;
    deploy)
        check_deploy_vars
        case $TARGET in
            mobile)
                deploy_mobile
                ;;
            monitoring)
                deploy_monitoring
                ;;
            all)
                deploy_monitoring
                deploy_mobile
                ;;
        esac
        ;;
    all)
        check_docker
        check_deploy_vars
        docker_login
        case $TARGET in
            mobile)
                build_push_mobile
                deploy_mobile
                ;;
            monitoring)
                build_push_monitoring
                deploy_monitoring
                ;;
            all)
                build_push_mobile
                build_push_monitoring
                deploy_monitoring
                deploy_mobile
                ;;
        esac
        ;;
esac

echo "[SUCCESS] Opérations terminées avec succès!"
