#!/bin/bash
#==============================================================================
# Nom du script : setup-ssh-keys.sh
# Description   : Script pour configurer les clés SSH à partir des secrets GitHub.
#                 Ce script récupère les secrets GitHub et configure les clés SSH
#                 pour permettre la communication entre les instances EC2.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2025-05-15
#==============================================================================
# Utilisation   : sudo ./setup-ssh-keys.sh
#==============================================================================
# Dépendances   :
#   - jq        : Pour traiter les fichiers JSON
#==============================================================================
# Droits requis : Ce script doit être exécuté avec des privilèges sudo ou en tant que root.
#==============================================================================

# Fonction pour afficher les messages d'information
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] $1"
}

# Fonction pour afficher les messages d'erreur et quitter
log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [ERROR] $1" >&2
    exit 1
}

# Fonction pour afficher les messages de succès
log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [SUCCESS] $1"
}

# Vérification des droits sudo
if [ "$(id -u)" -ne 0 ]; then
    log_error "Ce script doit être exécuté avec sudo ou en tant que root"
fi

# Création du répertoire .ssh s'il n'existe pas
log_info "Création du répertoire .ssh"
mkdir -p /home/ec2-user/.ssh
chmod 700 /home/ec2-user/.ssh

# Vérifier si les secrets GitHub sont disponibles dans les variables d'environnement
if [ -n "$EC2_SSH_PRIVATE_KEY" ]; then
    log_info "Utilisation de la clé privée SSH depuis la variable d'environnement"
    echo "$EC2_SSH_PRIVATE_KEY" > /home/ec2-user/.ssh/id_rsa
    chmod 600 /home/ec2-user/.ssh/id_rsa
    chown ec2-user:ec2-user /home/ec2-user/.ssh/id_rsa
else
    log_info "La variable d'environnement EC2_SSH_PRIVATE_KEY n'est pas définie"
    
    # Vérifier si le fichier de secrets existe
    if [ -f "/opt/secrets/EC2_SSH_PRIVATE_KEY" ]; then
        log_info "Utilisation de la clé privée SSH depuis le fichier de secrets"
        cp /opt/secrets/EC2_SSH_PRIVATE_KEY /home/ec2-user/.ssh/id_rsa
        chmod 600 /home/ec2-user/.ssh/id_rsa
        chown ec2-user:ec2-user /home/ec2-user/.ssh/id_rsa
    else
        log_info "Le fichier de secrets EC2_SSH_PRIVATE_KEY n'existe pas"
        
        # Créer un fichier vide pour éviter les erreurs
        touch /home/ec2-user/.ssh/id_rsa
        chmod 600 /home/ec2-user/.ssh/id_rsa
        chown ec2-user:ec2-user /home/ec2-user/.ssh/id_rsa
    fi
fi

if [ -n "$EC2_SSH_PUBLIC_KEY" ]; then
    log_info "Utilisation de la clé publique SSH depuis la variable d'environnement"
    echo "$EC2_SSH_PUBLIC_KEY" > /home/ec2-user/.ssh/id_rsa.pub
    chmod 644 /home/ec2-user/.ssh/id_rsa.pub
    chown ec2-user:ec2-user /home/ec2-user/.ssh/id_rsa.pub
    
    # Ajouter la clé publique au fichier authorized_keys
    cat /home/ec2-user/.ssh/id_rsa.pub >> /home/ec2-user/.ssh/authorized_keys
    chmod 600 /home/ec2-user/.ssh/authorized_keys
    chown ec2-user:ec2-user /home/ec2-user/.ssh/authorized_keys
else
    log_info "La variable d'environnement EC2_SSH_PUBLIC_KEY n'est pas définie"
    
    # Vérifier si le fichier de secrets existe
    if [ -f "/opt/secrets/EC2_SSH_PUBLIC_KEY" ]; then
        log_info "Utilisation de la clé publique SSH depuis le fichier de secrets"
        cp /opt/secrets/EC2_SSH_PUBLIC_KEY /home/ec2-user/.ssh/id_rsa.pub
        chmod 644 /home/ec2-user/.ssh/id_rsa.pub
        chown ec2-user:ec2-user /home/ec2-user/.ssh/id_rsa.pub
        
        # Ajouter la clé publique au fichier authorized_keys
        cat /home/ec2-user/.ssh/id_rsa.pub >> /home/ec2-user/.ssh/authorized_keys
        chmod 600 /home/ec2-user/.ssh/authorized_keys
        chown ec2-user:ec2-user /home/ec2-user/.ssh/authorized_keys
    else
        log_info "Le fichier de secrets EC2_SSH_PUBLIC_KEY n'existe pas"
        
        # Créer un fichier vide pour éviter les erreurs
        touch /home/ec2-user/.ssh/id_rsa.pub
        chmod 644 /home/ec2-user/.ssh/id_rsa.pub
        chown ec2-user:ec2-user /home/ec2-user/.ssh/id_rsa.pub
    fi
fi

# Ajouter les hôtes connus pour éviter les prompts
log_info "Ajout des hôtes connus"
echo "10.0.1.135 ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCyPbn4pECLmVRBXhXEyQoC4vBTMxfODN9Rw8W6/XxpLvrYX+Td7dUNQM6CLegTsL1E9S3R2AhzUPbYXRHhJNZIkEwK2GYEpYWOZjZ9jY5Xia5dBLVUkU2AY9WYjsxuYL5DKYyH0KpKmTUYO4eOOkZKrYVyXjP+PPv9zKV5hK6JbmkgG/ZWzF8nZoZVETLQb0gMNLTpYAEEKKs3FNE2YRQJJYDCgQP3GsqQQIYRuQLnL0Ts9X/wV8Y6xT5xqIUJUmhRFJOY4e5QpLRG4hA1h9ZIEfPdu5AQGcKjBZRqEFjZVmRddh8aTYbBFBEQY5Ks0QZBqnx5KoT8Q0wEpSZGXmQD" >> /home/ec2-user/.ssh/known_hosts
echo "10.0.1.132 ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCyPbn4pECLmVRBXhXEyQoC4vBTMxfODN9Rw8W6/XxpLvrYX+Td7dUNQM6CLegTsL1E9S3R2AhzUPbYXRHhJNZIkEwK2GYEpYWOZjZ9jY5Xia5dBLVUkU2AY9WYjsxuYL5DKYyH0KpKmTUYO4eOOkZKrYVyXjP+PPv9zKV5hK6JbmkgG/ZWzF8nZoZVETLQb0gMNLTpYAEEKKs3FNE2YRQJJYDCgQP3GsqQQIYRuQLnL0Ts9X/wV8Y6xT5xqIUJUmhRFJOY4e5QpLRG4hA1h9ZIEfPdu5AQGcKjBZRqEFjZVmRddh8aTYbBFBEQY5Ks0QZBqnx5KoT8Q0wEpSZGXmQD" >> /home/ec2-user/.ssh/known_hosts
chmod 644 /home/ec2-user/.ssh/known_hosts
chown ec2-user:ec2-user /home/ec2-user/.ssh/known_hosts

# Exécuter le script fix-ssh-keys.sh pour corriger les clés SSH
if [ -f "/opt/scripts/utils/fix-ssh-keys.sh" ]; then
    log_info "Exécution du script fix-ssh-keys.sh"
    sudo -u ec2-user bash /opt/scripts/utils/fix-ssh-keys.sh
fi

log_success "Configuration des clés SSH terminée avec succès"
exit 0
