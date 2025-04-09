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
* Utilisation de l'AMI `ami-0925eac45db11fef2` (Amazon Linux 2 AMI) pour toutes les instances EC2
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
    >
    > **Instructions détaillées pour créer un GH_PAT** :
    >
    > 1. **Accédez à votre compte GitHub** :
    >    - Connectez-vous à votre compte GitHub
    >    - Cliquez sur votre photo de profil en haut à droite
    >    - Sélectionnez "Settings" (Paramètres)
    >
    > 2. **Accédez aux paramètres développeur** :
    >    - Dans le menu de gauche, faites défiler vers le bas et cliquez sur "Developer settings" (Paramètres développeur)
    >
    > 3. **Créez un nouveau token** :
    >    - Cliquez sur "Personal access tokens" (Tokens d'accès personnels)
    >    - Sélectionnez "Tokens (classic)"
    >    - Cliquez sur "Generate new token" (Générer un nouveau token)
    >    - Sélectionnez "Generate new token (classic)"
    >
    > 4. **Configurez le token** :
    >    - Donnez un nom descriptif à votre token (par exemple "YourMedia Terraform Amplify")
    >    - Définissez une date d'expiration (recommandé : 90 jours)
    >    - Sélectionnez les autorisations nécessaires :
    >      - `repo` (accès complet au dépôt)
    >      - `admin:repo_hook` (pour les webhooks Amplify)
    >    - Faites défiler vers le bas et cliquez sur "Generate token" (Générer le token)
    >
    > 5. **Copiez le token** :
    >    - **IMPORTANT** : Copiez immédiatement le token généré. Vous ne pourrez plus le voir après avoir quitté cette page.
5.  Planifiez les changements : `terraform plan -var-file=terraform.tfvars`
6.  Appliquez les changements : `terraform apply -var-file=terraform.tfvars`
7.  Pour détruire : `terraform destroy -var-file=terraform.tfvars`

**Important :** Il est fortement recommandé d'utiliser le workflow GitHub Actions pour gérer l'infrastructure en production ou en environnement partagé afin d'assurer la cohérence et la sécurité.

### Stockage sécurisé de l'état Terraform avec Terraform Cloud

Ce projet utilise Terraform Cloud pour stocker de manière sécurisée l'état Terraform. Cette approche offre plusieurs avantages :

1. **Sécurité renforcée** : L'état Terraform est stocké de manière chiffrée et sécurisée.
2. **Gestion des secrets** : Les variables sensibles sont stockées de manière sécurisée.
3. **Verrouillage d'état** : Empêche les modifications simultanées de l'infrastructure.
4. **Historique des exécutions** : Toutes les exécutions sont enregistrées et peuvent être consultées.
5. **Collaboration facilitée** : Plusieurs membres de l'équipe peuvent travailler sur l'infrastructure.

#### Configuration pour le développement local

Pour utiliser Terraform Cloud en local :

1. **Créez un compte** sur [Terraform Cloud](https://app.terraform.io/signup/account).
2. **Créez une organisation** nommée `Med3Sin` (ou modifiez le nom dans `backend.tf`).
3. **Créez un workspace** nommé `Med3Sin`.
4. **Générez un token API** dans Terraform Cloud (User Settings > Tokens).
5. **Connectez-vous via la ligne de commande** :
   ```bash
   terraform login
   ```
   Ou créez un fichier de configuration avec votre token :
   ```bash
   # Pour Linux/macOS : ~/.terraformrc
   # Pour Windows : %APPDATA%\terraform.rc
   credentials "app.terraform.io" {
     token = "votre-token-api"
   }
   ```
6. **Initialisez Terraform** :
   ```bash
   terraform init
   ```

#### Configuration pour GitHub Actions

Le workflow GitHub Actions est configuré pour utiliser Terraform Cloud :

1. **Ajoutez le secret `TF_API_TOKEN`** dans les secrets GitHub avec votre token API Terraform Cloud.
2. **Créez un environnement GitHub** nommé `approval` avec des règles d'approbation :
   - Allez dans Settings > Environments > New environment
   - Nom : `approval`
   - Activez "Required reviewers" et ajoutez les personnes qui peuvent approuver les déploiements

#### Workflow avec approbation

Le workflow GitHub Actions est structuré en trois étapes :

1. **Plan** : Génère un plan des modifications à apporter à l'infrastructure.
2. **Approbation** : Requiert une approbation manuelle avant de continuer.
3. **Apply/Destroy** : Applique ou détruit l'infrastructure après approbation.

Cette approche garantit qu'aucune modification n'est apportée à l'infrastructure sans une vérification humaine préalable.
