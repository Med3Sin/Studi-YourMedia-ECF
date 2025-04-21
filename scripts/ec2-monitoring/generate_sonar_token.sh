#!/bin/bash
# Script pour générer un token SonarQube et le stocker dans Terraform Cloud
#
# Usage: ./generate_sonar_token.sh <SONAR_HOST> <TF_API_TOKEN> <TF_WORKSPACE_ID> [SONAR_ADMIN_USER] [SONAR_ADMIN_PASSWORD]
#
# Exemple: ./generate_sonar_token.sh 10.0.0.1 tfp_1234567890abcdef ws-1234567890abcdef admin admin
#
# Ce script:
# 1. Attend que SonarQube soit opérationnel
# 2. Génère un token SonarQube avec un nom unique
# 3. Stocke le token dans Terraform Cloud comme variable sensible
# 4. Affiche des instructions pour ajouter le token comme secret GitHub

# Vérification des arguments
if [ $# -lt 3 ]; then
    echo "Erreur: Arguments insuffisants."
    echo "Usage: $0 <SONAR_HOST> <TF_API_TOKEN> <TF_WORKSPACE_ID> [SONAR_ADMIN_USER] [SONAR_ADMIN_PASSWORD]"
    exit 1
fi

# Variables
SONAR_HOST=$1
TF_API_TOKEN=$2
TF_WORKSPACE_ID=$3
SONAR_ADMIN_USER=${4:-admin}
SONAR_ADMIN_PASSWORD=${5:-admin}
MAX_RETRIES=30
RETRY_INTERVAL=10
TOKEN_NAME="terraform-cloud-$(date +%Y%m%d%H%M%S)"

# Fonction pour vérifier si SonarQube est opérationnel
check_sonarqube() {
    curl --output /dev/null --silent --head --fail "http://$SONAR_HOST:9000"
    return $?
}

# Attendre que SonarQube soit opérationnel
echo "Attente du démarrage de SonarQube..."
RETRY_COUNT=0
while ! check_sonarqube; do
    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "Erreur: SonarQube n'est pas disponible après $MAX_RETRIES tentatives."
        exit 1
    fi
    echo "SonarQube n'est pas encore disponible. Nouvelle tentative dans $RETRY_INTERVAL secondes..."
    sleep $RETRY_INTERVAL
done

echo "SonarQube est opérationnel."

# Générer un token SonarQube
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

# Vérifier si le workspace ID est au format correct
if [[ "$TF_WORKSPACE_ID" == ws-* ]]; then
    # Si le workspace ID commence déjà par 'ws-', l'utiliser tel quel
    FULL_WORKSPACE_ID="$TF_WORKSPACE_ID"
else
    # Sinon, ajouter le préfixe 'ws-'
    FULL_WORKSPACE_ID="ws-$TF_WORKSPACE_ID"
fi

STORE_RESPONSE=$(curl -s -X POST "https://app.terraform.io/api/v2/workspaces/$FULL_WORKSPACE_ID/vars" \
    -H "Authorization: Bearer $TF_API_TOKEN" \
    -H "Content-Type: application/vnd.api+json" \
    -d '{
        "data": {
            "type": "vars",
            "attributes": {
                "key": "sonar_token",
                "value": "'"$TOKEN"'",
                "category": "terraform",
                "sensitive": true,
                "description": "Token SonarQube généré automatiquement le '"$(date +'%Y-%m-%d %H:%M:%S')"'"
            }
        }
    }')

# Vérifier si le stockage a réussi
if echo $STORE_RESPONSE | grep -q "errors"; then
    echo "Erreur: Impossible de stocker le token dans Terraform Cloud."
    echo "Réponse: $STORE_RESPONSE"

    # Afficher des informations de débogage
    echo "\nInformations de débogage:"
    echo "Workspace ID utilisé: $FULL_WORKSPACE_ID"
    echo "URL de l'API: https://app.terraform.io/api/v2/workspaces/$FULL_WORKSPACE_ID/vars"

    # Afficher le token quand même pour permettre à l'utilisateur de le sauvegarder manuellement
    echo "\nLe token SonarQube a été généré mais n'a pas pu être stocké dans Terraform Cloud."
    echo "Veuillez ajouter manuellement la variable 'sonar_token' dans Terraform Cloud avec la valeur suivante:"
    echo "$TOKEN"

    exit 1
fi

echo "Token SonarQube stocké avec succès dans Terraform Cloud."

# Créer également un secret GitHub
echo "Le token SonarQube a été généré et stocké dans Terraform Cloud."
echo "Pour l'utiliser dans GitHub Actions, ajoutez manuellement le secret SONAR_TOKEN avec la valeur suivante:"
echo "$TOKEN"

exit 0
