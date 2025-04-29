# Monitoring

## Description

Le système de monitoring de YourMedia est basé sur Prometheus et Grafana, déployés sur une instance EC2 dédiée. Il permet de surveiller les performances et la disponibilité des différentes composantes de l'infrastructure.

## Architecture

Le système de monitoring est déployé sur une instance EC2 avec les caractéristiques suivantes :
- Type d'instance : t2.micro (1 vCPU, 1 Go de RAM)
- Système d'exploitation : Amazon Linux 2023
- Conteneurs Docker : Prometheus, Grafana, Node Exporter, CloudWatch Exporter, MySQL Exporter
- Volume EBS : 20 Go (gp3)

## Composants

### Prometheus

Prometheus est un système de surveillance et d'alerte open-source qui collecte et stocke des métriques dans une base de données temporelle. Il est configuré pour scraper les métriques des différentes composantes de l'infrastructure.

### Grafana

Grafana est une plateforme d'analyse et de visualisation de données qui permet de créer des tableaux de bord interactifs. Il est configuré pour utiliser Prometheus comme source de données.

### Node Exporter

Node Exporter est un exportateur Prometheus qui collecte des métriques système sur l'instance EC2 (CPU, mémoire, disque, réseau, etc.).

### CloudWatch Exporter

CloudWatch Exporter est un exportateur Prometheus qui collecte des métriques AWS CloudWatch (S3, RDS, EC2, etc.).

### MySQL Exporter

MySQL Exporter est un exportateur Prometheus qui collecte des métriques MySQL depuis la base de données RDS.

## Déploiement

Le déploiement du système de monitoring est géré par Terraform via le module `ec2-monitoring`. Ce module crée l'instance EC2, configure les groupes de sécurité, et installe les conteneurs Docker.

### Prérequis

- Un VPC avec au moins un sous-réseau public
- Une paire de clés SSH pour l'accès à l'instance
- Un bucket S3 pour stocker les scripts de configuration

### Variables Terraform

Les principales variables du module `ec2-monitoring` sont :

| Variable | Description | Valeur par défaut |
|----------|-------------|------------------|
| `project_name` | Nom du projet | - |
| `environment` | Environnement (dev, pre-prod, prod) | `dev` |
| `instance_type` | Type d'instance EC2 | `t2.micro` |
| `root_volume_size` | Taille du volume racine en Go | `20` |
| `grafana_admin_password` | Mot de passe administrateur Grafana | `admin` |

## Accès aux interfaces

### Grafana

Grafana est accessible à l'adresse suivante :
```
http://<IP_PUBLIQUE_INSTANCE>:3000
```

Les identifiants par défaut sont :
- Utilisateur : `admin`
- Mot de passe : défini par la variable `grafana_admin_password`

### Prometheus

Prometheus est accessible à l'adresse suivante :
```
http://<IP_PUBLIQUE_INSTANCE>:9090
```

## Configuration

### Configuration de Prometheus

Prometheus est configuré pour scraper les métriques des cibles suivantes :
- Prometheus lui-même
- Node Exporter (métriques système)
- CloudWatch Exporter (métriques AWS)
- MySQL Exporter (métriques RDS)
- Instance EC2 Java/Tomcat

### Configuration de Grafana

Grafana est configuré avec les paramètres suivants :
- Source de données Prometheus
- Tableaux de bord prédéfinis pour les métriques système, AWS et MySQL
- Authentification anonyme activée en mode lecture seule

## Alertes

Le système de monitoring est configuré avec les alertes suivantes :

### Alertes de conteneurs

- ContainerDown : Un conteneur est arrêté depuis plus d'une minute
- ContainerHighCPU : Un conteneur utilise plus de 80% de CPU pendant plus de 5 minutes
- ContainerHighMemory : Un conteneur utilise plus de 80% de mémoire pendant plus de 5 minutes
- ContainerHighRestarts : Un conteneur a redémarré plus de 3 fois en 15 minutes

### Alertes système

- HighCPULoad : La charge CPU est supérieure à 80% pendant plus de 5 minutes
- HighMemoryUsage : L'utilisation de la mémoire est supérieure à 80% pendant plus de 5 minutes
- HighDiskUsage : L'utilisation du disque est supérieure à 80% pendant plus de 5 minutes
- InstanceDown : Une instance EC2 est arrêtée

### Alertes RDS

- RDSHighCPU : La charge CPU de RDS est supérieure à 80% pendant plus de 5 minutes
- RDSHighMemory : L'utilisation de la mémoire de RDS est supérieure à 80% pendant plus de 5 minutes
- RDSHighDiskUsage : L'utilisation du disque de RDS est supérieure à 80% pendant plus de 5 minutes
- RDSHighConnections : Le nombre de connexions à RDS est supérieur à 80% de la limite pendant plus de 5 minutes

## Sécurité

L'instance de monitoring est sécurisée avec les mesures suivantes :
- Groupe de sécurité dédié qui limite l'accès aux ports 22 (SSH), 3000 (Grafana) et 9090 (Prometheus)
- Accès SSH limité aux adresses IP autorisées
- Volumes EBS chiffrés

## Maintenance

### Sauvegarde

Pour sauvegarder le système de monitoring, vous devez sauvegarder :
1. Le répertoire `/opt/monitoring/prometheus-data`
2. Le répertoire `/opt/monitoring/grafana-data`
3. Les fichiers de configuration dans `/opt/monitoring`

### Mise à jour

Pour mettre à jour les conteneurs Docker :
```bash
cd /opt/monitoring
docker-compose pull
docker-compose up -d
```

## Dépannage

### Problèmes courants

1. **Les conteneurs ne démarrent pas**
   - Vérifiez les logs Docker : `docker logs <NOM_CONTENEUR>`
   - Vérifiez l'état des conteneurs : `docker ps -a`

2. **Prometheus ne collecte pas de métriques**
   - Vérifiez la configuration de Prometheus : `/opt/monitoring/prometheus.yml`
   - Vérifiez l'état des cibles dans l'interface Prometheus : `http://<IP_PUBLIQUE_INSTANCE>:9090/targets`

3. **Grafana n'affiche pas de données**
   - Vérifiez la configuration de la source de données Prometheus
   - Vérifiez que Prometheus collecte bien les métriques
