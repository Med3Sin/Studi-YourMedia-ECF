# Module Terraform : S3 Storage

Ce module crée et configure un bucket S3 pour le projet YourMédia.

## Rôle du Bucket

*   **Stockage des Médias**: Destiné à stocker les fichiers (photos, vidéos) uploadés par les utilisateurs de l'application. L'accès en écriture/lecture sera géré via la politique IAM attachée au rôle de l'instance EC2.
*   **Stockage des Builds**: Utilisé comme emplacement temporaire pour les artefacts de build (`.war` du backend, fichiers statiques du frontend) avant leur déploiement respectif sur EC2/Tomcat et Amplify.

## Ressources Créées

*   **`aws_s3_bucket.media_storage`**: Le bucket S3 principal.
    *   Le nom est généré dynamiquement pour assurer l'unicité globale en incluant le nom du projet, l'ID du compte AWS et une chaîne aléatoire.
    *   L'attribut `force_destroy = true` permet de supprimer le bucket même s'il contient des objets, ce qui facilite la destruction de l'infrastructure.
*   **`aws_s3_bucket_public_access_block`**: Bloque tout accès public au bucket par défaut.
*   **`aws_s3_bucket_versioning`**: Active le versioning sur le bucket pour pouvoir récupérer des versions précédentes des objets.
*   **`aws_s3_bucket_lifecycle_configuration`**: Configure des règles de cycle de vie pour :
    *   Supprimer automatiquement les anciennes versions des objets après 1 jour.
    *   Supprimer les marqueurs de suppression expirés.
    *   Ces règles facilitent le nettoyage et la suppression du bucket.
*   **`aws_s3_bucket_server_side_encryption_configuration`**: Configure le chiffrement côté serveur par défaut (SSE-S3/AES256).
*   **`aws_s3_bucket_policy`**: Attache une politique au bucket pour autoriser spécifiquement le service AWS Amplify (`amplify.amazonaws.com`) à lire les objets dans le préfixe `builds/frontend/` (nécessaire pour le déploiement Amplify depuis S3, bien que nous utilisions la connexion directe au repo GitHub pour le build Amplify dans la configuration actuelle).

## Variables d'Entrée

*   `project_name` (String): Nom du projet utilisé pour nommer et taguer le bucket.
*   `aws_region` (String): Région AWS (utilisée dans la condition de la politique de bucket pour Amplify).

## Sorties

*   `bucket_name`: Nom du bucket S3 créé.
*   `bucket_arn`: ARN (Amazon Resource Name) du bucket S3 créé.
*   `bucket_id`: ID (nom) du bucket S3 créé.

## Notes sur les Permissions

*   Les permissions pour l'instance EC2 (`ec2-java-tomcat`) pour lire/écrire dans ce bucket sont définies dans le module `ec2-java-tomcat` via une politique IAM attachée au rôle de l'instance.
*   Les permissions pour le service Amplify sont définies via la politique de bucket ci-dessus.
