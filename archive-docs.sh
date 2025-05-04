#!/bin/bash

# Script pour archiver les documents obsolètes

# Créer le répertoire d'archive s'il n'existe pas
mkdir -p docs/archive

# Liste des fichiers à archiver
files_to_archive=(
  "docs/AMELIORATIONS-FUTURES.md"
  "docs/ARCHITECTURE-IMPROVEMENT-PLAN.md"
  "docs/CLEANUP-GUIDE.md"
  "docs/DOCUMENTATION-PLAN.md"
  "docs/FUTURE-IMPROVEMENTS.md"
  "docs/GUIDE-MONITORING.md"
  "docs/GUIDE-PRINCIPAL.md"
  "docs/GUIDE-TERRAFORM.md"
  "docs/GUIDE-VARIABLES.md"
  "docs/INSTANCE-INITIALIZATION.md"
  "docs/INSTANCE-ROLES-SEPARATION.md"
  "docs/MONITORING-SETUP-GUIDE.md"
  "docs/monitoring.md"
  "docs/RAPPORT-OPTIMISATIONS.md"
  "docs/RAPPORT-STANDARDISATION-VARIABLES.md"
  "docs/RAPPORT-STANDARDISATION.md"
  "docs/RAPPORT-VERIFICATION-FINALE.md"
  "docs/RAPPORT-VERIFICATION-PROJET.md"
  "docs/SCRIPTS-GITHUB-APPROACH.md"
  "docs/SYNC-SECRETS-GUIDE.md"
  "docs/TERRAFORM-CLOUD-TFSTATE.md"
  "docs/TERRAFORM-SECRETS-GUIDE.md"
  "docs/TROUBLESHOOTING-COMPLET.md"
  "docs/Variables-Management.md"
  "docs/DOCKER-INSTALLATION-AL2023.md"
  "docs/DOCKER-INSTALLATION-FIXES.md"
  "docs/AMAZON-LINUX-2023-MIGRATION.md"
  "docs/AMELIORATIONS-SECURITE-PRODUCTION.md"
  "docs/DOCKER-SECURITY-GUIDE.md"
  "docs/SSH-KEYS-MANAGEMENT.md"
  "docs/SCRIPT-PERMISSIONS.md"
  "docs/TOMCAT-DEPLOYMENT-GUIDE.md"
  "docs/WORKFLOWS-IMPROVEMENTS.md"
  "docs/GITHUB-ACTIONS-UPDATES.md"
  "docs/GITHUB-SECRETS-CONFIGURATION.md"
  "docs/GUIDE-GITHUB-ACTIONS.md"
  "docs/DOCKER-MANAGEMENT.md"
  "docs/DOCKER-TROUBLESHOOTING.md"
  "docs/DOCKER-VARIABLES-STANDARDISATION.md"
  "docs/GUIDE-DOCKER.md"
)

# Archiver chaque fichier
for file in "${files_to_archive[@]}"; do
  if [ -f "$file" ]; then
    echo "Archivage de $file..."
    mv "$file" "docs/archive/$(basename "$file")"
  else
    echo "Le fichier $file n'existe pas, ignoré."
  fi
done

echo "Archivage terminé."
