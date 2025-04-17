# Module Terraform : EC2 Java Tomcat

Ce module est responsable de la création d'une instance EC2 configurée pour exécuter une application Java sur Tomcat, avec accès à un bucket S3 pour le stockage des médias.

## Ressources Créées

* **`aws_iam_policy.ec2_s3_access_policy`**: Politique IAM permettant l'accès au bucket S3.
  * Autorise les actions `s3:GetObject`, `s3:PutObject`, `s3:ListBucket` et `s3:DeleteObject` sur le bucket S3 spécifié.
  * Permet à l'application de lire, écrire et supprimer des objets dans le bucket.

* **`aws_iam_role.ec2_role`**: Rôle IAM que l'instance EC2 assumera.
  * Permet à l'instance EC2 d'assumer le rôle via le service EC2.
  * Utilisé pour attacher la politique d'accès S3.

* **`aws_iam_instance_profile.ec2_instance_profile`**: Profil d'instance IAM.
  * Permet d'attacher le rôle IAM à l'instance EC2.

* **`aws_key_pair.ec2_key_pair`**: Paire de clés SSH pour l'accès à l'instance EC2.
  * Utilise la clé publique SSH fournie en entrée.

* **`aws_instance.ec2_java_tomcat`**: Instance EC2 pour l'application Java/Tomcat.
  * Utilise l'AMI Amazon Linux 2 spécifiée.
  * Type d'instance t2.micro (Free Tier eligible).
  * Déployée dans le sous-réseau public spécifié.
  * Configurée avec le groupe de sécurité spécifié.
  * Utilise le script `user_data` pour l'initialisation.

## Variables d'Entrée

* `project_name` (String): Nom du projet utilisé pour taguer les ressources.
* `environment` (String): Environnement de déploiement (dev, pre-prod, prod).
* `ami_id` (String): ID de l'AMI à utiliser pour l'instance EC2.
* `instance_type_ec2` (String): Type d'instance EC2 (par défaut: t2.micro pour Free Tier).
* `key_pair_name` (String): Nom de la paire de clés EC2 à utiliser pour l'accès SSH.
* `subnet_id` (String): ID du sous-réseau public où déployer l'instance EC2.
* `ec2_security_group_id` (String): ID du groupe de sécurité à attacher à l'instance EC2.
* `s3_bucket_arn` (String): ARN du bucket S3 pour accorder les permissions à l'EC2.
* `ssh_public_key` (String): Clé publique SSH pour l'accès à l'instance EC2.

## Sorties

* `instance_id`: ID de l'instance EC2 créée.
* `public_ip`: Adresse IP publique de l'instance EC2.
* `private_ip`: Adresse IP privée de l'instance EC2.
* `public_dns`: Nom DNS public de l'instance EC2.
* `iam_role_name`: Nom du rôle IAM créé pour l'instance EC2.
* `iam_role_arn`: ARN du rôle IAM créé pour l'instance EC2.

## Script d'Initialisation (user_data)

Le script `user_data` exécute les actions suivantes lors du démarrage de l'instance :

1. Met à jour le système et installe les packages nécessaires.
2. Installe Java 11 via Amazon Linux Extras.
3. Installe et configure Tomcat.
4. Configure les permissions pour le répertoire webapps de Tomcat.
5. Installe l'AWS CLI pour interagir avec S3.
6. Configure le service Tomcat pour démarrer automatiquement.

## Notes Importantes

1. **Sécurité**: L'instance EC2 est déployée dans un sous-réseau public avec une adresse IP publique. Le groupe de sécurité doit être configuré pour limiter l'accès.

2. **Accès SSH**: L'accès SSH est configuré avec la clé publique fournie en entrée. La clé privée correspondante doit être conservée en sécurité.

3. **Accès S3**: L'instance EC2 a accès au bucket S3 via le rôle IAM et la politique attachée. Cela permet à l'application de lire, écrire et supprimer des objets dans le bucket.

4. **Zone de disponibilité**: L'instance EC2 est déployée dans la zone de disponibilité eu-west-3a pour minimiser les coûts de transfert de données avec l'instance RDS.

5. **Free Tier**: La configuration par défaut (t2.micro) est éligible au Free Tier AWS. Pour un environnement de production, il est recommandé d'utiliser un type d'instance plus puissant.
