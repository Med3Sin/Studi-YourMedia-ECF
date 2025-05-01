# Guide de configuration de Grafana et Prometheus

Ce guide vous aidera à configurer Grafana, Prometheus et les exportateurs sur votre instance EC2 de monitoring. La configuration est automatisée via des scripts, mais ce guide explique également comment effectuer une configuration manuelle si nécessaire.

## Prérequis

- Une instance EC2 de monitoring déployée via Terraform
- Accès SSH à l'instance EC2
- Les ports 3000 (Grafana) et 9090 (Prometheus) ouverts dans le groupe de sécurité

## Configuration automatisée

L'instance EC2 de monitoring est configurée automatiquement lors de son déploiement via Terraform. Les scripts suivants sont exécutés dans l'ordre :

1. **init-monitoring.sh** : Initialise l'environnement et télécharge les scripts depuis GitHub
2. **setup-monitoring.sh** : Configure les services de monitoring (Prometheus, Grafana, etc.)
3. **container-health-check.sh** : Vérifie l'état des conteneurs et corrige automatiquement les problèmes courants

> **Note importante** : Depuis la version 2.0 du projet, les scripts sont téléchargés directement depuis GitHub au lieu d'être stockés dans un bucket S3. Pour plus de détails sur cette nouvelle approche, consultez le document [SCRIPTS-GITHUB-APPROACH.md](SCRIPTS-GITHUB-APPROACH.md).

### Vérification de l'installation automatisée

Pour vérifier que l'installation automatisée a réussi, connectez-vous à l'instance EC2 via SSH et exécutez :

```bash
ssh ec2-user@<IP_PUBLIQUE_DE_L_INSTANCE>
sudo docker ps
```

Vous devriez voir les conteneurs suivants en cours d'exécution :
- prometheus
- grafana

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
sudo mkdir -p /opt/monitoring/prometheus-data /opt/monitoring/grafana-data
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
sudo mkdir -p /opt/monitoring/prometheus-data /opt/monitoring/grafana-data
sudo chown -R ec2-user:ec2-user /opt/monitoring
```

**Important** : Après avoir exécuté la commande `sudo usermod`, déconnectez-vous et reconnectez-vous à l'instance pour que les changements de groupe prennent effet.

### 3. Configurer les limites système

```bash
# Configurer les limites de ressources pour l'utilisateur ec2-user
echo "ec2-user soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "ec2-user hard nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "ec2-user soft nproc 4096" | sudo tee -a /etc/security/limits.conf
echo "ec2-user hard nproc 4096" | sudo tee -a /etc/security/limits.conf
```



### 4. Créer les fichiers de configuration

#### 4.1. Créer le fichier docker-compose.yml

Vous pouvez télécharger le fichier docker-compose.yml préconfiguré directement depuis GitHub :

```bash
# Télécharger le fichier docker-compose.yml depuis GitHub
curl -L -o /opt/monitoring/docker-compose.yml "https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main/scripts/ec2-monitoring/docker-compose.yml"

# Ou si vous avez cloné le dépôt Git
cp /chemin/vers/scripts/ec2-monitoring/docker-compose.yml /opt/monitoring/docker-compose.yml
```

Le fichier docker-compose.yml contient la configuration pour Prometheus, Grafana, et d'autres exportateurs.

#### 4.2. Créer le fichier prometheus.yml

Vous pouvez télécharger le fichier prometheus.yml préconfiguré directement depuis GitHub :

```bash
# Télécharger le fichier prometheus.yml depuis GitHub
curl -L -o /opt/monitoring/prometheus.yml "https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main/scripts/config/prometheus/prometheus.yml"

# Ou si vous avez cloné le dépôt Git
cp /chemin/vers/scripts/config/prometheus/prometheus.yml /opt/monitoring/prometheus.yml
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

- mysql-exporter
- cloudwatch-exporter
- node-exporter

### 7. Accéder aux interfaces web

- **Prometheus** : http://<IP_PUBLIQUE_DE_L_INSTANCE>:9090
- **Grafana** : http://<IP_PUBLIQUE_DE_L_INSTANCE>:3000


Pour Grafana, utilisez les identifiants suivants :
- Nom d'utilisateur : `admin`
- Mot de passe : défini dans la variable d'environnement `GRAFANA_ADMIN_PASSWORD` (par défaut : `admin`)

Lors de la première connexion, Grafana vous demandera de changer le mot de passe.

## Dépannage

### Les conteneurs ne démarrent pas

Vérifiez les logs des conteneurs :

```bash
docker logs prometheus
docker logs grafana
docker logs mysql-exporter
```

### Problèmes de téléchargement depuis GitHub

Si vous rencontrez des erreurs 404 lors du téléchargement des scripts ou des fichiers de configuration depuis GitHub, assurez-vous d'utiliser l'option `-L` avec curl pour suivre les redirections HTTP :

```bash
# Incorrect
curl -s -o /opt/monitoring/file.yml "https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main/path/to/file.yml"

# Correct
curl -L -o /opt/monitoring/file.yml "https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main/path/to/file.yml"
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
