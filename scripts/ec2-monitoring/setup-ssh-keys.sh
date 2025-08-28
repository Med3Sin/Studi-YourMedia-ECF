#!/bin/bash
#==============================================================================
# Nom du script : setup-ssh-keys.sh
# Description   : Script pour configurer les clés SSH entre les instances
# Auteur        : Med3Sin
# Version       : 1.0
#==============================================================================

# Fonction de logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Vérifier si nous sommes root
if [ "$EUID" -eq 0 ]; then
    log "Ce script doit être exécuté en tant qu'utilisateur ec2-user, pas en tant que root"
    log "Veuillez exécuter : ./scripts/ec2-monitoring/setup-ssh-keys.sh"
    exit 1
fi

# Vérifier si une clé SSH existe déjà
if [ ! -f ~/.ssh/id_rsa ]; then
    log "Génération d'une nouvelle paire de clés SSH..."
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
fi

# Créer le fichier authorized_keys s'il n'existe pas
log "Configuration du fichier authorized_keys..."
mkdir -p ~/.ssh
touch ~/.ssh/authorized_keys

# Ajouter la clé publique au fichier authorized_keys
log "Ajout de la clé publique..."
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

# Configurer les permissions correctes
log "Configuration des permissions..."
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub

# Afficher la clé publique pour la copier manuellement
log "Voici votre clé publique à copier sur l'instance Java :"
echo "----------------------------------------"
cat ~/.ssh/id_rsa.pub
echo "----------------------------------------"
log "Instructions :"
log "1. Connectez-vous à l'instance Java (10.0.1.48) :"
log "   ssh ec2-user@10.0.1.48"
log "2. Créez le dossier .ssh s'il n'existe pas :"
log "   mkdir -p ~/.ssh"
log "3. Ajoutez la clé publique ci-dessus dans ~/.ssh/authorized_keys :"
log "   echo 'VOTRE_CLE_PUBLIQUE' >> ~/.ssh/authorized_keys"
log "4. Configurez les permissions :"
log "   chmod 700 ~/.ssh"
log "   chmod 600 ~/.ssh/authorized_keys"
log ""
log "Une fois ces étapes effectuées, exécutez :"
log "ssh -o BatchMode=yes -o ConnectTimeout=5 ec2-user@10.0.1.48 echo 'Connexion SSH réussie'"
log ""
log "Configuration SSH terminée" 
