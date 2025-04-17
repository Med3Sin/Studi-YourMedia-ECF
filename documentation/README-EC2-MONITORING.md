# Module Terraform : EC2 Monitoring

Ce module est responsable de la création d'une instance EC2 configurée pour exécuter Prometheus et Grafana dans des conteneurs Docker pour le monitoring de l'infrastructure et des applications.

## Ressources Créées

* **`aws_iam_role.monitoring_role`**: Rôle IAM pour l'instance EC2 de monitoring.
  * Permet à l'instance EC2 d'assumer le rôle via le service EC2.
  * Utilisé pour attacher les politiques d'accès CloudWatch et S3.

* **`aws_iam_role_policy_attachment.monitoring_cloudwatch_access`**: Attachement de la politique CloudWatch au rôle IAM.
  * Permet à l'instance EC2 de collecter et publier des métriques CloudWatch.

* **`aws_iam_role_policy_attachment.monitoring_s3_access`**: Attachement de la politique S3 au rôle IAM.
  * Permet à l'instance EC2 d'accéder aux fichiers de configuration dans le bucket S3.

* **`aws_iam_instance_profile.monitoring_instance_profile`**: Profil d'instance IAM.
  * Permet d'attacher le rôle IAM à l'instance EC2.

* **`aws_key_pair.monitoring_key_pair`**: Paire de clés SSH pour l'accès à l'instance EC2.
  * Utilise la clé publique SSH fournie en entrée.

* **`aws_instance.ec2_monitoring`**: Instance EC2 pour le monitoring.
  * Utilise l'AMI Amazon Linux 2 spécifiée.
  * Type d'instance t2.micro (Free Tier eligible).
  * Déployée dans le sous-réseau public spécifié.
  * Configurée avec le groupe de sécurité spécifié.
  * Utilise le script `user_data` pour l'initialisation.

## Variables d'Entrée

* `project_name` (String): Nom du projet utilisé pour taguer les ressources.
* `environment` (String): Environnement de déploiement (dev, pre-prod, prod).
* `aws_region` (String): Région AWS où déployer les ressources.
* `vpc_id` (String): ID du VPC où déployer l'instance EC2.
* `subnet_ids` (List(String)): Liste des IDs de sous-réseaux où déployer l'instance EC2.
* `monitoring_security_group_id` (String): ID du groupe de sécurité à attacher à l'instance EC2.
* `ec2_instance_private_ip` (String): Adresse IP privée de l'instance EC2 Java/Tomcat à monitorer.
* `monitoring_task_cpu` (Number): Nombre de vCPUs à allouer aux conteneurs Docker.
* `monitoring_task_memory` (Number): Quantité de mémoire à allouer aux conteneurs Docker.
* `monitoring_ami_id` (String): ID de l'AMI à utiliser pour l'instance EC2.
* `key_pair_name` (String): Nom de la paire de clés EC2 à utiliser pour l'accès SSH.
* `ssh_public_key` (String): Clé publique SSH pour l'accès à l'instance EC2.
* `enable_provisioning` (Boolean): Activer ou désactiver le provisionnement automatique.
* `s3_bucket_name` (String): Nom du bucket S3 contenant les fichiers de configuration.
* `s3_config_policy_arn` (String): ARN de la politique IAM pour accéder au bucket S3.
* `db_username` (String): Nom d'utilisateur pour la base de données RDS.
* `db_password` (String): Mot de passe pour la base de données RDS.
* `rds_endpoint` (String): Endpoint de connexion à la base de données RDS.

## Sorties

* `instance_id`: ID de l'instance EC2 créée.
* `public_ip`: Adresse IP publique de l'instance EC2.
* `private_ip`: Adresse IP privée de l'instance EC2.
* `public_dns`: Nom DNS public de l'instance EC2.
* `grafana_url`: URL d'accès à Grafana.
* `prometheus_url`: URL d'accès à Prometheus.

## Script d'Initialisation (user_data)

Le script `user_data` exécute les actions suivantes lors du démarrage de l'instance :

1. Met à jour le système et installe les packages nécessaires.
2. Installe Docker et Docker Compose.
3. Crée les répertoires pour les données Prometheus et Grafana.
4. Télécharge les fichiers de configuration depuis le bucket S3.
5. Démarre les conteneurs Docker pour Prometheus et Grafana.

## Fichiers de Configuration

Les fichiers de configuration pour Prometheus et Grafana sont stockés dans le bucket S3 et téléchargés lors de l'initialisation de l'instance :

1. **docker-compose.yml**: Configuration des conteneurs Docker pour Prometheus et Grafana.
2. **prometheus.yml**: Configuration de Prometheus pour collecter les métriques.
3. **deploy_containers.sh**: Script pour déployer les conteneurs Docker.
4. **fix_permissions.sh**: Script pour corriger les permissions des répertoires.
5. **cloudwatch-config.yml**: Configuration pour l'exportateur CloudWatch.

## Notes Importantes

1. **Sécurité**: L'instance EC2 est déployée dans un sous-réseau public avec une adresse IP publique. Le groupe de sécurité doit être configuré pour limiter l'accès.

2. **Accès SSH**: L'accès SSH est configuré avec la clé publique fournie en entrée. La clé privée correspondante doit être conservée en sécurité.

3. **Accès S3**: L'instance EC2 a accès au bucket S3 via le rôle IAM et la politique attachée. Cela permet à l'instance de télécharger les fichiers de configuration.

4. **Zone de disponibilité**: L'instance EC2 est déployée dans la zone de disponibilité eu-west-3a pour minimiser les coûts de transfert de données avec l'instance EC2 Java/Tomcat.

5. **Free Tier**: La configuration par défaut (t2.micro) est éligible au Free Tier AWS. Pour un environnement de production, il est recommandé d'utiliser un type d'instance plus puissant.
