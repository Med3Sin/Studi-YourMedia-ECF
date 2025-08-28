#!/bin/bash
#==============================================================================
# Nom du script : docker-manager.sh
# Description   : Script unifié pour la gestion des conteneurs Docker de monitoring
# Auteur        : Med3Sin
# Version       : 1.0
#==============================================================================

# Couleurs pour les messages
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Fonction de logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️ $1${NC}"
}

# Vérifier les prérequis
check_prerequisites() {
    log "Vérification des prérequis..."
    
    # Vérifier docker
    if ! command -v docker &> /dev/null; then
        log_error "docker n'est pas installé"
        exit 1
    fi
    
    # Vérifier docker-compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "docker-compose n'est pas installé"
        exit 1
    fi
    
    # Vérifier le fichier docker-compose.yml
    if [ ! -f "docker-compose.yml" ]; then
        log_error "docker-compose.yml n'est pas trouvé"
        exit 1
    fi
    
    log_success "Tous les prérequis sont satisfaits"
}

# Démarrer les conteneurs
start_containers() {
    log "Démarrage des conteneurs..."
    
    if docker-compose up -d; then
        log_success "Les conteneurs ont été démarrés avec succès"
    else
        log_error "Erreur lors du démarrage des conteneurs"
        return 1
    fi
}

# Arrêter les conteneurs
stop_containers() {
    log "Arrêt des conteneurs..."
    
    if docker-compose down; then
        log_success "Les conteneurs ont été arrêtés avec succès"
    else
        log_error "Erreur lors de l'arrêt des conteneurs"
        return 1
    fi
}

# Redémarrer les conteneurs
restart_containers() {
    log "Redémarrage des conteneurs..."
    
    if docker-compose restart; then
        log_success "Les conteneurs ont été redémarrés avec succès"
    else
        log_error "Erreur lors du redémarrage des conteneurs"
        return 1
    fi
}

# Vérifier l'état des conteneurs
check_containers() {
    log "Vérification de l'état des conteneurs..."
    
    local containers=("prometheus" "grafana" "cadvisor" "loki" "promtail")
    local all_healthy=true
    
    for container in "${containers[@]}"; do
        if docker ps | grep -q "$container"; then
            local status=$(docker inspect --format='{{.State.Status}}' "$container")
            local health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}N/A{{end}}' "$container")
            
            if [ "$status" == "running" ]; then
                if [ "$health" == "healthy" ] || [ "$health" == "N/A" ]; then
                    log_success "$container est en cours d'exécution (Santé: $health)"
                else
                    log_warning "$container est en cours d'exécution mais état de santé: $health"
                    all_healthy=false
                fi
            else
                log_error "$container n'est pas en cours d'exécution (État: $status)"
                all_healthy=false
            fi
        else
            log_error "$container n'est pas en cours d'exécution"
            all_healthy=false
        fi
    done
    
    if $all_healthy; then
        log_success "Tous les conteneurs sont en bonne santé"
    else
        log_warning "Certains conteneurs ne sont pas en bonne santé"
    fi
}

# Nettoyer les conteneurs
cleanup_containers() {
    log "Nettoyage des conteneurs..."
    
    # Arrêter et supprimer les conteneurs
    if docker-compose down; then
        log_success "Les conteneurs ont été arrêtés et supprimés"
    else
        log_error "Erreur lors de l'arrêt et de la suppression des conteneurs"
        return 1
    fi
    
    # Supprimer les images non utilisées
    if docker image prune -f; then
        log_success "Les images non utilisées ont été supprimées"
    else
        log_warning "Erreur lors de la suppression des images non utilisées"
    fi
    
    # Supprimer les volumes non utilisés
    if docker volume prune -f; then
        log_success "Les volumes non utilisés ont été supprimés"
    else
        log_warning "Erreur lors de la suppression des volumes non utilisés"
    fi
}

# Afficher les logs des conteneurs
show_logs() {
    local container=$1
    
    if [ -z "$container" ]; then
        log "Affichage des logs de tous les conteneurs..."
        docker-compose logs --tail=100 -f
    else
        log "Affichage des logs du conteneur $container..."
        docker-compose logs --tail=100 -f "$container"
    fi
}

# Afficher l'aide
show_help() {
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  start       Démarrer tous les conteneurs"
    echo "  stop        Arrêter tous les conteneurs"
    echo "  restart     Redémarrer tous les conteneurs"
    echo "  check       Vérifier l'état des conteneurs"
    echo "  cleanup     Nettoyer les conteneurs et les ressources non utilisées"
    echo "  logs [container]  Afficher les logs (optionnel: spécifier un conteneur)"
    echo "  help        Afficher cette aide"
    echo ""
    echo "Options:"
    echo "  -h, --help  Afficher cette aide"
}

# Fonction principale
main() {
    local command=$1
    local container=$2
    
    check_prerequisites
    
    case "$command" in
        start)
            start_containers
            ;;
        stop)
            stop_containers
            ;;
        restart)
            restart_containers
            ;;
        check)
            check_containers
            ;;
        cleanup)
            cleanup_containers
            ;;
        logs)
            show_logs "$container"
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            log_error "Commande inconnue: $command"
            show_help
            exit 1
            ;;
    esac
}

# Exécuter la fonction principale
main "$@" 
