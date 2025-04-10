# Module Terraform : Network

Ce module est responsable de la création des groupes de sécurité (Security Groups) nécessaires pour les différentes ressources AWS dans le VPC par défaut.

## Ressources Créées

*   **`aws_security_group.ec2_sg`**: Groupe de sécurité pour l'instance EC2 (`ec2-java-tomcat`).
    *   Autorise le trafic entrant sur les ports :
        *   `22` (SSH) depuis l'`operator_ip` fournie.
        *   `8080` (Tomcat/API) depuis n'importe où (`0.0.0.0/0`).
        *   `8080` (Tomcat/API - pour Prometheus) depuis le groupe de sécurité ECS (`ecs_sg`).
    *   Autorise le trafic sortant spécifique :
        *   `3306` (MySQL) vers le groupe de sécurité RDS.
        *   `443` (HTTPS) vers Internet pour les services AWS.
        *   `80` (HTTP) vers Internet pour les téléchargements et mises à jour.
*   **`aws_security_group.rds_sg`**: Groupe de sécurité pour l'instance RDS (`rds-mysql`).
    *   Autorise le trafic entrant sur le port `3306` (MySQL) uniquement depuis le groupe de sécurité EC2 (`ec2_sg`).
    *   Autorise le trafic sortant spécifique :
        *   `443` (HTTPS) vers Internet pour les mises à jour et la maintenance AWS.
*   **`aws_security_group.ecs_sg`**: Groupe de sécurité pour les tâches ECS (`ecs-monitoring`).
    *   Autorise le trafic entrant sur le port `3000` (Grafana) depuis l'`operator_ip` fournie.
    *   Autorise le trafic sortant spécifique :
        *   `8080` (Tomcat/API) vers le groupe de sécurité EC2 pour le scraping des métriques par Prometheus.
        *   `443` (HTTPS) vers Internet pour télécharger des images Docker et des plugins.
        *   `80` (HTTP) vers Internet pour télécharger des images Docker et des plugins.

## Variables d'Entrée

*   `project_name` (String): Nom du projet utilisé pour taguer les ressources.
*   `vpc_id` (String): ID du VPC (par défaut) où créer les groupes de sécurité.
*   `operator_ip` (String): Adresse IP publique de l'opérateur/développeur pour restreindre l'accès SSH et Grafana.

## Sorties

*   `ec2_security_group_id`: ID du groupe de sécurité créé pour l'EC2.
*   `rds_security_group_id`: ID du groupe de sécurité créé pour RDS.
*   `ecs_security_group_id`: ID du groupe de sécurité créé pour ECS.

## Bonnes Pratiques de Sécurité

1. **Principe du moindre privilège** : Chaque groupe de sécurité n'autorise que le trafic nécessaire pour son fonctionnement.
2. **Restriction par IP source** : L'accès SSH et Grafana est restreint à l'IP de l'opérateur.
3. **Restriction par groupe de sécurité** : L'accès à la base de données est restreint au groupe de sécurité EC2.
4. **Règles sortantes spécifiques** : Les règles sortantes sont limitées aux ports et destinations nécessaires.

## Recommandations

1. **IP de l'opérateur** : Mettez à jour la variable `operator_ip` avec votre adresse IP réelle pour renforcer la sécurité.
2. **Révision périodique** : Révisez régulièrement les règles de sécurité pour vous assurer qu'elles correspondent aux besoins actuels.
3. **Journalisation** : Envisagez d'activer les journaux de flux VPC pour surveiller le trafic réseau.
