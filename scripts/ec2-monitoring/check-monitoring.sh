#!/bin/bash
#==============================================================================
# Nom du script : check-monitoring.sh
# Description   : Script pour vérifier l'état des conteneurs et des connexions réseau
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
#==============================================================================
# Utilisation   : sudo ./check-monitoring.sh
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

# Vérifier l'état des conteneurs
log_info "Vérification de l'état des conteneurs"
CONTAINERS=$(docker ps -a --format "{{.Names}}: {{.Status}}")
echo "$CONTAINERS"

# Vérifier les réseaux Docker
log_info "Vérification des réseaux Docker"
NETWORKS=$(docker network ls)
echo "$NETWORKS"

# Vérifier le réseau monitoring_network
log_info "Vérification du réseau monitoring_network"
NETWORK_INFO=$(docker network inspect monitoring_network 2>/dev/null)
if [ $? -ne 0 ]; then
    log_error "Le réseau monitoring_network n'existe pas"
    log_info "Création du réseau monitoring_network"
    docker network create monitoring_network
    if [ $? -eq 0 ]; then
        log_success "Réseau monitoring_network créé avec succès"
    else
        log_error "Échec de la création du réseau monitoring_network"
        exit 1
    fi
else
    log_success "Le réseau monitoring_network existe"
    echo "$NETWORK_INFO"
fi

# Vérifier les connexions réseau entre les conteneurs
log_info "Vérification des connexions réseau entre les conteneurs"

# Vérifier la connexion entre Grafana et Prometheus
log_info "Vérification de la connexion entre Grafana et Prometheus"
docker exec -it grafana ping -c 2 prometheus
if [ $? -eq 0 ]; then
    log_success "Connexion entre Grafana et Prometheus OK"
else
    log_error "Échec de la connexion entre Grafana et Prometheus"
fi

# Vérifier la connexion entre Grafana et Loki
log_info "Vérification de la connexion entre Grafana et Loki"
docker exec -it grafana ping -c 2 loki
if [ $? -eq 0 ]; then
    log_success "Connexion entre Grafana et Loki OK"
else
    log_error "Échec de la connexion entre Grafana et Loki"
fi

# Vérifier la connexion entre Promtail et Loki
log_info "Vérification de la connexion entre Promtail et Loki"
docker exec -it promtail ping -c 2 loki
if [ $? -eq 0 ]; then
    log_success "Connexion entre Promtail et Loki OK"
else
    log_error "Échec de la connexion entre Promtail et Loki"
fi

# Vérifier les logs des conteneurs
log_info "Vérification des logs des conteneurs"

# Vérifier les logs de Grafana
log_info "Logs de Grafana (dernières 10 lignes)"
docker logs grafana --tail 10

# Vérifier les logs de Prometheus
log_info "Logs de Prometheus (dernières 10 lignes)"
docker logs prometheus --tail 10

# Vérifier les logs de Loki
log_info "Logs de Loki (dernières 10 lignes)"
docker logs loki --tail 10

# Vérifier les logs de Promtail
log_info "Logs de Promtail (dernières 10 lignes)"
docker logs promtail --tail 10

# Vérifier les sources de données dans Grafana
log_info "Vérification des sources de données dans Grafana"
DATASOURCES=$(curl -s -u admin:${GF_SECURITY_ADMIN_PASSWORD:-YourMedia2025!} http://localhost:3000/api/datasources)
echo "$DATASOURCES"

log_info "Vérification terminée"
exit 0
