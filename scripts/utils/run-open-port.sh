#!/bin/bash
# Script pour exécuter le script open-port.sh sur l'instance de monitoring

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

# Vérifier si l'adresse IP de l'instance de monitoring est définie
if [ -z "$1" ]; then
    log_error "L'adresse IP de l'instance de monitoring n'est pas définie"
    echo "Usage: $0 <monitoring_ip> [ssh_key_file]"
    exit 1
fi

MONITORING_IP=$1

# Vérifier si le fichier de clé SSH est défini
if [ -z "$2" ]; then
    SSH_KEY_FILE="$HOME/.ssh/id_rsa"
    log_info "Utilisation du fichier de clé SSH par défaut: $SSH_KEY_FILE"
else
    SSH_KEY_FILE=$2
    log_info "Utilisation du fichier de clé SSH spécifié: $SSH_KEY_FILE"
fi

# Vérifier si le fichier de clé SSH existe
if [ ! -f "$SSH_KEY_FILE" ]; then
    log_error "Le fichier de clé SSH n'existe pas: $SSH_KEY_FILE"
    exit 1
fi

log_info "Connexion à l'instance de monitoring ($MONITORING_IP) pour ouvrir le port 8080..."

# Télécharger le script open-port.sh depuis GitHub
ssh -i "$SSH_KEY_FILE" -o StrictHostKeyChecking=no ec2-user@$MONITORING_IP << EOF
    echo "Téléchargement du script open-port.sh depuis GitHub..."
    curl -s -o /tmp/open-port.sh https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main/scripts/utils/open-port.sh
    chmod +x /tmp/open-port.sh
    
    echo "Exécution du script open-port.sh..."
    sudo /tmp/open-port.sh
    
    echo "Suppression du script temporaire..."
    rm -f /tmp/open-port.sh
EOF

if [ $? -eq 0 ]; then
    log_success "Le port 8080 a été ouvert avec succès sur l'instance de monitoring"
else
    log_error "Erreur lors de l'ouverture du port 8080 sur l'instance de monitoring"
    exit 1
fi

log_info "Vérification de l'état du conteneur app-mobile..."

ssh -i "$SSH_KEY_FILE" -o StrictHostKeyChecking=no ec2-user@$MONITORING_IP << EOF
    echo "État du conteneur app-mobile:"
    sudo docker ps -a | grep app-mobile
    
    echo "Logs du conteneur app-mobile:"
    sudo docker logs app-mobile
EOF

log_success "Opération terminée"
