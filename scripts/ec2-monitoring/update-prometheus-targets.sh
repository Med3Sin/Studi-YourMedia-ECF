#!/bin/bash
#==============================================================================
# Nom du script : update-prometheus-targets.sh
# Description   : Script pour mettre à jour les cibles Prometheus avec l'adresse IP
#                 de l'instance EC2 Java Tomcat.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2023-07-10
#==============================================================================
# Utilisation   : sudo ./update-prometheus-targets.sh
#==============================================================================
# Dépendances   :
#   - aws-cli   : Pour récupérer les informations sur les instances EC2
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

# Récupérer l'adresse IP privée de l'instance EC2 Java Tomcat
log_info "Récupération de l'adresse IP privée de l'instance EC2 Java Tomcat"
JAVA_TOMCAT_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=yourmedia-dev-app-server" --query "Reservations[0].Instances[0].PrivateIpAddress" --output text)

if [ -z "$JAVA_TOMCAT_IP" ]; then
    log_error "Impossible de récupérer l'adresse IP privée de l'instance EC2 Java Tomcat"
fi

log_info "Adresse IP privée de l'instance EC2 Java Tomcat : $JAVA_TOMCAT_IP"

# Mettre à jour le fichier prometheus.yml
log_info "Mise à jour du fichier prometheus.yml"
sed -i "s/java-tomcat-instance:8080/$JAVA_TOMCAT_IP:8080/g" /opt/monitoring/prometheus.yml

if [ $? -ne 0 ]; then
    log_error "Échec de la mise à jour du fichier prometheus.yml"
fi

# Redémarrer Prometheus pour prendre en compte les modifications
log_info "Redémarrage de Prometheus"
docker restart prometheus

if [ $? -ne 0 ]; then
    log_error "Échec du redémarrage de Prometheus"
fi

log_success "Mise à jour des cibles Prometheus terminée avec succès"
exit 0
