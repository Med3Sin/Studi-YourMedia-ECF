#!/bin/bash
#==============================================================================
# Nom du script : check-grafana-datasources.sh
# Description   : Script pour vérifier les sources de données Grafana
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
#==============================================================================
# Utilisation   : sudo ./check-grafana-datasources.sh
#==============================================================================

# Fonction pour afficher les messages d'information
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] $1"
}

# Fonction pour afficher les messages d'erreur et quitter
log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [ERROR] $1" >&2
}

# Fonction pour afficher les messages de succès
log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [SUCCESS] $1"
}

# Vérifier si le script est exécuté en tant que root
if [ "$(id -u)" -ne 0 ]; then
    log_error "Ce script doit être exécuté en tant que root ou avec sudo"
    exit 1
fi

# Vérifier si curl est installé
if ! command -v curl &> /dev/null; then
    log_error "curl n'est pas installé"
    exit 1
fi

# Vérifier si jq est installé
if ! command -v jq &> /dev/null; then
    log_info "jq n'est pas installé, installation en cours..."
    apt-get update && apt-get install -y jq || yum install -y jq
    if [ $? -ne 0 ]; then
        log_error "Échec de l'installation de jq"
        exit 1
    fi
    log_success "jq installé avec succès"
fi

# Vérifier si Grafana est en cours d'exécution
log_info "Vérification si Grafana est en cours d'exécution"
if ! docker ps | grep -q "grafana"; then
    log_error "Grafana n'est pas en cours d'exécution"
    exit 1
fi

# Définir les variables
GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="admin"
GRAFANA_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD:-YourMedia2025!}

# Vérifier si Grafana est accessible
log_info "Vérification si Grafana est accessible"
if ! curl -s -o /dev/null -w "%{http_code}" $GRAFANA_URL | grep -q "200"; then
    log_error "Grafana n'est pas accessible"
    exit 1
fi

# Obtenir un jeton d'authentification
log_info "Obtention d'un jeton d'authentification"
TOKEN=$(curl -s -X POST -H "Content-Type: application/json" -d "{\"name\":\"api_key\", \"role\": \"Admin\"}" $GRAFANA_URL/api/auth/keys -u $GRAFANA_USER:$GRAFANA_PASSWORD | jq -r '.key')
if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then
    log_error "Échec de l'obtention du jeton d'authentification"
    # Essayer avec l'authentification de base
    log_info "Essai avec l'authentification de base"
    TOKEN="$GRAFANA_USER:$GRAFANA_PASSWORD"
fi

# Vérifier les sources de données
log_info "Vérification des sources de données"
DATASOURCES=$(curl -s -H "Authorization: Bearer $TOKEN" $GRAFANA_URL/api/datasources -u $GRAFANA_USER:$GRAFANA_PASSWORD)
echo "$DATASOURCES" | jq .

# Vérifier la source de données Prometheus
log_info "Vérification de la source de données Prometheus"
if echo "$DATASOURCES" | jq -e '.[] | select(.name=="Prometheus")' > /dev/null; then
    log_success "Source de données Prometheus trouvée"
    PROMETHEUS_ID=$(echo "$DATASOURCES" | jq -r '.[] | select(.name=="Prometheus") | .id')
    
    # Tester la source de données Prometheus
    log_info "Test de la source de données Prometheus"
    PROMETHEUS_TEST=$(curl -s -H "Authorization: Bearer $TOKEN" $GRAFANA_URL/api/datasources/$PROMETHEUS_ID/health -u $GRAFANA_USER:$GRAFANA_PASSWORD)
    echo "$PROMETHEUS_TEST" | jq .
else
    log_error "Source de données Prometheus non trouvée"
    
    # Créer la source de données Prometheus
    log_info "Création de la source de données Prometheus"
    PROMETHEUS_CREATE=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d '{
        "name": "Prometheus",
        "type": "prometheus",
        "url": "http://prometheus:9090",
        "access": "proxy",
        "isDefault": true
    }' $GRAFANA_URL/api/datasources -u $GRAFANA_USER:$GRAFANA_PASSWORD)
    echo "$PROMETHEUS_CREATE" | jq .
fi

# Vérifier la source de données Loki
log_info "Vérification de la source de données Loki"
if echo "$DATASOURCES" | jq -e '.[] | select(.name=="Loki")' > /dev/null; then
    log_success "Source de données Loki trouvée"
    LOKI_ID=$(echo "$DATASOURCES" | jq -r '.[] | select(.name=="Loki") | .id')
    
    # Tester la source de données Loki
    log_info "Test de la source de données Loki"
    LOKI_TEST=$(curl -s -H "Authorization: Bearer $TOKEN" $GRAFANA_URL/api/datasources/$LOKI_ID/health -u $GRAFANA_USER:$GRAFANA_PASSWORD)
    echo "$LOKI_TEST" | jq .
else
    log_error "Source de données Loki non trouvée"
    
    # Créer la source de données Loki
    log_info "Création de la source de données Loki"
    LOKI_CREATE=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d '{
        "name": "Loki",
        "type": "loki",
        "url": "http://loki:3100",
        "access": "proxy",
        "isDefault": false
    }' $GRAFANA_URL/api/datasources -u $GRAFANA_USER:$GRAFANA_PASSWORD)
    echo "$LOKI_CREATE" | jq .
fi

log_info "Vérification terminée"
exit 0
