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

# Récupérer l'adresse IP privée de l'instance EC2 Java Tomcat depuis le fichier de configuration
log_info "Récupération de l'adresse IP privée de l'instance EC2 Java Tomcat"

# Vérifier si le fichier de configuration existe
if [ -f "/opt/monitoring/secure/java_tomcat_ip.txt" ]; then
    JAVA_TOMCAT_IP=$(cat /opt/monitoring/secure/java_tomcat_ip.txt)
    log_info "Adresse IP privée récupérée depuis le fichier de configuration : $JAVA_TOMCAT_IP"
else
    # Essayer de récupérer l'adresse IP via AWS CLI en recherchant l'instance avec le tag Name contenant "yourmedia-dev-app-server"
    log_info "Tentative de récupération de l'adresse IP via AWS CLI"
    JAVA_TOMCAT_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=yourmedia-dev-app-server" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].PrivateIpAddress" --output text)

    if [ -z "$JAVA_TOMCAT_IP" ] || [ "$JAVA_TOMCAT_IP" == "None" ]; then
        log_info "Impossible de récupérer l'adresse IP via AWS CLI, utilisation de l'adresse par défaut"
        JAVA_TOMCAT_IP="10.0.1.135"  # Adresse IP par défaut si la récupération échoue
    else
        # Sauvegarder l'adresse IP pour les prochaines exécutions
        mkdir -p /opt/monitoring/secure
        echo "$JAVA_TOMCAT_IP" > /opt/monitoring/secure/java_tomcat_ip.txt
    fi
fi

log_info "Adresse IP privée de l'instance EC2 Java Tomcat : $JAVA_TOMCAT_IP"

# Synchroniser les logs de Tomcat
log_info "Synchronisation des logs de Tomcat"
sudo rsync -avz -e "ssh -o StrictHostKeyChecking=no -i /home/ec2-user/.ssh/id_rsa" ec2-user@$JAVA_TOMCAT_IP:/opt/tomcat/logs/ /mnt/ec2-java-tomcat-logs/

if [ $? -ne 0 ]; then
    log_error "Échec de la synchronisation des logs de Tomcat"
fi

# Vérifier si les logs ont été synchronisés
log_info "Vérification des logs synchronisés"
if [ -f "/mnt/ec2-java-tomcat-logs/catalina.out" ]; then
    log_success "Le fichier catalina.out a été synchronisé avec succès"
else
    log_error "Le fichier catalina.out n'a pas été synchronisé"
fi

# Afficher les logs disponibles
log_info "Logs Tomcat disponibles:"
ls -la /mnt/ec2-java-tomcat-logs/

log_success "Synchronisation des logs de Tomcat terminée avec succès"
exit 0
