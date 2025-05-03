#!/bin/bash
#==============================================================================
# Nom du script : check-github-secrets.sh
# Description   : Vérifie que les secrets GitHub nécessaires sont configurés
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.1
# Date          : 2023-11-15
#==============================================================================
# Utilisation   : ./check-github-secrets.sh
#
# Ce script vérifie que les secrets GitHub nécessaires sont configurés.
# Il utilise les variables d'environnement suivantes :
#   - GITHUB_TOKEN : Token GitHub pour l'authentification
#   - GITHUB_REPOSITORY : Nom du dépôt GitHub (format: owner/repo)
#
# Les secrets suivants sont vérifiés :
#   - AWS_ACCESS_KEY_ID
#   - AWS_SECRET_ACCESS_KEY
#   - RDS_USERNAME
#   - RDS_PASSWORD
#   - EC2_SSH_PRIVATE_KEY
#   - EC2_SSH_PUBLIC_KEY
#   - DOCKERHUB_USERNAME (standard)
#   - DOCKERHUB_TOKEN (standard)
#   - DOCKERHUB_REPO (standard)
#   - TF_API_TOKEN
#   - TF_WORKSPACE_ID
#   - GRAFANA_ADMIN_PASSWORD
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

# Vérifier les variables d'environnement requises
if [ -z "$GITHUB_TOKEN" ]; then
    error_exit "La variable d'environnement GITHUB_TOKEN n'est pas définie"
fi

if [ -z "$GITHUB_REPOSITORY" ]; then
    # Si GITHUB_REPOSITORY n'est pas défini, essayer de le déduire du répertoire git
    GITHUB_REPOSITORY=$(git config --get remote.origin.url | sed -e 's/.*github.com[:\/]\(.*\)\.git/\1/')
    if [ -z "$GITHUB_REPOSITORY" ]; then
        error_exit "La variable d'environnement GITHUB_REPOSITORY n'est pas définie et n'a pas pu être déduite"
    fi
    log "GITHUB_REPOSITORY déduit: $GITHUB_REPOSITORY"
fi

log "Vérification des secrets GitHub pour le dépôt: $GITHUB_REPOSITORY"

# Liste des secrets à vérifier
REQUIRED_SECRETS=(
    "AWS_ACCESS_KEY_ID"
    "AWS_SECRET_ACCESS_KEY"
    "RDS_USERNAME"
    "RDS_PASSWORD"
    "EC2_SSH_PRIVATE_KEY"
    "EC2_SSH_PUBLIC_KEY"
    "DOCKERHUB_USERNAME"
    "DOCKERHUB_TOKEN"
    "DOCKERHUB_REPO"
    "TF_API_TOKEN"
    "TF_WORKSPACE_ID"
    "GF_SECURITY_ADMIN_PASSWORD"
)

# Variables pour le suivi des secrets manquants
MISSING_SECRETS=()
TOTAL_SECRETS=${#REQUIRED_SECRETS[@]}
FOUND_SECRETS=0

# Récupérer la liste des secrets configurés
log "Récupération de la liste des secrets configurés..."
SECRETS_RESPONSE=$(wget -q -O - \
    --header="Authorization: token $GITHUB_TOKEN" \
    --header="Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$GITHUB_REPOSITORY/actions/secrets")

# Vérifier si la réponse est valide
if [[ "$SECRETS_RESPONSE" == *"message"* && "$SECRETS_RESPONSE" == *"Not Found"* ]]; then
    error_exit "Impossible de récupérer les secrets. Vérifiez le token GitHub et le nom du dépôt."
fi

# Extraire les noms des secrets
CONFIGURED_SECRETS=$(echo "$SECRETS_RESPONSE" | jq -r '.secrets[].name')

# Vérifier chaque secret requis
for SECRET in "${REQUIRED_SECRETS[@]}"; do
    if echo "$CONFIGURED_SECRETS" | grep -q "^$SECRET$"; then
        log "✅ Secret trouvé: $SECRET"
        FOUND_SECRETS=$((FOUND_SECRETS+1))
    else
        log "❌ Secret manquant: $SECRET"
        MISSING_SECRETS+=("$SECRET")
    fi
done

# Vérifier les secrets de compatibilité
COMPAT_SECRETS=(
    "DOCKER_USERNAME:DOCKERHUB_USERNAME"
    "DOCKER_REPO:DOCKERHUB_REPO"
    "GRAFANA_ADMIN_PASSWORD:GF_SECURITY_ADMIN_PASSWORD"
    "DB_USERNAME:RDS_USERNAME"
    "DB_PASSWORD:RDS_PASSWORD"
)

for COMPAT in "${COMPAT_SECRETS[@]}"; do
    OLD_SECRET=$(echo "$COMPAT" | cut -d':' -f1)
    NEW_SECRET=$(echo "$COMPAT" | cut -d':' -f2)

    if echo "$CONFIGURED_SECRETS" | grep -q "^$OLD_SECRET$"; then
        if echo "$CONFIGURED_SECRETS" | grep -q "^$NEW_SECRET$"; then
            log "ℹ️ Les secrets $OLD_SECRET et $NEW_SECRET sont tous deux configurés (compatibilité)"
        else
            log "⚠️ Le secret de compatibilité $OLD_SECRET est configuré, mais le secret standard $NEW_SECRET est manquant"
            MISSING_SECRETS+=("$NEW_SECRET (remplacer par $OLD_SECRET)")
        fi
    fi
done

# Afficher le résumé
log "Résumé de la vérification des secrets:"
log "- Secrets requis: $TOTAL_SECRETS"
log "- Secrets trouvés: $FOUND_SECRETS"
log "- Secrets manquants: ${#MISSING_SECRETS[@]}"

if [ ${#MISSING_SECRETS[@]} -gt 0 ]; then
    log "Liste des secrets manquants:"
    for SECRET in "${MISSING_SECRETS[@]}"; do
        log "  - $SECRET"
    done

    log "Pour configurer les secrets manquants, suivez les instructions dans le document docs/GITHUB-SECRETS-CONFIGURATION.md"
    exit 1
else
    log "Tous les secrets requis sont configurés ✅"
    exit 0
fi
