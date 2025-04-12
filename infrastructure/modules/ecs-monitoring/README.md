# Module Terraform : Monitoring avec Docker (Prometheus & Grafana)

Ce module met en place un système de monitoring basé sur Prometheus et Grafana, exécuté dans des conteneurs Docker sur une instance EC2 dédiée.

## Ressources Créées

* **`aws_iam_role.monitoring_role`**: Rôle IAM pour l'instance EC2 de monitoring.
* **`aws_iam_role_policy_attachment.ecr_policy`**: Attache la politique ECR au rôle IAM.
* **`aws_iam_instance_profile.monitoring_profile`**: Profil d'instance pour attacher le rôle IAM à l'instance EC2.
* **`aws_instance.monitoring_instance`**: Instance EC2 dédiée au monitoring.
* **`null_resource.copy_docker_compose`**: Ressource pour copier le fichier docker-compose.yml sur l'instance EC2.

## Fichiers de Configuration

* **`scripts/docker-compose.yml`**: Fichier Docker Compose pour déployer Prometheus et Grafana.
* **`scripts/install_docker.sh`**: Script d'initialisation pour installer Docker et configurer les conteneurs.
* **`config/prometheus.yml`**: Template de configuration pour Prometheus. La variable `${ec2_private_ip}` est remplacée par l'IP privée de l'instance EC2 pour définir la cible de scraping.

## Variables d'Entrée

* `project_name` (String): Nom du projet pour taguer les ressources.
* `aws_region` (String): Région AWS.
* `vpc_id` (String): ID du VPC.
* `subnet_ids` (List(String)): Liste des IDs des sous-réseaux.
* `ecs_security_group_id` (String): ID du groupe de sécurité pour l'instance EC2.
* `ec2_instance_private_ip` (String): IP privée de l'instance EC2 à monitorer.
* `ecs_ami_id` (String): ID de l'AMI pour l'instance EC2.
* `key_pair_name` (String): Nom de la paire de clés SSH pour l'instance EC2.
* `ssh_private_key_path` (String): Chemin vers la clé privée SSH pour se connecter à l'instance EC2.

## Sorties

* `ec2_instance_id`: ID de l'instance EC2 hébergeant Grafana et Prometheus.
* `ec2_instance_public_ip`: Adresse IP publique de l'instance EC2.
* `ec2_instance_private_ip`: Adresse IP privée de l'instance EC2.
* `grafana_url`: URL d'accès à Grafana.
* `prometheus_url`: URL d'accès à Prometheus.

## Accès à Grafana

L'accès à l'interface Grafana se fait via l'IP publique de l'instance EC2 sur le port 3000:
1. Accédez à `http://<EC2_PUBLIC_IP>:3000` dans votre navigateur.
2. Connectez-vous avec `admin` / `admin` (mot de passe par défaut).
3. Lors de la première connexion, Grafana vous demandera de changer le mot de passe.

## Accès à Prometheus

L'accès à l'interface Prometheus se fait via l'IP publique de l'instance EC2 sur le port 9090:
1. Accédez à `http://<EC2_PUBLIC_IP>:9090` dans votre navigateur.

## Optimisations pour le Free Tier AWS

Ce module est optimisé pour rester dans les limites du Free Tier AWS :
1. Utilisation d'une instance t2.micro.
2. Limitation des ressources des conteneurs Docker.
3. Configuration de la rétention des données Prometheus (15 jours, 1 Go maximum).
4. Rotation des logs Docker pour limiter l'utilisation du disque.
