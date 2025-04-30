#!/bin/bash
# Script de vérification de santé des conteneurs
# Ce script est un lien symbolique vers container-monitor.sh

# Exécuter container-monitor.sh en mode health
$(dirname "$0")/container-monitor.sh --mode=health "$@"
