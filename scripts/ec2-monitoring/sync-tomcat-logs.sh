#!/bin/bash
#==============================================================================
# Nom du script : sync-tomcat-logs.sh
# Description   : Script pour synchroniser les logs de l'instance EC2 Java Tomcat
#                 vers l'instance EC2 Monitoring.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2023-07-10
#==============================================================================
# Utilisation   : sudo ./sync-tomcat-logs.sh
#==============================================================================
# Dépendances   :
#   - rsync     : Pour synchroniser les fichiers
#   - ssh       : Pour se connecter à l'instance EC2 Java Tomcat
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

# Vérifier si le répertoire de destination existe, sinon le créer
if [ ! -d "/mnt/ec2-java-tomcat-logs" ]; then
    log_info "Création du répertoire /mnt/ec2-java-tomcat-logs"
    sudo mkdir -p /mnt/ec2-java-tomcat-logs
    if [ $? -ne 0 ]; then
        log_error "Échec de la création du répertoire /mnt/ec2-java-tomcat-logs"
    fi
fi

# Utiliser l'adresse IP privée statique de l'instance EC2 Java Tomcat
log_info "Utilisation de l'adresse IP privée statique de l'instance EC2 Java Tomcat"
JAVA_TOMCAT_IP="10.0.1.135"  # Adresse IP privée statique de l'instance EC2 Java Tomcat

log_info "Adresse IP privée de l'instance EC2 Java Tomcat : $JAVA_TOMCAT_IP"

# Synchroniser les logs de Tomcat
log_info "Synchronisation des logs de Tomcat"
sudo rsync -avz -e "ssh -o StrictHostKeyChecking=no -i /home/ec2-user/.ssh/id_rsa" ec2-user@$JAVA_TOMCAT_IP:/opt/tomcat/logs/catalina.out /mnt/ec2-java-tomcat-logs/

if [ $? -ne 0 ]; then
    log_error "Échec de la synchronisation des logs de Tomcat"
fi

log_success "Synchronisation des logs de Tomcat terminée avec succès"
exit 0
