#!/bin/bash
#==============================================================================
# Nom du script : sync-github-secrets-to-terraform.sh
# Description   : Synchronise les secrets GitHub vers Terraform Cloud
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.2
# Date          : 2024-05-03
#==============================================================================
# Utilisation   : ./sync-github-secrets-to-terraform.sh
#
# Ce script synchronise les secrets GitHub vers Terraform Cloud.
# Il utilise les variables d'environnement suivantes :
#   - GITHUB_TOKEN : Token GitHub pour l'authentification
#   - TF_API_TOKEN : Token Terraform Cloud pour l'authentification
#   - GITHUB_REPOSITORY : Nom du dépôt GitHub (format: owner/repo)
#   - TF_WORKSPACE_ID : ID du workspace Terraform Cloud
#
# Les secrets suivants sont synchronisés :
#   - AWS_ACCESS_KEY_ID
#   - AWS_SECRET_ACCESS_KEY
#   - RDS_USERNAME
#   - RDS_PASSWORD
#   - EC2_SSH_PRIVATE_KEY (encodé en base64 pour éviter les problèmes d'échappement)
#   - EC2_SSH_PUBLIC_KEY
#   - DOCKERHUB_USERNAME (standard)
#   - DOCKERHUB_TOKEN (standard)
#   - DOCKERHUB_REPO (standard)
#   - TF_EC2_PUBLIC_IP
#   - TF_S3_BUCKET_NAME
#   - TF_MONITORING_EC2_PUBLIC_IP
#   - TF_RDS_ENDPOINT
#
# Améliorations dans cette version :
# - Utilisation de curl au lieu de wget pour une meilleure gestion des API
# - Encodage en base64 des clés SSH pour éviter les problèmes d'échappement
# - Logs de débogage améliorés
# - Option pour diviser les grandes clés SSH si nécessaire
#
# Note: Pour une solution plus robuste en production, envisagez d'utiliser
# AWS Secrets Manager ou HashiCorp Vault pour stocker les clés SSH, puis
# référencez ces secrets dans Terraform.
#==============================================================================

set -e

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Fonction pour afficher les messages de débogage
debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - DEBUG: $1"
    fi
}

# Fonction pour afficher les erreurs et quitter
error_exit() {
    log "ERREUR: $1"
    exit 1
}

# Fonction pour vérifier la taille d'une variable
check_variable_size() {
    local key="$1"
    local value="$2"
    local size=${#value}

    debug "Taille de la variable $key: $size caractères"

    # Terraform Cloud a une limite de taille pour les variables
    # Si la taille dépasse 20000 caractères, afficher un avertissement
    if [ $size -gt 20000 ]; then
        log "AVERTISSEMENT: La variable $key est très grande ($size caractères). Envisagez de la diviser ou d'utiliser un gestionnaire de secrets externe."
        return 1
    fi

    return 0
}

# Vérifier les variables d'environnement requises
if [ -z "$GITHUB_TOKEN" ]; then
    error_exit "La variable d'environnement GITHUB_TOKEN n'est pas définie"
fi

if [ -z "$TF_API_TOKEN" ]; then
    error_exit "La variable d'environnement TF_API_TOKEN n'est pas définie"
fi

if [ -z "$GITHUB_REPOSITORY" ]; then
    error_exit "La variable d'environnement GITHUB_REPOSITORY n'est pas définie"
fi

if [ -z "$TF_WORKSPACE_ID" ]; then
    error_exit "La variable d'environnement TF_WORKSPACE_ID n'est pas définie"
fi

log "Synchronisation des secrets GitHub vers Terraform Cloud"
log "Dépôt GitHub: $GITHUB_REPOSITORY"
log "Workspace Terraform Cloud: $TF_WORKSPACE_ID"

# Fonction pour échapper les caractères spéciaux dans les valeurs JSON
escape_json_value() {
    local value="$1"
    # Échapper les caractères spéciaux pour JSON
    value="${value//\\/\\\\}"  # Échapper les backslashes
    value="${value//\"/\\\"}"  # Échapper les guillemets
    value="${value//\//\\/}"   # Échapper les slashes
    value="${value//	/\\t}"    # Échapper les tabulations
    value="${value//
/\\n}"    # Échapper les sauts de ligne
    value="${value//
/\\r}"    # Échapper les retours chariot
    echo "$value"
}

# Fonction pour encoder une valeur en base64
encode_base64() {
    local value="$1"
    echo "$value" | base64 -w 0
}

# Fonction pour diviser une grande valeur en plusieurs parties
split_large_value() {
    local value="$1"
    local max_size="$2"
    local parts=()

    # Calculer le nombre de parties nécessaires
    local total_size=${#value}
    local num_parts=$(( (total_size + max_size - 1) / max_size ))

    debug "Divisant la valeur de taille $total_size en $num_parts parties de taille maximale $max_size"

    # Diviser la valeur en parties
    for (( i=0; i<num_parts; i++ )); do
        local start=$((i * max_size))
        local part="${value:$start:$max_size}"
        parts+=("$part")
    done

    echo "${parts[@]}"
}

# Fonction pour créer ou mettre à jour une variable Terraform Cloud
create_or_update_tf_variable() {
    local key="$1"
    local value="$2"
    local category="$3"  # terraform ou env
    local sensitive="$4" # true ou false
    local description="$5"

    # Vérifier la taille de la variable
    check_variable_size "$key" "$value"
    local size_check_result=$?

    # Pour les clés SSH, utiliser l'encodage base64
    if [[ "$key" == *"SSH"* && "$key" == *"KEY"* ]]; then
        log "Traitement spécial pour la clé SSH: $key"

        # Si la clé est trop grande, la diviser
        if [ $size_check_result -eq 1 ]; then
            log "La clé SSH est trop grande, elle sera divisée et encodée en base64"

            # Diviser la clé en parties de 15000 caractères maximum
            local parts=($(split_large_value "$value" 15000))
            local num_parts=${#parts[@]}

            log "La clé SSH a été divisée en $num_parts parties"

            # Créer une variable pour chaque partie
            for (( i=0; i<num_parts; i++ )); do
                local part_key="${key}_PART_$((i+1))_OF_$num_parts"
                local part_value=$(encode_base64 "${parts[$i]}")
                local part_description="$description (Partie $((i+1)) de $num_parts, encodée en base64)"

                # Créer ou mettre à jour la variable pour cette partie
                create_or_update_tf_variable_with_curl "$part_key" "$part_value" "$category" "$sensitive" "$part_description"
            done

            # Créer une variable indiquant le nombre de parties
            create_or_update_tf_variable_with_curl "${key}_PARTS_COUNT" "$num_parts" "$category" "false" "Nombre de parties pour $key"

            return
        else
            # Encoder la clé en base64
            log "Encodage de la clé SSH en base64: $key"
            value=$(encode_base64 "$value")
            description="$description (encodée en base64)"
        fi
    fi

    # Créer ou mettre à jour la variable
    create_or_update_tf_variable_with_curl "$key" "$value" "$category" "$sensitive" "$description"
}

# Fonction pour créer ou mettre à jour une variable Terraform Cloud avec curl
create_or_update_tf_variable_with_curl() {
    local key="$1"
    local value="$2"
    local category="$3"  # terraform ou env
    local sensitive="$4" # true ou false
    local description="$5"

    # Échapper les caractères spéciaux dans la valeur
    local escaped_value=$(escape_json_value "$value")

    # Vérifier si la variable existe déjà
    debug "Vérification de l'existence de la variable $key dans Terraform Cloud"
    local response=$(curl -s -H "Authorization: Bearer $TF_API_TOKEN" \
        -H "Content-Type: application/vnd.api+json" \
        "https://app.terraform.io/api/v2/workspaces/$TF_WORKSPACE_ID/vars")

    local variable_id=$(echo "$response" | jq -r --arg key "$key" --arg category "$category" '.data[] | select(.attributes.key == $key and .attributes.category == $category) | .id')
    debug "ID de la variable $key: $variable_id"

    # Créer un fichier temporaire pour les données JSON
    local tmp_json_file=$(mktemp)

    if [ -z "$variable_id" ] || [ "$variable_id" == "null" ]; then
        # Créer une nouvelle variable
        log "Création de la variable $key dans Terraform Cloud"

        cat > "$tmp_json_file" << EOF
{
  "data": {
    "type": "vars",
    "attributes": {
      "key": "$key",
      "value": "$escaped_value",
      "description": "$description",
      "category": "$category",
      "hcl": false,
      "sensitive": $sensitive,
      "read": true
    }
  }
}
EOF

        # Utiliser curl pour envoyer la requête POST
        local response=$(curl -s -X POST \
            -H "Authorization: Bearer $TF_API_TOKEN" \
            -H "Content-Type: application/vnd.api+json" \
            -d @"$tmp_json_file" \
            "https://app.terraform.io/api/v2/workspaces/$TF_WORKSPACE_ID/vars")

        debug "Réponse de l'API Terraform Cloud (création): $response"

        # Vérifier si la requête a réussi
        if echo "$response" | jq -e '.errors' > /dev/null; then
            log "ERREUR lors de la création de la variable $key:"
            echo "$response" | jq '.errors'
        fi
    else
        # Mettre à jour la variable existante
        log "Mise à jour de la variable $key dans Terraform Cloud"

        cat > "$tmp_json_file" << EOF
{
  "data": {
    "id": "$variable_id",
    "type": "vars",
    "attributes": {
      "key": "$key",
      "value": "$escaped_value",
      "description": "$description",
      "category": "$category",
      "hcl": false,
      "sensitive": $sensitive,
      "read": true
    }
  }
}
EOF

        # Utiliser curl pour envoyer la requête PATCH
        local response=$(curl -s -X PATCH \
            -H "Authorization: Bearer $TF_API_TOKEN" \
            -H "Content-Type: application/vnd.api+json" \
            -d @"$tmp_json_file" \
            "https://app.terraform.io/api/v2/workspaces/$TF_WORKSPACE_ID/vars/$variable_id")

        debug "Réponse de l'API Terraform Cloud (mise à jour): $response"

        # Vérifier si la requête a réussi
        if echo "$response" | jq -e '.errors' > /dev/null; then
            log "ERREUR lors de la mise à jour de la variable $key:"
            echo "$response" | jq '.errors'
        fi
    fi

    # Supprimer le fichier temporaire
    rm -f "$tmp_json_file"
}

# Synchroniser les secrets AWS
if [ ! -z "$AWS_ACCESS_KEY_ID" ]; then
    create_or_update_tf_variable "AWS_ACCESS_KEY_ID" "$AWS_ACCESS_KEY_ID" "env" "true" "AWS Access Key ID"
    create_or_update_tf_variable "aws_access_key" "$AWS_ACCESS_KEY_ID" "terraform" "true" "AWS Access Key ID"
fi

if [ ! -z "$AWS_SECRET_ACCESS_KEY" ]; then
    create_or_update_tf_variable "AWS_SECRET_ACCESS_KEY" "$AWS_SECRET_ACCESS_KEY" "env" "true" "AWS Secret Access Key"
    create_or_update_tf_variable "aws_secret_key" "$AWS_SECRET_ACCESS_KEY" "terraform" "true" "AWS Secret Access Key"
fi

if [ ! -z "$AWS_DEFAULT_REGION" ]; then
    create_or_update_tf_variable "AWS_DEFAULT_REGION" "$AWS_DEFAULT_REGION" "env" "false" "AWS Default Region"
    create_or_update_tf_variable "aws_region" "$AWS_DEFAULT_REGION" "terraform" "false" "AWS Region"
fi

# Synchroniser les secrets RDS/DB
if [ ! -z "$RDS_USERNAME" ]; then
    create_or_update_tf_variable "RDS_USERNAME" "$RDS_USERNAME" "env" "true" "RDS Username"
    create_or_update_tf_variable "db_username" "$RDS_USERNAME" "terraform" "true" "RDS Username"
fi

if [ ! -z "$RDS_PASSWORD" ]; then
    create_or_update_tf_variable "RDS_PASSWORD" "$RDS_PASSWORD" "env" "true" "RDS Password"
    create_or_update_tf_variable "db_password" "$RDS_PASSWORD" "terraform" "true" "RDS Password"
fi

if [ ! -z "$DB_NAME" ]; then
    create_or_update_tf_variable "DB_NAME" "$DB_NAME" "env" "true" "Database Name"
    create_or_update_tf_variable "db_name" "$DB_NAME" "terraform" "true" "Database Name"
fi

if [ ! -z "$DB_USERNAME" ]; then
    create_or_update_tf_variable "DB_USERNAME" "$DB_USERNAME" "env" "true" "Database Username"
fi

if [ ! -z "$DB_PASSWORD" ]; then
    create_or_update_tf_variable "DB_PASSWORD" "$DB_PASSWORD" "env" "true" "Database Password"
fi

# Synchroniser les secrets SSH et EC2
if [ ! -z "$EC2_SSH_PRIVATE_KEY" ]; then
    create_or_update_tf_variable "EC2_SSH_PRIVATE_KEY" "$EC2_SSH_PRIVATE_KEY" "env" "true" "EC2 SSH Private Key"
    create_or_update_tf_variable "ssh_private_key_content" "$EC2_SSH_PRIVATE_KEY" "terraform" "true" "EC2 SSH Private Key"
fi

if [ ! -z "$EC2_SSH_PUBLIC_KEY" ]; then
    create_or_update_tf_variable "EC2_SSH_PUBLIC_KEY" "$EC2_SSH_PUBLIC_KEY" "env" "true" "EC2 SSH Public Key"
    create_or_update_tf_variable "ssh_public_key" "$EC2_SSH_PUBLIC_KEY" "terraform" "true" "EC2 SSH Public Key"
fi

if [ ! -z "$EC2_KEY_PAIR_NAME" ]; then
    create_or_update_tf_variable "EC2_KEY_PAIR_NAME" "$EC2_KEY_PAIR_NAME" "env" "false" "EC2 Key Pair Name"
    create_or_update_tf_variable "ec2_key_pair_name" "$EC2_KEY_PAIR_NAME" "terraform" "false" "EC2 Key Pair Name"
fi

# Synchroniser les secrets Docker
if [ ! -z "$DOCKERHUB_USERNAME" ]; then
    create_or_update_tf_variable "DOCKERHUB_USERNAME" "$DOCKERHUB_USERNAME" "env" "true" "Docker Hub Username"
    create_or_update_tf_variable "dockerhub_username" "$DOCKERHUB_USERNAME" "terraform" "true" "Docker Hub Username"

    # Pour la compatibilité avec les anciens scripts
    create_or_update_tf_variable "DOCKER_USERNAME" "$DOCKERHUB_USERNAME" "env" "true" "Docker Username"
fi

if [ ! -z "$DOCKERHUB_TOKEN" ]; then
    create_or_update_tf_variable "DOCKERHUB_TOKEN" "$DOCKERHUB_TOKEN" "env" "true" "Docker Hub Token"
    create_or_update_tf_variable "dockerhub_token" "$DOCKERHUB_TOKEN" "terraform" "true" "Docker Hub Token"

    # Pour la compatibilité avec les anciens scripts
    create_or_update_tf_variable "DOCKER_PASSWORD" "$DOCKERHUB_TOKEN" "env" "true" "Docker Password"
fi

if [ ! -z "$DOCKERHUB_REPO" ]; then
    create_or_update_tf_variable "DOCKERHUB_REPO" "$DOCKERHUB_REPO" "env" "false" "Docker Hub Repository"
    create_or_update_tf_variable "dockerhub_repo" "$DOCKERHUB_REPO" "terraform" "false" "Docker Hub Repository"

    # Pour la compatibilité avec les anciens scripts
    create_or_update_tf_variable "DOCKER_REPO" "$DOCKERHUB_REPO" "env" "false" "Docker Repository"
fi

# Compatibilité avec les anciens noms de variables
if [ ! -z "$DOCKER_USERNAME" ] && [ -z "$DOCKERHUB_USERNAME" ]; then
    create_or_update_tf_variable "DOCKERHUB_USERNAME" "$DOCKER_USERNAME" "env" "true" "Docker Hub Username"
    create_or_update_tf_variable "dockerhub_username" "$DOCKER_USERNAME" "terraform" "true" "Docker Hub Username"
fi

if [ ! -z "$DOCKER_REPO" ] && [ -z "$DOCKERHUB_REPO" ]; then
    create_or_update_tf_variable "DOCKERHUB_REPO" "$DOCKER_REPO" "env" "false" "Docker Hub Repository"
    create_or_update_tf_variable "dockerhub_repo" "$DOCKER_REPO" "terraform" "false" "Docker Hub Repository"
fi

# Synchroniser les secrets Grafana
if [ ! -z "$GF_SECURITY_ADMIN_PASSWORD" ]; then
    create_or_update_tf_variable "GF_SECURITY_ADMIN_PASSWORD" "$GF_SECURITY_ADMIN_PASSWORD" "env" "true" "Grafana Admin Password"
    create_or_update_tf_variable "grafana_admin_password" "$GF_SECURITY_ADMIN_PASSWORD" "terraform" "true" "Grafana Admin Password"
fi

# Synchroniser les secrets GitHub
if [ ! -z "$GH_PAT" ]; then
    create_or_update_tf_variable "GH_PAT" "$GH_PAT" "env" "true" "GitHub Personal Access Token"
    create_or_update_tf_variable "github_token" "$GH_PAT" "terraform" "true" "GitHub Token"
fi

# Synchroniser les secrets Terraform
if [ ! -z "$TF_API_TOKEN" ]; then
    create_or_update_tf_variable "TF_API_TOKEN" "$TF_API_TOKEN" "env" "true" "Terraform API Token"
    create_or_update_tf_variable "tf_api_token" "$TF_API_TOKEN" "terraform" "true" "Terraform API Token"
fi

if [ ! -z "$TF_WORKSPACE_ID" ]; then
    create_or_update_tf_variable "TF_WORKSPACE_ID" "$TF_WORKSPACE_ID" "env" "false" "Terraform Workspace ID"
    create_or_update_tf_variable "tf_workspace_id" "$TF_WORKSPACE_ID" "terraform" "false" "Terraform Workspace ID"
fi

# Synchroniser les variables d'infrastructure
if [ ! -z "$TF_EC2_PUBLIC_IP" ]; then
    create_or_update_tf_variable "TF_EC2_PUBLIC_IP" "$TF_EC2_PUBLIC_IP" "env" "false" "EC2 Public IP"
    create_or_update_tf_variable "ec2_public_ip" "$TF_EC2_PUBLIC_IP" "terraform" "false" "EC2 Public IP"
fi

if [ ! -z "$TF_S3_BUCKET_NAME" ]; then
    create_or_update_tf_variable "TF_S3_BUCKET_NAME" "$TF_S3_BUCKET_NAME" "env" "false" "S3 Bucket Name"
    create_or_update_tf_variable "s3_bucket_name" "$TF_S3_BUCKET_NAME" "terraform" "false" "S3 Bucket Name"
fi

if [ ! -z "$TF_MONITORING_EC2_PUBLIC_IP" ]; then
    create_or_update_tf_variable "TF_MONITORING_EC2_PUBLIC_IP" "$TF_MONITORING_EC2_PUBLIC_IP" "env" "false" "Monitoring EC2 Public IP"
    create_or_update_tf_variable "monitoring_ec2_public_ip" "$TF_MONITORING_EC2_PUBLIC_IP" "terraform" "false" "Monitoring EC2 Public IP"
fi

if [ ! -z "$TF_RDS_ENDPOINT" ]; then
    create_or_update_tf_variable "TF_RDS_ENDPOINT" "$TF_RDS_ENDPOINT" "env" "false" "RDS Endpoint"
    create_or_update_tf_variable "rds_endpoint" "$TF_RDS_ENDPOINT" "terraform" "false" "RDS Endpoint"
fi

if [ ! -z "$TF_GRAFANA_URL" ]; then
    create_or_update_tf_variable "TF_GRAFANA_URL" "$TF_GRAFANA_URL" "env" "false" "Grafana URL"
    create_or_update_tf_variable "grafana_url" "$TF_GRAFANA_URL" "terraform" "false" "Grafana URL"
fi



# Activer le mode débogage si la variable DEBUG est définie
if [ "${DEBUG:-false}" = "true" ]; then
    log "Mode débogage activé"
fi

log "Synchronisation des secrets GitHub vers Terraform Cloud terminée avec succès"

# Afficher un message d'information sur l'utilisation d'un gestionnaire de secrets externe
log "Note: Pour une solution plus robuste en production, envisagez d'utiliser AWS Secrets Manager ou HashiCorp Vault pour stocker les clés SSH."
