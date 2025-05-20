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

# Mettre à jour le fichier prometheus.yml
log_info "Mise à jour du fichier prometheus.yml"

# Vérifier si le fichier prometheus.yml existe
if [ ! -f "/opt/monitoring/prometheus.yml" ]; then
    log_info "Le fichier prometheus.yml n'existe pas, création..."
    mkdir -p /opt/monitoring
    cat > /opt/monitoring/prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "node_exporter_monitoring"
    static_configs:
      - targets: ["localhost:9100"]

  - job_name: "node_exporter_java_tomcat"
    static_configs:
      - targets: ["$JAVA_TOMCAT_IP:9100"]

  - job_name: "tomcat_jvm"
    static_configs:
      - targets: ["$JAVA_TOMCAT_IP:9404"]

  - job_name: "cadvisor"
    static_configs:
      - targets: ["cadvisor:8080"]
EOF
else
    # Remplacer l'adresse IP de l'instance Java/Tomcat dans le fichier de configuration
    sed -i "s/\(node_exporter_java_tomcat.*targets.*\[\"\)[^\"]*\(\".*\)/\1$JAVA_TOMCAT_IP\2/" /opt/monitoring/prometheus.yml
    sed -i "s/\(tomcat_jvm.*targets.*\[\"\)[^\"]*\(\".*\)/\1$JAVA_TOMCAT_IP\2/" /opt/monitoring/prometheus.yml
    sed -i "s/java-tomcat-instance:8080/$JAVA_TOMCAT_IP:8080/g" /opt/monitoring/prometheus.yml
fi

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
