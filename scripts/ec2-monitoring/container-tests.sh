#!/bin/bash
#==============================================================================
# Nom du script : container-tests.sh
# Description   : Script de tests des conteneurs Docker.
#                 Ce script est un wrapper pour container-monitor.sh en mode test.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2025-05-02
#==============================================================================
# Utilisation   : sudo ./container-tests.sh [options]
#
# Options       :
#   --auto-restart  : Redémarrer automatiquement les conteneurs en échec
#   --containers=LIST: Liste des conteneurs à surveiller, séparés par des virgules
#   --report-dir=DIR: Répertoire pour les rapports de test (par défaut: /opt/monitoring/test-reports)
#
# Exemples      :
#   sudo ./container-tests.sh
#   sudo ./container-tests.sh --auto-restart
#==============================================================================
# Dépendances   :
#   - container-monitor.sh : Script principal de surveillance des conteneurs
#==============================================================================
# Droits requis : Ce script doit être exécuté avec des privilèges sudo ou en tant que root.
#==============================================================================

# Exécuter container-monitor.sh en mode test
sudo $(dirname "$0")/container-monitor.sh --mode=test "$@"
