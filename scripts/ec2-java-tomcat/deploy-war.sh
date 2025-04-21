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
