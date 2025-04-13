#!/bin/bash

#############################################################################
# Script de correction des permissions pour Grafana et Prometheus
# 
# Ce script résout les problèmes courants de permissions qui empêchent
# Grafana et Prometheus de fonctionner correctement dans des conteneurs Docker.
#
# Problèmes résolus :
# - Prometheus : "open /prometheus/queries.active: permission denied"
# - Grafana : "GF_PATHS_DATA='/var/lib/grafana' is not writable"
#
# Auteur: Med3Sin
# Date: 2025-04-13
#############################################################################

# Afficher un message avec formatage
print_section() {
    echo ""
    echo "===================================================================="
    echo "  $1"
    echo "===================================================================="
    echo ""
}

# Afficher un message d'information
print_info() {
    echo "[INFO] $1"
}

# Afficher un message de succès
print_success() {
    echo "[SUCCÈS] $1"
}

# Afficher un message d'erreur
print_error() {
    echo "[ERREUR] $1" >&2
}

# Vérifier si une commande s'est exécutée avec succès
check_success() {
    if [ $? -eq 0 ]; then
        print_success "$1"
    else
        print_error "$1 a échoué"
    fi
}

#############################################################################
# ÉTAPE 1 : Arrêter les conteneurs existants
#############################################################################
print_section "Arrêt des conteneurs existants"

cd /opt/monitoring
print_info "Arrêt des conteneurs Docker..."
docker-compose down 2>/dev/null || true
check_success "Arrêt des conteneurs"

#############################################################################
# ÉTAPE 2 : Nettoyer et préparer les répertoires de données
#############################################################################
print_section "Préparation des répertoires de données"

# Nettoyer les répertoires de données existants
print_info "Nettoyage des répertoires de données..."
rm -rf /opt/monitoring/prometheus-data/*
rm -rf /opt/monitoring/grafana-data/*
check_success "Nettoyage des répertoires"

# Créer les répertoires s'ils n'existent pas
print_info "Création des répertoires de données..."
mkdir -p /opt/monitoring/prometheus-data
mkdir -p /opt/monitoring/grafana-data
check_success "Création des répertoires"

#############################################################################
# ÉTAPE 3 : Corriger les permissions des répertoires
#############################################################################
print_section "Configuration des permissions"

print_info "Configuration des permissions pour Prometheus (UID 65534)..."
chown -R 65534:65534 /opt/monitoring/prometheus-data
check_success "Configuration des permissions pour Prometheus"

print_info "Configuration des permissions pour Grafana (UID 472)..."
chown -R 472:472 /opt/monitoring/grafana-data
check_success "Configuration des permissions pour Grafana"

#############################################################################
# ÉTAPE 4 : Créer les fichiers de configuration
#############################################################################
print_section "Création des fichiers de configuration"

print_info "Création du fichier docker-compose.yml..."
cat > /opt/monitoring/docker-compose.yml << 'EOL'
version: '3'

services:
  # Service Prometheus
  # - Utilise l'UID 65534 pour éviter les problèmes de permissions
  # - Expose le port 9090 pour l'interface web
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    user: "65534"  # Utilisateur non privilégié dans le conteneur
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro  # Configuration en lecture seule
      - ./prometheus-data:/prometheus  # Données persistantes
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.enable-lifecycle'  # Permet de recharger la configuration
    restart: always

  # Service Grafana
  # - Utilise l'UID 472 pour éviter les problèmes de permissions
  # - Expose le port 3000 pour l'interface web
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    user: "472"  # Utilisateur Grafana dans le conteneur
    ports:
      - "3000:3000"
    volumes:
      - ./grafana-data:/var/lib/grafana  # Données persistantes
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin  # Mot de passe par défaut
      - GF_USERS_ALLOW_SIGN_UP=false  # Désactive l'inscription des utilisateurs
    restart: always
    depends_on:
      - prometheus
EOL
check_success "Création du fichier docker-compose.yml"

print_info "Création du fichier prometheus.yml..."
cat > /opt/monitoring/prometheus.yml << 'EOL'
# Configuration globale de Prometheus
global:
  scrape_interval: 15s      # Fréquence de collecte des métriques
  evaluation_interval: 15s  # Fréquence d'évaluation des règles d'alerte

# Configuration des cibles à surveiller
scrape_configs:
  # Prometheus lui-même
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Node Exporter (métriques système)
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']

  # Application Spring Boot
  - job_name: 'spring_boot'
    metrics_path: '/actuator/prometheus'  # Chemin des métriques Spring Boot
    static_configs:
      - targets: ['backend:8080']
EOL
check_success "Création du fichier prometheus.yml"

#############################################################################
# ÉTAPE 5 : Démarrer les conteneurs
#############################################################################
print_section "Démarrage des conteneurs"

print_info "Démarrage des conteneurs Docker..."
cd /opt/monitoring
docker-compose up -d
check_success "Démarrage des conteneurs"

#############################################################################
# ÉTAPE 6 : Vérification
#############################################################################
print_section "Vérification"

print_info "Statut des conteneurs:"
docker ps

# Vérifier si les conteneurs sont en cours d'exécution
if docker ps | grep -q "prometheus" && docker ps | grep -q "grafana"; then
    print_success "Les conteneurs Prometheus et Grafana sont en cours d'exécution."
    
    # Récupérer l'adresse IP publique
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
    
    echo ""
    print_section "Accès aux interfaces web"
    echo "Vous pouvez accéder aux interfaces web:"
    echo "- Prometheus: http://$PUBLIC_IP:9090"
    echo "- Grafana: http://$PUBLIC_IP:3000"
    echo ""
    echo "Identifiants Grafana par défaut:"
    echo "- Utilisateur: admin"
    echo "- Mot de passe: admin"
    echo ""
    echo "N'oubliez pas de vérifier que les ports 3000 et 9090 sont ouverts dans votre groupe de sécurité AWS."
    echo ""
 else
    print_error "Les conteneurs ne sont pas en cours d'exécution. Vérifiez les logs pour plus d'informations."
    echo "Logs de Prometheus:"
    docker logs prometheus
    echo "Logs de Grafana:"
    docker logs grafana
fi
