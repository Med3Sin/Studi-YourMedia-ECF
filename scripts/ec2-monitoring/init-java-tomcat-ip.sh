#!/bin/bash
#==============================================================================
# Nom du script : init-java-tomcat-ip.sh
# Description   : Script pour initialiser l'adresse IP de l'instance EC2 Java Tomcat
#                 à partir de la variable Terraform.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2023-07-10
#==============================================================================
# Utilisation   : sudo ./init-java-tomcat-ip.sh <adresse_ip>
#==============================================================================
# Dépendances   : Aucune
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

# Vérifier si l'adresse IP a été fournie en argument
if [ $# -ne 1 ]; then
    log_error "Usage: $0 <adresse_ip>"
fi

# Récupérer l'adresse IP fournie en argument
JAVA_TOMCAT_IP="$1"

# Vérifier si l'adresse IP est valide
if [[ ! $JAVA_TOMCAT_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "L'adresse IP fournie n'est pas valide : $JAVA_TOMCAT_IP"
fi

log_info "Adresse IP de l'instance EC2 Java Tomcat : $JAVA_TOMCAT_IP"

# Créer le répertoire secure s'il n'existe pas
if [ ! -d "/opt/monitoring/secure" ]; then
    log_info "Création du répertoire /opt/monitoring/secure"
    sudo mkdir -p /opt/monitoring/secure
    if [ $? -ne 0 ]; then
        log_error "Échec de la création du répertoire /opt/monitoring/secure"
    fi
fi

# Enregistrer l'adresse IP dans un fichier
log_info "Enregistrement de l'adresse IP dans le fichier /opt/monitoring/secure/java_tomcat_ip.txt"
echo "$JAVA_TOMCAT_IP" | sudo tee /opt/monitoring/secure/java_tomcat_ip.txt > /dev/null

if [ $? -ne 0 ]; then
    log_error "Échec de l'enregistrement de l'adresse IP dans le fichier"
fi

# Mettre à jour le fichier prometheus.yml
log_info "Mise à jour du fichier prometheus.yml"
sudo sed -i "s/java-tomcat-instance:8080/$JAVA_TOMCAT_IP:8080/g" /opt/monitoring/prometheus.yml

if [ $? -ne 0 ]; then
    log_error "Échec de la mise à jour du fichier prometheus.yml"
fi

# Redémarrer Prometheus pour prendre en compte les modifications
log_info "Redémarrage de Prometheus"
sudo docker restart prometheus

if [ $? -ne 0 ]; then
    log_error "Échec du redémarrage de Prometheus"
fi

log_success "Initialisation de l'adresse IP de l'instance EC2 Java Tomcat terminée avec succès"
exit 0
