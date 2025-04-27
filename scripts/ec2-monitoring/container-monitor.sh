#!/bin/bash
#==============================================================================
# Nom du script : container-monitor.sh
# Description   : Script unifié pour la surveillance et les tests des conteneurs Docker.
#                 Ce script combine les fonctionnalités de container-health-check.sh
#                 et container-tests.sh.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2025-04-27
#==============================================================================
# Utilisation   : sudo ./container-monitor.sh [options]
#
# Options       :
#   --mode=MODE     : Mode d'exécution (health, test, all) (par défaut: health)
#   --auto-restart  : Redémarrer automatiquement les conteneurs en échec
#   --report-dir=DIR: Répertoire pour les rapports de test (par défaut: /opt/monitoring/test-reports)
#   --containers=LIST: Liste des conteneurs à surveiller, séparés par des virgules
#   --thresholds=LIST: Seuils d'alerte (disk:90,mem:90,cpu:90)
#
# Exemples      :
#   sudo ./container-monitor.sh
#   sudo ./container-monitor.sh --mode=test
#   sudo ./container-monitor.sh --mode=all --auto-restart
#   sudo ./container-monitor.sh --containers=prometheus,grafana
#==============================================================================
# Dépendances   :
#   - docker     : Pour gérer les conteneurs
#   - curl       : Pour tester les API
#   - nc         : Pour tester les ports
#   - jq         : Pour le traitement JSON (optionnel)
#==============================================================================
# Droits requis : Ce script doit être exécuté avec des privilèges sudo ou en tant que root.
#==============================================================================

# Fonction de journalisation
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Fonction pour afficher les erreurs et quitter
error_exit() {
    log "ERREUR: $1"
    exit 1
}

# Vérifier si le script est exécuté avec les privilèges root
if [ "$(id -u)" -ne 0 ]; then
    error_exit "Ce script doit être exécuté avec les privilèges root (sudo)."
fi

# Variables par défaut
MODE="health"
AUTO_RESTART=false
REPORT_DIR="/opt/monitoring/test-reports"
DEFAULT_CONTAINERS=("prometheus" "grafana" "sonarqube" "sonarqube-db" "cloudwatch-exporter" "mysql-exporter")
CONTAINERS=("${DEFAULT_CONTAINERS[@]}")
DISK_THRESHOLD=90
MEM_THRESHOLD=90
CPU_THRESHOLD=90

# Traitement des arguments
for arg in "$@"; do
    case $arg in
        --mode=*)
            MODE="${arg#*=}"
            if [ "$MODE" != "health" ] && [ "$MODE" != "test" ] && [ "$MODE" != "all" ]; then
                error_exit "Mode invalide: $MODE. Les modes valides sont: health, test, all"
            fi
            shift
            ;;
        --auto-restart)
            AUTO_RESTART=true
            shift
            ;;
        --report-dir=*)
            REPORT_DIR="${arg#*=}"
            shift
            ;;
        --containers=*)
            IFS=',' read -r -a CONTAINERS <<< "${arg#*=}"
            shift
            ;;
        --thresholds=*)
            THRESHOLDS="${arg#*=}"
            # Traiter les seuils
            IFS=',' read -r -a THRESHOLD_ARRAY <<< "$THRESHOLDS"
            for threshold in "${THRESHOLD_ARRAY[@]}"; do
                KEY="${threshold%%:*}"
                VALUE="${threshold#*:}"
                case $KEY in
                    disk) DISK_THRESHOLD=$VALUE ;;
                    mem) MEM_THRESHOLD=$VALUE ;;
                    cpu) CPU_THRESHOLD=$VALUE ;;
                    *) log "Seuil inconnu: $KEY, ignoré" ;;
                esac
            done
            shift
            ;;
        *)
            error_exit "Option inconnue: $arg"
            ;;
    esac
done

# Créer le répertoire de rapport si nécessaire
mkdir -p "$REPORT_DIR"

# Fichier de rapport
REPORT_FILE="$REPORT_DIR/container-monitor-$(date +%Y%m%d-%H%M%S).json"

# Liste des ports à tester
declare -A PORTS
PORTS["prometheus"]=9090
PORTS["grafana"]=3000
PORTS["sonarqube"]=9000
PORTS["sonarqube-db"]=5432
PORTS["cloudwatch-exporter"]=9106
PORTS["mysql-exporter"]=9104
PORTS["loki"]=3100
PORTS["promtail"]=9080

#==============================================================================
# Fonctions de vérification de santé
#==============================================================================

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
    
    if [ "$disk_usage" -gt "$DISK_THRESHOLD" ]; then
        log "⚠️ Alerte: Utilisation du disque à $disk_usage% (seuil: $DISK_THRESHOLD%)"
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
    
    if [ "$mem_usage" -gt "$MEM_THRESHOLD" ]; then
        log "⚠️ Alerte: Utilisation de la mémoire à $mem_usage% (seuil: $MEM_THRESHOLD%)"
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
    
    if (( $(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l) )); then
        log "⚠️ Alerte: Utilisation du CPU à $cpu_usage% (seuil: $CPU_THRESHOLD%)"
        return 1
    else
        log "✅ CPU OK: $cpu_usage% utilisé"
        return 0
    fi
}

# Fonction principale pour la vérification de santé
run_health_check() {
    log "Démarrage de la surveillance des conteneurs..."
    
    # Vérifier les ressources système
    check_disk_space
    check_memory
    check_cpu
    
    # Vérifier les conteneurs
    check_all_containers
    
    log "Surveillance des conteneurs terminée."
}

#==============================================================================
# Fonctions de test
#==============================================================================

# Fonction pour tester si un conteneur est en cours d'exécution
test_container_running() {
    local container=$1
    local status=$(docker inspect --format='{{.State.Status}}' $container 2>/dev/null)
    
    if [ "$status" == "running" ]; then
        return 0
    else
        return 1
    fi
}

# Fonction pour tester si un port est accessible
test_port_accessible() {
    local container=$1
    local port=${PORTS[$container]}
    
    if [ -z "$port" ]; then
        return 0  # Pas de port à tester
    fi
    
    if nc -z localhost $port; then
        return 0
    else
        return 1
    fi
}

# Fonction pour tester la santé d'un conteneur
test_container_health() {
    local container=$1
    local health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}N/A{{end}}' $container 2>/dev/null)
    
    if [ "$health" == "healthy" ] || [ "$health" == "N/A" ]; then
        return 0
    else
        return 1
    fi
}

# Fonction pour tester les métriques Prometheus
test_prometheus_metrics() {
    local container=$1
    local port=${PORTS[$container]}
    
    if [ -z "$port" ]; then
        return 0  # Pas de port à tester
    fi
    
    # Vérifier si le conteneur expose des métriques Prometheus
    if curl -s "http://localhost:$port/metrics" | grep -q "go_"; then
        return 0
    else
        return 1
    fi
}

# Fonction pour exécuter tous les tests pour un conteneur
run_tests_for_container() {
    local container=$1
    local results=()
    local test_status=0
    
    # Test 1: Conteneur en cours d'exécution
    if test_container_running $container; then
        results+=("\"container_running\": true")
    else
        results+=("\"container_running\": false")
        test_status=1
    fi
    
    # Test 2: Port accessible
    if test_port_accessible $container; then
        results+=("\"port_accessible\": true")
    else
        results+=("\"port_accessible\": false")
        test_status=1
    fi
    
    # Test 3: Santé du conteneur
    if test_container_health $container; then
        results+=("\"container_health\": true")
    else
        results+=("\"container_health\": false")
        test_status=1
    fi
    
    # Test 4: Métriques Prometheus (si applicable)
    if test_prometheus_metrics $container; then
        results+=("\"prometheus_metrics\": true")
    else
        results+=("\"prometheus_metrics\": false")
        # Ne pas échouer le test si les métriques ne sont pas disponibles
    fi
    
    # Ajouter les résultats au rapport
    echo "  \"$container\": {"
    echo "    $(IFS=, ; echo "${results[*]}"),"
    echo "    \"status\": $([ $test_status -eq 0 ] && echo "\"pass\"" || echo "\"fail\""),"
    echo "    \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\""
    echo "  }$([ $container != ${CONTAINERS[-1]} ] && echo ",")"
    
    return $test_status
}

# Fonction principale pour exécuter tous les tests
run_all_tests() {
    local failed_tests=0
    local total_tests=${#CONTAINERS[@]}
    local passed_tests=0
    
    log "Démarrage des tests des conteneurs..."
    
    # Début du rapport JSON
    echo "{" > $REPORT_FILE
    echo "  \"test_suite\": \"Container Tests\"," >> $REPORT_FILE
    echo "  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"," >> $REPORT_FILE
    echo "  \"results\": {" >> $REPORT_FILE
    
    # Exécuter les tests pour chaque conteneur
    for container in "${CONTAINERS[@]}"; do
        log "Exécution des tests pour le conteneur $container..."
        if run_tests_for_container $container >> $REPORT_FILE; then
            log "✅ Tests réussis pour $container"
            passed_tests=$((passed_tests + 1))
        else
            log "❌ Tests échoués pour $container"
            failed_tests=$((failed_tests + 1))
            
            # Option pour redémarrer automatiquement les conteneurs en échec
            if [ "$AUTO_RESTART" == "true" ]; then
                log "Redémarrage automatique du conteneur $container..."
                restart_container $container
            fi
        fi
    done
    
    # Fin du rapport JSON
    echo "  }," >> $REPORT_FILE
    echo "  \"summary\": {" >> $REPORT_FILE
    echo "    \"total\": $total_tests," >> $REPORT_FILE
    echo "    \"passed\": $passed_tests," >> $REPORT_FILE
    echo "    \"failed\": $failed_tests," >> $REPORT_FILE
    echo "    \"status\": $([ $failed_tests -eq 0 ] && echo "\"pass\"" || echo "\"fail\"")" >> $REPORT_FILE
    echo "  }" >> $REPORT_FILE
    echo "}" >> $REPORT_FILE
    
    log "Tests terminés. Rapport généré: $REPORT_FILE"
    log "Résumé: $passed_tests/$total_tests tests réussis, $failed_tests échecs."
    
    # Afficher le rapport
    cat $REPORT_FILE
    
    return $failed_tests
}

#==============================================================================
# Exécution principale
#==============================================================================

log "Démarrage du script container-monitor.sh en mode $MODE"
log "Conteneurs à surveiller: ${CONTAINERS[*]}"

case $MODE in
    health)
        run_health_check
        ;;
    test)
        run_all_tests
        ;;
    all)
        run_health_check
        run_all_tests
        ;;
esac

log "Script container-monitor.sh terminé"
exit 0
