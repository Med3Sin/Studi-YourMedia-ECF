# Monitoring

## Description

Le système de monitoring de YourMedia est basé sur Prometheus et Grafana, déployés sur une instance EC2 dédiée. Il permet de surveiller les performances et la disponibilité des différentes composantes de l'infrastructure.

## Architecture

Le système de monitoring est déployé sur une instance EC2 avec les caractéristiques suivantes :
- Type d'instance : t2.micro (1 vCPU, 1 Go de RAM)
- Système d'exploitation : Amazon Linux 2023
- Conteneurs Docker : Prometheus, Grafana, Node Exporter, Loki, Promtail
- Volume EBS : 20 Go (gp3)

## Composants

### Prometheus

Prometheus est un système de surveillance et d'alerte open-source qui collecte et stocke des métriques dans une base de données temporelle. Il est configuré pour scraper les métriques des différentes composantes de l'infrastructure.

### Grafana

Grafana est une plateforme d'analyse et de visualisation de données qui permet de créer des tableaux de bord interactifs. Il est configuré pour utiliser Prometheus comme source de données.

### Node Exporter

Node Exporter est un exportateur Prometheus qui collecte des métriques système sur l'instance EC2 (CPU, mémoire, disque, réseau, etc.).

### Loki

Loki est un système d'agrégation de logs inspiré de Prometheus. Il est conçu pour être très économe en ressources et est parfaitement intégré à Grafana.

### Promtail

Promtail est un agent qui collecte les logs et les envoie à Loki. Il est configuré pour collecter les logs système et les logs des conteneurs Docker.

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

### Configuration de Grafana

Grafana est configuré avec les paramètres suivants :
- Source de données Prometheus pour les métriques
- Source de données Loki pour les logs
- Authentification avec identifiants par défaut (admin/admin)

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

## Sécurité

L'instance de monitoring est sécurisée avec les mesures suivantes :
- Groupe de sécurité dédié qui limite l'accès aux ports 22 (SSH), 3000 (Grafana) et 9090 (Prometheus)
- Accès SSH limité aux adresses IP autorisées
- Volumes EBS chiffrés

## Maintenance

### Sauvegarde

Pour sauvegarder le système de monitoring, vous devez sauvegarder :
1. Le répertoire `/opt/monitoring/prometheus`
2. Le répertoire `/var/lib/grafana`
3. Le répertoire `/opt/monitoring/loki`
4. Les fichiers de configuration dans `/opt/monitoring`

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
   - Vérifiez les permissions des répertoires : `/var/lib/grafana` et `/opt/monitoring/loki`

2. **Prometheus ne collecte pas de métriques**
   - Vérifiez la configuration de Prometheus : `/opt/monitoring/prometheus.yml`
   - Vérifiez l'état des cibles dans l'interface Prometheus : `http://<IP_PUBLIQUE_INSTANCE>:9090/targets`

3. **Grafana n'affiche pas de données**
   - Vérifiez la configuration des sources de données dans Grafana
   - Vérifiez que Prometheus collecte bien les métriques

4. **Loki ne collecte pas de logs**
   - Vérifiez la configuration de Promtail : `/opt/monitoring/promtail-config.yml`
   - Vérifiez les logs de Promtail : `docker logs promtail`

## Simplifications apportées

Pour améliorer la fiabilité et la simplicité du système de monitoring, les modifications suivantes ont été apportées :

1. **Suppression des exporters problématiques**
   - MySQL Exporter a été supprimé car il nécessitait une configuration complexe pour se connecter à RDS
   - CloudWatch Exporter a été supprimé car il nécessitait des permissions AWS spécifiques

2. **Simplification de la configuration**
   - Les fichiers de configuration sont maintenant générés directement lors de l'initialisation de l'instance
   - Les chemins de fichiers ont été standardisés pour éviter les problèmes de liens symboliques
   - Les permissions des répertoires ont été ajustées pour éviter les problèmes d'accès

3. **Optimisation pour le free tier AWS**
   - Utilisation d'images Docker officielles pour une meilleure compatibilité
   - Configuration simplifiée pour réduire la consommation de ressources
   - Réduction du nombre de conteneurs pour limiter l'utilisation de la mémoire
