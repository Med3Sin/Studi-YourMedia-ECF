Configuration de Promtail pour la Collecte de Logs d'Application Java/Tomcat sur une Instance EC2 Dédiée
Objectif

Ce document détaille les étapes pour installer et configurer Promtail sur une instance EC2 Amazon Linux 2023 (appelée "Serveur Applicatif") hébergeant une application Java/Tomcat. Promtail collectera les logs de Tomcat (catalina.out et logs d'accès) et les enverra à une instance Loki centrale hébergée sur une autre instance EC2 (appelée "Serveur de Monitoring").
Prérequis

    Serveur Applicatif (EC2_App) :

        Instance EC2 avec Amazon Linux 2023.

        Application Java déployée sur Tomcat (ex: hello-world-dev).

        Chemins des logs Tomcat connus (ex: /opt/tomcat/logs/).

        Accès SSH à cette instance.

        Nom d'hôte ou identifiant pour cette instance (ex: yourmedia-dev-app-server, IP: 10.0.1.48 dans notre exemple).

    Serveur de Monitoring (EC2_Monitoring) :

        Instance EC2 hébergeant la stack de monitoring (Prometheus, Loki, Grafana).

        Loki en cours d'exécution et écoutant sur le port 3100 (IP: 10.0.1.222 dans notre exemple).

    Connectivité Réseau :

        Le groupe de sécurité du Serveur de Monitoring (10.0.1.222) doit autoriser les connexions TCP entrantes sur le port 3100 depuis l'adresse IP privée du Serveur Applicatif (10.0.1.48).

.
3. Réseau AWS :
* Le groupe de sécurité du Serveur de Monitoring (yourmedia-dev-monitoring-sg) doit autoriser les connexions TCP entrantes sur le port 3100 depuis l'adresse IP du Serveur Applicatif (10.0.1.48).
Étapes d'Installation et de Configuration de Promtail sur le Serveur Applicatif (yourmedia-dev-app-server, IP 10.0.1.48)
1. Préparation du Système

Connectez-vous en SSH à votre serveur applicatif.

a. Mettez à jour les paquets du système :
bash sudo dnf update -y

b. Installez unzip (s'il n'est pas déjà présent) :
bash sudo dnf install unzip -y
2. Téléchargement et Installation de Promtail

a. Téléchargez la dernière version stable de Promtail.
* Vérifiez sur https://github.com/grafana/loki/releases la dernière version. L'exemple ci-dessous utilise la v3.5.1. Ajustez si une version plus récente est disponible.
* Pour une instance Amazon Linux 2023 x86_64, utilisez promtail-linux-amd64.zip.
bash wget https://github.com/grafana/loki/releases/download/v3.5.1/promtail-linux-amd64.zip

b. Décompressez l'archive et installez le binaire :
bash unzip promtail-linux-amd64.zip sudo mv promtail-linux-amd64 /usr/local/bin/promtail sudo chmod +x /usr/local/bin/promtail

c. Vérifiez l'installation :
bash promtail --version
Vous devriez voir la version s'afficher (ex: promtail, version 3.5.1 ...).
3. Configuration de Promtail

a. Créez le répertoire de configuration :
bash sudo mkdir -p /etc/promtail

b. Créez et éditez le fichier de configuration config-promtail.yml :
bash sudo nano /etc/promtail/config-promtail.yml

c. Collez le contenu suivant dans le fichier. Il est configuré pour votre environnement :
```yaml
server:
http_listen_port: 9080 # Port local pour l'API HTTP de Promtail (optionnel pour ce flux)
grpc_listen_port: 0

      
positions:
  filename: /var/lib/promtail/positions.yaml # Fichier pour suivre la progression de lecture des logs

clients:
  - url: http://10.0.1.222:3100/loki/api/v1/push # URL de votre serveur Loki

scrape_configs:
  - job_name: tomcat_helloworld_app # Job pour les logs principaux de l'application
    static_configs:
      - targets:
          - localhost
        labels:
          job: tomcat_app                 # Label principal pour ce type de logs
          application: hello-world-dev    # Nom de votre application
          env: development                # Environnement (ajustez si besoin)
          instance: yourmedia-dev-app-server # Nom de votre serveur applicatif
          __path__: /opt/tomcat/logs/catalina.out # Chemin vers catalina.out

  - job_name: tomcat_access_logs # Job pour les logs d'accès de Tomcat
    static_configs:
      - targets:
          - localhost
        labels:
          job: tomcat_access              # Label principal pour les logs d'accès
          application: hello-world-dev    # Nom de votre application
          env---

    

IGNORE_WHEN_COPYING_START
Use code with caution.
IGNORE_WHEN_COPYING_END
Installation et Configuration de Promtail sur le Serveur Applicatif (EC2_App)

Les commandes suivantes sont à exécuter sur votre Serveur Applicatif Java/Tomcat (ex: yourmedia-dev-app-server, IP 10.0.1.48).

    Préparation du Système :
    Mettez à jour les paquets et installez unzip.

          
    sudo dnf update -y
    sudo dnf install unzip -y

        

    IGNORE_WHEN_COPYING_START

Use code with caution. Bash
IGNORE_WHEN_COPYING_END

Téléchargement de Promtail :

    Vérifiez la dernière version stable de Promtail sur GitHub.

    Adaptez la version et l'architecture (amd64 pour la plupart des EC2, arm64 pour Graviton) si nécessaire.

      
# Exemple avec la version v3.5.1 (amd64)
wget https://github.com/grafana/loki/releases/download/v3.5.1/promtail-linux-amd64.zip

    

IGNORE_WHEN_COPYING_START
Use code with caution. Bash
IGNORE_WHEN_COPYING_END

Installation de Promtail :
Décompressez l'archive, déplacez le binaire et rendez-le exécutable.

      
unzip promtail-linux-amd64.zip
sudo mv promtail-linux-amd64 /usr/local/bin/promtail
sudo chmod +x /usr/local/bin/promtail

    

IGNORE_WHEN_COPYING_START
Use code with caution. Bash
IGNORE_WHEN_COPYING_END

Vérification de l'Installation :

      
promtail --version

    

IGNORE_WHEN_COPYING_START
Use code with caution. Bash
IGNORE_WHEN_COPYING_END

Cela devrait afficher la version installée (ex: promtail, version 3.5.1 ...).

Création des Répertoires Nécessaires :
Pour la configuration et le fichier de position (qui permet à Promtail de se souvenir où il s'est arrêté de lire).

      
sudo mkdir -p /etc/promtail
sudo mkdir -p /var/lib/promtail

    

IGNORE_WHEN_COPYING_START
Use code with caution. Bash
IGNORE_WHEN_COPYING_END

Configuration de Promtail (/etc/promtail/config-promtail.yml) :
Créez le fichier de configuration.

      
sudo nano /etc/promtail/config-promtail.yml

    

IGNORE_WHEN_COPYING_START
Use code with caution. Bash
IGNORE_WHEN_COPYING_END

Collez le contenu suivant, adapté à notre cas d'usage :

      
server:
  http_listen_port: 9080 # Port local pour l'API HTTP de Promtail (non exposé publiquement)
  grpc_listen_port: 0    # Généralement pas nécessaire pour un simple agent

positions:
  filename: /var/lib/promtail/positions.yaml # Chemin pour le fichier de positions

clients:
  - url: http://10.0.1.222:3100/loki/api/v1/push # URL de votre serveur Loki central

scrape_configs:
  - job_name: tomcat_helloworld_app # Nom du job pour les logs applicatifs
    static_configs:
      - targets:
          - localhost # Les logs sont sur la machine locale
        labels:
          job: tomcat_app                 # Label principal pour ce type de log
          application: hello-world-dev    # Nom de votre application
          env: development                # Environnement (dev, staging, prod)
          instance: yourmedia-dev-app-server # Nom de l'instance source
          __path__: /opt/tomcat/logs/catalina.out # Chemin vers catalina.out

  - job_name: tomcat_access_logs # Nom du job pour les logs d'accès
    static_configs:
      - targets:
          - localhost
        labels:
          job: tomcat_access              # Label principal pour ce type de log
          application: hello-world-dev
          env: development
          instance: yourmedia-dev-app-server
          __path__: /opt/tomcat/logs/localhost_access_log.*.txt # Cible les logs d'accès (y compris rotatés)

    

IGNORE_WHEN_COPYING_START
Use code with caution. Yaml
IGNORE_WHEN_COPYING_END

Sauvegardez (Ctrl+X, Y, Entrée).

Création du Service Systemd (/etc/systemd/system/promtail.service) :
Pour gérer Promtail comme un service.

      
sudo nano /etc/systemd/system/promtail.service

    

IGNORE_WHEN_COPYING_START
Use code with caution. Bash
IGNORE_WHEN_COPYING_END

Collez le contenu suivant :

      
[Unit]
Description=Promtail Loki Log Shipper
Wants=network-online.target
After=network-online.target

[Service]
User=root # Exécute en tant que root pour lire les logs de Tomcat
Group=root
Type=simple
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/config-promtail.yml
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target

    

IGNORE_WHEN_COPYING_START
Use code with caution. Ini
IGNORE_WHEN_COPYING_END

Sauvegardez (Ctrl+X, Y, Entrée).

Démarrage et Activation du Service Promtail :

      
sudo systemctl daemon-reload
sudo systemctl enable promtail
sudo systemctl start promtail

    

IGNORE_WHEN_COPYING_START

    Use code with caution. Bash
    IGNORE_WHEN_COPYING_END

Vérification et Test

    Vérifier le Statut du Service Promtail (sur EC2_App) :

          
    sudo systemctl status promtail

        

    IGNORE_WHEN_COPYING_START

Use code with caution. Bash
IGNORE_WHEN_COPYING_END

Assurez-vous qu'il est active (running).

Consulter les Logs de Promtail (sur EC2_App) :

      
sudo journalctl -u promtail -f -n 100

    

IGNORE_WHEN_COPYING_START
Use code with caution. Bash
IGNORE_WHEN_COPYING_END

Recherchez :

    La confirmation du chargement de la configuration.

    Des lignes indiquant que Promtail suit (tailing) les fichiers /opt/tomcat/logs/catalina.out et /opt/tomcat/logs/localhost_access_log.*.txt.

    L'absence d'erreurs de type context deadline exceeded lors de l'envoi à 10.0.1.222:3100.

Test de Connectivité Réseau (depuis EC2_App, si nécessaire) :
Si: development # Environnement
instance: yourmedia-dev-app-server # Nom de votre serveur applicatif
path: /opt/tomcat/logs/localhost_access_log.*.txt # Chemin vers les logs d'accès (inclut la rotation)

      
Sauvegardez (`Ctrl+X`, puis `Y`, puis `Entrée`).

    

IGNORE_WHEN_COPYING_START

    Use code with caution.
    IGNORE_WHEN_COPYING_END

d. Créez le répertoire pour le fichier de positions :
bash sudo mkdir -p /var/lib/promtail
4. Création du Service Systemd pour Promtail

a. Créez et éditez le fichier de service promtail.service :
bash sudo nano /etc/systemd/system/promtail.service

b. Collez le contenu suivant. Le service tournera en tant que root pour assurer l'accès aux logs de Tomcat.
```ini
[Unit]
Description=Promtail Loki Log Shipper
Wants=network-online.target
After=network-online.target

      
[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/config-promtail.yml
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
```
Sauvegardez (`Ctrl+X`, puis `Y`, puis `Entrée`).

    

IGNORE_WHEN_COPYING_START
Use code with caution.
IGNORE_WHEN_COPYING_END
5. Démarrage et Vérification du Service Promtail

a. Rechargez la configuration systemd, activez et démarrez Promtail :
bash sudo systemctl daemon-reload sudo systemctl enable promtail sudo systemctl start promtail

b. Vérifiez le statut du service :
bash sudo systemctl status promtail
Il devrait être active (running).

c. Consultez les logs de Promtail pour vérifier son bon fonctionnement et l'absence d'erreurs :
bash sudo journalctl -u promtail -f -n 100
Recherchez :
* Confirmation du chargement de la configuration.
* Messages indiquant que les fichiers /opt/tomcat/logs/catalina.out et /opt/tomcat/logs/localhost_access_log.*.txt sont surveillés ("tail routine: started").
* Absence d'erreurs de connexion à Loki (pas de "context deadline exceeded" si la configuration réseau est correcte).
Configuration du Pare-feu/Groupe de Sécurité sur le Serveur de Monitoring (10.0.1.222)

Assurez-vous que le groupe de sécurité AWS (yourmedia-dev-monitoring-sg) associé à votre instance de monitoring (10.0.1.222) autorise le trafic entrant sur le port 3100 (TCP) depuis l'adresse IP de votre serveur applicatif (10.0.1.48).

Règle entrante requise pour yourmedia-dev-monitoring-sg :

    Type : TCP personnalisé (ou "Custom TCP")

    Protocole : TCP

    Plage de ports : 3100

    Source : 10.0.1.48/32 (pour autoriser uniquement votre serveur applicatif)

    Description (optionnel) : Allow Loki access from App Server (yourmedia-dev-app-server)

Vérification de la Réception des Logs dans Grafana

    Test de connectivité (depuis le Serveur Applicatif 10.0.1.48) :

        Installez telnet ou nmap-ncat si nécessaire :

              
        sudo dnf install telnet -y
        # ou
        sudo dnf install nmap-ncat -y

            

        IGNORE_WHEN_COPYING_START

Use code with caution. Bash
IGNORE_WHEN_COPYING_END

Testez la connexion à Loki :

      
telnet 10.0.1.222 3100
# ou
nc -zv 10.0.1.222 3100

    

IGNORE_WHEN_COPYING_START

    Use code with caution. Bash
    IGNORE_WHEN_COPYING_END

    Une connexion réussie est attendue.

Accédez à Grafana sur votre serveur de monitoring.

Allez dans la section Explore.

Sélectionnez votre source de données Loki.

Utilisez le "Log browser" ou écrivez des requêtes LogQL pour trouver vos logs :

    Pour les logs de catalina.out :

          
    {job="tomcat_app", instance="yourmedia-dev-app-server"}

        

    IGNORE_WHEN_COPYING_START

Use code with caution. Logql
IGNORE_WHEN_COPYING_END

Pour les logs d'accès :

      
{job="tomcat_access", instance="yourmedia-dev-app-server"}

    

IGNORE_WHEN_COPYING_START
Use code with caution. Logql
IGNORE_WHEN_COPYING_END

Pour rechercher des erreurs dans catalina.out :

      
{job="tomcat_app", instance="yourmedia-dev-app-server"} |= "ERROR"

    

IGNORE_WHEN_COPYING_START

        Use code with caution. Logql
        IGNORE_WHEN_COPYING_END

    Générez du trafic sur votre application hello-world-dev pour voir apparaître de nouveaux logs.

Dépannage

    Logs de Promtail (Serveur Applicatif) : sudo journalctl -u promtail -f

        Vérifiez les erreurs de permission, les erreurs de configuration, les problèmes de connexion à Loki.

    Logs de Loki (Serveur de Monitoring) : Si Loki tourne en Docker : sudo docker logs <nom_conteneur_loki>

        Vérifiez si Loki reçoit des données ou signale des erreurs.

    Groupes de sécurité AWS et Network ACLs : Assurez-vous qu'ils autorisent le trafic sur le port 3100 entre les deux instances.
