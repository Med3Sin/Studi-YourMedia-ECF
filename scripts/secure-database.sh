#!/bin/bash
# Script pour sécuriser la base de données MySQL
# Ce script exécute le script SQL secure-database.sql pour révoquer les privilèges de l'utilisateur root
# et créer un utilisateur dédié pour l'application

# Variables (à définir avant l'exécution ou à passer en paramètres)
DB_HOST=${1:-localhost}
DB_PORT=${2:-3306}
DB_ROOT_USER=${3:-root}
DB_ROOT_PASSWORD=${4:-password}
NEW_DB_USER=${5:-yourmedia_user}
NEW_DB_PASSWORD=${6:-$(openssl rand -base64 12)}

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Fonction pour afficher les erreurs et quitter
error_exit() {
    log "ERREUR: $1"
    exit 1
}

# Vérifier si mysql est installé
if ! command -v mysql &> /dev/null; then
    error_exit "mysql n'est pas installé. Veuillez l'installer avant d'exécuter ce script."
fi

# Générer un mot de passe fort si non fourni
if [ "$NEW_DB_PASSWORD" = "$(openssl rand -base64 12)" ]; then
    log "Génération d'un mot de passe fort pour l'utilisateur $NEW_DB_USER..."
    NEW_DB_PASSWORD=$(openssl rand -base64 12)
    log "Mot de passe généré: $NEW_DB_PASSWORD"
    log "IMPORTANT: Notez ce mot de passe dans un gestionnaire de mots de passe sécurisé."
fi

# Créer un fichier SQL temporaire avec le mot de passe généré
log "Création du fichier SQL temporaire..."
TMP_SQL_FILE=$(mktemp)
cat scripts/secure-database.sql | sed "s/__DB_PASSWORD_PLACEHOLDER__/$NEW_DB_PASSWORD/g" > $TMP_SQL_FILE

# Exécuter le script SQL
log "Exécution du script SQL pour sécuriser la base de données..."
mysql -h $DB_HOST -P $DB_PORT -u $DB_ROOT_USER -p$DB_ROOT_PASSWORD < $TMP_SQL_FILE
if [ $? -ne 0 ]; then
    rm $TMP_SQL_FILE
    error_exit "Impossible d'exécuter le script SQL. Vérifiez les informations de connexion."
fi

# Supprimer le fichier SQL temporaire
rm $TMP_SQL_FILE

# Vérifier que l'utilisateur a été créé
log "Vérification de la création de l'utilisateur..."
USER_EXISTS=$(mysql -h $DB_HOST -P $DB_PORT -u $DB_ROOT_USER -p$DB_ROOT_PASSWORD -e "SELECT user FROM mysql.user WHERE user='$NEW_DB_USER'" | grep -c $NEW_DB_USER)
if [ $USER_EXISTS -eq 0 ]; then
    error_exit "L'utilisateur $NEW_DB_USER n'a pas été créé. Vérifiez les logs MySQL."
fi

# Mettre à jour le secret dans GitHub Actions (si GH_PAT est défini)
if [ -n "$GH_PAT" ] && [ -n "$GITHUB_REPOSITORY" ]; then
    log "Mise à jour du secret DB_PASSWORD dans GitHub Actions..."

    # Récupérer la clé publique pour chiffrer le secret
    log "Récupération de la clé publique pour le dépôt..."
    PUBLIC_KEY_RESPONSE=$(curl -s -H "Authorization: token $GH_PAT" \
        -H "Accept: application/vnd.github.v3+json" \
        https://api.github.com/repos/$GITHUB_REPOSITORY/actions/secrets/public-key)

    # Extraire key_id et key
    KEY_ID=$(echo $PUBLIC_KEY_RESPONSE | grep -o '"key_id":"[^"]*"' | cut -d '"' -f 4)
    PUBLIC_KEY=$(echo $PUBLIC_KEY_RESPONSE | grep -o '"key":"[^"]*"' | cut -d '"' -f 4)

    if [ -z "$KEY_ID" ] || [ -z "$PUBLIC_KEY" ]; then
        log "AVERTISSEMENT: Impossible de récupérer la clé publique. Vous devrez mettre à jour le secret manuellement."
    else
        # Chiffrer le mot de passe avec la clé publique (nécessite sodium-plus)
        # Note: Cette étape nécessite des outils supplémentaires pour le chiffrement
        # Pour simplifier, nous recommandons de mettre à jour le secret manuellement
        log "AVERTISSEMENT: Le chiffrement des secrets nécessite des outils supplémentaires."
        log "Veuillez mettre à jour le secret DB_PASSWORD manuellement dans les paramètres GitHub Actions."
        log "Valeur du secret à définir: $NEW_DB_PASSWORD"
    fi
fi

# Mettre à jour le secret dans Terraform Cloud (si TF_API_TOKEN et TF_WORKSPACE_ID sont définis)
if [ -n "$TF_API_TOKEN" ] && [ -n "$TF_WORKSPACE_ID" ]; then
    log "Mise à jour du secret db_password dans Terraform Cloud..."
    curl -s -X POST "https://app.terraform.io/api/v2/workspaces/$TF_WORKSPACE_ID/vars" \
        -H "Authorization: Bearer $TF_API_TOKEN" \
        -H "Content-Type: application/vnd.api+json" \
        -d "{
            \"data\": {
                \"type\": \"vars\",
                \"attributes\": {
                    \"key\": \"db_password\",
                    \"value\": \"$NEW_DB_PASSWORD\",
                    \"category\": \"terraform\",
                    \"sensitive\": true,
                    \"description\": \"Mot de passe de la base de données MySQL (généré automatiquement)\"
                }
            }
        }"
    if [ $? -ne 0 ]; then
        log "AVERTISSEMENT: Impossible de mettre à jour le secret dans Terraform Cloud. Vous devrez le faire manuellement."
    fi
fi

log "Base de données sécurisée avec succès."
log "Nouvel utilisateur: $NEW_DB_USER"
log "Nouveau mot de passe: $NEW_DB_PASSWORD"
log "IMPORTANT: Notez ce mot de passe dans un gestionnaire de mots de passe sécurisé."
log "IMPORTANT: Mettez à jour les variables d'environnement de votre application avec ces nouvelles informations."

exit 0
