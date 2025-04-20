#!/bin/bash
# Script pour récupérer les secrets depuis Terraform Cloud

# Variables
TF_API_TOKEN=$1
TF_WORKSPACE_ID=$2
SECRET_NAME=$3
SHOW_VALUE=${4:-false}

# Vérifier les paramètres
if [ -z "$TF_API_TOKEN" ] || [ -z "$TF_WORKSPACE_ID" ] || [ -z "$SECRET_NAME" ]; then
    echo "Usage: $0 <TF_API_TOKEN> <TF_WORKSPACE_ID> <SECRET_NAME> [SHOW_VALUE]"
    echo "  TF_API_TOKEN: Token d'API Terraform Cloud"
    echo "  TF_WORKSPACE_ID: ID de l'espace de travail Terraform Cloud (format: ws-xxxxxxxx)"
    echo "  SECRET_NAME: Nom du secret à récupérer"
    echo "  SHOW_VALUE: Afficher la valeur du secret (true/false, défaut: false)"
    exit 1
fi

# Récupérer la liste des variables
echo "Récupération des variables depuis Terraform Cloud..."
VARS_RESPONSE=$(curl -s -H "Authorization: Bearer $TF_API_TOKEN" \
    "https://app.terraform.io/api/v2/workspaces/$TF_WORKSPACE_ID/vars")

# Vérifier si la requête a réussi
if echo $VARS_RESPONSE | grep -q "errors"; then
    echo "Erreur: Impossible de récupérer les variables depuis Terraform Cloud."
    echo "Réponse: $VARS_RESPONSE"
    exit 1
fi

# Extraire l'ID de la variable recherchée
VAR_ID=$(echo $VARS_RESPONSE | jq -r ".data[] | select(.attributes.key == \"$SECRET_NAME\") | .id")

if [ -z "$VAR_ID" ] || [ "$VAR_ID" = "null" ]; then
    echo "Erreur: Variable '$SECRET_NAME' non trouvée dans Terraform Cloud."
    echo "Variables disponibles:"
    echo $VARS_RESPONSE | jq -r '.data[] | .attributes.key'
    exit 1
fi

# Récupérer les détails de la variable
VAR_DETAILS=$(curl -s -H "Authorization: Bearer $TF_API_TOKEN" \
    "https://app.terraform.io/api/v2/workspaces/$TF_WORKSPACE_ID/vars/$VAR_ID")

# Vérifier si la requête a réussi
if echo $VAR_DETAILS | grep -q "errors"; then
    echo "Erreur: Impossible de récupérer les détails de la variable depuis Terraform Cloud."
    echo "Réponse: $VAR_DETAILS"
    exit 1
fi

# Extraire les informations de la variable
VAR_KEY=$(echo $VAR_DETAILS | jq -r '.data.attributes.key')
VAR_VALUE=$(echo $VAR_DETAILS | jq -r '.data.attributes.value')
VAR_SENSITIVE=$(echo $VAR_DETAILS | jq -r '.data.attributes.sensitive')
VAR_CATEGORY=$(echo $VAR_DETAILS | jq -r '.data.attributes.category')
VAR_DESCRIPTION=$(echo $VAR_DETAILS | jq -r '.data.attributes.description')

# Afficher les informations de la variable
echo "Variable: $VAR_KEY"
echo "Catégorie: $VAR_CATEGORY"
echo "Sensible: $VAR_SENSITIVE"
echo "Description: $VAR_DESCRIPTION"

if [ "$VAR_SENSITIVE" = "true" ] && [ "$SHOW_VALUE" != "true" ]; then
    echo "Valeur: ********** (sensible)"
    echo "Pour afficher la valeur, exécutez la commande avec SHOW_VALUE=true"
else
    echo "Valeur: $VAR_VALUE"
fi

exit 0
