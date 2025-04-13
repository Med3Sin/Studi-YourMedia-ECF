# Module EC2 Monitoring

Ce module déploie une instance EC2 exécutant Prometheus et Grafana dans des conteneurs Docker pour surveiller l'application backend.

## Historique

Ce module s'appelait auparavant "ecs-monitoring" car il était initialement prévu d'utiliser ECS pour le déploiement. Il a été renommé en "ec2-monitoring" pour refléter son implémentation actuelle, qui utilise une instance EC2 avec Docker.

## Architecture

Le module déploie les composants suivants :

- Une instance EC2 basée sur Amazon Linux 2
- Docker et Docker Compose installés automatiquement
- Conteneurs Docker pour Grafana et Prometheus
- Configuration des groupes de sécurité pour permettre l'accès aux interfaces web

## Fonctionnalités

- **Monitoring complet** : Collecte et visualisation des métriques de l'application
- **Déploiement automatisé** : Installation et configuration automatiques de Docker, Grafana et Prometheus
- **Correction des permissions** : Résolution automatique des problèmes de permissions courants
- **Accès sécurisé** : Configuration des groupes de sécurité pour contrôler l'accès
- **Intégration avec Spring Boot** : Collecte des métriques via l'endpoint Actuator

## Ressources créées

- **`aws_iam_role.monitoring_role`**: Rôle IAM pour l'instance EC2
- **`aws_iam_role_policy_attachment.ssm_policy`**: Politique pour l'accès à SSM
- **`aws_iam_role_policy_attachment.cloudwatch_policy`**: Politique pour l'accès à CloudWatch
- **`aws_iam_instance_profile.monitoring_profile`**: Profil d'instance pour attacher le rôle IAM
- **`aws_instance.monitoring_instance`**: Instance EC2 exécutant Docker
- **`null_resource.copy_docker_compose`**: Ressource pour copier le fichier docker-compose.yml sur l'instance

## Variables

| Nom | Description | Type | Défaut | Obligatoire |
|-----|-------------|------|--------|------------|
| project_name | Nom du projet pour taguer les ressources | string | - | oui |
| environment | Environnement de déploiement (dev, pre-prod, prod) | string | "dev" | oui |
| aws_region | Région AWS où déployer les ressources | string | - | oui |
| vpc_id | ID du VPC où déployer l'instance EC2 | string | - | oui |
| subnet_ids | Liste des IDs des sous-réseaux | list(string) | - | oui |
| monitoring_security_group_id | ID du groupe de sécurité pour l'instance EC2 de monitoring | string | - | oui |
| ec2_instance_private_ip | IP privée de l'instance EC2 backend | string | - | oui |
| monitoring_task_cpu | CPU alloué (maintenu pour compatibilité) | number | - | oui |
| monitoring_task_memory | Mémoire allouée (maintenu pour compatibilité) | number | - | oui |
| monitoring_ami_id | ID de l'AMI Amazon Linux 2 | string | ami-0f4982c2ea2a68de5 | non |
| key_pair_name | Nom de la paire de clés SSH | string | - | oui |
| ssh_private_key_path | Chemin vers la clé privée SSH | string | ~/.ssh/id_rsa | non |

## Outputs

| Nom | Description |
|-----|-------------|
| ec2_instance_id | ID de l'instance EC2 |
| ec2_instance_public_ip | Adresse IP publique de l'instance EC2 |
| ec2_instance_private_ip | Adresse IP privée de l'instance EC2 |
| grafana_url | URL d'accès à Grafana |
| prometheus_url | URL d'accès à Prometheus |

## Scripts

Le module utilise deux scripts principaux pour le déploiement et la configuration :

### 1. `deploy_containers.sh`

Ce script est responsable de l'installation initiale et du déploiement des conteneurs :

- Installation de Docker et Docker Compose si nécessaire
- Création des répertoires pour les volumes Docker
- Copie des fichiers de configuration
- Démarrage des conteneurs

### 2. `fix_permissions.sh`

Ce script résout les problèmes de permissions courants avec Grafana et Prometheus :

- Correction des permissions des répertoires de données
- Configuration des utilisateurs Docker appropriés (65534 pour Prometheus, 472 pour Grafana)
- Redémarrage des conteneurs avec les bonnes configurations

## Ports utilisés

- **22** : SSH pour l'accès à l'instance
- **3000** : Interface web de Grafana
- **9090** : Interface web de Prometheus

## Accès aux interfaces web

### Grafana

L'accès à l'interface Grafana se fait via l'IP publique de l'instance EC2 sur le port 3000 :

```
http://<EC2_PUBLIC_IP>:3000
```

Les identifiants par défaut sont :
- Utilisateur : `admin`
- Mot de passe : `admin` (ou celui configuré dans le secret GitHub `GF_SECURITY_ADMIN_PASSWORD`)

### Prometheus

L'accès à l'interface Prometheus se fait via l'IP publique de l'instance EC2 sur le port 9090 :

```
http://<EC2_PUBLIC_IP>:9090
```

## Dépannage

### Problèmes de permissions

Si vous rencontrez des problèmes de permissions, vous pouvez exécuter manuellement le script de correction :

```bash
ssh ec2-user@<IP_PUBLIQUE_DE_L_INSTANCE>
sudo /opt/monitoring/fix_permissions.sh
```

### Vérification des logs

Pour vérifier les logs des conteneurs :

```bash
docker logs prometheus
docker logs grafana
```

## Notes de maintenance

Ce module contient plusieurs éléments qui seront renommés ou supprimés dans une future version pour plus de cohérence :

1. La variable `monitoring_security_group_id` pourrait être renommée en `ec2_security_group_id` pour plus de cohérence
2. La variable `monitoring_ami_id` pourrait être renommée en `ec2_ami_id` pour plus de cohérence
3. Les variables `monitoring_task_cpu` et `monitoring_task_memory` seront supprimées car elles ne sont plus utilisées (vestiges de l'ancienne version ECS)

Ces changements seront effectués dans une future version pour éviter de casser la compatibilité avec le code existant.
