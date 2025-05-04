#!/bin/bash
#==============================================================================
# Nom du script : deploy-war.sh
# Description   : Script simplifié pour déployer un fichier WAR dans Tomcat.
#                 Ce script copie le fichier WAR spécifié dans le répertoire webapps de Tomcat,
#                 change le propriétaire et redémarre Tomcat.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.1
# Date          : 2024-05-03
#==============================================================================
# Utilisation   : sudo ./deploy-war.sh <chemin_vers_war>
#
# Exemples      :
#   sudo ./deploy-war.sh /tmp/hello-world.war
#==============================================================================
# Dépendances   :
#   - Tomcat    : Le serveur d'applications Tomcat doit être installé
#==============================================================================
# Droits requis : Ce script doit être exécuté avec des privilèges sudo ou en tant que root.
#==============================================================================

# Vérifier si un argument a été fourni
if [ $# -ne 1 ]; then
  echo "Usage: $0 <chemin_vers_war>"
  exit 1
fi

WAR_PATH=$1
WAR_NAME=$(basename $WAR_PATH)
TARGET_NAME="hello-world.war"

echo "Déploiement du fichier WAR: $WAR_PATH vers /opt/tomcat/webapps/$TARGET_NAME"

# Vérifier si le fichier existe
if [ ! -f "$WAR_PATH" ]; then
  echo "ERREUR: Le fichier $WAR_PATH n'existe pas"
  exit 1
fi

# Copier le fichier WAR dans webapps
sudo cp $WAR_PATH /opt/tomcat/webapps/$TARGET_NAME

# Vérifier si la copie a réussi
if [ $? -ne 0 ]; then
  echo "ERREUR: Échec de la copie du fichier WAR dans /opt/tomcat/webapps/"
  exit 1
fi

# Changer le propriétaire
sudo chown tomcat:tomcat /opt/tomcat/webapps/$TARGET_NAME

# Vérifier si le changement de propriétaire a réussi
if [ $? -ne 0 ]; then
  echo "ERREUR: Échec du changement de propriétaire du fichier WAR"
  exit 1
fi

# Redémarrer Tomcat
sudo systemctl restart tomcat

# Vérifier si le redémarrage a réussi
if [ $? -ne 0 ]; then
  echo "ERREUR: Échec du redémarrage de Tomcat"
  exit 1
fi

echo "Déploiement terminé avec succès"
exit 0
