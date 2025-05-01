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
#   - DOCKERHUB_USERNAME (standard)
#   - DOCKERHUB_TOKEN (standard)
#   - DOCKERHUB_REPO (standard)
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
      "sensitive": $sensitive,
      "read": true
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
      "sensitive": $sensitive,
      "read": true
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



log "Synchronisation des secrets GitHub vers Terraform Cloud terminée avec succès"
