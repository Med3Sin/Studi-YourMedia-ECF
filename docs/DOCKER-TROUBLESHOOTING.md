# Guide de dépannage pour l'installation de Docker

Ce document fournit des instructions pour résoudre les problèmes courants liés à l'installation de Docker sur les instances EC2 du projet YourMedia.

## Problèmes courants

### 1. Docker ne s'installe pas sur l'instance de monitoring

Si Docker ne s'installe pas correctement sur l'instance EC2 de monitoring, plusieurs causes sont possibles :

#### Problème : Version d'Amazon Linux non prise en charge

**Symptômes** : L'installation échoue avec des erreurs liées à `amazon-linux-extras`.

**Solution** :
1. Vérifiez la version d'Amazon Linux :
   ```bash
   cat /etc/os-release
   ```

2. Utilisez le script d'installation amélioré :
   ```bash
   sudo /opt/monitoring/install-docker.sh
   ```

3. Si le script n'est pas disponible, installez Docker manuellement selon la version d'Amazon Linux :

   **Pour Amazon Linux 2** :
   ```bash
   sudo amazon-linux-extras install docker -y
   sudo systemctl start docker
   sudo systemctl enable docker
   sudo usermod -aG docker ec2-user
   ```

   **Pour Amazon Linux 2023** :
   ```bash
   # Méthode recommandée (utilisant le package natif)
   sudo dnf install -y docker
   sudo systemctl start docker
   sudo systemctl enable docker
   sudo usermod -aG docker ec2-user

   # Méthode alternative (si la méthode recommandée échoue)
   sudo yum install -y yum-utils
   sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
   sudo yum install -y docker-ce docker-ce-cli containerd.io
   sudo systemctl start docker
   sudo systemctl enable docker
   sudo usermod -aG docker ec2-user
   ```

#### Problème : Dépendances manquantes

**Symptômes** : L'installation échoue avec des erreurs de dépendances.

**Solution** :
1. Mettez à jour le système et installez les dépendances requises :
   ```bash
   sudo yum update -y
   sudo yum install -y yum-utils device-mapper-persistent-data lvm2
   ```

2. Réessayez l'installation de Docker.

#### Problème : Problèmes de réseau

**Symptômes** : L'installation échoue avec des erreurs de connexion ou de téléchargement.

**Solution** :
1. Vérifiez la connectivité réseau :
   ```bash
   ping -c 4 google.com
   ```

2. Vérifiez que les dépôts sont accessibles :
   ```bash
   sudo yum repolist
   ```

3. Si vous êtes derrière un proxy, configurez-le pour yum et Docker.

### 2. Docker est installé mais ne démarre pas

**Symptômes** : Docker est installé mais le service ne démarre pas.

**Solution** :
1. Vérifiez le statut du service Docker :
   ```bash
   sudo systemctl status docker
   ```

2. Consultez les journaux pour identifier les erreurs :
   ```bash
   sudo journalctl -u docker
   ```

3. Redémarrez le service Docker :
   ```bash
   sudo systemctl restart docker
   ```

4. Si le problème persiste, réinstallez Docker :
   ```bash
   sudo yum remove docker docker-common docker-selinux docker-engine
   sudo rm -rf /var/lib/docker
   sudo /opt/monitoring/install-docker.sh
   ```

### 3. Docker Compose n'est pas installé ou ne fonctionne pas

**Symptômes** : La commande `docker-compose` n'est pas trouvée ou génère des erreurs.

**Solution** :
1. Installez Docker Compose manuellement :
   ```bash
   sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
   ```

2. Vérifiez l'installation :
   ```bash
   docker-compose --version
   ```

### 4. Problèmes de permissions

**Symptômes** : Erreurs "Permission denied" lors de l'utilisation de Docker.

**Solution** :
1. Ajoutez l'utilisateur au groupe Docker :
   ```bash
   sudo usermod -aG docker ec2-user
   ```

2. Déconnectez-vous et reconnectez-vous, ou exécutez :
   ```bash
   newgrp docker
   ```

3. Vérifiez que l'utilisateur appartient au groupe Docker :
   ```bash
   groups
   ```

## Vérification de l'installation

Pour vérifier que Docker est correctement installé et fonctionne :

1. Vérifiez la version de Docker :
   ```bash
   docker --version
   ```

2. Exécutez un conteneur de test :
   ```bash
   docker run --rm hello-world
   ```

3. Vérifiez que Docker Compose est installé :
   ```bash
   docker-compose --version
   ```

## Problèmes spécifiques aux conteneurs

### 1. SonarQube ne démarre pas (erreur 137)

**Symptômes** : Le conteneur SonarQube redémarre constamment avec le code d'erreur 137 (Out Of Memory).

**Solution** :
1. Vérifiez les logs du conteneur :
   ```bash
   docker logs sonarqube
   ```

2. Vérifiez la configuration système pour Elasticsearch :
   ```bash
   sysctl -n vm.max_map_count
   ```

3. Augmentez la limite de mmap count :
   ```bash
   sudo sysctl -w vm.max_map_count=262144
   echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
   ```

4. Limitez la mémoire utilisée par Elasticsearch dans le fichier docker-compose.yml :
   ```yaml
   environment:
     - SONAR_ES_JAVA_OPTS=-Xms512m -Xmx512m
   ```

5. Redémarrez le conteneur :
   ```bash
   cd /opt/monitoring
   docker-compose restart sonarqube
   ```

### 2. MySQL Exporter ne démarre pas

**Symptômes** : Le conteneur MySQL Exporter redémarre constamment avec des erreurs de configuration.

**Solution** :
1. Vérifiez les logs du conteneur :
   ```bash
   docker logs mysql-exporter
   ```

2. Vérifiez que les variables d'environnement RDS sont correctement définies :
   ```bash
   cat /opt/monitoring/env.sh | grep RDS
   ```

3. Créez manuellement un fichier .my.cnf :
   ```bash
   cat > /tmp/.my.cnf << EOF
   [client]
   user=<RDS_USERNAME>
   password=<RDS_PASSWORD>
   host=<RDS_HOST>
   port=<RDS_PORT>
   EOF
   chmod 600 /tmp/.my.cnf
   ```

4. Modifiez la configuration dans docker-compose.yml :
   ```yaml
   mysql-exporter:
     environment:
       - DATA_SOURCE_NAME=<RDS_USERNAME>:<RDS_PASSWORD>@tcp(<RDS_HOST>:<RDS_PORT>)/
   ```

5. Redémarrez le conteneur :
   ```bash
   cd /opt/monitoring
   docker-compose restart mysql-exporter
   ```

## Journaux et diagnostics

Pour collecter des informations de diagnostic :

1. Vérifiez les journaux Docker :
   ```bash
   sudo journalctl -u docker
   ```

2. Vérifiez les journaux d'installation :
   ```bash
   cat /var/log/docker-install.log
   ```

3. Vérifiez les journaux des conteneurs :
   ```bash
   docker logs <nom_du_conteneur>
   ```

4. Vérifiez l'état du système :
   ```bash
   sudo systemctl status
   ```

5. Vérifiez l'espace disque disponible :
   ```bash
   df -h
   ```

6. Vérifiez l'utilisation de la mémoire :
   ```bash
   free -h
   ```

7. Vérifiez les logs du script de vérification automatique :
   ```bash
   sudo tail -f /var/log/container-check.log
   ```

## Réinstallation complète

Si tous les autres dépannages échouent, effectuez une réinstallation complète :

1. Arrêtez tous les conteneurs en cours d'exécution :
   ```bash
   docker stop $(docker ps -aq)
   ```

2. Supprimez tous les conteneurs, images, volumes et réseaux :
   ```bash
   docker system prune -af --volumes
   ```

3. Désinstallez Docker :
   ```bash
   sudo yum remove -y docker docker-common docker-selinux docker-engine docker-ce docker-ce-cli containerd.io
   sudo rm -rf /var/lib/docker
   sudo rm -rf /etc/docker
   ```

4. Réinstallez Docker avec le script amélioré :
   ```bash
   sudo /opt/monitoring/install-docker.sh
   ```

## Ressources supplémentaires

- [Documentation officielle de Docker pour CentOS](https://docs.docker.com/engine/install/centos/)
- [Documentation officielle de Docker Compose](https://docs.docker.com/compose/install/)
- [Guide d'installation de Docker sur Amazon Linux 2](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/docker-basics.html)
- [Guide d'installation de Docker sur Amazon Linux 2023](https://docs.aws.amazon.com/linux/al2023/ug/docker.html)
