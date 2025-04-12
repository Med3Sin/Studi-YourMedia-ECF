# Module Terraform : S3 Storage

Ce module provisionne un bucket S3 pour le stockage des médias et des artefacts de build.

## Ressources Créées

* **`aws_s3_bucket.media_storage`**: Bucket S3 principal pour le stockage des médias et des artefacts.
  * Utilise un nom unique généré avec un suffixe aléatoire pour éviter les conflits.
  * **Configuration `force_destroy = true`** pour permettre la suppression du bucket même s'il contient des objets.
  * Cette option est essentielle pour la destruction complète de l'infrastructure, notamment lors d'échecs de déploiement.

* **`aws_s3_bucket_public_access_block`**: Bloque tout accès public au bucket pour des raisons de sécurité.

* **`aws_s3_bucket_versioning`**: Active le versionnement des objets pour permettre la récupération de versions antérieures.

* **`aws_s3_bucket_server_side_encryption_configuration`**: Configure le chiffrement côté serveur pour protéger les données au repos.

* **`aws_s3_bucket_policy`**: Définit une politique permettant à AWS Amplify d'accéder aux artefacts de build.

## Variables d'Entrée

* `project_name` (String): Nom du projet pour taguer les ressources.
* `environment` (String): Environnement de déploiement (dev, pre-prod, prod).
* `aws_region` (String): Région AWS où le bucket est déployé.

## Sorties

* `bucket_name` (String): Nom du bucket S3 créé.
* `bucket_arn` (String): ARN (Amazon Resource Name) du bucket S3.
* `bucket_domain_name` (String): Nom de domaine du bucket S3.

## Remarques sur la Destruction

Le bucket est configuré avec `force_destroy = true`, ce qui permet à Terraform de supprimer automatiquement tous les objets du bucket lors de la destruction de l'infrastructure. Cette configuration est particulièrement utile dans les scénarios suivants :

1. Échec partiel du déploiement de l'infrastructure
2. Tests et environnements de développement temporaires
3. Nettoyage complet des ressources

Sans cette option, Terraform échouerait à détruire un bucket contenant des objets, ce qui nécessiterait une suppression manuelle des objets avant de pouvoir détruire le bucket.
