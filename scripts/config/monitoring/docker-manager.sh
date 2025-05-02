#!/bin/bash
#==============================================================================
# Nom du script : docker-manager.sh
# Description   : Script simplifié de gestion des conteneurs Docker.
#                 Ce script permet de démarrer, arrêter, redémarrer et vérifier
#                 le statut des conteneurs Docker.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2025-05-02
#==============================================================================
# Utilisation   : sudo ./docker-manager.sh [start|stop|restart|status|deploy] [service_name]
#
# Options       :
#   start       : Démarrer les conteneurs
#   stop        : Arrêter les conteneurs
#   restart     : Redémarrer les conteneurs
#   status      : Afficher le statut des conteneurs
#   deploy      : Déployer les conteneurs (arrêter puis démarrer)
#
# Exemples      :
#   sudo ./docker-manager.sh start
#   sudo ./docker-manager.sh stop grafana
#   sudo ./docker-manager.sh restart prometheus
#==============================================================================
# Dépendances   :
#   - docker    : Pour gérer les conteneurs
#   - docker-compose : Pour gérer les services
#==============================================================================
# Droits requis : Ce script doit être exécuté avec des privilèges sudo ou en tant que root.
#==============================================================================

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
    error_exit "Ce script doit être exécuté avec sudo ou en tant que root"
fi

# Charger les variables d'environnement
if [ -f "/opt/monitoring/env.sh" ]; then
    source /opt/monitoring/env.sh
fi

if [ -f "/opt/monitoring/secure/sensitive-env.sh" ]; then
    source /opt/monitoring/secure/sensitive-env.sh
fi

# Vérifier si Docker est installé
if ! command -v docker &> /dev/null; then
    error_exit "Docker n'est pas installé"
fi

# Vérifier si Docker Compose est installé
if ! command -v docker-compose &> /dev/null; then
    error_exit "Docker Compose n'est pas installé"
fi

# Vérifier les arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 [start|stop|restart|status|deploy] [service_name]"
    exit 1
fi

ACTION=$1
SERVICE=${2:-all}

# Fonction pour démarrer les conteneurs
start_containers() {
    log "Démarrage des conteneurs..."
    cd /opt/monitoring
    sudo docker-compose up -d $SERVICE
    if [ $? -eq 0 ]; then
        log "Conteneurs démarrés avec succès"
    else
        error_exit "Échec du démarrage des conteneurs"
    fi
}

# Fonction pour arrêter les conteneurs
stop_containers() {
    log "Arrêt des conteneurs..."
    cd /opt/monitoring
    sudo docker-compose down $SERVICE
    if [ $? -eq 0 ]; then
        log "Conteneurs arrêtés avec succès"
    else
        error_exit "Échec de l'arrêt des conteneurs"
    fi
}

# Fonction pour redémarrer les conteneurs
restart_containers() {
    log "Redémarrage des conteneurs..."
    cd /opt/monitoring
    sudo docker-compose restart $SERVICE
    if [ $? -eq 0 ]; then
        log "Conteneurs redémarrés avec succès"
    else
        error_exit "Échec du redémarrage des conteneurs"
    fi
}

# Fonction pour afficher le statut des conteneurs
status_containers() {
    log "Statut des conteneurs:"
    sudo docker ps -a
}

# Fonction pour déployer les conteneurs
deploy_containers() {
    log "Déploiement des conteneurs..."
    cd /opt/monitoring

    # Arrêter les conteneurs existants
    sudo docker-compose down

    # Démarrer les conteneurs
    sudo docker-compose up -d

    if [ $? -eq 0 ]; then
        log "Conteneurs déployés avec succès"
    else
        error_exit "Échec du déploiement des conteneurs"
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
    *)
        echo "Action non reconnue: $ACTION"
        echo "Usage: $0 [start|stop|restart|status|deploy] [service_name]"
        exit 1
        ;;
esac

exit 0
