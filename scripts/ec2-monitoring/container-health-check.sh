#!/bin/bash
#==============================================================================
# Nom du script : container-health-check.sh
# Description   : Script de vérification de santé des conteneurs Docker.
#                 Ce script est un wrapper pour container-monitor.sh en mode health.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2025-05-02
#==============================================================================
# Utilisation   : sudo ./container-health-check.sh [options]
#
# Options       :
#   --auto-restart  : Redémarrer automatiquement les conteneurs en échec
#   --containers=LIST: Liste des conteneurs à surveiller, séparés par des virgules
#
# Exemples      :
#   sudo ./container-health-check.sh
#   sudo ./container-health-check.sh --auto-restart
#==============================================================================
# Dépendances   :
#   - container-monitor.sh : Script principal de surveillance des conteneurs
#==============================================================================
# Droits requis : Ce script doit être exécuté avec des privilèges sudo ou en tant que root.
#==============================================================================

# Exécuter container-monitor.sh en mode health
$(dirname "$0")/container-monitor.sh --mode=health "$@"
