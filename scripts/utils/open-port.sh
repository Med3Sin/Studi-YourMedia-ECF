#!/bin/bash
# Script pour ouvrir le port 8080 dans le groupe de sécurité de l'instance EC2

# Fonction pour afficher les messages de log
log_info() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - [INFO] $1"
}

log_success() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - [SUCCESS] $1"
}

log_error() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - [ERROR] $1" >&2
}

# Vérifier si AWS CLI est installé
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI n'est pas installé. Installation en cours..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
fi

# Récupérer l'ID de l'instance
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
if [ -z "$INSTANCE_ID" ]; then
    log_error "Impossible de récupérer l'ID de l'instance"
    exit 1
fi
log_info "ID de l'instance: $INSTANCE_ID"

# Récupérer la région
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
if [ -z "$REGION" ]; then
    log_error "Impossible de récupérer la région"
    exit 1
fi
log_info "Région: $REGION"

# Configurer la région par défaut
aws configure set default.region $REGION

# Récupérer les groupes de sécurité associés à l'instance
SECURITY_GROUPS=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[0].Instances[0].SecurityGroups[*].GroupId" --output text)
if [ -z "$SECURITY_GROUPS" ]; then
    log_error "Impossible de récupérer les groupes de sécurité"
    exit 1
fi

# Pour chaque groupe de sécurité
for SG_ID in $SECURITY_GROUPS; do
    log_info "Vérification du groupe de sécurité: $SG_ID"
    
    # Vérifier si le port 8080 est déjà ouvert
    PORT_OPEN=$(aws ec2 describe-security-groups --group-ids $SG_ID --query "SecurityGroups[0].IpPermissions[?ToPort==\`8080\`]" --output text)
    
    if [ -z "$PORT_OPEN" ]; then
        log_info "Le port 8080 n'est pas ouvert dans le groupe de sécurité $SG_ID. Ouverture du port..."
        
        # Ouvrir le port 8080
        aws ec2 authorize-security-group-ingress \
            --group-id $SG_ID \
            --protocol tcp \
            --port 8080 \
            --cidr 0.0.0.0/0
        
        if [ $? -eq 0 ]; then
            log_success "Le port 8080 a été ouvert avec succès dans le groupe de sécurité $SG_ID"
        else
            log_error "Erreur lors de l'ouverture du port 8080 dans le groupe de sécurité $SG_ID"
        fi
    else
        log_info "Le port 8080 est déjà ouvert dans le groupe de sécurité $SG_ID"
    fi
done

log_success "Vérification et ouverture du port 8080 terminées"
