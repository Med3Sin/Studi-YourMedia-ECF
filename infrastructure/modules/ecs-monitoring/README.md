# Module Terraform : ECS Monitoring (Prometheus & Grafana)

Ce module met en place un système de monitoring basé sur Prometheus et Grafana, exécuté sur AWS ECS Fargate pour une approche serverless.

## Ressources Créées

*   **`aws_ecs_cluster.monitoring_cluster`**: Un cluster ECS dédié au monitoring.
*   **`aws_cloudwatch_log_group.ecs_logs`**: Un groupe de logs CloudWatch pour centraliser les logs des conteneurs Prometheus et Grafana.
*   **`aws_iam_role.ecs_task_execution_role`**: Rôle IAM nécessaire à ECS pour exécuter les tâches Fargate (tirer les images de Docker Hub, envoyer les logs à CloudWatch).
*   **`aws_iam_role_policy_attachment.ecs_task_execution_role_policy`**: Attache la politique managée AWS requise au rôle d'exécution.
*   **`aws_ecs_task_definition.prometheus_task`**: Définition de la tâche ECS pour Prometheus.
    *   Utilise l'image `prom/prometheus:latest`.
    *   Configure le logging vers CloudWatch.
    *   Injecte la configuration `prometheus.yml` (rendue avec l'IP privée de l'EC2) via une variable d'environnement encodée en base64 et une commande de démarrage personnalisée.
    *   Utilise le mode réseau `awsvpc` requis par Fargate.
*   **`aws_ecs_task_definition.grafana_task`**: Définition de la tâche ECS pour Grafana.
    *   Utilise l'image `grafana/grafana-oss:latest`.
    *   Configure le logging vers CloudWatch.
    *   Expose le port `3000`.
    *   Configure l'utilisateur/mot de passe admin Grafana via des variables d'environnement (mot de passe par défaut à changer!).
    *   Utilise le mode réseau `awsvpc`.
*   **`aws_ecs_service.prometheus_service`**: Service ECS qui assure qu'une instance de la tâche Prometheus est toujours en cours d'exécution sur Fargate.
    *   Utilise les sous-réseaux et le groupe de sécurité ECS fournis.
    *   N'assigne pas d'IP publique (Prometheus n'a pas besoin d'être accessible de l'extérieur).
*   **`aws_ecs_service.grafana_service`**: Service ECS qui assure qu'une instance de la tâche Grafana est toujours en cours d'exécution sur Fargate.
    *   Utilise les sous-réseaux publics et le groupe de sécurité ECS fournis.
    *   **Assign une IP publique** pour permettre l'accès à l'interface web Grafana.

## Fichiers de Configuration

*   **`config/prometheus.yml`**: Template de configuration pour Prometheus. La variable `${ec2_private_ip}` est remplacée par l'IP privée de l'instance EC2 pour définir la cible de scraping.
*   **`task-definitions/prometheus.json`**: Template JSON pour la définition de tâche Prometheus. Des variables comme la région, le groupe de log, les ressources CPU/mémoire et le contenu de la config Prometheus y sont injectées.
*   **`task-definitions/grafana.json`**: Template JSON pour la définition de tâche Grafana. Des variables comme la région, le groupe de log et les ressources CPU/mémoire y sont injectées.

## Variables d'Entrée

*   `project_name` (String): Nom du projet pour taguer les ressources.
*   `aws_region` (String): Région AWS.
*   `vpc_id` (String): ID du VPC.
*   `subnet_ids` (List(String)): Liste des IDs des sous-réseaux (publics recommandés pour l'accès Grafana).
*   `ecs_security_group_id` (String): ID du groupe de sécurité ECS.
*   `ec2_instance_private_ip` (String): IP privée de l'instance EC2 à monitorer.
*   `ecs_task_cpu` (Number): Unités CPU pour les tâches Fargate.
*   `ecs_task_memory` (Number): Mémoire (MiB) pour les tâches Fargate.

## Sorties

*   `ecs_cluster_name`: Nom du cluster ECS créé.
*   `prometheus_service_name`: Nom du service ECS Prometheus.
*   `grafana_service_name`: Nom du service ECS Grafana.
*   `cloudwatch_log_group_name`: Nom du groupe de logs CloudWatch.

## Accès à Grafana

L'accès à l'interface Grafana se fait via l'IP publique assignée à la tâche Fargate Grafana sur le port 3000. Cette IP est dynamique et doit être récupérée après le déploiement :
1.  Allez dans la console AWS -> ECS -> Cluster `${project_name}-monitoring-cluster`.
2.  Cliquez sur le service `${project_name}-grafana-service`.
3.  Allez dans l'onglet "Tasks".
4.  Cliquez sur l'ID de la tâche en cours d'exécution.
5.  Dans la section "Network", trouvez l'"Public IP".
6.  Accédez à `http://<IP_PUBLIQUE_GRAFANA>:3000` dans votre navigateur.
7.  Connectez-vous avec `admin` / `YourSecurePassword123!` (ou le mot de passe que vous avez configuré).
8.  Configurez manuellement Prometheus comme source de données en utilisant l'URL interne du service Prometheus : `http://prometheus.local:9090` (si la découverte de service DNS ECS est activée, sinon utilisez l'IP privée de la tâche Prometheus). Pour la simplicité, l'IP privée peut être trouvée de la même manière que pour Grafana.
