#!/bin/bash
#==============================================================================
# Nom du script : docker-cleanup.sh
# Description   : Script pour nettoyer les ressources Docker non utilisées
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2023-11-15
#==============================================================================

# Fonction pour afficher les messages d'information
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] $1"
}

# Fonction pour afficher les messages d'avertissement
log_warning() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [WARNING] $1" >&2
}

# Fonction pour afficher les messages d'erreur et quitter
log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [ERROR] $1" >&2
    exit 1
}

# Fonction pour afficher les messages de succès
log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [SUCCESS] $1"
}

# Vérifier l'espace disque avant le nettoyage
log_info "Vérification de l'espace disque avant le nettoyage..."
df -h / | grep -v "Filesystem"

# Vérifier l'utilisation de la mémoire avant le nettoyage
log_info "Vérification de l'utilisation de la mémoire avant le nettoyage..."
free -h

# Arrêter les conteneurs inutilisés
log_info "Arrêt des conteneurs inutilisés..."
unused_containers=$(sudo docker ps -a --filter "status=exited" --filter "status=created" --filter "status=dead" -q)
if [ -n "$unused_containers" ]; then
    sudo docker stop $unused_containers
    log_success "Conteneurs arrêtés: $(echo $unused_containers | wc -w)"
else
    log_info "Aucun conteneur inutilisé à arrêter."
fi

# Supprimer les conteneurs arrêtés
log_info "Suppression des conteneurs arrêtés..."
sudo docker container prune -f
log_success "Conteneurs arrêtés supprimés."

# Supprimer les images non utilisées
log_info "Suppression des images non utilisées..."
sudo docker image prune -a -f
log_success "Images non utilisées supprimées."

# Supprimer les volumes non utilisés
log_info "Suppression des volumes non utilisés..."
sudo docker volume prune -f
log_success "Volumes non utilisés supprimés."

# Supprimer les réseaux non utilisés
log_info "Suppression des réseaux non utilisés..."
sudo docker network prune -f
log_success "Réseaux non utilisés supprimés."

# Nettoyer le cache de construction
log_info "Nettoyage du cache de construction..."
sudo docker builder prune -f
log_success "Cache de construction nettoyé."

# Vérifier l'espace disque après le nettoyage
log_info "Vérification de l'espace disque après le nettoyage..."
df -h / | grep -v "Filesystem"

# Vérifier l'utilisation de la mémoire après le nettoyage
log_info "Vérification de l'utilisation de la mémoire après le nettoyage..."
free -h

log_success "Nettoyage des ressources Docker terminé."
exit 0
