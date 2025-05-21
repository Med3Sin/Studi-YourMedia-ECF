#!/bin/bash
#==============================================================================
# Nom du script : cleanup-obsolete.sh
# Description   : Script de nettoyage des fichiers obsolètes
# Auteur        : Med3Sin
# Version       : 1.0
# Date          : 2024-01-15
#==============================================================================

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Fonction pour vérifier si un fichier est référencé
is_file_referenced() {
    local file=$1
    local references=$(grep -r --include="*.{sh,yml,md,tf}" "$(basename "$file")" .)
    if [ -n "$references" ]; then
        return 0
    else
        return 1
    fi
}

# Fonction pour nettoyer les fichiers obsolètes
cleanup_obsolete_files() {
    log "Démarrage du nettoyage des fichiers obsolètes"
    
    # Liste des fichiers potentiellement obsolètes
    local obsolete_files=(
        "scripts/ec2-monitoring/fix-monitoring-legacy.sh"
        "scripts/utils/install-docker-al2023.sh"
        "scripts/docker/docker-manager-simple.sh"
        "infrastructure/modules/rds-mysql/main.tf.new2"
        "infrastructure/modules/rds-mysql/main.tf.new3"
    )
    
    # Vérifier chaque fichier
    for file in "${obsolete_files[@]}"; do
        if [ -f "$file" ]; then
            if ! is_file_referenced "$file"; then
                log "Suppression du fichier obsolète : $file"
                rm "$file"
            else
                log "Le fichier $file est toujours référencé, il sera conservé"
            fi
        fi
    done
    
    log "Nettoyage des fichiers obsolètes terminé"
}

# Fonction pour mettre à jour les références obsolètes
update_obsolete_references() {
    log "Mise à jour des références obsolètes"
    
    # Mettre à jour les références à Amazon Linux 2
    find . -type f -name "*.{sh,yml,md,tf}" -exec sed -i 's/Amazon Linux 2/Amazon Linux 2023/g' {} +
    
    # Mettre à jour les références à MySQL 8.0.35
    find . -type f -name "*.{sh,yml,md,tf}" -exec sed -i 's/MySQL 8.0.35/MySQL 8.0.28/g' {} +
    
    log "Mise à jour des références terminée"
}

# Fonction principale
main() {
    # Vérifier si le script est exécuté en tant que root
    if [ "$EUID" -ne 0 ]; then
        log "Ce script doit être exécuté en tant que root ou avec sudo"
        exit 1
    fi
    
    # Nettoyer les fichiers obsolètes
    cleanup_obsolete_files
    
    # Mettre à jour les références obsolètes
    update_obsolete_references
    
    log "Opération terminée avec succès"
}

# Exécution du script
main 