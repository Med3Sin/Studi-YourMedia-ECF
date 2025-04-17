# Module Terraform : S3 Storage

Ce module crée et configure un bucket S3 pour le projet YourMédia.

## Rôle du Bucket

* **Stockage des Médias**: Destiné à stocker les fichiers (photos, vidéos) uploadés par les utilisateurs de l'application. L'accès en écriture/lecture est géré via la politique IAM attachée au rôle de l'instance EC2.
* **Stockage des Builds**: Utilisé comme emplacement temporaire pour les artefacts de build (`.war` du backend, fichiers statiques du frontend) avant leur déploiement respectif sur EC2/Tomcat et Amplify.
* **Stockage des Configurations**: Stocke les fichiers de configuration pour le monitoring (Prometheus, Grafana) qui sont téléchargés par l'instance EC2 de monitoring lors de son initialisation.

## Ressources Créées

* **`aws_s3_bucket.media_storage`**: Le bucket S3 principal.
  * Le nom est généré dynamiquement pour assurer l'unicité globale en incluant le nom du projet, l'ID du compte AWS et une chaîne aléatoire.

* **`aws_s3_bucket_public_access_block`**: Bloque tout accès public au bucket par défaut.

* **`aws_s3_bucket_versioning`**: Active le versioning sur le bucket pour pouvoir récupérer des versions précédentes des objets.

* **`aws_s3_bucket_server_side_encryption_configuration`**: Configure le chiffrement côté serveur par défaut (SSE-S3/AES256).

* **`aws_s3_bucket_lifecycle_configuration`**: Configure des règles de cycle de vie pour nettoyer automatiquement les anciens objets.
  * Règle pour les builds temporaires: expiration après 30 jours, versions précédentes après 7 jours.
  * Règle pour les fichiers WAR déployés: expiration après 60 jours, versions précédentes après 14 jours.

* **`aws_s3_bucket_policy`**: Attache une politique au bucket pour autoriser spécifiquement le service AWS Amplify (`amplify.amazonaws.com`) à lire les objets dans le préfixe `builds/frontend/`.

* **`aws_s3_object`**: Télécharge les fichiers de configuration de monitoring dans le bucket S3.
  * docker-compose.yml
  * prometheus.yml
  * deploy_containers.sh
  * fix_permissions.sh
  * cloudwatch-config.yml

* **`aws_iam_policy.monitoring_s3_access`**: Politique IAM pour permettre à l'instance EC2 de monitoring d'accéder aux fichiers de configuration dans S3.

## Variables d'Entrée

* `project_name` (String): Nom du projet utilisé pour nommer et taguer le bucket.
* `environment` (String): Environnement de déploiement (dev, pre-prod, prod).
* `aws_region` (String): Région AWS (utilisée dans la condition de la politique de bucket pour Amplify).
* `monitoring_scripts_path` (String): Chemin vers les scripts de monitoring. Si fourni, les scripts seront chargés depuis ce chemin plutôt que depuis les fichiers locaux.

## Sorties

* `bucket_name`: Nom du bucket S3 créé.
* `bucket_arn`: ARN (Amazon Resource Name) du bucket S3 créé.
* `bucket_domain_name`: Nom de domaine du bucket S3.
* `bucket_regional_domain_name`: Nom de domaine régional du bucket S3.
* `monitoring_s3_access_policy_arn`: ARN de la politique IAM pour accéder aux fichiers de configuration de monitoring dans S3.

## Accès au Bucket

L'accès au bucket S3 est configuré de la manière suivante :

1. **Accès via IAM Roles et Policies**:
   * Le bucket S3 n'est pas directement dans un VPC (c'est un service global)
   * L'accès est principalement contrôlé via des politiques IAM attachées aux rôles des instances EC2
   * L'accès se fait via l'Internet Gateway

2. **Sécurité du bucket**:
   * Tout accès public au bucket est bloqué
   * Le chiffrement côté serveur est activé (SSE-S3/AES256)
   * Le versioning est activé pour la récupération de fichiers

3. **Permissions pour l'instance EC2 Java/Tomcat**:
   * L'instance EC2 Java/Tomcat a des permissions pour lire, écrire et supprimer des objets dans le bucket
   * Ces permissions sont accordées via un rôle IAM attaché à l'instance EC2

4. **Permissions pour l'instance EC2 Monitoring**:
   * L'instance EC2 Monitoring a des permissions en lecture seule pour accéder aux fichiers de configuration dans le préfixe "monitoring/"

5. **Permissions pour AWS Amplify**:
   * AWS Amplify a des permissions en lecture seule pour accéder aux fichiers dans le préfixe "builds/frontend/"

## Optimisations pour les coûts de transfert de données

Plusieurs optimisations ont été mises en place pour réduire les coûts de transfert de données :

1. **Placement des ressources**: Les ressources qui communiquent fréquemment (EC2, RDS) sont placées dans la même zone de disponibilité
2. **Utilisation de S3**: Le bucket S3 est utilisé principalement pour le stockage des fichiers de configuration et des artefacts de build
3. **Règles de cycle de vie**: Configuration de règles pour nettoyer automatiquement les anciens fichiers
4. **Limitation des transferts entre régions**: Toute l'infrastructure est déployée dans une seule région AWS
5. **Compression des données**: Les fichiers WAR sont compressés avant d'être transférés vers S3

## Notes sur les Permissions

* Les permissions pour l'instance EC2 (`ec2-java-tomcat`) pour lire/écrire dans ce bucket sont définies dans le module `ec2-java-tomcat` via une politique IAM attachée au rôle de l'instance.
* Les permissions pour le service Amplify sont définies via la politique de bucket ci-dessus.
