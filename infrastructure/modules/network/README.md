# Module Terraform : Network

Ce module est responsable de la création des groupes de sécurité (Security Groups) nécessaires pour les différentes ressources AWS dans le VPC par défaut.

## Ressources Créées

*   **`aws_security_group.ec2_sg`**: Groupe de sécurité pour l'instance EC2 (`ec2-java-tomcat`).
    *   Autorise le trafic entrant sur les ports :
        *   `22` (SSH) depuis l'`operator_ip` fournie.
        *   `80` (HTTP) depuis n'importe où (`0.0.0.0/0`).
        *   `8080` (Tomcat/API) depuis n'importe où (`0.0.0.0/0`).
        *   `8080` (Tomcat/API - pour Prometheus) depuis le groupe de sécurité ECS (`ecs_sg`).
    *   Autorise tout le trafic sortant.
*   **`aws_security_group.rds_sg`**: Groupe de sécurité pour l'instance RDS (`rds-mysql`).
    *   Autorise le trafic entrant sur le port `3306` (MySQL) uniquement depuis le groupe de sécurité EC2 (`ec2_sg`).
    *   Autorise tout le trafic sortant.
*   **`aws_security_group.ecs_sg`**: Groupe de sécurité pour les tâches ECS Fargate (`ecs-monitoring`).
    *   Autorise le trafic entrant sur le port `3000` (Grafana) depuis l'`operator_ip` fournie.
    *   Autorise tout le trafic sortant (nécessaire pour Prometheus pour scraper l'EC2 et pour les tâches pour tirer les images Docker).

## Variables d'Entrée

*   `project_name` (String): Nom du projet utilisé pour taguer les ressources.
*   `vpc_id` (String): ID du VPC (par défaut) où créer les groupes de sécurité.
*   `operator_ip` (String): Adresse IP publique de l'opérateur/développeur pour restreindre l'accès SSH et Grafana.

## Sorties

*   `ec2_security_group_id`: ID du groupe de sécurité créé pour l'EC2.
*   `rds_security_group_id`: ID du groupe de sécurité créé pour RDS.
*   `ecs_security_group_id`: ID du groupe de sécurité créé pour ECS.
