#!/bin/sh
set -e

# Afficher la version de serve
echo "Serve version:"
serve --version

# Démarrer serve avec les options appropriées
# Note: La version 14.2.4 de serve n'accepte pas l'option --host
# Utiliser l'option -l avec l'adresse IP et le port
exec serve -s build -l 3000
