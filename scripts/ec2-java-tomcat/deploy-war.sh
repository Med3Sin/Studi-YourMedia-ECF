#!/bin/bash
#==============================================================================
# Nom du script : deploy-war.sh
# Description   : Script pour déployer un fichier WAR dans Tomcat.
#                 Ce script copie le fichier WAR spécifié dans le répertoire webapps de Tomcat,
#                 change le propriétaire, crée un fichier index.html si nécessaire,
#                 et redémarre Tomcat.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.1
# Date          : 2025-05-04
#==============================================================================
# Utilisation   : sudo ./deploy-war.sh <chemin_vers_war>
#
# Exemples      :
#   sudo ./deploy-war.sh /tmp/hello-world-dev.war
#==============================================================================
# Dépendances   :
#   - Tomcat    : Le serveur d'applications Tomcat doit être installé
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

# Vérifier si un argument a été fourni
if [ $# -ne 1 ]; then
  log_error "Usage: $0 <chemin_vers_war>"
fi

WAR_PATH=$1
WAR_NAME=$(basename $WAR_PATH)
APP_NAME=${WAR_NAME%.war}

log_info "Déploiement du fichier WAR: $WAR_PATH vers /opt/tomcat/webapps/$WAR_NAME"

# Vérifier si le fichier existe
if [ ! -f "$WAR_PATH" ]; then
  log_error "Le fichier $WAR_PATH n'existe pas"
fi

# Copier le fichier WAR dans webapps
sudo cp $WAR_PATH /opt/tomcat/webapps/$WAR_NAME

# Vérifier si la copie a réussi
if [ $? -ne 0 ]; then
  log_error "Échec de la copie du fichier WAR dans /opt/tomcat/webapps/"
fi

# Changer le propriétaire
sudo chown tomcat:tomcat /opt/tomcat/webapps/$WAR_NAME

# Vérifier si le changement de propriétaire a réussi
if [ $? -ne 0 ]; then
  log_error "Échec du changement de propriétaire du fichier WAR"
fi

# Attendre que Tomcat extraie le WAR
log_info "Attente de l'extraction du WAR par Tomcat..."
sleep 5

# Vérifier si le répertoire a été créé
if [ -d "/opt/tomcat/webapps/$APP_NAME" ]; then
  log_info "Répertoire $APP_NAME créé avec succès"

  # Vérifier si un fichier index.html ou index.jsp existe
  if [ ! -f "/opt/tomcat/webapps/$APP_NAME/index.html" ] && [ ! -f "/opt/tomcat/webapps/$APP_NAME/index.jsp" ]; then
    log_info "Aucun fichier index trouvé. Création d'un fichier index.html..."

    # Créer un fichier index.html
    sudo bash -c "cat > /opt/tomcat/webapps/$APP_NAME/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Hello World</title>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background-color: white;
            padding: 20px;
            border-radius: 5px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c3e50;
        }
        p {
            color: #34495e;
            line-height: 1.6;
        }
    </style>
</head>
<body>
    <div class=\"container\">
        <h1>Hello World from YourMedia!</h1>
        <p>This is a simple Hello World application deployed on Tomcat.</p>
        <p>Application: $APP_NAME</p>
        <p>Deployment time: $(date)</p>
    </div>
</body>
</html>
EOF"

    # Changer le propriétaire du fichier index.html
    sudo chown tomcat:tomcat /opt/tomcat/webapps/$APP_NAME/index.html

    # Définir les permissions correctes
    sudo chmod 644 /opt/tomcat/webapps/$APP_NAME/index.html

    log_info "Fichier index.html créé avec succès"
  else
    log_info "Fichier index trouvé, aucune action nécessaire"
  fi

  # Ajuster les permissions du répertoire déployé pour permettre l'accès
  log_info "Ajustement des permissions du répertoire déployé..."
  sudo chmod -R 755 /opt/tomcat/webapps/$APP_NAME
  sudo chown -R tomcat:tomcat /opt/tomcat/webapps/$APP_NAME
else
  log_info "Le répertoire $APP_NAME n'a pas encore été créé, Tomcat pourrait être en train de l'extraire"
fi

# Redémarrer Tomcat
log_info "Redémarrage de Tomcat..."
sudo systemctl restart tomcat

# Vérifier si le redémarrage a réussi
if [ $? -ne 0 ]; then
  log_error "Échec du redémarrage de Tomcat"
fi

# Attendre que Tomcat démarre
log_info "Attente du démarrage de Tomcat..."
sleep 10

# Vérifier si Tomcat est en cours d'exécution
if sudo systemctl is-active --quiet tomcat; then
  log_success "Tomcat a démarré avec succès"
else
  log_error "Échec du démarrage de Tomcat"
fi

# Vérifier si le port 8080 est ouvert
if sudo netstat -tuln | grep -q ":8080"; then
  log_success "Le port 8080 est ouvert"
else
  log_error "Le port 8080 n'est pas ouvert"
fi

log_success "Déploiement terminé avec succès"
log_info "L'application est accessible à l'adresse: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080/$APP_NAME/"
exit 0
