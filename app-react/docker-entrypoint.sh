#!/bin/sh
set -e

# Afficher la version de serve
echo "Serve version:"
serve --version

# Démarrer serve avec les options appropriées
exec serve -s build -p 3000 --host 0.0.0.0
