#!/bin/bash
#==============================================================================
# Nom du script : sync-github-secrets-to-terraform.sh
# Description   : Synchronise les secrets GitHub vers Terraform Cloud
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2025-04-28
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
#   - EC2_SSH_PRIVATE_KEY
#   - EC2_SSH_PUBLIC_KEY
#   - DOCKER_USERNAME
#   - DOCKERHUB_TOKEN
#   - TF_EC2_PUBLIC_IP
#   - TF_S3_BUCKET_NAME
#   - TF_MONITORING_EC2_PUBLIC_IP
#   - TF_RDS_ENDPOINT
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

# Fonction pour créer ou mettre à jour une variable Terraform Cloud
create_or_update_tf_variable() {
    local key="$1"
    local value="$2"
    local category="$3"  # terraform ou env
    local sensitive="$4" # true ou false
    local description="$5"

    # Échapper les caractères spéciaux dans la valeur
    local escaped_value=$(escape_json_value "$value")

    # Vérifier si la variable existe déjà
    local variable_id=$(curl -s \
        --header "Authorization: Bearer $TF_API_TOKEN" \
        --header "Content-Type: application/vnd.api+json" \
        "https://app.terraform.io/api/v2/workspaces/$TF_WORKSPACE_ID/vars" | \
        jq -r --arg key "$key" --arg category "$category" '.data[] | select(.attributes.key == $key and .attributes.category == $category) | .id')

    if [ -z "$variable_id" ] || [ "$variable_id" == "null" ]; then
        # Créer une nouvelle variable
        log "Création de la variable $key dans Terraform Cloud"
        curl -s \
            --header "Authorization: Bearer $TF_API_TOKEN" \
            --header "Content-Type: application/vnd.api+json" \
            --request POST \
            --data @- \
            "https://app.terraform.io/api/v2/workspaces/$TF_WORKSPACE_ID/vars" << EOF
{
  "data": {
    "type": "vars",
    "attributes": {
      "key": "$key",
      "value": "$escaped_value",
      "description": "$description",
      "category": "$category",
      "hcl": false,
      "sensitive": $sensitive
    }
  }
}
EOF
    else
        # Mettre à jour la variable existante
        log "Mise à jour de la variable $key dans Terraform Cloud"
        curl -s \
            --header "Authorization: Bearer $TF_API_TOKEN" \
            --header "Content-Type: application/vnd.api+json" \
            --request PATCH \
            --data @- \
            "https://app.terraform.io/api/v2/workspaces/$TF_WORKSPACE_ID/vars/$variable_id" << EOF
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
      "sensitive": $sensitive
    }
  }
}
EOF
    fi
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

# Synchroniser les secrets RDS
if [ ! -z "$RDS_USERNAME" ]; then
    create_or_update_tf_variable "RDS_USERNAME" "$RDS_USERNAME" "env" "true" "RDS Username"
    create_or_update_tf_variable "db_username" "$RDS_USERNAME" "terraform" "true" "RDS Username"
fi

if [ ! -z "$RDS_PASSWORD" ]; then
    create_or_update_tf_variable "RDS_PASSWORD" "$RDS_PASSWORD" "env" "true" "RDS Password"
    create_or_update_tf_variable "db_password" "$RDS_PASSWORD" "terraform" "true" "RDS Password"
fi

# Synchroniser les secrets SSH
if [ ! -z "$EC2_SSH_PRIVATE_KEY" ]; then
    create_or_update_tf_variable "EC2_SSH_PRIVATE_KEY" "$EC2_SSH_PRIVATE_KEY" "env" "true" "EC2 SSH Private Key"
    create_or_update_tf_variable "ssh_private_key_content" "$EC2_SSH_PRIVATE_KEY" "terraform" "true" "EC2 SSH Private Key"
fi

if [ ! -z "$EC2_SSH_PUBLIC_KEY" ]; then
    create_or_update_tf_variable "EC2_SSH_PUBLIC_KEY" "$EC2_SSH_PUBLIC_KEY" "env" "true" "EC2 SSH Public Key"
    create_or_update_tf_variable "ssh_public_key" "$EC2_SSH_PUBLIC_KEY" "terraform" "true" "EC2 SSH Public Key"
fi

# Synchroniser les secrets Docker
if [ ! -z "$DOCKER_USERNAME" ]; then
    create_or_update_tf_variable "DOCKER_USERNAME" "$DOCKER_USERNAME" "env" "true" "Docker Username"
    create_or_update_tf_variable "dockerhub_username" "$DOCKER_USERNAME" "terraform" "true" "Docker Username"
fi

if [ ! -z "$DOCKERHUB_TOKEN" ]; then
    create_or_update_tf_variable "DOCKERHUB_TOKEN" "$DOCKERHUB_TOKEN" "env" "true" "Docker Hub Token"
    create_or_update_tf_variable "dockerhub_token" "$DOCKERHUB_TOKEN" "terraform" "true" "Docker Hub Token"
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

log "Synchronisation des secrets GitHub vers Terraform Cloud terminée avec succès"
