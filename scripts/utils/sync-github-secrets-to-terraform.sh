#!/bin/bash
# Script pour synchroniser les secrets GitHub vers Terraform Cloud
# Auteur: Med3Sin
# Date: $(date +%Y-%m-%d)

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Fonction pour afficher les erreurs et quitter
error_exit() {
    log "ERREUR: $1"
    exit 1
}

# Vérification des variables d'environnement requises
if [ -z "$GITHUB_TOKEN" ]; then
    error_exit "La variable GITHUB_TOKEN n'est pas définie"
fi

if [ -z "$TF_API_TOKEN" ]; then
    error_exit "La variable TF_API_TOKEN n'est pas définie"
fi

if [ -z "$GITHUB_REPOSITORY" ]; then
    error_exit "La variable GITHUB_REPOSITORY n'est pas définie"
fi

if [ -z "$TF_WORKSPACE_ID" ]; then
    error_exit "La variable TF_WORKSPACE_ID n'est pas définie"
fi

# Vérification des dépendances
check_dependency() {
    local cmd=$1
    local pkg=$2

    if ! command -v $cmd &> /dev/null; then
        log "Dépendance manquante: $cmd. Installation de $pkg..."
        sudo dnf install -y $pkg || sudo apt-get install -y $pkg || error_exit "Impossible d'installer $pkg"
    fi
}

check_dependency curl curl
check_dependency jq jq

# Récupérer la liste des secrets GitHub
log "Récupération de la liste des secrets GitHub..."
SECRETS_RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$GITHUB_REPOSITORY/actions/secrets")

# Vérifier si la réponse contient une erreur
if echo "$SECRETS_RESPONSE" | jq -e '.message' > /dev/null; then
    error_exit "Erreur lors de la récupération des secrets GitHub: $(echo "$SECRETS_RESPONSE" | jq -r '.message')"
fi

# Extraire les noms des secrets
SECRET_NAMES=$(echo "$SECRETS_RESPONSE" | jq -r '.secrets[].name')

# Pour chaque secret, récupérer sa valeur et la synchroniser vers Terraform Cloud
for SECRET_NAME in $SECRET_NAMES; do
    log "Traitement du secret: $SECRET_NAME"
    
    # Vérifier si le secret est déjà défini dans Terraform Cloud
    TF_VAR_RESPONSE=$(curl -s -H "Authorization: Bearer $TF_API_TOKEN" \
        -H "Content-Type: application/vnd.api+json" \
        "https://app.terraform.io/api/v2/workspaces/$TF_WORKSPACE_ID/vars?filter%5Bname%5D=$SECRET_NAME")
    
    # Vérifier si la variable existe déjà
    VAR_ID=$(echo "$TF_VAR_RESPONSE" | jq -r '.data[] | select(.attributes.key == "'$SECRET_NAME'") | .id')
    
    # La valeur du secret GitHub n'est pas accessible directement via l'API
    # Nous devons utiliser la valeur qui est déjà disponible dans l'environnement
    SECRET_VALUE="${!SECRET_NAME}"
    
    if [ -z "$SECRET_VALUE" ]; then
        log "La valeur du secret $SECRET_NAME n'est pas disponible dans l'environnement"
        continue
    fi
    
    # Déterminer si le secret doit être sensible dans Terraform Cloud
    IS_SENSITIVE=true
    if [[ "$SECRET_NAME" == *"_URL"* ]] || [[ "$SECRET_NAME" == *"_ENDPOINT"* ]] || [[ "$SECRET_NAME" == *"_IP"* ]]; then
        IS_SENSITIVE=false
    fi
    
    # Créer ou mettre à jour la variable dans Terraform Cloud
    if [ -n "$VAR_ID" ]; then
        # Mettre à jour la variable existante
        log "Mise à jour de la variable $SECRET_NAME dans Terraform Cloud..."
        curl -s -X PATCH "https://app.terraform.io/api/v2/workspaces/$TF_WORKSPACE_ID/vars/$VAR_ID" \
            -H "Authorization: Bearer $TF_API_TOKEN" \
            -H "Content-Type: application/vnd.api+json" \
            -d '{
                "data": {
                    "id": "'$VAR_ID'",
                    "type": "vars",
                    "attributes": {
                        "key": "'$SECRET_NAME'",
                        "value": "'$SECRET_VALUE'",
                        "description": "Synchronisé depuis GitHub Secrets",
                        "sensitive": '$IS_SENSITIVE'
                    }
                }
            }'
    else
        # Créer une nouvelle variable
        log "Création de la variable $SECRET_NAME dans Terraform Cloud..."
        curl -s -X POST "https://app.terraform.io/api/v2/workspaces/$TF_WORKSPACE_ID/vars" \
            -H "Authorization: Bearer $TF_API_TOKEN" \
            -H "Content-Type: application/vnd.api+json" \
            -d '{
                "data": {
                    "type": "vars",
                    "attributes": {
                        "key": "'$SECRET_NAME'",
                        "value": "'$SECRET_VALUE'",
                        "description": "Synchronisé depuis GitHub Secrets",
                        "category": "terraform",
                        "sensitive": '$IS_SENSITIVE'
                    }
                }
            }'
    fi
    
    if [ $? -ne 0 ]; then
        log "AVERTISSEMENT: Impossible de synchroniser le secret $SECRET_NAME vers Terraform Cloud"
    else
        log "Secret $SECRET_NAME synchronisé avec succès vers Terraform Cloud"
    fi
done

log "Synchronisation des secrets terminée"
exit 0
