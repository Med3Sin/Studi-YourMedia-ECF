#!/bin/bash
# Script simplifié pour déployer un fichier WAR dans Tomcat

# Vérifier si un argument a été fourni
if [ $# -ne 1 ]; then
  echo "Usage: sudo $0 <chemin_vers_war>"
  exit 1
fi

WAR_PATH=$1
TARGET_NAME="yourmedia-backend.war"

echo "Déploiement du fichier WAR: $WAR_PATH vers /opt/tomcat/webapps/$TARGET_NAME"

# Vérifier si le fichier existe
if [ ! -f "$WAR_PATH" ]; then
  echo "ERREUR: Le fichier $WAR_PATH n'existe pas"
  exit 1
fi

# Vérifier si l'utilisateur a les droits sudo
if [ "$(id -u)" -ne 0 ]; then
  echo "ERREUR: Ce script doit être exécuté avec sudo"
  echo "Exemple: sudo $0 $WAR_PATH"
  exit 1
fi

# Copier le fichier WAR dans webapps et changer le propriétaire
cp "$WAR_PATH" /opt/tomcat/webapps/$TARGET_NAME && \
chown tomcat:tomcat /opt/tomcat/webapps/$TARGET_NAME && \
systemctl restart tomcat

# Vérifier si tout s'est bien passé
if [ $? -eq 0 ]; then
  echo "Déploiement terminé avec succès"
  echo "L'application sera accessible à l'adresse: http://$(hostname -I | awk '{print $1}'):8080/$TARGET_NAME"
else
  echo "ERREUR: Le déploiement a échoué"
  exit 1
fi
