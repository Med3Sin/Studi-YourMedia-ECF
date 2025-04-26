#!/bin/bash

# Script simplifié de correction des permissions pour Grafana et Prometheus
# Résout les problèmes de permissions dans les conteneurs Docker
#
# EXIGENCES EN MATIÈRE DE DROITS :
# Ce script doit être exécuté avec des privilèges sudo ou en tant que root.
# Exemple d'utilisation : sudo ./fix_permissions.sh [--force]
#
# Le script vérifie automatiquement les droits et affichera une erreur si nécessaire.

# Afficher l'aide
if [ "$1" = "--help" ]; then
    echo "Usage: sudo $0 [--force]"
    echo "  --force : Force le nettoyage des répertoires de données existants"
    echo ""
    echo "Ce script corrige les permissions pour Grafana et Prometheus"
    exit 0
fi

# Fonctions simplifiées pour les messages
info() { echo "[INFO] $1"; }
success() { echo "[SUCCÈS] $1"; }
error() { echo "[ERREUR] $1" >&2; }

# Vérifier si l'utilisateur a les droits sudo
if [ "$(id -u)" -ne 0 ]; then
    error "Ce script doit être exécuté avec sudo"
    error "Exemple: sudo $0 $*"

    # Tentative d'obtention des droits sudo
    info "Tentative d'obtention des privilèges sudo..."
    if sudo -n true 2>/dev/null; then
        info "Relancement du script avec sudo..."
        exec sudo "$0" "$@"
    else
        error "Impossible d'obtenir les privilèges sudo automatiquement."
        exit 1
    fi
fi

# ÉTAPE 1: Arrêter les conteneurs existants
info "Arrêt des conteneurs Docker..."
cd /opt/monitoring
docker-compose down 2>/dev/null || true

# ÉTAPE 2: Préparer les répertoires
info "Préparation des répertoires..."
mkdir -p /opt/monitoring/prometheus-data
mkdir -p /opt/monitoring/grafana-data

# Nettoyer les répertoires si --force est spécifié
if [ "$1" = "--force" ]; then
    info "Nettoyage des répertoires (--force)..."
    rm -rf /opt/monitoring/prometheus-data/*
    rm -rf /opt/monitoring/grafana-data/*
fi

# ÉTAPE 3: Corriger les permissions
info "Configuration des permissions..."
chown -R 65534:65534 /opt/monitoring/prometheus-data
chown -R 472:472 /opt/monitoring/grafana-data

# Création du répertoire pour CloudWatch Exporter s'il n'existe pas
if [ ! -d "/opt/monitoring/cloudwatch-config" ]; then
    info "Création du répertoire pour CloudWatch Exporter..."
    mkdir -p /opt/monitoring/cloudwatch-config
fi

# Vérification de l'existence du fichier de configuration CloudWatch
if [ ! -f "/opt/monitoring/cloudwatch-config/cloudwatch-config.yml" ] && [ -f "/opt/monitoring/cloudwatch-config.yml" ]; then
    info "Copie du fichier de configuration CloudWatch..."
    cp /opt/monitoring/cloudwatch-config.yml /opt/monitoring/cloudwatch-config/cloudwatch-config.yml
fi

# Configuration des permissions pour SonarQube
if [ -d "/opt/monitoring/sonarqube-data" ]; then
    info "Configuration des permissions pour SonarQube..."
    mkdir -p /opt/monitoring/sonarqube-data/data
    mkdir -p /opt/monitoring/sonarqube-data/logs
    mkdir -p /opt/monitoring/sonarqube-data/extensions
    mkdir -p /opt/monitoring/sonarqube-data/db
    chown -R 999:999 /opt/monitoring/sonarqube-data/data
    chown -R 999:999 /opt/monitoring/sonarqube-data/logs
    chown -R 999:999 /opt/monitoring/sonarqube-data/extensions
    chown -R 999:999 /opt/monitoring/sonarqube-data/db
fi

# ÉTAPE 4: Sauvegarder les fichiers de configuration
if [ -f "/opt/monitoring/docker-compose.yml" ]; then
    cp /opt/monitoring/docker-compose.yml /opt/monitoring/docker-compose.yml.bak
fi

if [ -f "/opt/monitoring/prometheus.yml" ]; then
    cp /opt/monitoring/prometheus.yml /opt/monitoring/prometheus.yml.bak
fi

# ÉTAPE 5: Mettre à jour les permissions dans docker-compose.yml
if [ -f "/opt/monitoring/docker-compose.yml" ]; then
    info "Mise à jour des permissions dans docker-compose.yml..."
    sed -i 's/\(\s*user:\s*\)"[^"]*"/\1"65534"/' /opt/monitoring/docker-compose.yml
    sed -i 's/\(\s*user:\s*\)"[^"]*"/\1"472"/' /opt/monitoring/docker-compose.yml
fi

# ÉTAPE 6: Démarrer les conteneurs
info "Démarrage des conteneurs Docker..."
cd /opt/monitoring
sudo docker-compose up -d

# ÉTAPE 7: Vérification
info "Vérification des conteneurs..."
sudo docker ps | grep -E 'prometheus|grafana'

# Afficher les URLs d'accès
if sudo docker ps | grep -q "prometheus" && sudo docker ps | grep -q "grafana"; then
    success "Les conteneurs sont en cours d'exécution"
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
    echo ""
    echo "Accès aux interfaces:"
    echo "- Prometheus: http://$PUBLIC_IP:9090"
    echo "- Grafana: http://$PUBLIC_IP:3000 (admin/admin)"
else
    error "Les conteneurs ne sont pas en cours d'exécution"
    sudo docker logs prometheus 2>&1 | tail -10
    sudo docker logs grafana 2>&1 | tail -10
fi
