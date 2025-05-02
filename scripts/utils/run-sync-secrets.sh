#!/bin/bash
#==============================================================================
# Nom du script : run-sync-secrets.sh
# Description   : Exécute la synchronisation des secrets GitHub vers Terraform Cloud
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.1
# Date          : 2023-11-15
#==============================================================================
# Utilisation   : ./run-sync-secrets.sh
#
# Ce script exécute la synchronisation des secrets GitHub vers Terraform Cloud.
# Il demande interactivement les informations nécessaires si elles ne sont pas
# déjà définies comme variables d'environnement.
#
# Variables d'environnement utilisées :
#   - GITHUB_TOKEN : Token GitHub pour l'authentification
#   - TF_API_TOKEN : Token Terraform Cloud pour l'authentification
#   - GITHUB_REPOSITORY : Nom du dépôt GitHub (format: owner/repo)
#   - TF_WORKSPACE_ID : ID du workspace Terraform Cloud
#==============================================================================

set -e

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Fonction pour afficher les erreurs et quitter
error_exit() {
    log "ERREUR: $1"
    exit 1
}

# Fonction pour demander une valeur si elle n'est pas définie
ask_if_not_set() {
    local var_name=$1
    local prompt=$2
    local is_secret=${3:-false}

    if [ -z "${!var_name}" ]; then
        if [ "$is_secret" = "true" ]; then
            # Pour les secrets, utiliser read -s pour ne pas afficher la saisie
            read -s -p "$prompt: " value
            echo  # Ajouter une nouvelle ligne après la saisie
        else
            read -p "$prompt: " value
        fi
        eval "$var_name=\"$value\""
    fi
}

# Vérifier si le script de synchronisation existe
SYNC_SCRIPT="./scripts/utils/sync-github-secrets-to-terraform.sh"
if [ ! -f "$SYNC_SCRIPT" ]; then
    error_exit "Le script de synchronisation n'existe pas: $SYNC_SCRIPT"
fi

# S'assurer que le script est exécutable
chmod +x "$SYNC_SCRIPT"

# Demander les informations nécessaires si elles ne sont pas définies
ask_if_not_set "GITHUB_TOKEN" "Entrez votre token GitHub (avec les droits repo et workflow)" true
ask_if_not_set "TF_API_TOKEN" "Entrez votre token Terraform Cloud" true
ask_if_not_set "GITHUB_REPOSITORY" "Entrez le nom du dépôt GitHub (format: owner/repo)"
ask_if_not_set "TF_WORKSPACE_ID" "Entrez l'ID du workspace Terraform Cloud"

# Afficher les informations (sans les tokens)
log "Synchronisation des secrets GitHub vers Terraform Cloud"
log "Dépôt GitHub: $GITHUB_REPOSITORY"
log "Workspace Terraform Cloud: $TF_WORKSPACE_ID"

# Exporter les variables d'environnement pour le script de synchronisation
export GITHUB_TOKEN
export TF_API_TOKEN
export GITHUB_REPOSITORY
export TF_WORKSPACE_ID

# Exécuter le script de synchronisation
log "Exécution du script de synchronisation..."
"$SYNC_SCRIPT"

# Vérifier le code de retour
if [ $? -eq 0 ]; then
    log "Synchronisation terminée avec succès ✅"
else
    error_exit "La synchronisation a échoué ❌"
fi
