#!/bin/bash
#==============================================================================
# Nom du script : secure-database.sh
# Description   : Script pour sécuriser la base de données MySQL.
#                 Ce script exécute le script SQL secure-database.sql pour révoquer
#                 les privilèges de l'utilisateur root et créer un utilisateur dédié
#                 pour l'application.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2025-04-27
#==============================================================================
# Utilisation   : ./secure-database.sh [options]
#
# Options       :
#   --host=HOST           : Hôte de la base de données (par défaut: localhost)
#   --port=PORT           : Port de la base de données (par défaut: 3306)
#   --root-user=USER      : Utilisateur root de la base de données (par défaut: root)
#   --root-password=PASS  : Mot de passe root de la base de données (par défaut: password)
#   --new-user=USER       : Nouvel utilisateur à créer (par défaut: yourmedia_user)
#   --new-password=PASS   : Mot de passe du nouvel utilisateur (par défaut: généré aléatoirement)
#   --output-file=FILE    : Fichier où enregistrer les informations d'identification (optionnel)
#
# Exemples      :
#   ./secure-database.sh
#   ./secure-database.sh --host=localhost --port=3306 --root-user=root --root-password=password --new-user=yourmedia_user
#   ./secure-database.sh --output-file=/tmp/db-credentials.txt
#
# Compatibilité : L'ancienne syntaxe positionnelle est toujours supportée :
#   ./secure-database.sh localhost 3306 root password yourmedia_user my_secure_password
#==============================================================================
# Dépendances   :
#   - mysql     : Client MySQL pour exécuter les commandes SQL
#   - openssl   : Pour générer un mot de passe aléatoire
#   - curl      : Pour mettre à jour les secrets dans GitHub Actions et Terraform Cloud
#==============================================================================
# Variables d'environnement :
#   - GH_PAT    : Token d'accès personnel GitHub (optionnel)
#   - GITHUB_REPOSITORY : Nom du dépôt GitHub (optionnel)
#   - TF_API_TOKEN : Token d'API Terraform Cloud (optionnel)
#   - TF_WORKSPACE_ID : ID de l'espace de travail Terraform Cloud (optionnel)
#==============================================================================

# Traitement des options
OUTPUT_FILE=""
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --output-file=*)
            OUTPUT_FILE="${1#*=}"
            shift
            ;;
        --host=*)
            DB_HOST="${1#*=}"
            shift
            ;;
        --port=*)
            DB_PORT="${1#*=}"
            shift
            ;;
        --root-user=*)
            DB_ROOT_USER="${1#*=}"
            shift
            ;;
        --root-password=*)
            DB_ROOT_PASSWORD="${1#*=}"
            shift
            ;;
        --new-user=*)
            NEW_DB_USER="${1#*=}"
            shift
            ;;
        --new-password=*)
            NEW_DB_PASSWORD="${1#*=}"
            shift
            ;;
        *)
            # Compatibilité avec l'ancienne syntaxe positionnelle
            if [ -z "$DB_HOST" ]; then
                DB_HOST="$1"
            elif [ -z "$DB_PORT" ]; then
                DB_PORT="$1"
            elif [ -z "$DB_ROOT_USER" ]; then
                DB_ROOT_USER="$1"
            elif [ -z "$DB_ROOT_PASSWORD" ]; then
                DB_ROOT_PASSWORD="$1"
            elif [ -z "$NEW_DB_USER" ]; then
                NEW_DB_USER="$1"
            elif [ -z "$NEW_DB_PASSWORD" ]; then
                NEW_DB_PASSWORD="$1"
            fi
            shift
            ;;
    esac
done

# Valeurs par défaut si non spécifiées
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-3306}
DB_ROOT_USER=${DB_ROOT_USER:-root}
DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD:-password}
NEW_DB_USER=${NEW_DB_USER:-yourmedia_user}
NEW_DB_PASSWORD=${NEW_DB_PASSWORD:-$(openssl rand -base64 12)}

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
    log "Mot de passe généré avec succès (non affiché pour des raisons de sécurité)"
    log "IMPORTANT: Notez ce mot de passe dans un gestionnaire de mots de passe sécurisé."
fi

# Créer un fichier SQL temporaire avec le mot de passe généré
log "Création du fichier SQL temporaire..."
TMP_SQL_FILE=$(mktemp)
cat scripts/database/secure-database.sql | sed "s/__DB_PASSWORD_PLACEHOLDER__/$NEW_DB_PASSWORD/g" > $TMP_SQL_FILE

# Exécuter le script SQL
log "Exécution du script SQL pour sécuriser la base de données..."
sudo mysql -h $DB_HOST -P $DB_PORT -u $DB_ROOT_USER -p$DB_ROOT_PASSWORD < $TMP_SQL_FILE
if [ $? -ne 0 ]; then
    sudo rm $TMP_SQL_FILE
    error_exit "Impossible d'exécuter le script SQL. Vérifiez les informations de connexion."
fi

# Supprimer le fichier SQL temporaire
sudo rm $TMP_SQL_FILE

# Vérifier que l'utilisateur a été créé
log "Vérification de la création de l'utilisateur..."
USER_EXISTS=$(sudo mysql -h $DB_HOST -P $DB_PORT -u $DB_ROOT_USER -p$DB_ROOT_PASSWORD -e "SELECT user FROM mysql.user WHERE user='$NEW_DB_USER'" | grep -c $NEW_DB_USER)
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
log "IMPORTANT: Le nouveau mot de passe a été généré et appliqué."
log "IMPORTANT: Notez ce mot de passe dans un gestionnaire de mots de passe sécurisé."
log "IMPORTANT: Mettez à jour les variables d'environnement de votre application avec ces nouvelles informations."

# Écrire le mot de passe dans un fichier temporaire sécurisé si l'option --output-file est spécifiée
if [ ! -z "$OUTPUT_FILE" ]; then
    sudo echo "Utilisateur: $NEW_DB_USER" > "$OUTPUT_FILE"
    sudo echo "Mot de passe: $NEW_DB_PASSWORD" >> "$OUTPUT_FILE"
    sudo chmod 600 "$OUTPUT_FILE"
    log "Les informations d'identification ont été enregistrées dans $OUTPUT_FILE"
    log "IMPORTANT: Supprimez ce fichier après avoir enregistré les informations dans un endroit sécurisé."
fi

exit 0
