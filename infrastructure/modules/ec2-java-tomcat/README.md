# Module Terraform : EC2 Java Tomcat

Ce module est responsable de la création d'une instance EC2 configurée pour exécuter une application Java sur Tomcat, avec accès à un bucket S3 pour le stockage des médias.

## Ressources Créées

* **`aws_iam_policy.ec2_s3_access_policy`**: Politique IAM permettant l'accès au bucket S3.
  * Autorise les actions `s3:GetObject`, `s3:PutObject`, `s3:ListBucket` et `s3:DeleteObject` sur le bucket S3 spécifié.
  * Permet à l'application de lire, écrire et supprimer des objets dans le bucket.

* **`aws_iam_role.ec2_role`**: Rôle IAM que l'instance EC2 assumera.
  * Permet à l'instance EC2 d'assumer le rôle via le service EC2.
  * Utilisé pour attacher la politique d'accès S3.

* **`aws_iam_role_policy_attachment.ec2_s3_policy_attach`**: Attache la politique S3 au rôle EC2.

* **`aws_iam_instance_profile.ec2_profile`**: Profil d'instance permettant d'attacher le rôle IAM à l'instance EC2.

* **`aws_instance.app_server`**: Instance EC2 exécutant Java et Tomcat.
  * Utilise l'AMI spécifiée (Amazon Linux 2 recommandé).
  * Configurée avec le type d'instance spécifié (t2.micro par défaut pour Free Tier).
  * Déployée dans le sous-réseau spécifié et associée au groupe de sécurité fourni.
  * Exécute un script d'installation de Java et Tomcat au premier démarrage via user_data.

## Variables d'Entrée

* `project_name` (String): Nom du projet utilisé pour taguer les ressources.
* `environment` (String): Environnement de déploiement (dev, pre-prod, prod).
* `ami_id` (String): ID de l'AMI à utiliser pour l'instance EC2 (Amazon Linux 2 recommandé).
* `instance_type_ec2` (String): Type d'instance EC2 (par défaut: t2.micro pour Free Tier).
* `key_pair_name` (String): Nom de la paire de clés SSH pour l'accès à l'instance.
* `subnet_id` (String): ID du sous-réseau où déployer l'instance EC2.
* `ec2_security_group_id` (String): ID du groupe de sécurité pour l'instance EC2.
* `s3_bucket_arn` (String): ARN du bucket S3 pour le stockage des médias.
* `s3_bucket_name` (String): Nom du bucket S3 pour le stockage des médias.

## Sorties

* `instance_id`: ID de l'instance EC2 créée.
* `public_ip`: Adresse IP publique de l'instance EC2.
* `private_ip`: Adresse IP privée de l'instance EC2.
* `tomcat_url`: URL d'accès à l'application Tomcat (http://<public_ip>:8080).

## Script d'Installation

Le module utilise un script d'installation (`install_java_tomcat.sh`) qui est exécuté au premier démarrage de l'instance via user_data. Ce script:

1. Met à jour le système
2. Installe Java 11 (Amazon Corretto)
3. Télécharge et installe Tomcat 9
4. Configure Tomcat pour démarrer automatiquement
5. Crée un utilisateur et un mot de passe pour l'interface d'administration Tomcat
6. Configure les permissions nécessaires

## Notes Importantes

1. **Compatibilité Free Tier**: Cette configuration est optimisée pour rester dans les limites du Free Tier AWS avec une instance t2.micro.

2. **Sécurité**: 
   * L'accès SSH est limité aux adresses IP spécifiées dans le groupe de sécurité.
   * L'accès à Tomcat (port 8080) est ouvert selon la configuration du groupe de sécurité.
   * Un mot de passe est configuré pour l'interface d'administration Tomcat.

3. **Déploiement d'applications**:
   * Les applications WAR peuvent être déployées via l'interface d'administration Tomcat ou en les copiant directement dans le répertoire `/opt/tomcat/webapps/`.
   * Le workflow GitHub Actions peut être utilisé pour automatiser le déploiement des applications.

4. **Accès S3**:
   * L'instance EC2 a accès au bucket S3 spécifié via le rôle IAM attaché.
   * L'application peut utiliser l'AWS SDK pour Java pour interagir avec S3 sans avoir besoin de clés d'accès codées en dur.

5. **Mise à l'échelle**:
   * Pour les environnements de production, envisagez d'utiliser un Auto Scaling Group et un Application Load Balancer pour une haute disponibilité et une mise à l'échelle automatique.
