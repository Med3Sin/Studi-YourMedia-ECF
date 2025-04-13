# Module Terraform : RDS MySQL

Ce module est responsable de la création d'une instance de base de données MySQL sur Amazon RDS, optimisée pour rester dans les limites du Free Tier AWS.

## Ressources Créées

* **`aws_db_subnet_group.rds_subnet_group`**: Groupe de sous-réseaux pour l'instance RDS.
  * Utilise les sous-réseaux fournis (au moins deux sous-réseaux dans des zones de disponibilité différentes sont requis par AWS).
  * Permet à RDS d'être déployé dans les sous-réseaux spécifiés.

* **`aws_db_instance.mysql_db`**: Instance de base de données MySQL.
  * Utilise MySQL 8.0.35 (version compatible avec db.t2.micro).
  * Configuration optimisée pour le Free Tier AWS (instance db.t2.micro, 20 Go de stockage).
  * Déployée dans le groupe de sous-réseaux créé.
  * Sécurisée par le groupe de sécurité RDS fourni.
  * Configurée pour un environnement de développement/test (pas de Multi-AZ, pas de backups automatiques).

## Variables d'Entrée

* `project_name` (String): Nom du projet utilisé pour taguer les ressources.
* `environment` (String): Environnement de déploiement (dev, pre-prod, prod).
* `subnet_ids` (List(String)): Liste des IDs de sous-réseaux où déployer RDS (au moins deux dans des zones de disponibilité différentes).
* `rds_security_group_id` (String): ID du groupe de sécurité pour RDS.
* `instance_type_rds` (String): Type d'instance RDS (par défaut: db.t2.micro pour Free Tier).
* `db_username` (String): Nom d'utilisateur pour la base de données (sensible).
* `db_password` (String): Mot de passe pour la base de données (sensible).

## Sorties

* `db_instance_endpoint`: Point de terminaison de connexion à la base de données (hostname:port).
* `db_instance_port`: Port de connexion à la base de données (3306 par défaut).
* `db_instance_name`: Nom de la base de données initiale créée.
* `db_instance_id`: Identifiant de l'instance RDS.
* `db_subnet_group_name`: Nom du groupe de sous-réseaux RDS.

## Notes Importantes

1. **Exigence de deux zones de disponibilité**: AWS RDS exige que le groupe de sous-réseaux contienne des sous-réseaux dans au moins deux zones de disponibilité différentes, même si vous n'utilisez pas la fonctionnalité Multi-AZ.

2. **Compatibilité Free Tier**: Cette configuration est optimisée pour rester dans les limites du Free Tier AWS:
   * Instance db.t2.micro
   * 20 Go de stockage
   * Pas de Multi-AZ
   * Pas de backups automatiques

3. **Sécurité**: Par défaut, l'instance n'est pas accessible publiquement et n'accepte les connexions que depuis le groupe de sécurité de l'instance EC2.

4. **Version de MySQL**: La version 8.0.35 est spécifiée car elle est compatible avec l'instance db.t2.micro. D'autres versions peuvent ne pas être compatibles avec cette classe d'instance.

5. **Environnement de développement/test**: Cette configuration est destinée aux environnements de développement et de test. Pour un environnement de production, il est recommandé d'activer:
   * Multi-AZ pour la haute disponibilité
   * Backups automatiques
   * Chiffrement des données
   * Paramètres de performance optimisés
