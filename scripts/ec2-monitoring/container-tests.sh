#!/bin/bash
# Script de tests des conteneurs
# Ce script est un lien symbolique vers container-monitor.sh

# Exécuter container-monitor.sh en mode test
$(dirname "$0")/container-monitor.sh --mode=test "$@"
