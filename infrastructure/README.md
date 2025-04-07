# Infrastructure Terraform

Ce répertoire contient l'ensemble du code Terraform pour provisionner l'infrastructure AWS du projet YourMédia. L'infrastructure a été conçue pour rester dans les limites du Free Tier AWS.

## Structure

*   **`main.tf`**: Point d'entrée principal. Définit l'utilisation des modules, récupère les informations du VPC par défaut et crée la ressource AWS Amplify App.
*   **`variables.tf`**: Déclare toutes les variables d'entrée utilisées par la configuration racine et les modules (région AWS, nom du projet, identifiants DB, nom de clé SSH, etc.).
*   **`outputs.tf`**: Définit les sorties principales de l'infrastructure (IP publique EC2, endpoint RDS, nom du bucket S3, URL Amplify, etc.).
*   **`providers.tf`**: Configure le provider AWS.
*   **`modules/`**: Contient les modules Terraform réutilisables pour chaque composant logique de l'infrastructure :
    *   `network/`: Gestion des groupes de sécurité.
    *   `ec2-java-tomcat/`: Instance EC2, installation Java/Tomcat, rôle IAM.
    *   `rds-mysql/`: Instance de base de données RDS MySQL.
    *   `s3/`: Bucket S3 pour le stockage.
    *   `ecs-monitoring/`: Cluster ECS avec instance EC2 (t2.micro) pour Prometheus et Grafana.

## Utilisation

L'infrastructure est gérée via le workflow GitHub Actions `1-infra-deploy-destroy.yml`. Ce workflow permet d'exécuter les commandes Terraform (`plan`, `apply`, `destroy`) de manière sécurisée et automatisée.

### Optimisations Free Tier

Plusieurs optimisations ont été réalisées pour rester dans les limites du Free Tier AWS :

* Utilisation d'instances EC2 t2.micro pour l'application Java/Tomcat
* Utilisation d'une instance RDS db.t2.micro pour MySQL
* Utilisation d'ECS avec une instance EC2 t2.micro (au lieu de Fargate qui n'est pas inclus dans le Free Tier) pour le monitoring
* Configuration minimale des ressources pour éviter les coûts supplémentaires

**Prérequis pour le Workflow :**

*   Configurer les secrets GitHub Actions requis (voir `README.md` principal).
*   Fournir les informations demandées lors du déclenchement manuel (nom de la paire de clés EC2, propriétaire et nom du repo GitHub).

**Commandes Manuelles (Local - Non recommandé pour la CI/CD) :**

Si vous souhaitez exécuter Terraform localement (pour tester par exemple) :

1.  Assurez-vous d'avoir configuré vos [credentials AWS](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html).
2.  Naviguez dans le répertoire `infrastructure/`.
3.  Initialisez Terraform : `terraform init`
4.  Créez un fichier `terraform.tfvars` (ignoré par git) pour définir les variables sensibles ou spécifiques :
    ```tfvars
    # terraform.tfvars
    db_username         = "admin"
    db_password         = "votreMotDePasseSecret"
    ec2_key_pair_name   = "votre-cle-ssh-aws"
    github_token        = "votre-token-github-pat" # Correspond au secret GH_PAT dans GitHub Actions
    repo_owner          = "votre-user-github"
    repo_name           = "nom-du-repo"
    # operator_ip         = "votre.ip.publique" # Optionnel si vous voulez restreindre l'accès
    ```

    > **Note importante**: Dans GitHub Actions, nous utilisons le secret `GH_PAT` (et non `GITHUB_TOKEN`) car les noms de secrets personnalisés ne doivent pas commencer par `GITHUB_`. Ce préfixe est réservé aux variables d'environnement intégrées de GitHub Actions.
5.  Planifiez les changements : `terraform plan -var-file=terraform.tfvars`
6.  Appliquez les changements : `terraform apply -var-file=terraform.tfvars`
7.  Pour détruire : `terraform destroy -var-file=terraform.tfvars`

**Important :** Il est fortement recommandé d'utiliser le workflow GitHub Actions pour gérer l'infrastructure en production ou en environnement partagé afin d'assurer la cohérence et la sécurité.
