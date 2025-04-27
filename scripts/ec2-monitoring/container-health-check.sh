#!/bin/bash
# Script de surveillance des conteneurs Docker
# Auteur: Med3Sin
# Date: $(date +%Y-%m-%d)

# Fonction de journalisation
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Vérifier si le script est exécuté avec les privilèges root
if [ "$(id -u)" -ne 0 ]; then
    log "Ce script doit être exécuté avec les privilèges root (sudo)."
    exit 1
fi

# Liste des conteneurs à surveiller
CONTAINERS=("prometheus" "grafana" "sonarqube" "sonarqube-db" "cloudwatch-exporter" "mysql-exporter")

# Fonction pour vérifier l'état d'un conteneur
check_container() {
    local container=$1
    local status=$(docker inspect --format='{{.State.Status}}' $container 2>/dev/null)
    local exit_code=$(docker inspect --format='{{.State.ExitCode}}' $container 2>/dev/null)
    local health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}N/A{{end}}' $container 2>/dev/null)
    local restart_count=$(docker inspect --format='{{.RestartCount}}' $container 2>/dev/null)
    
    if [ "$status" == "running" ]; then
        if [ "$health" == "healthy" ] || [ "$health" == "N/A" ]; then
            log "✅ Conteneur $container: En cours d'exécution (Santé: $health, Redémarrages: $restart_count)"
            return 0
        else
            log "⚠️ Conteneur $container: En cours d'exécution mais état de santé: $health (Redémarrages: $restart_count)"
            return 1
        fi
    else
        log "❌ Conteneur $container: $status (Code de sortie: $exit_code, Redémarrages: $restart_count)"
        return 2
    fi
}

# Fonction pour récupérer les logs récents d'un conteneur
get_recent_logs() {
    local container=$1
    local lines=${2:-10}
    log "Derniers logs de $container:"
    docker logs --tail $lines $container 2>&1 | sed 's/^/    /'
}

# Fonction pour redémarrer un conteneur
restart_container() {
    local container=$1
    log "Redémarrage du conteneur $container..."
    docker restart $container
    sleep 5
    check_container $container
}

# Fonction pour vérifier l'utilisation des ressources
check_resources() {
    local container=$1
    log "Utilisation des ressources pour $container:"
    docker stats --no-stream $container | sed 's/^/    /'
}

# Vérifier tous les conteneurs
check_all_containers() {
    local failed_containers=()
    
    log "Début de la vérification des conteneurs..."
    
    for container in "${CONTAINERS[@]}"; do
        if ! check_container $container; then
            failed_containers+=("$container")
            get_recent_logs $container
            check_resources $container
        fi
    done
    
    # Afficher un résumé
    log "Résumé de la vérification:"
    log "  Total des conteneurs vérifiés: ${#CONTAINERS[@]}"
    log "  Conteneurs en échec: ${#failed_containers[@]}"
    
    if [ ${#failed_containers[@]} -gt 0 ]; then
        log "Liste des conteneurs en échec:"
        for container in "${failed_containers[@]}"; do
            log "  - $container"
        done
        
        # Option pour redémarrer automatiquement les conteneurs en échec
        if [ "$AUTO_RESTART" == "true" ]; then
            log "Redémarrage automatique des conteneurs en échec..."
            for container in "${failed_containers[@]}"; do
                restart_container $container
            done
        fi
        
        return 1
    fi
    
    return 0
}

# Vérifier l'espace disque disponible
check_disk_space() {
    log "Vérification de l'espace disque..."
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    local disk_threshold=${DISK_THRESHOLD:-90}
    
    if [ "$disk_usage" -gt "$disk_threshold" ]; then
        log "⚠️ Alerte: Utilisation du disque à $disk_usage% (seuil: $disk_threshold%)"
        return 1
    else
        log "✅ Espace disque OK: $disk_usage% utilisé"
        return 0
    fi
}

# Vérifier l'utilisation de la mémoire
check_memory() {
    log "Vérification de la mémoire..."
    local mem_usage=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
    local mem_threshold=${MEM_THRESHOLD:-90}
    
    if [ "$mem_usage" -gt "$mem_threshold" ]; then
        log "⚠️ Alerte: Utilisation de la mémoire à $mem_usage% (seuil: $mem_threshold%)"
        return 1
    else
        log "✅ Mémoire OK: $mem_usage% utilisée"
        return 0
    fi
}

# Vérifier l'utilisation du CPU
check_cpu() {
    log "Vérification du CPU..."
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    local cpu_threshold=${CPU_THRESHOLD:-90}
    
    if [ "$(echo "$cpu_usage > $cpu_threshold" | bc)" -eq 1 ]; then
        log "⚠️ Alerte: Utilisation du CPU à $cpu_usage% (seuil: $cpu_threshold%)"
        return 1
    else
        log "✅ CPU OK: $cpu_usage% utilisé"
        return 0
    fi
}

# Fonction principale
main() {
    log "Démarrage de la surveillance des conteneurs..."
    
    # Vérifier les ressources système
    check_disk_space
    check_memory
    check_cpu
    
    # Vérifier les conteneurs
    check_all_containers
    
    log "Surveillance des conteneurs terminée."
}

# Exécuter la fonction principale
main "$@"
