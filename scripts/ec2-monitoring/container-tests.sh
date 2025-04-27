#!/bin/bash
# Script de tests automatisés pour les conteneurs Docker
# Auteur: Med3Sin
# Date: $(date +%Y-%m-%d)

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
    log "Ce script doit être exécuté avec les privilèges root (sudo)."
    exit 1
fi

# Définir le répertoire de sortie pour les rapports de test
REPORT_DIR="/opt/monitoring/test-reports"
mkdir -p "$REPORT_DIR"

# Fichier de rapport
REPORT_FILE="$REPORT_DIR/container-tests-$(date +%Y%m%d-%H%M%S).json"

# Liste des conteneurs à tester
CONTAINERS=("prometheus" "grafana" "sonarqube" "sonarqube-db" "cloudwatch-exporter" "mysql-exporter" "loki" "promtail")

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

# Exécuter tous les tests
run_all_tests
