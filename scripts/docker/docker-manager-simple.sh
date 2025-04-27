#!/bin/bash
# Script simplifié de gestion des conteneurs Docker
# Usage: docker-manager-simple.sh [start|stop|restart|status|deploy|logs] [service_name]

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Fonction pour afficher les erreurs et quitter
error_exit() {
    log "ERREUR: $1"
    exit 1
}

# Vérification des droits sudo
if [ "$(id -u)" -ne 0 ]; then
    log "Ce script nécessite des privilèges sudo."
    if sudo -n true 2>/dev/null; then
        log "Privilèges sudo disponibles sans mot de passe."
    else
        log "Tentative d'obtention des privilèges sudo..."
        if ! sudo -v; then
            error_exit "Impossible d'obtenir les privilèges sudo. Veuillez exécuter ce script avec sudo ou en tant que root."
        fi
        log "Privilèges sudo obtenus avec succès."
    fi
fi

# Vérifier si Docker est installé
if ! command -v docker &> /dev/null; then
    error_exit "Docker n'est pas installé. Veuillez installer Docker avant d'utiliser ce script."
fi

# Vérifier si Docker Compose est installé
if ! command -v docker-compose &> /dev/null; then
    error_exit "Docker Compose n'est pas installé. Veuillez installer Docker Compose avant d'utiliser ce script."
fi

# Vérifier les arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 [start|stop|restart|status|deploy|logs] [service_name]"
    echo "  start    : Démarrer les conteneurs"
    echo "  stop     : Arrêter les conteneurs"
    echo "  restart  : Redémarrer les conteneurs"
    echo "  status   : Afficher le statut des conteneurs"
    echo "  deploy   : Déployer les conteneurs (arrêter puis démarrer)"
    echo "  logs     : Afficher les logs des conteneurs"
    echo "  service_name : (Optionnel) Nom du service à gérer"
    exit 1
fi

ACTION=$1
SERVICE=${2:-all}

# Déterminer le répertoire de travail
if [ -f "/opt/monitoring/docker-compose.yml" ]; then
    WORK_DIR="/opt/monitoring"
elif [ -f "/opt/yourmedia/docker-compose.yml" ]; then
    WORK_DIR="/opt/yourmedia"
else
    # Chercher le fichier docker-compose.yml dans le répertoire courant et ses sous-répertoires
    DOCKER_COMPOSE_FILE=$(find . -name "docker-compose.yml" -type f -print -quit)
    if [ -n "$DOCKER_COMPOSE_FILE" ]; then
        WORK_DIR=$(dirname "$DOCKER_COMPOSE_FILE")
    else
        error_exit "Aucun fichier docker-compose.yml trouvé"
    fi
fi

log "Utilisation du répertoire de travail: $WORK_DIR"

# Fonction pour démarrer les conteneurs
start_containers() {
    log "Démarrage des conteneurs..."
    cd "$WORK_DIR"
    if [ "$SERVICE" = "all" ]; then
        docker-compose up -d
    else
        docker-compose up -d "$SERVICE"
    fi
    if [ $? -eq 0 ]; then
        log "Conteneurs démarrés avec succès"
    else
        error_exit "Échec du démarrage des conteneurs"
    fi
}

# Fonction pour arrêter les conteneurs
stop_containers() {
    log "Arrêt des conteneurs..."
    cd "$WORK_DIR"
    if [ "$SERVICE" = "all" ]; then
        docker-compose down
    else
        docker-compose stop "$SERVICE"
    fi
    if [ $? -eq 0 ]; then
        log "Conteneurs arrêtés avec succès"
    else
        error_exit "Échec de l'arrêt des conteneurs"
    fi
}

# Fonction pour redémarrer les conteneurs
restart_containers() {
    log "Redémarrage des conteneurs..."
    cd "$WORK_DIR"
    if [ "$SERVICE" = "all" ]; then
        docker-compose restart
    else
        docker-compose restart "$SERVICE"
    fi
    if [ $? -eq 0 ]; then
        log "Conteneurs redémarrés avec succès"
    else
        error_exit "Échec du redémarrage des conteneurs"
    fi
}

# Fonction pour afficher le statut des conteneurs
status_containers() {
    log "Statut des conteneurs:"
    docker ps -a
}

# Fonction pour déployer les conteneurs
deploy_containers() {
    log "Déploiement des conteneurs..."
    cd "$WORK_DIR"
    
    # Arrêter les conteneurs existants
    docker-compose down
    
    # Démarrer les conteneurs
    docker-compose up -d
    
    if [ $? -eq 0 ]; then
        log "Conteneurs déployés avec succès"
    else
        error_exit "Échec du déploiement des conteneurs"
    fi
}

# Fonction pour afficher les logs des conteneurs
logs_containers() {
    log "Affichage des logs des conteneurs..."
    cd "$WORK_DIR"
    if [ "$SERVICE" = "all" ]; then
        docker-compose logs
    else
        docker-compose logs "$SERVICE"
    fi
}

# Exécuter l'action demandée
case $ACTION in
    start)
        start_containers
        ;;
    stop)
        stop_containers
        ;;
    restart)
        restart_containers
        ;;
    status)
        status_containers
        ;;
    deploy)
        deploy_containers
        ;;
    logs)
        logs_containers
        ;;
    *)
        echo "Action non reconnue: $ACTION"
        echo "Usage: $0 [start|stop|restart|status|deploy|logs] [service_name]"
        exit 1
        ;;
esac

exit 0
