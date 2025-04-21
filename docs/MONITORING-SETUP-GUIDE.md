# Guide de configuration manuelle de Grafana et Prometheus

Ce guide vous aidera à configurer manuellement Grafana et Prometheus sur votre instance EC2 de monitoring.

## Prérequis

- Une instance EC2 de monitoring déployée via Terraform
- Accès SSH à l'instance EC2
- Les ports 3000 (Grafana) et 9090 (Prometheus) ouverts dans le groupe de sécurité

## Étapes de configuration

### 1. Se connecter à l'instance EC2 via SSH

```bash
ssh ec2-user@<IP_PUBLIQUE_DE_L_INSTANCE>
```

Remplacez `<IP_PUBLIQUE_DE_L_INSTANCE>` par l'adresse IP publique de votre instance EC2 de monitoring.

### 2. Installer Docker et Docker Compose

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

### 3. Créer les fichiers de configuration

#### 3.1. Créer le fichier docker-compose.yml

Vous pouvez utiliser le fichier docker-compose.yml préconfiguré dans le répertoire `scripts/ec2-monitoring/` :

```bash
# Copier le fichier docker-compose.yml depuis le bucket S3 ou le dépôt Git
aws s3 cp s3://<NOM_DU_BUCKET>/monitoring/docker-compose.yml /opt/monitoring/docker-compose.yml

# Ou si vous avez cloné le dépôt Git
cp /chemin/vers/scripts/ec2-monitoring/docker-compose.yml /opt/monitoring/docker-compose.yml
```

Le fichier docker-compose.yml contient la configuration pour Prometheus, Grafana, et d'autres exportateurs :

#### 3.2. Créer le fichier prometheus.yml

Vous pouvez utiliser le fichier prometheus.yml préconfiguré dans le répertoire `scripts/ec2-monitoring/` :

```bash
# Copier le fichier prometheus.yml depuis le bucket S3 ou le dépôt Git
aws s3 cp s3://<NOM_DU_BUCKET>/monitoring/prometheus.yml /opt/monitoring/prometheus.yml

# Ou si vous avez cloné le dépôt Git
cp /chemin/vers/scripts/ec2-monitoring/prometheus.yml /opt/monitoring/prometheus.yml
```

Le fichier prometheus.yml contient la configuration pour collecter les métriques de différentes sources, notamment :
- Prometheus lui-même
- Node Exporter (métriques système)
- MySQL Exporter (métriques de base de données)
- CloudWatch Exporter (métriques AWS)
- Application backend (via Spring Boot Actuator)

### 4. Démarrer les conteneurs

```bash
cd /opt/monitoring
docker-compose up -d
```

### 5. Vérifier que les conteneurs sont en cours d'exécution

```bash
docker ps
```

Vous devriez voir deux conteneurs en cours d'exécution : `prometheus` et `grafana`.

### 6. Accéder aux interfaces web

- **Prometheus** : http://<IP_PUBLIQUE_DE_L_INSTANCE>:9090
- **Grafana** : http://<IP_PUBLIQUE_DE_L_INSTANCE>:3000

Pour Grafana, utilisez les identifiants suivants :
- Nom d'utilisateur : `admin`
- Mot de passe : `admin`

Lors de la première connexion, Grafana vous demandera de changer le mot de passe.

## Dépannage

### Les conteneurs ne démarrent pas

Vérifiez les logs des conteneurs :

```bash
docker logs prometheus
docker logs grafana
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

## Configuration de Grafana

Une fois Grafana accessible, vous devrez configurer une source de données Prometheus :

1. Connectez-vous à Grafana
2. Allez dans Configuration > Data Sources
3. Cliquez sur "Add data source"
4. Sélectionnez "Prometheus"
5. Dans le champ URL, entrez `http://prometheus:9090`
6. Cliquez sur "Save & Test"

Vous pouvez maintenant créer des tableaux de bord pour visualiser vos métriques.
