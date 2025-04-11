# Module Terraform : RDS MySQL Database

Ce module provisionne une instance de base de données MySQL managée via AWS RDS.

## Ressources Créées

*   **`aws_db_subnet_group.rds_subnet_group`**: Groupe de sous-réseaux requis par RDS, indiquant les sous-réseaux (privés ou publics, selon la configuration du VPC par défaut) dans lesquels l'instance peut être lancée.
    *   Utilise un nom fixe (sans timestamp) pour éviter les erreurs lors des mises à jour.
    *   **Note importante**: AWS ne permet pas de changer le groupe de sous-réseaux d'une instance RDS pour un autre groupe dans le même VPC. Si vous devez modifier les sous-réseaux, vous devrez recréer l'instance RDS complète.
*   **`aws_db_instance.mysql_db`**: L'instance de base de données MySQL elle-même.
    *   Utilise le moteur MySQL version 8.0.
    *   Configurée avec un type d'instance et une taille de stockage éligibles au Free Tier (`db.t3.micro` par défaut, 20 Go gp2).
    *   Le type d'instance est configurable via la variable `instance_type_rds`.
    *   Le nom de la base de données initiale, le nom d'utilisateur et le mot de passe sont fournis via des variables.
    *   Attachée au groupe de sécurité RDS (`rds_sg`) fourni par le module `network`, qui autorise l'accès uniquement depuis l'instance EC2.
    *   Configurée pour la simplicité et le Free Tier :
        *   Pas de Multi-AZ.
        *   Non accessible publiquement depuis Internet.
        *   Pas de snapshot final lors de la destruction.
        *   Backups automatiques désactivés.

## Variables d'Entrée

*   `project_name` (String): Nom du projet pour taguer les ressources.
*   `db_username` (String, Sensitive): Nom d'utilisateur administrateur pour la base de données.
*   `db_password` (String, Sensitive): Mot de passe pour l'utilisateur administrateur.
*   `instance_type_rds` (String): Type d'instance RDS (ex: `db.t3.micro`).
*   `vpc_id` (String): ID du VPC où déployer l'instance.
*   `subnet_ids` (List(String)): Liste des IDs des sous-réseaux pour le groupe de sous-réseaux RDS.
*   `rds_security_group_id` (String): ID du groupe de sécurité à attacher à l'instance.

## Sorties

*   `db_instance_endpoint` (String, Sensitive): Endpoint (hostname) à utiliser pour se connecter à la base de données depuis l'application.
*   `db_instance_port` (Number): Port de connexion à la base de données (par défaut 3306).
*   `db_instance_name` (String): Nom de la base de données initiale créée.
*   `db_instance_username` (String, Sensitive): Nom d'utilisateur administrateur.

## Connexion

La connexion à cette base de données ne peut se faire que depuis des ressources situées dans le groupe de sécurité EC2 (`ec2_sg`), typiquement l'instance `ec2-java-tomcat`. L'application Java devra utiliser l'endpoint, le port, le nom de la base, l'utilisateur et le mot de passe pour établir la connexion JDBC.
