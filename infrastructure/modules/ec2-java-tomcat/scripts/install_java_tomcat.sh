#!/bin/bash -xe
# Script d'installation pour Java (Amazon Corretto 11) et Tomcat 9 sur Amazon Linux 2
# Exécuté en tant que root via user_data

# Rediriger stdout et stderr vers un fichier log pour le débogage
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "--- Mise à jour des paquets ---"
sudo yum update -y

echo "--- Installation de Java (Amazon Corretto 11) ---"
sudo amazon-linux-extras enable corretto8
sudo yum install -y java-11-amazon-corretto-devel

# Vérifier l'installation de Java
java -version

echo "--- Création de l'utilisateur et groupe Tomcat ---"
sudo groupadd tomcat
sudo useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat

echo "--- Téléchargement et Extraction de Tomcat 9 ---"
# La version de Tomcat est passée via la variable TOMCAT_VERSION depuis le template Terraform
# Si non définie, utiliser une valeur par défaut
TOMCAT_VERSION="${TOMCAT_VERSION}"
TOMCAT_URL="https://dlcdn.apache.org/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"

cd /tmp
wget $TOMCAT_URL

sudo mkdir /opt/tomcat
sudo tar xzvf apache-tomcat-${TOMCAT_VERSION}.tar.gz -C /opt/tomcat --strip-components=1

echo "--- Configuration des Permissions Tomcat ---"
cd /opt/tomcat
sudo chgrp -R tomcat /opt/tomcat
sudo chmod -R g+r conf
sudo chmod g+x conf
sudo chown -R tomcat webapps/ work/ temp/ logs/

echo "--- Création du fichier de service Systemd pour Tomcat ---"
sudo bash -c 'cat > /etc/systemd/system/tomcat.service' << EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

Environment=JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto
Environment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat
Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC'
Environment='JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom'

ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

User=tomcat
Group=tomcat
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "--- Rechargement de Systemd et Démarrage de Tomcat ---"
sudo systemctl daemon-reload
sudo systemctl start tomcat
sudo systemctl enable tomcat # Activer le démarrage automatique au boot

# Vérifier le statut de Tomcat (optionnel, pour le log)
sudo systemctl status tomcat

echo "--- Installation terminée ---"
