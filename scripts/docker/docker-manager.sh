#!/bin/bash

# Script pour gérer les images Docker et les conteneurs
# Utilisation: ./docker-manager.sh [build|deploy|all] [mobile|monitoring|all]
#
# EXIGENCES EN MATIÈRE DE DROITS :
# Ce script doit être exécuté avec des privilèges sudo ou en tant que root pour certaines opérations.
# Exemple d'utilisation : sudo ./docker-manager.sh deploy monitoring
#
# Le script vérifie automatiquement les droits et affichera une erreur si nécessaire.

# Fonction pour afficher les messages d'information
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] $1"
}

# Fonction pour afficher les messages d'avertissement
log_warning() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [WARNING] $1" >&2
}

# Fonction pour afficher les messages d'erreur et quitter
log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [ERROR] $1" >&2
    # Capturer la trace d'appel pour le débogage
    if [ "${DEBUG:-false}" = "true" ]; then
        echo "Trace d'appel:" >&2
        local i=0
        while caller $i; do
            i=$((i+1))
        done >&2
    fi
    exit 1
}

# Fonction pour afficher les messages de succès
log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [SUCCESS] $1"
}

# Variables avec noms standardisés
# Variables Docker
DOCKER_USERNAME=${DOCKERHUB_USERNAME:-medsin}
DOCKER_REPO=${DOCKERHUB_REPO:-yourmedia-ecf}
DOCKER_VERSION=$(date +%Y%m%d%H%M%S)

# Variables d'action
ACTION=${1:-all}
TARGET=${2:-all}

# Variables EC2
EC2_MONITORING_IP=${TF_MONITORING_EC2_PUBLIC_IP}
EC2_APP_IP=${TF_EC2_PUBLIC_IP}
EC2_SSH_KEY="${EC2_SSH_PRIVATE_KEY}"

# Variables Grafana
GRAFANA_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD:-admin}

# Variables RDS
RDS_USERNAME=${DB_USERNAME}
RDS_PASSWORD=${DB_PASSWORD}
RDS_ENDPOINT=${TF_RDS_ENDPOINT}

# Variables GitHub
GITHUB_CLIENT_ID=${GITHUB_CLIENT_ID}
GITHUB_CLIENT_SECRET=${GITHUB_CLIENT_SECRET}

# Déterminer le chemin absolu du répertoire racine du projet
# Obtenir le chemin absolu du répertoire contenant ce script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Remonter au répertoire racine du projet (2 niveaux au-dessus de scripts/docker)
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Afficher les variables pour le débogage
log_info "Variables d'environnement utilisées:"
log_info "- DOCKER_USERNAME: $DOCKER_USERNAME"
log_info "- DOCKER_REPO: $DOCKER_REPO"
log_info "- DOCKER_VERSION: $DOCKER_VERSION"
log_info "- EC2_MONITORING_IP: $EC2_MONITORING_IP"
log_info "- EC2_APP_IP: $EC2_APP_IP"
log_info "- RDS_ENDPOINT: $RDS_ENDPOINT"

# Vérification des mots de passe par défaut
if [ "$GRAFANA_ADMIN_PASSWORD" = "admin" ]; then
    log_warning "Le mot de passe administrateur Grafana est défini sur la valeur par défaut 'admin'."
    log_warning "Il est fortement recommandé de définir un mot de passe plus sécurisé via la variable GF_SECURITY_ADMIN_PASSWORD."

    # Vérifier si le script est exécuté en mode interactif
    if [ -t 0 ]; then
        # Mode interactif
        read -p "Voulez-vous continuer avec ce mot de passe par défaut? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Opération annulée. Veuillez définir un mot de passe plus sécurisé."
            exit 1
        fi
    else
        # Mode non interactif (CI/CD)
        log_warning "Exécution en mode non interactif. Continuation avec le mot de passe par défaut."
        log_warning "Pensez à changer le mot de passe après le déploiement."
    fi
fi

# Afficher la bannière
echo "========================================================="
echo "=== Script de gestion Docker pour YourMedia ==="
echo "========================================================="



# Fonction pour gérer les erreurs de commande
handle_error() {
    local exit_code=$1
    local error_message=${2:-"Une erreur s'est produite"}

    if [ $exit_code -ne 0 ]; then
        log_error "$error_message (code: $exit_code)"
    fi
}

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

# Fonction pour vérifier si une commande est installée
check_dependency() {
    local cmd=$1
    local pkg=${2:-$1}

    if ! command -v $cmd &> /dev/null; then
        log_warning "Dépendance manquante: $cmd"

        # Vérifier si nous pouvons installer le package
        if [ "$(id -u)" -eq 0 ] || sudo -n true 2>/dev/null; then
            log_info "Installation de $pkg..."
            if [ "$(id -u)" -eq 0 ]; then
                dnf install -y $pkg || apt-get install -y $pkg || log_error "Impossible d'installer $pkg"
            else
                sudo dnf install -y $pkg || sudo apt-get install -y $pkg || log_error "Impossible d'installer $pkg"
            fi
        else
            log_error "La commande $cmd n'est pas installée et nous n'avons pas les privilèges pour l'installer. Veuillez l'installer manuellement."
        fi
    fi
}

# Vérifier si Docker est installé et si l'utilisateur a les droits sudo
check_docker() {
    # Vérifier les dépendances requises
    check_dependency docker docker-ce
    check_dependency docker-compose docker-compose-plugin
    check_dependency curl curl
    check_dependency openssl openssl

    # Vérifier si l'utilisateur a les droits sudo
    if [ "$(id -u)" -ne 0 ]; then
        log_warning "Ce script nécessite des privilèges sudo pour certaines opérations."

        # Vérifier si sudo est disponible sans mot de passe
        if sudo -n true 2>/dev/null; then
            log_info "Privilèges sudo disponibles sans mot de passe."
        else
            log_info "Tentative d'obtention des privilèges sudo..."
            if ! sudo -v; then
                log_error "Impossible d'obtenir les privilèges sudo. Certaines opérations pourraient échouer. Il est recommandé d'exécuter ce script avec sudo ou en tant que root."

                # Demander à l'utilisateur s'il souhaite continuer
                if [ -t 0 ]; then  # Vérifier si le script est exécuté en mode interactif
                    read -p "Voulez-vous continuer quand même? (y/n) " -n 1 -r
                    echo
                    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                        log_info "Opération annulée."
                        exit 1
                    fi
                else
                    # Mode non interactif, sortir avec une erreur
                    exit 1
                fi
            else
                log_info "Privilèges sudo obtenus avec succès."
            fi
        fi
    fi
}

# Vérifier les variables requises pour le déploiement
check_deploy_vars() {
    # Vérifier les variables essentielles
    if [ -z "$EC2_SSH_KEY" ]; then
        log_error "La clé SSH privée n'est pas définie. Veuillez définir la variable EC2_SSH_PRIVATE_KEY."
    fi

    if [ -z "$DOCKERHUB_TOKEN" ]; then
        log_error "Le token Docker Hub n'est pas défini. Veuillez définir la variable DOCKERHUB_TOKEN."
    fi

    # Vérifier les variables spécifiques à la cible
    if [ "$TARGET" = "mobile" ] || [ "$TARGET" = "all" ]; then
        if [ -z "$EC2_APP_IP" ]; then
            log_error "L'adresse IP de l'instance EC2 de l'application n'est pas définie. Veuillez définir la variable TF_EC2_PUBLIC_IP."
        fi
    fi

    if [ "$TARGET" = "monitoring" ] || [ "$TARGET" = "all" ]; then
        if [ -z "$EC2_MONITORING_IP" ]; then
            log_error "L'adresse IP de l'instance EC2 de monitoring n'est pas définie. Veuillez définir la variable TF_MONITORING_EC2_PUBLIC_IP."
        fi

        # Vérifier les variables de base de données pour le monitoring
        if [ -z "$RDS_USERNAME" ] || [ -z "$RDS_PASSWORD" ] || [ -z "$RDS_ENDPOINT" ]; then
            log_error "Les informations de connexion à la base de données ne sont pas complètes. Veuillez définir les variables RDS_USERNAME (DB_USERNAME), RDS_PASSWORD (DB_PASSWORD) et RDS_ENDPOINT (TF_RDS_ENDPOINT)."
        fi

        # Vérifier les variables GitHub pour SonarQube
        if [ -z "$GITHUB_CLIENT_ID" ] || [ -z "$GITHUB_CLIENT_SECRET" ]; then
            log_warning "Les informations d'authentification GitHub pour SonarQube ne sont pas définies."
            log_warning "L'intégration GitHub avec SonarQube ne sera pas disponible."
            log_warning "Veuillez définir les variables GITHUB_CLIENT_ID et GITHUB_CLIENT_SECRET pour activer cette fonctionnalité."

            if [ -t 0 ]; then  # Vérifier si le script est exécuté en mode interactif
                read -p "Voulez-vous continuer sans l'intégration GitHub? (y/n) " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    log_info "Opération annulée. Veuillez définir les variables GitHub."
                    exit 1
                fi
            else
                log_info "Mode non interactif. Continuation sans l'intégration GitHub."
            fi
        fi
    fi
}

# Connexion à Docker Hub
docker_login() {
    log_info "Connexion à Docker Hub..."
    echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKER_USERNAME" --password-stdin || log_error "Échec de la connexion à Docker Hub"
}

# Fonction pour construire et pousser l'image mobile
build_push_mobile() {
    log_info "Construction de l'image Docker pour l'application mobile..."
    # Utiliser le chemin absolu pour l'application mobile
    APP_REACT_DIR="${PROJECT_ROOT}/app-react"

    # Vérifier que le répertoire existe
    if [ ! -d "$APP_REACT_DIR" ]; then
        log_error "Le répertoire de l'application mobile n'existe pas: $APP_REACT_DIR"
    fi

    # Construire l'image depuis le répertoire de l'application
    docker build -t $DOCKER_USERNAME/$DOCKER_REPO:mobile-$DOCKER_VERSION -t $DOCKER_USERNAME/$DOCKER_REPO:mobile-latest "$APP_REACT_DIR" || log_error "Échec de la construction de l'image mobile"

    log_info "Publication de l'image mobile sur Docker Hub..."
    docker push $DOCKER_USERNAME/$DOCKER_REPO:mobile-$DOCKER_VERSION || log_error "Échec de la publication de l'image mobile (version)"
    docker push $DOCKER_USERNAME/$DOCKER_REPO:mobile-latest || log_error "Échec de la publication de l'image mobile (latest)"

    log_success "Image mobile publiée avec succès!"
}

# Fonction pour construire et pousser les images de monitoring
build_push_monitoring() {
    # Définir les chemins absolus pour les répertoires Docker
    GRAFANA_DIR="${PROJECT_ROOT}/scripts/docker/grafana"
    PROMETHEUS_DIR="${PROJECT_ROOT}/scripts/docker/prometheus"
    SONARQUBE_DIR="${PROJECT_ROOT}/scripts/docker/sonarqube"

    # Vérifier que les répertoires existent
    for DIR in "$GRAFANA_DIR" "$PROMETHEUS_DIR" "$SONARQUBE_DIR"; do
        if [ ! -d "$DIR" ]; then
            log_error "Le répertoire n'existe pas: $DIR"
        fi
    done

    log_info "Construction de l'image Docker pour Grafana..."
    docker build -t $DOCKER_USERNAME/$DOCKER_REPO:grafana-$DOCKER_VERSION -t $DOCKER_USERNAME/$DOCKER_REPO:grafana-latest "$GRAFANA_DIR" || log_error "Échec de la construction de l'image Grafana"

    log_info "Publication de l'image Grafana sur Docker Hub..."
    docker push $DOCKER_USERNAME/$DOCKER_REPO:grafana-$DOCKER_VERSION || log_error "Échec de la publication de l'image Grafana (version)"
    docker push $DOCKER_USERNAME/$DOCKER_REPO:grafana-latest || log_error "Échec de la publication de l'image Grafana (latest)"

    log_info "Construction de l'image Docker pour Prometheus..."
    docker build -t $DOCKER_USERNAME/$DOCKER_REPO:prometheus-$DOCKER_VERSION -t $DOCKER_USERNAME/$DOCKER_REPO:prometheus-latest "$PROMETHEUS_DIR" || log_error "Échec de la construction de l'image Prometheus"

    log_info "Publication de l'image Prometheus sur Docker Hub..."
    docker push $DOCKER_USERNAME/$DOCKER_REPO:prometheus-$DOCKER_VERSION || log_error "Échec de la publication de l'image Prometheus (version)"
    docker push $DOCKER_USERNAME/$DOCKER_REPO:prometheus-latest || log_error "Échec de la publication de l'image Prometheus (latest)"

    log_info "Construction de l'image Docker pour SonarQube..."
    docker build -t $DOCKER_USERNAME/$DOCKER_REPO:sonarqube-$DOCKER_VERSION -t $DOCKER_USERNAME/$DOCKER_REPO:sonarqube-latest "$SONARQUBE_DIR" || log_error "Échec de la construction de l'image SonarQube"

    log_info "Publication de l'image SonarQube sur Docker Hub..."
    docker push $DOCKER_USERNAME/$DOCKER_REPO:sonarqube-$DOCKER_VERSION || log_error "Échec de la publication de l'image SonarQube (version)"
    docker push $DOCKER_USERNAME/$DOCKER_REPO:sonarqube-latest || log_error "Échec de la publication de l'image SonarQube (latest)"

    log_success "Images de monitoring publiées avec succès!"
}

# Fonction pour déployer les conteneurs de monitoring
deploy_monitoring() {
    log_info "Déploiement des conteneurs de monitoring sur $EC2_MONITORING_IP..."

    # Utiliser un fichier temporaire sécurisé pour la clé SSH avec un nom aléatoire
    # Supprimer les guillemets simples qui pourraient être présents dans la clé
    CLEAN_SSH_KEY=$(echo "$EC2_SSH_KEY" | sed "s/'//g")
    SSH_KEY_FILE=$(mktemp -p /tmp ssh_key_XXXXXXXX)
    echo "$CLEAN_SSH_KEY" > "$SSH_KEY_FILE"
    chmod 400 "$SSH_KEY_FILE" || log_error "Impossible de définir les permissions sur le fichier de clé SSH"
    # Ajouter le fichier à la liste des fichiers à supprimer à la fin
    trap "rm -f $SSH_KEY_FILE" EXIT

    # Se connecter à l'instance EC2 et déployer les conteneurs
    ssh -i "$SSH_KEY_FILE" -o StrictHostKeyChecking=no ec2-user@$EC2_MONITORING_IP << EOF
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
      - GF_SECURITY_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD
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
      - DATA_SOURCE_NAME=$RDS_USERNAME:$RDS_PASSWORD@($RDS_ENDPOINT:3306)/
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
      - POSTGRES_USER=${SONAR_JDBC_USERNAME:-sonar}
      - POSTGRES_PASSWORD=${SONAR_JDBC_PASSWORD:-$(openssl rand -base64 16)}
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
        sed -i "s/\$GF_SECURITY_ADMIN_PASSWORD/$GRAFANA_ADMIN_PASSWORD/g" /tmp/docker-compose.yml
        sed -i "s/\$DB_USERNAME/$RDS_USERNAME/g" /tmp/docker-compose.yml
        sed -i "s/\$DB_PASSWORD/$RDS_PASSWORD/g" /tmp/docker-compose.yml
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

    # Le fichier temporaire de la clé SSH sera supprimé automatiquement grâce au trap EXIT

    log_success "Déploiement des conteneurs de monitoring terminé."
}

# Fonction pour déployer l'application mobile
deploy_mobile() {
    log_info "Déploiement de l'application mobile sur $EC2_APP_IP..."

    # Utiliser un fichier temporaire sécurisé pour la clé SSH avec un nom aléatoire
    # Supprimer les guillemets simples qui pourraient être présents dans la clé
    CLEAN_SSH_KEY=$(echo "$EC2_SSH_KEY" | sed "s/'//g")
    SSH_KEY_FILE=$(mktemp -p /tmp ssh_key_XXXXXXXX)
    echo "$CLEAN_SSH_KEY" > "$SSH_KEY_FILE"
    chmod 400 "$SSH_KEY_FILE" || log_error "Impossible de définir les permissions sur le fichier de clé SSH"
    # Ajouter le fichier à la liste des fichiers à supprimer à la fin
    trap "rm -f $SSH_KEY_FILE" EXIT

    # Se connecter à l'instance EC2 et déployer les conteneurs
    ssh -i "$SSH_KEY_FILE" -o StrictHostKeyChecking=no ec2-user@$EC2_APP_IP << EOF
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

    # Le fichier temporaire de la clé SSH sera supprimé automatiquement grâce au trap EXIT

    log_success "Déploiement de l'application mobile terminé."
}

# Vérifier les arguments
if [ "$ACTION" != "build" ] && [ "$ACTION" != "deploy" ] && [ "$ACTION" != "all" ]; then
    log_error "Action inconnue: $ACTION"
    show_help
fi

if [ "$TARGET" != "mobile" ] && [ "$TARGET" != "monitoring" ] && [ "$TARGET" != "all" ]; then
    log_error "Cible inconnue: $TARGET"
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

log_success "Opérations terminées avec succès!"
