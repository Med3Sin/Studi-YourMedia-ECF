# Guide de configuration de Grafana, Prometheus et SonarQube

Ce guide vous aidera à configurer Grafana, Prometheus, SonarQube et les exportateurs sur votre instance EC2 de monitoring. La configuration est automatisée via des scripts, mais ce guide explique également comment effectuer une configuration manuelle si nécessaire.

## Prérequis

- Une instance EC2 de monitoring déployée via Terraform
- Accès SSH à l'instance EC2
- Les ports 3000 (Grafana) et 9090 (Prometheus) ouverts dans le groupe de sécurité

## Configuration automatisée

L'instance EC2 de monitoring est configurée automatiquement lors de son déploiement via Terraform. Les scripts suivants sont exécutés dans l'ordre :

1. **init-instance-env.sh** : Initialise l'environnement et télécharge les scripts depuis S3
2. **install-docker.sh** : Installe Docker et Docker Compose
3. **setup.sh** : Configure les services de monitoring (Prometheus, Grafana, SonarQube, etc.)
4. **check-containers.sh** : Vérifie l'état des conteneurs et corrige automatiquement les problèmes courants

### Vérification de l'installation automatisée

Pour vérifier que l'installation automatisée a réussi, connectez-vous à l'instance EC2 via SSH et exécutez :

```bash
ssh ec2-user@<IP_PUBLIQUE_DE_L_INSTANCE>
sudo docker ps
```

Vous devriez voir les conteneurs suivants en cours d'exécution :
- prometheus
- grafana
- sonarqube
- sonarqube-db
- mysql-exporter
- cloudwatch-exporter
- node-exporter

## Configuration manuelle (si nécessaire)

Si vous devez configurer manuellement l'instance EC2 de monitoring, suivez les étapes ci-dessous.

### 1. Se connecter à l'instance EC2 via SSH

```bash
ssh ec2-user@<IP_PUBLIQUE_DE_L_INSTANCE>
```

Remplacez `<IP_PUBLIQUE_DE_L_INSTANCE>` par l'adresse IP publique de votre instance EC2 de monitoring.

### 2. Installer Docker et Docker Compose

Pour Amazon Linux 2023 (version recommandée) :

```bash
# Mettre à jour les packages
sudo dnf update -y

# Installer Docker
sudo dnf install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# Installer Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Créer les répertoires pour les volumes
sudo mkdir -p /opt/monitoring/prometheus-data /opt/monitoring/grafana-data /opt/monitoring/sonarqube-data/{data,logs,extensions,db}
sudo chown -R ec2-user:ec2-user /opt/monitoring
```

Pour Amazon Linux 2 (ancienne version) :

```bash
# Mettre à jour les packages
sudo yum update -y

# Installer Docker
sudo amazon-linux-extras install docker -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# Installer Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Créer les répertoires pour les volumes
sudo mkdir -p /opt/monitoring/prometheus-data /opt/monitoring/grafana-data /opt/monitoring/sonarqube-data/{data,logs,extensions,db}
sudo chown -R ec2-user:ec2-user /opt/monitoring
```

**Important** : Après avoir exécuté la commande `sudo usermod`, déconnectez-vous et reconnectez-vous à l'instance pour que les changements de groupe prennent effet.

### 3. Configurer les prérequis système pour SonarQube

```bash
# Augmenter la limite de mmap count (nécessaire pour Elasticsearch)
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

# Augmenter la limite de fichiers ouverts
sudo sysctl -w fs.file-max=65536
echo "fs.file-max=65536" | sudo tee -a /etc/sysctl.conf

# Configurer les limites de ressources pour l'utilisateur ec2-user
echo "ec2-user soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "ec2-user hard nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "ec2-user soft nproc 4096" | sudo tee -a /etc/security/limits.conf
echo "ec2-user hard nproc 4096" | sudo tee -a /etc/security/limits.conf
```

### 4. Créer les fichiers de configuration

#### 4.1. Créer le fichier docker-compose.yml

Vous pouvez utiliser le fichier docker-compose.yml préconfiguré dans le répertoire `scripts/ec2-monitoring/` :

```bash
# Copier le fichier docker-compose.yml depuis le bucket S3 ou le dépôt Git
aws s3 cp s3://<NOM_DU_BUCKET>/scripts/ec2-monitoring/docker-compose.yml /opt/monitoring/docker-compose.yml

# Ou si vous avez cloné le dépôt Git
cp /chemin/vers/scripts/ec2-monitoring/docker-compose.yml /opt/monitoring/docker-compose.yml
```

Le fichier docker-compose.yml contient la configuration pour Prometheus, Grafana, et d'autres exportateurs :

#### 4.2. Créer le fichier prometheus.yml

Vous pouvez utiliser le fichier prometheus.yml préconfiguré dans le répertoire `scripts/ec2-monitoring/` :

```bash
# Copier le fichier prometheus.yml depuis le bucket S3 ou le dépôt Git
aws s3 cp s3://<NOM_DU_BUCKET>/scripts/ec2-monitoring/prometheus.yml /opt/monitoring/prometheus.yml

# Ou si vous avez cloné le dépôt Git
cp /chemin/vers/scripts/ec2-monitoring/prometheus.yml /opt/monitoring/prometheus.yml
```

Le fichier prometheus.yml contient la configuration pour collecter les métriques de différentes sources, notamment :
- Prometheus lui-même
- Node Exporter (métriques système)
- MySQL Exporter (métriques de base de données)
- CloudWatch Exporter (métriques AWS)
- Application backend (via Spring Boot Actuator)

### 5. Démarrer les conteneurs

```bash
cd /opt/monitoring
docker-compose up -d
```

### 6. Vérifier que les conteneurs sont en cours d'exécution

```bash
docker ps
```

Vous devriez voir les conteneurs suivants en cours d'exécution :
- prometheus
- grafana
- sonarqube
- sonarqube-db
- mysql-exporter
- cloudwatch-exporter
- node-exporter

### 7. Accéder aux interfaces web

- **Prometheus** : http://<IP_PUBLIQUE_DE_L_INSTANCE>:9090
- **Grafana** : http://<IP_PUBLIQUE_DE_L_INSTANCE>:3000
- **SonarQube** : http://<IP_PUBLIQUE_DE_L_INSTANCE>:9000

Pour Grafana, utilisez les identifiants suivants :
- Nom d'utilisateur : `admin`
- Mot de passe : défini dans la variable d'environnement `GRAFANA_ADMIN_PASSWORD` (par défaut : `admin`)

Pour SonarQube, utilisez les identifiants suivants :
- Nom d'utilisateur : `admin`
- Mot de passe : `admin`

Lors de la première connexion, Grafana et SonarQube vous demanderont de changer le mot de passe.

## Dépannage

### Les conteneurs ne démarrent pas

Vérifiez les logs des conteneurs :

```bash
docker logs prometheus
docker logs grafana
docker logs sonarqube
docker logs mysql-exporter
```

### Problèmes avec SonarQube

Si SonarQube ne démarre pas, vérifiez les logs et les prérequis système :

```bash
# Vérifier les logs
docker logs sonarqube

# Vérifier les limites système
sysctl -a | grep -E "vm.max_map_count|fs.file-max"

# Appliquer les prérequis système
sudo sysctl -w vm.max_map_count=262144
sudo sysctl -w fs.file-max=65536
```

### Problèmes avec MySQL Exporter

Si MySQL Exporter ne démarre pas, vérifiez les logs et la configuration de connexion :

```bash
# Vérifier les logs
docker logs mysql-exporter

# Vérifier les variables d'environnement
cat /opt/monitoring/env.sh | grep RDS

# Vérifier la connectivité à la base de données
telnet <RDS_HOST> <RDS_PORT>
```

### Problèmes de permission

Assurez-vous que les répertoires ont les bonnes permissions :

```bash
sudo chown -R ec2-user:ec2-user /opt/monitoring
sudo chown -R 1000:1000 /opt/monitoring/sonarqube-data/data
sudo chown -R 1000:1000 /opt/monitoring/sonarqube-data/logs
sudo chown -R 1000:1000 /opt/monitoring/sonarqube-data/extensions
sudo chown -R 999:999 /opt/monitoring/sonarqube-data/db
```

### Problèmes de réseau

Vérifiez que les ports sont ouverts dans le groupe de sécurité AWS :

1. Ouvrez la console AWS
2. Accédez à EC2 > Groupes de sécurité
3. Sélectionnez le groupe de sécurité associé à votre instance EC2 de monitoring
4. Vérifiez que les règles entrantes autorisent le trafic sur les ports 3000 et 9090

## Configuration des services

### Configuration de Grafana

Une fois Grafana accessible, vous devrez configurer une source de données Prometheus :

1. Connectez-vous à Grafana
2. Allez dans Configuration > Data Sources
3. Cliquez sur "Add data source"
4. Sélectionnez "Prometheus"
5. Dans le champ URL, entrez `http://prometheus:9090`
6. Cliquez sur "Save & Test"

Vous pouvez maintenant créer des tableaux de bord pour visualiser vos métriques.

### Configuration de SonarQube

Une fois SonarQube accessible, vous devrez configurer un projet pour l'analyse de code :

1. Connectez-vous à SonarQube
2. Allez dans Administration > Projects > Management
3. Cliquez sur "Create Project"
4. Entrez un nom et une clé pour votre projet (par exemple, "yourmedia-backend" et "yourmedia-backend")
5. Cliquez sur "Set Up"
6. Sélectionnez "Locally" pour l'analyse locale
7. Générez un token d'authentification
8. Suivez les instructions pour configurer l'analyse dans votre projet

### Configuration de MySQL Exporter

MySQL Exporter est configuré pour se connecter à votre base de données RDS. Si vous devez modifier la configuration :

1. Modifiez le fichier docker-compose.yml :
   ```bash
   sudo vi /opt/monitoring/docker-compose.yml
   ```
2. Mettez à jour la section mysql-exporter avec les informations de connexion correctes
3. Redémarrez le conteneur :
   ```bash
   cd /opt/monitoring
   sudo docker-compose restart mysql-exporter
   ```

## Vérification et correction automatique des conteneurs

Un script de vérification et de correction automatique des conteneurs est configuré pour s'exécuter périodiquement via une tâche cron. Ce script vérifie l'état des conteneurs et les redémarre si nécessaire.

### Exécution manuelle du script

Vous pouvez exécuter manuellement le script de vérification :

```bash
sudo /opt/monitoring/check-containers.sh
```

### Configuration de la tâche cron

Le script est configuré pour s'exécuter toutes les 15 minutes via une tâche cron. Pour vérifier la configuration :

```bash
sudo crontab -l
```

Vous devriez voir une ligne similaire à celle-ci :

```
*/15 * * * * /usr/bin/sudo /opt/monitoring/check-containers.sh >> /var/log/container-check.log 2>&1
```

### Vérification des logs

Vous pouvez consulter les logs du script de vérification :

```bash
sudo tail -f /var/log/container-check.log
```
