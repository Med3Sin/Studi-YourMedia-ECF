#!/bin/bash
# Script pour vérifier l'état de Tomcat sur l'instance EC2 Java-Tomcat
# Auteur: Med3Sin
# Date: $(date +%Y-%m-%d)

# Fonction de journalisation
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Vérifier si le script est exécuté avec les privilèges root
if [ "$(id -u)" -ne 0 ]; then
    log "Ce script doit être exécuté avec les privilèges root (sudo)."
    exit 1
fi

# Vérifier si Java est installé
log "Vérification de l'installation de Java..."
if command -v java &> /dev/null; then
    java_version=$(java -version 2>&1 | head -n 1)
    log "✅ Java est installé: $java_version"
else
    log "❌ Java n'est pas installé."
    log "Installation de Java..."
    sudo dnf install -y java-17-amazon-corretto-devel
    if [ $? -eq 0 ]; then
        log "✅ Java a été installé avec succès."
    else
        log "❌ L'installation de Java a échoué."
        exit 1
    fi
fi

# Vérifier si Tomcat est installé
log "Vérification de l'installation de Tomcat..."
if [ -d "/opt/tomcat" ]; then
    log "✅ Le répertoire Tomcat existe: /opt/tomcat"
    
    # Vérifier si les fichiers binaires de Tomcat existent
    if [ -f "/opt/tomcat/bin/startup.sh" ] && [ -f "/opt/tomcat/bin/shutdown.sh" ]; then
        log "✅ Les fichiers binaires de Tomcat existent."
    else
        log "❌ Les fichiers binaires de Tomcat n'existent pas."
        log "Réinstallation de Tomcat..."
        
        # Exécuter le script d'installation de Tomcat
        if [ -f "/opt/yourmedia/install_java_tomcat.sh" ]; then
            sudo /opt/yourmedia/install_java_tomcat.sh
            if [ $? -eq 0 ]; then
                log "✅ Tomcat a été réinstallé avec succès."
            else
                log "❌ La réinstallation de Tomcat a échoué."
                exit 1
            fi
        else
            log "❌ Le script d'installation de Tomcat n'existe pas: /opt/yourmedia/install_java_tomcat.sh"
            exit 1
        fi
    fi
else
    log "❌ Le répertoire Tomcat n'existe pas: /opt/tomcat"
    log "Installation de Tomcat..."
    
    # Exécuter le script d'installation de Tomcat
    if [ -f "/opt/yourmedia/install_java_tomcat.sh" ]; then
        sudo /opt/yourmedia/install_java_tomcat.sh
        if [ $? -eq 0 ]; then
            log "✅ Tomcat a été installé avec succès."
        else
            log "❌ L'installation de Tomcat a échoué."
            exit 1
        fi
    else
        log "❌ Le script d'installation de Tomcat n'existe pas: /opt/yourmedia/install_java_tomcat.sh"
        exit 1
    fi
fi

# Vérifier si le service Tomcat est configuré
log "Vérification de la configuration du service Tomcat..."
if [ -f "/etc/systemd/system/tomcat.service" ]; then
    log "✅ Le service Tomcat est configuré."
else
    log "❌ Le service Tomcat n'est pas configuré."
    log "Configuration du service Tomcat..."
    
    # Créer le fichier de service Tomcat
    sudo bash -c 'cat > /etc/systemd/system/tomcat.service << EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

Environment=JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto
Environment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom"

ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

User=tomcat
Group=tomcat
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF'
    
    sudo systemctl daemon-reload
    log "✅ Le service Tomcat a été configuré."
fi

# Vérifier si le service Tomcat est activé
log "Vérification de l'activation du service Tomcat..."
if systemctl is-enabled --quiet tomcat; then
    log "✅ Le service Tomcat est activé."
else
    log "❌ Le service Tomcat n'est pas activé."
    log "Activation du service Tomcat..."
    sudo systemctl enable tomcat
    log "✅ Le service Tomcat a été activé."
fi

# Vérifier si le service Tomcat est en cours d'exécution
log "Vérification de l'état du service Tomcat..."
if systemctl is-active --quiet tomcat; then
    log "✅ Le service Tomcat est en cours d'exécution."
else
    log "❌ Le service Tomcat n'est pas en cours d'exécution."
    log "Démarrage du service Tomcat..."
    sudo systemctl start tomcat
    
    # Attendre quelques secondes pour que Tomcat démarre
    sleep 10
    
    # Vérifier à nouveau l'état du service
    if systemctl is-active --quiet tomcat; then
        log "✅ Le service Tomcat a été démarré avec succès."
    else
        log "❌ Le démarrage du service Tomcat a échoué."
        log "Vérification des journaux Tomcat..."
        journalctl -u tomcat --no-pager -n 50
        exit 1
    fi
fi

# Vérifier si le port 8080 est ouvert
log "Vérification du port 8080..."
if netstat -tuln | grep -q ":8080"; then
    log "✅ Le port 8080 est ouvert."
else
    log "❌ Le port 8080 n'est pas ouvert."
    log "Vérification des journaux Tomcat..."
    journalctl -u tomcat --no-pager -n 50
    exit 1
fi

# Vérifier si le script de déploiement WAR existe
log "Vérification du script de déploiement WAR..."
if [ -f "/opt/yourmedia/deploy-war.sh" ]; then
    log "✅ Le script de déploiement WAR existe: /opt/yourmedia/deploy-war.sh"
else
    log "❌ Le script de déploiement WAR n'existe pas: /opt/yourmedia/deploy-war.sh"
    log "Création du script de déploiement WAR..."
    
    # Créer le script de déploiement WAR
    cat > /opt/yourmedia/deploy-war.sh << 'EOF'
#!/bin/bash
# Script pour déployer un fichier WAR dans Tomcat
# Ce script doit être exécuté avec sudo

# Vérifier si un argument a été fourni
if [ $# -ne 1 ]; then
  echo "Usage: $0 <chemin_vers_war>"
  exit 1
fi

WAR_PATH=$1
WAR_NAME=$(basename $WAR_PATH)
TARGET_NAME="yourmedia-backend.war"

echo "Déploiement du fichier WAR: $WAR_PATH vers /opt/tomcat/webapps/$TARGET_NAME"

# Vérifier si le fichier existe
if [ ! -f "$WAR_PATH" ]; then
  echo "ERREUR: Le fichier $WAR_PATH n'existe pas"
  exit 1
fi

# Copier le fichier WAR dans webapps
cp $WAR_PATH /opt/tomcat/webapps/$TARGET_NAME

# Vérifier si la copie a réussi
if [ $? -ne 0 ]; then
  echo "ERREUR: Échec de la copie du fichier WAR dans /opt/tomcat/webapps/"
  exit 1
fi

# Changer le propriétaire
chown tomcat:tomcat /opt/tomcat/webapps/$TARGET_NAME

# Vérifier si le changement de propriétaire a réussi
if [ $? -ne 0 ]; then
  echo "ERREUR: Échec du changement de propriétaire du fichier WAR"
  exit 1
fi

# Redémarrer Tomcat
systemctl restart tomcat

# Vérifier si le redémarrage a réussi
if [ $? -ne 0 ]; then
  echo "ERREUR: Échec du redémarrage de Tomcat"
  exit 1
fi

echo "Déploiement terminé avec succès"
exit 0
EOF
    
    # Rendre le script exécutable
    chmod +x /opt/yourmedia/deploy-war.sh
    
    # Créer un lien symbolique vers le script dans /usr/local/bin
    ln -sf /opt/yourmedia/deploy-war.sh /usr/local/bin/deploy-war.sh
    chmod +x /usr/local/bin/deploy-war.sh
    
    log "✅ Le script de déploiement WAR a été créé."
fi

# Vérifier si le lien symbolique vers le script de déploiement WAR existe
log "Vérification du lien symbolique vers le script de déploiement WAR..."
if [ -f "/usr/local/bin/deploy-war.sh" ]; then
    log "✅ Le lien symbolique vers le script de déploiement WAR existe: /usr/local/bin/deploy-war.sh"
else
    log "❌ Le lien symbolique vers le script de déploiement WAR n'existe pas: /usr/local/bin/deploy-war.sh"
    log "Création du lien symbolique..."
    ln -sf /opt/yourmedia/deploy-war.sh /usr/local/bin/deploy-war.sh
    chmod +x /usr/local/bin/deploy-war.sh
    log "✅ Le lien symbolique vers le script de déploiement WAR a été créé."
fi

# Afficher un résumé
log "Résumé de la vérification de Tomcat:"
log "- Java est installé: $(java -version 2>&1 | head -n 1)"
log "- Tomcat est installé: $(ls -la /opt/tomcat/bin/startup.sh 2>/dev/null || echo "Non")"
log "- Service Tomcat configuré: $(systemctl is-enabled tomcat 2>/dev/null || echo "Non")"
log "- Service Tomcat en cours d'exécution: $(systemctl is-active tomcat 2>/dev/null || echo "Non")"
log "- Port 8080 ouvert: $(netstat -tuln | grep -q ":8080" && echo "Oui" || echo "Non")"
log "- Script de déploiement WAR: $(ls -la /opt/yourmedia/deploy-war.sh 2>/dev/null || echo "Non")"
log "- Lien symbolique vers le script de déploiement WAR: $(ls -la /usr/local/bin/deploy-war.sh 2>/dev/null || echo "Non")"

log "Vérification de Tomcat terminée avec succès."
