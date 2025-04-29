#!/bin/bash
#==============================================================================
# Nom du script : restart-containers.sh
# Description   : Script pour redémarrer les conteneurs Docker après avoir récupéré
#                 les informations RDS et S3. Ce script arrête les conteneurs existants,
#                 met à jour les configurations et redémarre les conteneurs.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2025-04-27
#==============================================================================
# Utilisation   : sudo ./restart-containers.sh
#
# Exemples      :
#   sudo ./restart-containers.sh
#==============================================================================
# Dépendances   :
#   - docker    : Pour gérer les conteneurs
#   - docker-compose : Pour orchestrer les conteneurs
#==============================================================================
# Fichiers requis :
#   - /opt/monitoring/docker-compose.yml : Fichier de configuration Docker Compose
#   - /opt/monitoring/get-aws-resources-info.sh : Script pour récupérer les informations AWS (optionnel)
#   - /opt/monitoring/fix_permissions.sh : Script pour corriger les permissions (optionnel)
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

# Vérification si le script est exécuté avec sudo
if [ "$(id -u)" -ne 0 ]; then
    error_exit "Ce script doit être exécuté avec sudo"
fi

# Vérification des dépendances
check_dependency() {
    local cmd=$1
    local pkg=$2

    if ! command -v $cmd &> /dev/null; then
        log "Dépendance manquante: $cmd. Installation de $pkg..."
        sudo dnf install -y $pkg || error_exit "Impossible d'installer $pkg"
    fi
}

check_dependency docker docker
check_dependency docker-compose docker-compose

# Récupérer les informations RDS et S3
log "Récupération des informations RDS et S3..."
if [ -f "/opt/monitoring/get-aws-resources-info.sh" ]; then
    log "Exécution du script get-aws-resources-info.sh..."
    sudo /opt/monitoring/get-aws-resources-info.sh

    # Vérifier si le script a réussi
    if [ $? -ne 0 ]; then
        log "AVERTISSEMENT: Le script get-aws-resources-info.sh a échoué."
    fi
else
    log "AVERTISSEMENT: Le script get-aws-resources-info.sh n'est pas disponible."
fi

# Charger les variables d'environnement
if [ -f "/opt/monitoring/aws-resources.env" ]; then
    log "Chargement des variables d'environnement depuis aws-resources.env..."
    source /opt/monitoring/aws-resources.env
else
    log "AVERTISSEMENT: Le fichier aws-resources.env n'existe pas."
fi

# Vérifier si docker-compose.yml existe
if [ ! -f "/opt/monitoring/docker-compose.yml" ]; then
    error_exit "Le fichier docker-compose.yml n'existe pas."
fi

# Arrêter les conteneurs existants
log "Arrêt des conteneurs existants..."
cd /opt/monitoring
docker-compose down || log "AVERTISSEMENT: Impossible d'arrêter les conteneurs."

# Exécuter le script de correction des permissions
log "Exécution du script de correction des permissions..."
if [ -f "/opt/monitoring/fix_permissions.sh" ]; then
    sudo /opt/monitoring/fix_permissions.sh || log "AVERTISSEMENT: Le script fix_permissions.sh a échoué."
else
    log "AVERTISSEMENT: Le script fix_permissions.sh n'est pas disponible."
    # Correction manuelle des permissions
    log "Application manuelle des permissions..."
    sudo chown -R 65534:65534 /opt/monitoring/prometheus-data
    sudo chmod -R 755 /opt/monitoring/prometheus-data
    sudo chown -R 472:472 /opt/monitoring/grafana-data
    sudo chmod -R 755 /opt/monitoring/grafana-data

fi

# Démarrer les conteneurs
log "Démarrage des conteneurs..."
docker-compose up -d

# Vérifier si les conteneurs sont en cours d'exécution
log "Vérification du statut des conteneurs..."
docker ps

# Vérifier si tous les conteneurs sont en cours d'exécution
EXPECTED_CONTAINERS=4  # prometheus, grafana, cloudwatch-exporter, mysql-exporter
RUNNING_CONTAINERS=$(docker ps --filter "name=prometheus|grafana|cloudwatch-exporter|mysql-exporter" --format "{{.Names}}" | wc -l)

if [ "$RUNNING_CONTAINERS" -lt "$EXPECTED_CONTAINERS" ]; then
    log "AVERTISSEMENT: Certains conteneurs ne sont pas en cours d'exécution. Vérifiez les logs pour plus d'informations."
    docker ps -a
    log "Logs des conteneurs qui ont échoué:"
    for container in prometheus grafana cloudwatch-exporter mysql-exporter; do
        if ! docker ps --filter "name=$container" --format "{{.Names}}" | grep -q "$container"; then
            log "Logs du conteneur $container:"
            docker logs $container 2>&1 | tail -n 20
        fi
    done
else
    log "Tous les conteneurs sont en cours d'exécution."
fi

log "Redémarrage des conteneurs terminé avec succès."
log "Grafana est accessible à l'adresse http://localhost:3000"
log "Prometheus est accessible à l'adresse http://localhost:9090"


exit 0
