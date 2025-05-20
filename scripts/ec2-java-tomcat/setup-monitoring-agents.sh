#!/bin/bash
#==============================================================================
# Nom du script : setup-monitoring-agents.sh
# Description   : Script pour installer et configurer les agents de monitoring sur l'instance EC2 Java/Tomcat
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2025-05-20
#==============================================================================
# Utilisation   : sudo ./setup-monitoring-agents.sh
#==============================================================================
# Dépendances   :
#   - wget      : Pour télécharger les fichiers
#   - java      : Pour exécuter JMX Exporter
#==============================================================================

# Journalisation
LOG_FILE="/var/log/setup-monitoring-agents.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Fonction pour afficher les erreurs et quitter
error_exit() {
    log "ERREUR: $1"
    exit 1
}

# Vérification des droits sudo
if [ "$(id -u)" -ne 0 ]; then
    error_exit "Ce script doit être exécuté avec sudo ou en tant que root"
fi

# Installation de Node Exporter
log "Installation de Node Exporter"
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz || error_exit "Impossible de télécharger Node Exporter"
tar xvfz node_exporter-1.7.0.linux-amd64.tar.gz || error_exit "Impossible d'extraire Node Exporter"
mv node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/ || error_exit "Impossible de déplacer Node Exporter"
useradd -rs /bin/false node_exporter || log "L'utilisateur node_exporter existe déjà"

# Création du service systemd pour Node Exporter
log "Création du service systemd pour Node Exporter"
cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

# Démarrage et activation du service Node Exporter
log "Démarrage et activation du service Node Exporter"
systemctl daemon-reload
systemctl start node_exporter
systemctl enable node_exporter

# Vérification que Node Exporter fonctionne
if systemctl is-active --quiet node_exporter; then
    log "Node Exporter est en cours d'exécution"
else
    error_exit "Node Exporter n'a pas pu être démarré"
fi

# Installation de JMX Exporter
log "Installation de JMX Exporter"
mkdir -p /opt/jmx_exporter
cd /opt/jmx_exporter
wget https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.20.0/jmx_prometheus_javaagent-0.20.0.jar || error_exit "Impossible de télécharger JMX Exporter"
wget https://raw.githubusercontent.com/prometheus/jmx_exporter/master/example_configs/tomcat.yml -O config.yml || error_exit "Impossible de télécharger la configuration de JMX Exporter"

# Détection du répertoire d'installation de Tomcat
if [ -d "/opt/tomcat" ]; then
    CATALINA_HOME="/opt/tomcat"
elif [ -d "/usr/share/tomcat" ]; then
    CATALINA_HOME="/usr/share/tomcat"
else
    # Recherche du répertoire Tomcat
    CATALINA_HOME=$(find / -name catalina.sh -type f 2>/dev/null | head -n 1 | xargs dirname | xargs dirname)
    if [ -z "$CATALINA_HOME" ]; then
        error_exit "Impossible de trouver le répertoire d'installation de Tomcat"
    fi
fi

log "Répertoire Tomcat détecté : $CATALINA_HOME"

# Configuration de Tomcat pour utiliser JMX Exporter
log "Configuration de Tomcat pour utiliser JMX Exporter"
mkdir -p $CATALINA_HOME/bin
cat > $CATALINA_HOME/bin/setenv.sh << EOF
export CATALINA_OPTS="\$CATALINA_OPTS -javaagent:/opt/jmx_exporter/jmx_prometheus_javaagent-0.20.0.jar=9404:/opt/jmx_exporter/config.yml"
EOF

chmod +x $CATALINA_HOME/bin/setenv.sh

# Redémarrage de Tomcat
log "Redémarrage de Tomcat"
if systemctl list-unit-files | grep -q tomcat; then
    systemctl restart tomcat
elif [ -f "$CATALINA_HOME/bin/shutdown.sh" ] && [ -f "$CATALINA_HOME/bin/startup.sh" ]; then
    $CATALINA_HOME/bin/shutdown.sh
    sleep 5
    $CATALINA_HOME/bin/startup.sh
else
    log "Impossible de redémarrer Tomcat automatiquement. Veuillez le redémarrer manuellement."
fi

log "Installation des agents de monitoring terminée"
log "Node Exporter est accessible à l'adresse http://localhost:9100/metrics"
log "JMX Exporter est accessible à l'adresse http://localhost:9404/metrics (après le redémarrage de Tomcat)"
