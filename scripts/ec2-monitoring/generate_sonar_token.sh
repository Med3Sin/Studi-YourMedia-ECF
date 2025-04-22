#!/bin/bash
# Script simplifié pour générer un token SonarQube et le stocker dans Terraform Cloud
#
# Usage: sudo ./generate_sonar_token.sh <SONAR_HOST> <TF_API_TOKEN> <TF_WORKSPACE_ID> [SONAR_ADMIN_USER] [SONAR_ADMIN_PASSWORD]

# Vérification des arguments
if [ $# -lt 3 ]; then
    echo "Erreur: Arguments insuffisants."
    echo "Usage: sudo $0 <SONAR_HOST> <TF_API_TOKEN> <TF_WORKSPACE_ID> [SONAR_ADMIN_USER] [SONAR_ADMIN_PASSWORD]"
    exit 1
fi

# Vérifier si l'utilisateur a les droits sudo
if [ "$(id -u)" -ne 0 ]; then
    echo "Ce script doit être exécuté avec sudo"
    echo "Exemple: sudo $0 $*"
    exit 1
fi

# Variables
SONAR_HOST=$1
TF_API_TOKEN=$2
TF_WORKSPACE_ID=$3
SONAR_ADMIN_USER=${4:-admin}
SONAR_ADMIN_PASSWORD=${5:-admin}
TOKEN_NAME="terraform-cloud-$(date +%Y%m%d%H%M%S)"

# Attendre que SonarQube soit opérationnel
echo "Vérification de l'accès à SonarQube..."
for i in {1..5}; do
    if curl --output /dev/null --silent --head --fail "http://$SONAR_HOST:9000"; then
        echo "SonarQube est accessible."
        break
    fi

    if [ $i -eq 5 ]; then
        echo "Erreur: SonarQube n'est pas accessible après 5 tentatives."
        exit 1
    fi

    echo "SonarQube n'est pas encore accessible. Nouvelle tentative dans 10 secondes..."
    sleep 10
done

# Générer un token SonarQube de façon simplifiée
echo "Génération d'un token SonarQube..."
TOKEN_RESPONSE=$(curl -s -X POST -u "$SONAR_ADMIN_USER:$SONAR_ADMIN_PASSWORD" \
    "http://$SONAR_HOST:9000/api/user_tokens/generate" \
    -d "name=$TOKEN_NAME")

# Extraire le token de la réponse JSON
TOKEN=$(echo $TOKEN_RESPONSE | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo "Erreur: Impossible de générer un token SonarQube."
    echo "Réponse: $TOKEN_RESPONSE"
    exit 1
fi

echo "Token SonarQube généré avec succès."

# Stocker le token dans Terraform Cloud
echo "Stockage du token dans Terraform Cloud..."

# Ajouter le préfixe 'ws-' si nécessaire
FULL_WORKSPACE_ID="$TF_WORKSPACE_ID"
if [[ ! "$TF_WORKSPACE_ID" == ws-* ]]; then
    FULL_WORKSPACE_ID="ws-$TF_WORKSPACE_ID"
fi

# Créer le JSON pour la requête
JSON_DATA='{"data":{"type":"vars","attributes":{"key":"sonar_token","value":"'"$TOKEN"'","category":"terraform","sensitive":true,"description":"Token SonarQube généré le '"$(date +'%Y-%m-%d')"'"}}'

# Envoyer la requête à Terraform Cloud
STORE_RESPONSE=$(curl -s -X POST "https://app.terraform.io/api/v2/workspaces/$FULL_WORKSPACE_ID/vars" \
    -H "Authorization: Bearer $TF_API_TOKEN" \
    -H "Content-Type: application/vnd.api+json" \
    -d "$JSON_DATA")

# Afficher le token pour permettre à l'utilisateur de le sauvegarder
echo "\nToken SonarQube généré: $TOKEN"
echo "Veuillez sauvegarder ce token en lieu sûr."

# Vérifier si le stockage a réussi
if ! echo $STORE_RESPONSE | grep -q "errors"; then
    echo "Token SonarQube stocké avec succès dans Terraform Cloud."
else
    echo "Erreur: Impossible de stocker le token dans Terraform Cloud."
    echo "Veuillez ajouter manuellement la variable 'sonar_token' dans Terraform Cloud."
fi

# Instructions pour GitHub Actions
echo "\nPour utiliser ce token dans GitHub Actions:"
echo "1. Ajoutez le secret SONAR_TOKEN dans votre dépôt GitHub"
echo "2. Configurez votre workflow pour utiliser ce token avec SonarQube"

exit 0
