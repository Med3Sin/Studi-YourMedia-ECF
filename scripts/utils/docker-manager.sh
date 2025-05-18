#!/bin/bash
#==============================================================================
# Nom du script : docker-manager.sh
# Description   : Script pour gérer les images Docker et les conteneurs.
#                 Permet de construire, pousser et déployer des images Docker.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.2
# Date          : 2023-11-15
#==============================================================================
# Utilisation   : ./docker-manager.sh [action] [cible] [options]
#
# Actions       :
#   build       : Construit et pousse les images Docker vers Docker Hub
#   deploy      : Déploie les conteneurs Docker sur les instances EC2
#   all         : Exécute les actions build et deploy
#   backup      : Sauvegarde les données des conteneurs Docker
#   restore     : Restaure les données des conteneurs Docker
#   cleanup     : Nettoie les conteneurs, images et volumes Docker
#
# Cibles        :
#   mobile      : Application mobile React Native
#   monitoring  : Services de monitoring (Grafana, Prometheus)
#   all         : Toutes les cibles
#
# Options pour backup/restore :
#   --s3-bucket : Nom du bucket S3 pour stocker/récupérer les sauvegardes
#
# Options pour cleanup :
#   --type      : Type de nettoyage (all, containers, images, volumes, networks, prune)
#
# Exemples      :
#   ./docker-manager.sh build mobile     # Construit et pousse l'image de l'application mobile
#   ./docker-manager.sh deploy monitoring # Déploie les services de monitoring
#   ./docker-manager.sh all all          # Construit, pousse et déploie toutes les images
#   ./docker-manager.sh backup all --s3-bucket=yourmedia-backups # Sauvegarde tous les conteneurs
#   ./docker-manager.sh restore all --s3-bucket=yourmedia-backups # Restaure tous les conteneurs
#   ./docker-manager.sh cleanup all --type=containers # Nettoie uniquement les conteneurs
#==============================================================================
# Dépendances   :
#   - docker    : Pour construire et gérer les conteneurs
#   - docker-compose : Pour orchestrer les conteneurs
#   - curl      : Pour les requêtes HTTP
#   - openssl   : Pour les opérations cryptographiques
#   - ssh       : Pour se connecter aux instances EC2
#==============================================================================
# Variables d'environnement :
#   - DOCKERHUB_USERNAME : Nom d'utilisateur Docker Hub (standard)
#   - DOCKERHUB_REPO : Nom du dépôt Docker Hub (standard)
#   - DOCKERHUB_TOKEN : Token d'authentification Docker Hub (standard)
#   - DOCKER_USERNAME : Alias pour DOCKERHUB_USERNAME (compatibilité)
#   - DOCKER_REPO : Alias pour DOCKERHUB_REPO (compatibilité)
#   - EC2_MONITORING_IP / TF_MONITORING_EC2_PUBLIC_IP : IP publique de l'instance EC2 de monitoring
#   - EC2_APP_IP / TF_EC2_PUBLIC_IP : IP publique de l'instance EC2 de l'application
#   - EC2_SSH_KEY / EC2_SSH_PRIVATE_KEY : Clé SSH privée pour se connecter aux instances EC2
#   - GRAFANA_ADMIN_PASSWORD / GF_SECURITY_ADMIN_PASSWORD : Mot de passe administrateur Grafana
#   - RDS_USERNAME / DB_USERNAME : Nom d'utilisateur RDS
#   - RDS_PASSWORD / DB_PASSWORD : Mot de passe RDS
#   - RDS_ENDPOINT / DB_ENDPOINT / TF_RDS_ENDPOINT : Point de terminaison RDS

#==============================================================================
# Droits requis : Ce script doit être exécuté avec des privilèges sudo ou en tant que root pour certaines opérations.
#==============================================================================

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

# Variables Docker standardisées
export DOCKERHUB_USERNAME=${DOCKERHUB_USERNAME:-medsin}
export DOCKERHUB_REPO=${DOCKERHUB_REPO:-yourmedia-ecf}
# Variables de compatibilité (pour les scripts existants)
export DOCKER_USERNAME=${DOCKER_USERNAME:-$DOCKERHUB_USERNAME}
export DOCKER_REPO=${DOCKER_REPO:-$DOCKERHUB_REPO}
export DOCKER_VERSION=$(date +%Y%m%d%H%M%S)

# Variables d'action
ACTION=${1:-all}
TARGET=${2:-all}

# Traitement des options supplémentaires
S3_BUCKET=""
CLEANUP_TYPE="all"

# Parcourir les arguments supplémentaires
shift 2 2>/dev/null || true
while [[ $# -gt 0 ]]; do
    case $1 in
        --s3-bucket=*)
            S3_BUCKET="${1#*=}"
            shift
            ;;
        --type=*)
            CLEANUP_TYPE="${1#*=}"
            shift
            ;;
        *)
            log_warning "Option inconnue: $1"
            shift
            ;;
    esac
done

# Variables EC2 - Utiliser plusieurs sources possibles pour les adresses IP
export EC2_MONITORING_IP=${TF_MONITORING_EC2_PUBLIC_IP:-${MONITORING_EC2_PUBLIC_IP:-""}}
export EC2_APP_IP=${TF_EC2_PUBLIC_IP:-${EC2_PUBLIC_IP:-""}}
export EC2_SSH_KEY="${EC2_SSH_PRIVATE_KEY}"

# Afficher un message si les variables ne sont pas définies
if [ -z "$EC2_MONITORING_IP" ]; then
    log_warning "La variable EC2_MONITORING_IP n'est pas définie. Certaines fonctionnalités pourraient ne pas fonctionner correctement."
fi

if [ -z "$EC2_APP_IP" ]; then
    log_warning "La variable EC2_APP_IP n'est pas définie. Certaines fonctionnalités pourraient ne pas fonctionner correctement."
fi

# Variables Grafana
export GRAFANA_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD:-YourMedia2025!}
export GF_SECURITY_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD:-$GRAFANA_ADMIN_PASSWORD}

# Variables RDS
export RDS_USERNAME=${RDS_USERNAME:-${DB_USERNAME}}
export DB_USERNAME=${DB_USERNAME:-$RDS_USERNAME}
export RDS_PASSWORD=${RDS_PASSWORD:-${DB_PASSWORD}}
export DB_PASSWORD=${DB_PASSWORD:-$RDS_PASSWORD}
export RDS_ENDPOINT=${RDS_ENDPOINT:-${TF_RDS_ENDPOINT}}
export DB_ENDPOINT=${DB_ENDPOINT:-$RDS_ENDPOINT}

# Extraire l'hôte et le port de RDS_ENDPOINT
if [[ "$RDS_ENDPOINT" == *":"* ]]; then
    export RDS_HOST=$(echo "$RDS_ENDPOINT" | cut -d':' -f1)
    export RDS_PORT=$(echo "$RDS_ENDPOINT" | cut -d':' -f2)
else
    export RDS_HOST="$RDS_ENDPOINT"
    export RDS_PORT="3306"
fi



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
        return 1
    fi
    return 0
}

# Fonction d'aide
show_help() {
    echo "Usage: $0 [action] [cible] [options]"
    echo ""
    echo "Actions:"
    echo "  build      - Construit et pousse les images Docker vers Docker Hub"
    echo "  deploy     - Déploie les conteneurs Docker sur les instances EC2"
    echo "  all        - Exécute les actions build et deploy"
    echo "  backup     - Sauvegarde les données des conteneurs Docker"
    echo "  restore    - Restaure les données des conteneurs Docker"
    echo "  cleanup    - Nettoie les conteneurs, images et volumes Docker"
    echo ""
    echo "Cibles:"
    echo "  mobile     - Application mobile React Native"
    echo "  monitoring - Services de monitoring (Grafana, Prometheus)"
    echo "  all        - Toutes les cibles"
    echo ""
    echo "Options pour backup/restore:"
    echo "  --s3-bucket=NOM - Nom du bucket S3 pour stocker/récupérer les sauvegardes"
    echo ""
    echo "Options pour cleanup:"
    echo "  --type=TYPE     - Type de nettoyage (all, containers, images, volumes, networks, prune)"
    echo ""
    echo "Exemples:"
    echo "  $0 build mobile     # Construit et pousse l'image de l'application mobile"
    echo "  $0 deploy monitoring # Déploie les services de monitoring"
    echo "  $0 all all          # Construit, pousse et déploie toutes les images"
    echo "  $0 backup all --s3-bucket=yourmedia-backups # Sauvegarde tous les conteneurs"
    echo "  $0 restore all --s3-bucket=yourmedia-backups # Restaure tous les conteneurs"
    echo "  $0 cleanup all --type=containers # Nettoie uniquement les conteneurs"
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

    # Pour l'action cleanup, nous n'avons pas besoin de vérifier le token Docker Hub
    if [ "$ACTION" != "cleanup" ] && [ -z "$DOCKERHUB_TOKEN" ]; then
        log_error "Le token Docker Hub n'est pas défini. Veuillez définir la variable DOCKERHUB_TOKEN."
    fi

    # Vérifier les variables spécifiques à la cible
    if [ "$TARGET" = "mobile" ] || [ "$TARGET" = "all" ]; then
        # L'application mobile est maintenant déployée sur l'instance de monitoring
        if [ -z "$EC2_MONITORING_IP" ]; then
            if [ "$ACTION" = "cleanup" ]; then
                log_warning "L'adresse IP de l'instance EC2 de monitoring n'est pas définie. Le nettoyage ne sera pas effectué pour cette cible."
                # Si nous sommes en train de nettoyer et que la cible est 'all', on continue avec les autres cibles
                if [ "$TARGET" = "all" ]; then
                    return 0
                else
                    # Sinon, on sort avec un code d'erreur
                    return 1
                fi
            else
                log_error "L'adresse IP de l'instance EC2 de monitoring n'est pas définie. Veuillez définir la variable TF_MONITORING_EC2_PUBLIC_IP ou MONITORING_EC2_PUBLIC_IP."
            fi
        fi

        # Avertissement si EC2_APP_IP est défini mais pas utilisé
        if [ -n "$EC2_APP_IP" ]; then
            log_warning "La variable EC2_APP_IP est définie mais n'est plus utilisée. L'application mobile est maintenant déployée sur l'instance de monitoring (EC2_MONITORING_IP)."
        fi
    fi

    if [ "$TARGET" = "monitoring" ] || [ "$TARGET" = "all" ]; then
        if [ -z "$EC2_MONITORING_IP" ]; then
            if [ "$ACTION" = "cleanup" ]; then
                log_warning "L'adresse IP de l'instance EC2 de monitoring n'est pas définie. Le nettoyage ne sera pas effectué pour cette cible."
                # Si nous sommes en train de nettoyer et que la cible est 'all', on continue avec les autres cibles
                if [ "$TARGET" = "all" ]; then
                    return 0
                else
                    # Sinon, on sort avec un code d'erreur
                    return 1
                fi
            else
                log_error "L'adresse IP de l'instance EC2 de monitoring n'est pas définie. Veuillez définir la variable TF_MONITORING_EC2_PUBLIC_IP ou MONITORING_EC2_PUBLIC_IP."
            fi
        fi

        # Vérifier les variables de base de données pour le monitoring
        # Pour l'action cleanup, nous n'avons pas besoin de vérifier les variables de base de données
        if [ "$ACTION" != "cleanup" ] && ([ -z "$RDS_USERNAME" ] || [ -z "$RDS_PASSWORD" ] || [ -z "$RDS_ENDPOINT" ]); then
            log_error "Les informations de connexion à la base de données ne sont pas complètes. Veuillez définir les variables RDS_USERNAME (DB_USERNAME), RDS_PASSWORD (DB_PASSWORD) et RDS_ENDPOINT (TF_RDS_ENDPOINT)."
        fi
    fi
}

# Connexion à Docker Hub
docker_login() {
    log_info "Connexion à Docker Hub..."
    echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin || log_error "Échec de la connexion à Docker Hub"
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
    docker build -t $DOCKERHUB_USERNAME/$DOCKERHUB_REPO:mobile-$DOCKER_VERSION -t $DOCKERHUB_USERNAME/$DOCKERHUB_REPO:mobile-latest "$APP_REACT_DIR" || log_error "Échec de la construction de l'image mobile"

    log_info "Publication de l'image mobile sur Docker Hub..."
    docker push $DOCKERHUB_USERNAME/$DOCKERHUB_REPO:mobile-$DOCKER_VERSION || log_error "Échec de la publication de l'image mobile (version)"
    docker push $DOCKERHUB_USERNAME/$DOCKERHUB_REPO:mobile-latest || log_error "Échec de la publication de l'image mobile (latest)"

    log_success "Image mobile publiée avec succès!"
}

# Fonction pour construire et pousser les images de monitoring
build_push_monitoring() {
    # Définir les chemins absolus pour les répertoires Docker
    GRAFANA_DIR="${PROJECT_ROOT}/scripts/config/grafana"
    PROMETHEUS_DIR="${PROJECT_ROOT}/scripts/config/prometheus"

    # Vérifier que les répertoires existent
    for DIR in "$GRAFANA_DIR" "$PROMETHEUS_DIR"; do
        if [ ! -d "$DIR" ]; then
            log_error "Le répertoire n'existe pas: $DIR"
        fi
    done

    log_info "Construction de l'image Docker pour Grafana..."
    docker build -t $DOCKERHUB_USERNAME/$DOCKERHUB_REPO:grafana-$DOCKER_VERSION -t $DOCKERHUB_USERNAME/$DOCKERHUB_REPO:grafana-latest "$GRAFANA_DIR" || log_error "Échec de la construction de l'image Grafana"

    log_info "Publication de l'image Grafana sur Docker Hub..."
    docker push $DOCKERHUB_USERNAME/$DOCKERHUB_REPO:grafana-$DOCKER_VERSION || log_error "Échec de la publication de l'image Grafana (version)"
    docker push $DOCKERHUB_USERNAME/$DOCKERHUB_REPO:grafana-latest || log_error "Échec de la publication de l'image Grafana (latest)"

    log_info "Construction de l'image Docker pour Prometheus..."
    docker build -t $DOCKERHUB_USERNAME/$DOCKERHUB_REPO:prometheus-$DOCKER_VERSION -t $DOCKERHUB_USERNAME/$DOCKERHUB_REPO:prometheus-latest "$PROMETHEUS_DIR" || log_error "Échec de la construction de l'image Prometheus"

    log_info "Publication de l'image Prometheus sur Docker Hub..."
    docker push $DOCKERHUB_USERNAME/$DOCKERHUB_REPO:prometheus-$DOCKER_VERSION || log_error "Échec de la publication de l'image Prometheus (version)"
    docker push $DOCKERHUB_USERNAME/$DOCKERHUB_REPO:prometheus-latest || log_error "Échec de la publication de l'image Prometheus (latest)"

    log_success "Images de monitoring publiées avec succès!"
}

# Fonction pour déployer les conteneurs de monitoring
deploy_monitoring() {
    # Vérifier que les variables requises sont définies
    if [ -z "$EC2_MONITORING_IP" ]; then
        log_error "La variable EC2_MONITORING_IP n'est pas définie"
        return 1
    fi

    if [ -z "$EC2_SSH_KEY" ]; then
        log_error "La variable EC2_SSH_KEY n'est pas définie"
        return 1
    fi

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
        echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

        # Créer les répertoires nécessaires
        sudo mkdir -p /opt/monitoring/prometheus-data /opt/monitoring/grafana-data /opt/monitoring/prometheus-rules

        # Configurer les permissions
        sudo chown -R 1000:1000 /opt/monitoring/grafana-data

        # Configurer les limites système
        echo "fs.file-max=4096" | sudo tee -a /etc/sysctl.conf
        sudo sysctl -p

        # Créer des fichiers de configuration pour les variables
        echo "$DOCKERHUB_USERNAME" | sudo tee /opt/monitoring/dockerhub_username.txt > /dev/null
        echo "$DOCKERHUB_REPO" | sudo tee /opt/monitoring/dockerhub_repo.txt > /dev/null
        echo "$GRAFANA_ADMIN_PASSWORD" | sudo tee /opt/monitoring/grafana_admin_password.txt > /dev/null

        # Créer le fichier docker-compose.yml avec les variables déjà remplacées
        cat > /tmp/docker-compose.yml << EOF_COMPOSE
version: '3'

services:
  # Prometheus pour la surveillance
  prometheus:
    image: $(cat /opt/monitoring/dockerhub_username.txt)/$(cat /opt/monitoring/dockerhub_repo.txt):prometheus-latest
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
    image: $(cat /opt/monitoring/dockerhub_username.txt)/$(cat /opt/monitoring/dockerhub_repo.txt):grafana-latest
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - /opt/monitoring/grafana-data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=$(cat /opt/monitoring/grafana_admin_password.txt)
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

  # Application React
  app-mobile:
    image: $(cat /opt/monitoring/dockerhub_username.txt)/$(cat /opt/monitoring/dockerhub_repo.txt):mobile-latest
    container_name: app-mobile
    ports:
      - "8080:3000"
    environment:
      - NODE_ENV=production
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
EOF_COMPOSE

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

# Fonction pour déployer l'application mobile sur l'instance de monitoring
deploy_mobile() {
    # Vérifier que les variables requises sont définies
    if [ -z "$EC2_MONITORING_IP" ]; then
        log_error "La variable EC2_MONITORING_IP n'est pas définie"
        return 1
    fi

    if [ -z "$EC2_SSH_KEY" ]; then
        log_error "La variable EC2_SSH_KEY n'est pas définie"
        return 1
    fi

    log_info "Déploiement de l'application mobile sur l'instance de monitoring ($EC2_MONITORING_IP)..."

    # Utiliser un fichier temporaire sécurisé pour la clé SSH avec un nom aléatoire
    # Supprimer les guillemets simples qui pourraient être présents dans la clé
    CLEAN_SSH_KEY=$(echo "$EC2_SSH_KEY" | sed "s/'//g")
    SSH_KEY_FILE=$(mktemp -p /tmp ssh_key_XXXXXXXX)
    echo "$CLEAN_SSH_KEY" > "$SSH_KEY_FILE"
    chmod 400 "$SSH_KEY_FILE" || log_error "Impossible de définir les permissions sur le fichier de clé SSH"
    # Ajouter le fichier à la liste des fichiers à supprimer à la fin
    trap "rm -f $SSH_KEY_FILE" EXIT

    # Créer un script de déploiement pour l'application mobile
    cat > /tmp/deploy-mobile-app.sh << 'EOL'
#!/bin/bash
set -e

echo "Nettoyage des ressources Docker non utilisées..."
sudo docker system prune -af --volumes

echo "Création du répertoire pour l'application mobile..."
sudo mkdir -p /opt/mobile-app
sudo mkdir -p /opt/mobile-app/build

echo "Création du fichier HTML pour l'application mobile..."
sudo tee /opt/mobile-app/build/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>YourMedia Mobile App</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            background-color: #f5f5f5;
        }
        .container {
            text-align: center;
            padding: 20px;
            background-color: white;
            border-radius: 10px;
            box-shadow: 0 4px 8px rgba(0,0,0,0.1);
        }
        h1 { color: #333; margin-bottom: 10px; }
        p { color: #666; }
        .logo { font-size: 48px; margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">📱</div>
        <h1>Hello World!</h1>
        <p>YourMedia Mobile Application</p>
    </div>
</body>
</html>
EOF

echo "Création du Dockerfile pour l'application mobile..."
sudo tee /opt/mobile-app/Dockerfile > /dev/null << 'EOF'
FROM node:16-alpine

# Installer les dépendances nécessaires (minimales)
RUN apk add --no-cache curl

# Définir le répertoire de travail
WORKDIR /app

# Installer un serveur web léger
RUN npm install -g serve

# Copier les fichiers de l'application
COPY build /app/build

# Exposer le port 8080
EXPOSE 8080

# Limiter les ressources utilisées
ENV NODE_OPTIONS="--max-old-space-size=256"

# Démarrer le serveur sur le port 8080
CMD ["serve", "-s", "build", "-l", "8080"]
EOF

echo "Arrêt et suppression du conteneur existant s'il existe..."
sudo docker stop app-mobile 2>/dev/null || true
sudo docker rm app-mobile 2>/dev/null || true

echo "Construction de l'image Docker localement..."
cd /opt/mobile-app
sudo docker build -t yourmedia-mobile-app:latest .

echo "Démarrage du conteneur avec la nouvelle image et des limites de ressources..."
sudo docker run -d --name app-mobile \
  --memory=256m \
  --cpus=0.5 \
  --restart=unless-stopped \
  -p 8080:8080 \
  yourmedia-mobile-app:latest

echo "Vérification de l'état du conteneur..."
if sudo docker ps | grep app-mobile; then
    echo "✅ Le conteneur app-mobile est en cours d'exécution"
else
    echo "❌ Le conteneur app-mobile n'est pas en cours d'exécution"
    echo "Logs du conteneur:"
    sudo docker logs app-mobile
fi

# Créer un script de nettoyage périodique
echo "Création d'un script de nettoyage périodique..."
sudo tee /opt/mobile-app/cleanup.sh > /dev/null << 'EOF'
#!/bin/bash
# Script de nettoyage des ressources Docker

# Supprimer les conteneurs arrêtés
docker container prune -f

# Supprimer les images non utilisées
docker image prune -a -f

# Supprimer les volumes non utilisés
docker volume prune -f

# Supprimer les réseaux non utilisés
docker network prune -f

# Nettoyer le cache de construction
docker builder prune -f
EOF

sudo chmod +x /opt/mobile-app/cleanup.sh

# Ajouter le script au cron pour une exécution quotidienne
echo "Ajout du script de nettoyage au cron..."
(sudo crontab -l 2>/dev/null || echo "") | grep -v "/opt/mobile-app/cleanup.sh" | sudo tee /tmp/crontab
echo "0 2 * * * /opt/mobile-app/cleanup.sh > /dev/null 2>&1" | sudo tee -a /tmp/crontab
sudo crontab /tmp/crontab
sudo rm /tmp/crontab
EOL

    # Copier le script sur l'instance de monitoring
    log_info "Copie du script de déploiement sur l'instance de monitoring..."
    scp -o StrictHostKeyChecking=no -i "$SSH_KEY_FILE" /tmp/deploy-mobile-app.sh ec2-user@$EC2_MONITORING_IP:/tmp/deploy-mobile-app.sh

    # Exécuter le script sur l'instance de monitoring
    log_info "Exécution du script de déploiement sur l'instance de monitoring..."
    ssh -i "$SSH_KEY_FILE" -o StrictHostKeyChecking=no ec2-user@$EC2_MONITORING_IP "chmod +x /tmp/deploy-mobile-app.sh && /tmp/deploy-mobile-app.sh"

    # Vérifier l'état du conteneur après le déploiement
    sleep 5
    ssh -i "$SSH_KEY_FILE" -o StrictHostKeyChecking=no ec2-user@$EC2_MONITORING_IP << EOF
        echo "Vérification de l'état du conteneur app-mobile..."
        if sudo docker ps | grep -q app-mobile; then
            echo "✅ Le conteneur app-mobile est en cours d'exécution"

            # Vérifier si l'application est accessible
            echo "Vérification de l'accessibilité de l'application..."
            if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080; then
                echo "✅ L'application est accessible localement"
            else
                echo "⚠️ L'application n'est pas accessible localement"
                echo "Logs du conteneur:"
                sudo docker logs app-mobile
            fi
        else
            echo "❌ Le conteneur app-mobile n'est pas en cours d'exécution"
            echo "Logs du conteneur (s'il existe):"
            sudo docker logs app-mobile 2>/dev/null || echo "Aucun log disponible"
        fi
EOF

    log_success "Déploiement de l'application mobile sur l'instance de monitoring terminé."
    log_info "L'application est accessible à l'adresse: http://$EC2_MONITORING_IP:8080"
}

# Fonction pour sauvegarder les données des conteneurs
backup_containers() {
    local ip=$1
    local instance_type=$2
    local s3_bucket=$3

    # Vérifier que les paramètres requis sont définis
    if [ -z "$ip" ]; then
        log_error "L'adresse IP n'est pas définie"
        return 1
    fi

    if [ -z "$instance_type" ]; then
        log_error "Le type d'instance n'est pas défini"
        return 1
    fi

    if [ -z "$s3_bucket" ]; then
        log_error "Le nom du bucket S3 n'est pas défini"
        return 1
    fi

    if [ -z "$EC2_SSH_KEY" ]; then
        log_error "La variable EC2_SSH_KEY n'est pas définie"
        return 1
    fi

    local timestamp=$(date +%Y%m%d%H%M%S)
    local backup_dir="yourmedia-backup-${instance_type}-${timestamp}"

    log_info "Sauvegarde des données des conteneurs sur l'instance $instance_type ($ip)..."

    # Utiliser un fichier temporaire sécurisé pour la clé SSH avec un nom aléatoire
    CLEAN_SSH_KEY=$(echo "$EC2_SSH_KEY" | sed "s/'//g")
    SSH_KEY_FILE=$(mktemp -p /tmp ssh_key_XXXXXXXX)
    echo "$CLEAN_SSH_KEY" > "$SSH_KEY_FILE"
    chmod 400 "$SSH_KEY_FILE" || log_error "Impossible de définir les permissions sur le fichier de clé SSH"
    # Ajouter le fichier à la liste des fichiers à supprimer à la fin
    trap "rm -f $SSH_KEY_FILE" EXIT

    # Se connecter à l'instance EC2 et sauvegarder les données
    ssh -i "$SSH_KEY_FILE" -o StrictHostKeyChecking=no ec2-user@$ip << EOF
        echo "[INFO] Création du répertoire de sauvegarde..."
        mkdir -p ~/$backup_dir

        # Sauvegarder les configurations Docker
        echo "[INFO] Sauvegarde des configurations Docker..."
        if [ -d "/opt/monitoring" ]; then
            tar -czf ~/$backup_dir/monitoring-config.tar.gz /opt/monitoring
        fi
        if [ -d "/opt/app-mobile" ]; then
            tar -czf ~/$backup_dir/app-mobile-config.tar.gz /opt/app-mobile
        fi

        # Sauvegarder les volumes Docker
        echo "[INFO] Sauvegarde des volumes Docker..."
        volumes=\$(sudo docker volume ls -q)
        if [ -n "\$volumes" ]; then
            mkdir -p ~/$backup_dir/volumes
            for volume in \$volumes; do
                echo "[INFO] Sauvegarde du volume \$volume..."
                # Créer un conteneur temporaire pour accéder au volume
                sudo docker run --rm -v \$volume:/source -v ~/$backup_dir/volumes:/backup alpine tar -czf /backup/\$volume.tar.gz -C /source .
            done
        else
            echo "[INFO] Aucun volume Docker à sauvegarder."
        fi

        # Sauvegarder les logs des conteneurs
        echo "[INFO] Sauvegarde des logs des conteneurs..."
        containers=\$(sudo docker ps -a --format "{{.Names}}")
        if [ -n "\$containers" ]; then
            mkdir -p ~/$backup_dir/logs
            for container in \$containers; do
                echo "[INFO] Sauvegarde des logs du conteneur \$container..."
                sudo docker logs \$container > ~/$backup_dir/logs/\$container.log 2>&1
            done
        else
            echo "[INFO] Aucun conteneur à sauvegarder."
        fi

        # Sauvegarder les images Docker
        echo "[INFO] Sauvegarde des informations sur les images Docker..."
        sudo docker images > ~/$backup_dir/docker-images.txt

        # Sauvegarder les configurations des conteneurs
        echo "[INFO] Sauvegarde des configurations des conteneurs..."
        containers=\$(sudo docker ps -a --format "{{.Names}}")
        if [ -n "\$containers" ]; then
            mkdir -p ~/$backup_dir/configs
            for container in \$containers; do
                echo "[INFO] Sauvegarde de la configuration du conteneur \$container..."
                sudo docker inspect \$container > ~/$backup_dir/configs/\$container.json
            done
        fi

        # Compresser le répertoire de sauvegarde
        echo "[INFO] Compression du répertoire de sauvegarde..."
        tar -czf ~/$backup_dir.tar.gz -C ~ $backup_dir
        rm -rf ~/$backup_dir

        # Installer AWS CLI si nécessaire
        if ! command -v aws &> /dev/null; then
            echo "[INFO] Installation de AWS CLI..."
            sudo wget -q "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -O "awscliv2.zip"
            sudo unzip awscliv2.zip
            sudo ./aws/install
            sudo rm -rf aws awscliv2.zip
        fi

        # Uploader la sauvegarde vers S3
        echo "[INFO] Upload de la sauvegarde vers S3..."
        aws s3 cp ~/$backup_dir.tar.gz s3://$s3_bucket/$backup_dir.tar.gz

        # Supprimer le fichier de sauvegarde local
        echo "[INFO] Suppression du fichier de sauvegarde local..."
        rm -f ~/$backup_dir.tar.gz

        echo "[INFO] Sauvegarde terminée et uploadée vers S3: s3://$s3_bucket/$backup_dir.tar.gz"
EOF

    log_success "Sauvegarde des conteneurs sur l'instance $instance_type terminée."
}

# Fonction pour restaurer les données des conteneurs
restore_containers() {
    local ip=$1
    local instance_type=$2
    local s3_bucket=$3

    # Vérifier que les paramètres requis sont définis
    if [ -z "$ip" ]; then
        log_error "L'adresse IP n'est pas définie"
        return 1
    fi

    if [ -z "$instance_type" ]; then
        log_error "Le type d'instance n'est pas défini"
        return 1
    fi

    if [ -z "$s3_bucket" ]; then
        log_error "Le nom du bucket S3 n'est pas défini"
        return 1
    fi

    if [ -z "$EC2_SSH_KEY" ]; then
        log_error "La variable EC2_SSH_KEY n'est pas définie"
        return 1
    fi

    log_info "Restauration des données des conteneurs sur l'instance $instance_type ($ip)..."

    # Utiliser un fichier temporaire sécurisé pour la clé SSH avec un nom aléatoire
    CLEAN_SSH_KEY=$(echo "$EC2_SSH_KEY" | sed "s/'//g")
    SSH_KEY_FILE=$(mktemp -p /tmp ssh_key_XXXXXXXX)
    echo "$CLEAN_SSH_KEY" > "$SSH_KEY_FILE"
    chmod 400 "$SSH_KEY_FILE" || log_error "Impossible de définir les permissions sur le fichier de clé SSH"
    # Ajouter le fichier à la liste des fichiers à supprimer à la fin
    trap "rm -f $SSH_KEY_FILE" EXIT

    # Se connecter à l'instance EC2 et restaurer les données
    ssh -i "$SSH_KEY_FILE" -o StrictHostKeyChecking=no ec2-user@$ip << EOF
        # Installer AWS CLI si nécessaire
        if ! command -v aws &> /dev/null; then
            echo "[INFO] Installation de AWS CLI..."
            sudo wget -q "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -O "awscliv2.zip"
            sudo unzip awscliv2.zip
            sudo ./aws/install
            sudo rm -rf aws awscliv2.zip
        fi

        # Lister les sauvegardes disponibles
        echo "[INFO] Liste des sauvegardes disponibles pour $instance_type..."
        backups=\$(aws s3 ls s3://$s3_bucket/ | grep "yourmedia-backup-$instance_type" | sort -r)

        if [ -z "\$backups" ]; then
            echo "[ERROR] Aucune sauvegarde trouvée pour $instance_type dans le bucket S3."
            exit 1
        fi

        # Afficher les sauvegardes disponibles
        echo "\$backups"

        # Demander à l'utilisateur de choisir une sauvegarde
        echo "[PROMPT] Entrez le nom complet du fichier de sauvegarde à restaurer:"
        read backup_file

        if [ -z "\$backup_file" ]; then
            echo "[ERROR] Aucun fichier de sauvegarde spécifié."
            exit 1
        fi

        # Télécharger la sauvegarde depuis S3
        echo "[INFO] Téléchargement de la sauvegarde depuis S3..."
        aws s3 cp s3://$s3_bucket/\$backup_file ~/\$backup_file

        # Extraire la sauvegarde
        echo "[INFO] Extraction de la sauvegarde..."
        mkdir -p ~/restore
        tar -xzf ~/\$backup_file -C ~/restore

        # Trouver le répertoire de sauvegarde
        backup_dir=\$(find ~/restore -type d -name "yourmedia-backup-*" | head -1)

        if [ -z "\$backup_dir" ]; then
            echo "[ERROR] Impossible de trouver le répertoire de sauvegarde dans l'archive."
            rm -rf ~/restore ~/\$backup_file
            exit 1
        fi

        # Restaurer les configurations Docker
        echo "[INFO] Restauration des configurations Docker..."
        if [ -f "\$backup_dir/monitoring-config.tar.gz" ]; then
            echo "[INFO] Restauration des configurations de monitoring..."
            sudo tar -xzf \$backup_dir/monitoring-config.tar.gz -C /
        fi

        if [ -f "\$backup_dir/app-mobile-config.tar.gz" ]; then
            echo "[INFO] Restauration des configurations d'application mobile..."
            sudo tar -xzf \$backup_dir/app-mobile-config.tar.gz -C /
        fi

        # Restaurer les volumes Docker
        echo "[INFO] Restauration des volumes Docker..."
        if [ -d "\$backup_dir/volumes" ]; then
            for volume_file in \$backup_dir/volumes/*.tar.gz; do
                if [ -f "\$volume_file" ]; then
                    volume_name=\$(basename \$volume_file .tar.gz)
                    echo "[INFO] Restauration du volume \$volume_name..."

                    # Vérifier si le volume existe déjà
                    if ! sudo docker volume inspect \$volume_name &>/dev/null; then
                        echo "[INFO] Création du volume \$volume_name..."
                        sudo docker volume create \$volume_name
                    else
                        echo "[INFO] Le volume \$volume_name existe déjà."
                    fi

                    # Restaurer les données du volume
                    sudo docker run --rm -v \$volume_name:/target -v \$volume_file:/backup.tar.gz alpine sh -c "tar -xzf /backup.tar.gz -C /target"
                fi
            done
        else
            echo "[INFO] Aucun volume à restaurer."
        fi

        # Nettoyer
        echo "[INFO] Nettoyage des fichiers temporaires..."
        rm -rf ~/restore ~/\$backup_file

        echo "[INFO] Restauration terminée. Redémarrez les conteneurs pour appliquer les changements."
EOF

    log_success "Restauration des conteneurs sur l'instance $instance_type terminée."
}

# Fonction pour nettoyer les conteneurs Docker
cleanup_containers() {
    local ip=$1
    local instance_type=$2
    local cleanup_type=$3

    # Vérifier que les paramètres requis sont définis
    if [ -z "$ip" ]; then
        log_warning "L'adresse IP n'est pas définie pour l'instance $instance_type. Le nettoyage ne sera pas effectué."
        return 1
    fi

    if [ -z "$instance_type" ]; then
        log_warning "Le type d'instance n'est pas défini. Le nettoyage ne sera pas effectué."
        return 1
    fi

    if [ -z "$cleanup_type" ]; then
        log_warning "Le type de nettoyage n'est pas défini. Utilisation du type par défaut: 'all'."
        cleanup_type="all"
    fi

    if [ -z "$EC2_SSH_KEY" ]; then
        log_warning "La variable EC2_SSH_KEY n'est pas définie. Le nettoyage ne sera pas effectué."
        return 1
    fi

    log_info "Nettoyage des conteneurs Docker sur l'instance $instance_type ($ip)..."
    log_info "Type de nettoyage: $cleanup_type"

    # Utiliser un fichier temporaire sécurisé pour la clé SSH avec un nom aléatoire
    CLEAN_SSH_KEY=$(echo "$EC2_SSH_KEY" | sed "s/'//g")
    SSH_KEY_FILE=$(mktemp -p /tmp ssh_key_XXXXXXXX)
    echo "$CLEAN_SSH_KEY" > "$SSH_KEY_FILE"
    chmod 400 "$SSH_KEY_FILE" || log_error "Impossible de définir les permissions sur le fichier de clé SSH"
    # Ajouter le fichier à la liste des fichiers à supprimer à la fin
    trap "rm -f $SSH_KEY_FILE" EXIT

    # Se connecter à l'instance EC2 et arrêter/supprimer les conteneurs
    ssh -i "$SSH_KEY_FILE" -o StrictHostKeyChecking=no ec2-user@$ip << EOF
        # Sauvegarder les logs avant le nettoyage
        if [ "$cleanup_type" = "all" ] || [ "$cleanup_type" = "containers" ]; then
            echo "[INFO] Sauvegarde des logs des conteneurs..."
            mkdir -p ~/docker-logs-backup
            for container in \$(sudo docker ps -a --format "{{.Names}}"); do
                sudo docker logs \$container > ~/docker-logs-backup/\$container-\$(date +%Y%m%d%H%M%S).log 2>&1 || echo "[WARN] Impossible de sauvegarder les logs pour \$container"
            done
            echo "[INFO] Logs sauvegardés dans ~/docker-logs-backup"
        fi

        # Arrêter tous les conteneurs en cours d'exécution
        if [ "$cleanup_type" = "all" ] || [ "$cleanup_type" = "containers" ]; then
            echo "[INFO] Arrêt des conteneurs Docker..."
            running_containers=\$(sudo docker ps -q)
            if [ -n "\$running_containers" ]; then
                sudo docker stop \$running_containers
                echo "[INFO] Conteneurs arrêtés: \$(echo \$running_containers | wc -w)"
            else
                echo "[INFO] Aucun conteneur en cours d'exécution"
            fi

            # Supprimer tous les conteneurs
            echo "[INFO] Suppression des conteneurs Docker..."
            all_containers=\$(sudo docker ps -aq)
            if [ -n "\$all_containers" ]; then
                sudo docker rm \$all_containers
                echo "[INFO] Conteneurs supprimés: \$(echo \$all_containers | wc -w)"
            else
                echo "[INFO] Aucun conteneur à supprimer"
            fi
        fi

        # Supprimer les images non utilisées
        if [ "$cleanup_type" = "all" ] || [ "$cleanup_type" = "images" ]; then
            echo "[INFO] Suppression des images Docker non utilisées..."
            dangling_images=\$(sudo docker images -f "dangling=true" -q)
            if [ -n "\$dangling_images" ]; then
                sudo docker rmi \$dangling_images
                echo "[INFO] Images dangling supprimées: \$(echo \$dangling_images | wc -w)"
            else
                echo "[INFO] Aucune image dangling à supprimer"
            fi

            # Supprimer toutes les images si demandé
            if [ "$cleanup_type" = "all" ]; then
                echo "[INFO] Suppression de toutes les images Docker..."
                all_images=\$(sudo docker images -q)
                if [ -n "\$all_images" ]; then
                    sudo docker rmi -f \$all_images
                    echo "[INFO] Images supprimées: \$(echo \$all_images | wc -w)"
                else
                    echo "[INFO] Aucune image à supprimer"
                fi
            fi
        fi

        # Supprimer les volumes non utilisés
        if [ "$cleanup_type" = "all" ] || [ "$cleanup_type" = "volumes" ]; then
            echo "[INFO] Suppression des volumes Docker non utilisés..."
            volumes=\$(sudo docker volume ls -q)
            if [ -n "\$volumes" ]; then
                sudo docker volume rm \$volumes
                echo "[INFO] Volumes supprimés: \$(echo \$volumes | wc -w)"
            else
                echo "[INFO] Aucun volume à supprimer"
            fi
        fi

        # Supprimer tous les réseaux personnalisés
        if [ "$cleanup_type" = "all" ] || [ "$cleanup_type" = "networks" ]; then
            echo "[INFO] Suppression des réseaux Docker personnalisés..."
            networks=\$(sudo docker network ls -q -f "type=custom")
            if [ -n "\$networks" ]; then
                sudo docker network rm \$networks
                echo "[INFO] Réseaux supprimés: \$(echo \$networks | wc -w)"
            else
                echo "[INFO] Aucun réseau à supprimer"
            fi
        fi

        # Nettoyage système Docker (prune)
        if [ "$cleanup_type" = "all" ] || [ "$cleanup_type" = "prune" ]; then
            echo "[INFO] Nettoyage système Docker (prune)..."
            sudo docker system prune -af --volumes
            echo "[INFO] Nettoyage système terminé"
        fi

        # Supprimer les fichiers de configuration Docker
        if [ "$cleanup_type" = "all" ]; then
            echo "[INFO] Suppression des fichiers de configuration Docker..."
            sudo rm -rf /opt/monitoring /opt/app-mobile 2>/dev/null || echo "[INFO] Aucun fichier de configuration à supprimer"
        fi

        # Afficher l'espace disque récupéré
        echo -e "\n[INFO] Espace disque disponible après nettoyage:"
        df -h /

        echo -e "\n[INFO] Nettoyage terminé sur l'instance $instance_type."
EOF

    log_success "Nettoyage des conteneurs sur l'instance $instance_type terminé."
}

# Vérifier les arguments
if [ "$ACTION" != "build" ] && [ "$ACTION" != "deploy" ] && [ "$ACTION" != "all" ] && [ "$ACTION" != "backup" ] && [ "$ACTION" != "restore" ] && [ "$ACTION" != "cleanup" ]; then
    log_error "Action inconnue: $ACTION"
    show_help
fi

if [ "$TARGET" != "mobile" ] && [ "$TARGET" != "monitoring" ] && [ "$TARGET" != "all" ]; then
    log_error "Cible inconnue: $TARGET"
    show_help
fi

# Vérifier les options supplémentaires
if [ "$ACTION" = "backup" ] || [ "$ACTION" = "restore" ]; then
    if [ -z "$S3_BUCKET" ]; then
        log_error "L'option --s3-bucket est requise pour les actions backup et restore"
        show_help
    fi
fi

if [ "$ACTION" = "cleanup" ] && [ "$CLEANUP_TYPE" != "all" ] && [ "$CLEANUP_TYPE" != "containers" ] && [ "$CLEANUP_TYPE" != "images" ] && [ "$CLEANUP_TYPE" != "volumes" ] && [ "$CLEANUP_TYPE" != "networks" ] && [ "$CLEANUP_TYPE" != "prune" ]; then
    log_error "Type de nettoyage invalide: $CLEANUP_TYPE"
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
    backup)
        check_deploy_vars
        log_info "Sauvegarde des conteneurs Docker vers le bucket S3: $S3_BUCKET"

        # Demander confirmation avant de procéder
        if [ -t 0 ]; then  # Vérifier si le script est exécuté en mode interactif
            echo -e "\n[WARN] Vous êtes sur le point de sauvegarder les données des conteneurs Docker sur les instances suivantes:"
            echo "  - Instance de monitoring: $EC2_MONITORING_IP"
            echo "  - Instance d'application: $EC2_APP_IP"
            echo "  - Bucket S3: $S3_BUCKET"
            read -p $'\n[PROMPT] Êtes-vous sûr de vouloir continuer? (y/n): ' -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Opération annulée."
                exit 0
            fi
        fi

        case $TARGET in
            mobile)
                backup_containers $EC2_APP_IP "app" $S3_BUCKET
                ;;
            monitoring)
                backup_containers $EC2_MONITORING_IP "monitoring" $S3_BUCKET
                ;;
            all)
                backup_containers $EC2_MONITORING_IP "monitoring" $S3_BUCKET
                backup_containers $EC2_APP_IP "app" $S3_BUCKET
                ;;
        esac
        ;;
    restore)
        check_deploy_vars
        log_info "Restauration des conteneurs Docker depuis le bucket S3: $S3_BUCKET"

        # Demander confirmation avant de procéder
        if [ -t 0 ]; then  # Vérifier si le script est exécuté en mode interactif
            echo -e "\n[WARN] Vous êtes sur le point de restaurer les données des conteneurs Docker sur les instances suivantes:"
            echo "  - Instance de monitoring: $EC2_MONITORING_IP"
            echo "  - Instance d'application: $EC2_APP_IP"
            echo "  - Bucket S3: $S3_BUCKET"
            echo -e "\n[WARN] Cette opération peut écraser des données existantes. Assurez-vous d'avoir arrêté les conteneurs avant de continuer."
            read -p $'\n[PROMPT] Êtes-vous sûr de vouloir continuer? (y/n): ' -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Opération annulée."
                exit 0
            fi
        fi

        case $TARGET in
            mobile)
                restore_containers $EC2_APP_IP "app" $S3_BUCKET
                ;;
            monitoring)
                restore_containers $EC2_MONITORING_IP "monitoring" $S3_BUCKET
                ;;
            all)
                restore_containers $EC2_MONITORING_IP "monitoring" $S3_BUCKET
                restore_containers $EC2_APP_IP "app" $S3_BUCKET
                ;;
        esac
        ;;
    cleanup)
        # Vérifier les variables requises, mais continuer même si certaines sont manquantes
        check_deploy_vars || log_warning "Des variables requises sont manquantes, mais le nettoyage va continuer avec les variables disponibles."

        log_info "Nettoyage des conteneurs Docker (type: $CLEANUP_TYPE)"

        # Demander confirmation avant de procéder
        if [ -t 0 ]; then  # Vérifier si le script est exécuté en mode interactif
            echo -e "\n[WARN] Vous êtes sur le point de nettoyer les conteneurs Docker sur les instances suivantes:"
            echo "  - Instance de monitoring: $EC2_MONITORING_IP"
            echo "  - Instance d'application: $EC2_APP_IP"
            echo "  - Type de nettoyage: $CLEANUP_TYPE"
            echo -e "\n[WARN] Cette opération peut supprimer des données. Les logs seront sauvegardés avant le nettoyage."
            read -p $'\n[PROMPT] Êtes-vous sûr de vouloir continuer? (y/n): ' -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Opération annulée."
                exit 0
            fi
        fi

        # Variable pour suivre le succès du nettoyage
        local cleanup_success=true

        case $TARGET in
            mobile)
                if [ -n "$EC2_APP_IP" ]; then
                    cleanup_containers "$EC2_APP_IP" "application" "$CLEANUP_TYPE" || {
                        log_warning "Le nettoyage des conteneurs sur l'instance d'application a échoué."
                        cleanup_success=false
                    }
                else
                    log_warning "L'adresse IP de l'instance d'application n'est pas définie. Le nettoyage ne sera pas effectué pour cette cible."
                fi
                ;;
            monitoring)
                if [ -n "$EC2_MONITORING_IP" ]; then
                    cleanup_containers "$EC2_MONITORING_IP" "monitoring" "$CLEANUP_TYPE" || {
                        log_warning "Le nettoyage des conteneurs sur l'instance de monitoring a échoué."
                        cleanup_success=false
                    }
                else
                    log_warning "L'adresse IP de l'instance de monitoring n'est pas définie. Le nettoyage ne sera pas effectué pour cette cible."
                fi
                ;;
            all)
                if [ -n "$EC2_MONITORING_IP" ]; then
                    cleanup_containers "$EC2_MONITORING_IP" "monitoring" "$CLEANUP_TYPE" || {
                        log_warning "Le nettoyage des conteneurs sur l'instance de monitoring a échoué."
                        cleanup_success=false
                    }
                else
                    log_warning "L'adresse IP de l'instance de monitoring n'est pas définie. Le nettoyage ne sera pas effectué pour cette cible."
                fi

                if [ -n "$EC2_APP_IP" ]; then
                    cleanup_containers "$EC2_APP_IP" "application" "$CLEANUP_TYPE" || {
                        log_warning "Le nettoyage des conteneurs sur l'instance d'application a échoué."
                        cleanup_success=false
                    }
                else
                    log_warning "L'adresse IP de l'instance d'application n'est pas définie. Le nettoyage ne sera pas effectué pour cette cible."
                fi
                ;;
        esac

        if [ "$cleanup_success" = true ]; then
            log_success "Nettoyage des conteneurs terminé avec succès."
        else
            log_warning "Le nettoyage des conteneurs a rencontré des problèmes. Vérifiez les logs pour plus de détails."
            # On ne sort pas avec un code d'erreur pour ne pas bloquer le workflow de destruction
            # exit 1
        fi
        ;;
esac

log_success "Opérations terminées avec succès!"
