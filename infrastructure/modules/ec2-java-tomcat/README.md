# Module Terraform : EC2 Java/Tomcat Instance

Ce module provisionne une instance EC2 configurée pour héberger l'application backend Java Spring Boot avec Tomcat.

## Ressources Créées

*   **`aws_iam_policy.ec2_s3_access_policy`**: Politique IAM autorisant l'accès (GetObject, PutObject, DeleteObject, ListBucket) au bucket S3 spécifié par `s3_bucket_arn`.
*   **`aws_iam_role.ec2_role`**: Rôle IAM que l'instance EC2 assumera. Permet à l'instance d'agir avec les permissions définies dans les politiques attachées.
*   **`aws_iam_role_policy_attachment.ec2_s3_policy_attach`**: Attache la politique d'accès S3 au rôle EC2.
*   **`aws_iam_instance_profile.ec2_profile`**: Profil d'instance qui lie le rôle IAM à l'instance EC2.
*   **`aws_instance.app_server`**: L'instance EC2 elle-même.
    *   Utilise une AMI Ubuntu spécifiée (`ami_id`).
    *   Type d'instance Free Tier (`instance_type_ec2`, ex: `t2.micro`).
    *   Configurée avec une paire de clés SSH (`key_pair_name`) pour l'accès.
    *   Placée dans un sous-réseau public (`subnet_id`) du VPC par défaut.
    *   Associée au groupe de sécurité EC2 (`ec2_security_group_id`) fourni par le module `network`.
    *   Associée au profil d'instance IAM (`ec2_profile`) pour obtenir les permissions S3.
    *   Exécute le script `scripts/install_java_tomcat.sh` via `user_data` lors de son premier démarrage pour installer OpenJDK 17 et Tomcat 9, et configurer Tomcat comme service systemd.

## Script d'Installation (`scripts/install_java_tomcat.sh`)

Ce script Bash est exécuté par `user_data` et effectue les actions suivantes :
1.  Met à jour les paquets Ubuntu.
2.  Installe OpenJDK 17.
3.  Crée un utilisateur et un groupe `tomcat`.
4.  Télécharge et extrait Tomcat 9 dans `/opt/tomcat`.
5.  Configure les permissions des répertoires Tomcat.
6.  Crée un fichier de service `tomcat.service` pour `systemd`.
7.  Démarre et active le service Tomcat pour qu'il s'exécute au démarrage.

## Variables d'Entrée

*   `project_name` (String): Nom du projet pour taguer les ressources.
*   `ami_id` (String): ID de l'AMI Ubuntu à utiliser.
*   `instance_type_ec2` (String): Type d'instance EC2 (ex: `t2.micro`).
*   `key_pair_name` (String): Nom de la paire de clés SSH existante dans AWS.
*   `subnet_id` (String): ID du sous-réseau public où lancer l'instance.
*   `ec2_security_group_id` (String): ID du groupe de sécurité EC2 à attacher.
*   `s3_bucket_arn` (String): ARN du bucket S3 auquel l'instance doit avoir accès.

## Sorties

*   `public_ip`: Adresse IP publique assignée à l'instance EC2.
*   `private_ip`: Adresse IP privée assignée à l'instance EC2 (utilisée par Prometheus).
*   `instance_id`: ID de l'instance EC2 créée.
