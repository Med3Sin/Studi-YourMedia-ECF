# Guide d'utilisation des secrets GitHub avec Terraform Cloud

Ce document explique comment configurer et utiliser les secrets GitHub et Terraform Cloud pour les variables sensibles dans le projet YourMédia.

## Problématique

Lors de l'exécution de Terraform via GitHub Actions, certaines variables sensibles (comme les identifiants de base de données, les tokens API, etc.) ne doivent pas être stockées en clair dans le code. Ces variables doivent être fournies de manière sécurisée via les secrets GitHub.

## Variables sensibles requises

Les variables suivantes sont considérées comme sensibles et doivent être configurées en tant que secrets GitHub :

### Secrets à configurer manuellement

| Nom du secret | Description | Utilisé dans | Date d'expiration |
|---------------|-------------|-------------|------------------|
| `AWS_ACCESS_KEY_ID` | Clé d'accès AWS pour l'authentification | Tous les workflows | 10 avril 2025 |
| `AWS_SECRET_ACCESS_KEY` | Clé secrète AWS pour l'authentification | Tous les workflows | 10 avril 2025 |
| `DB_USERNAME` | Nom d'utilisateur pour la base de données RDS | Workflow d'infrastructure | 7 avril 2025 |
| `DB_PASSWORD` | Mot de passe pour la base de données RDS | Workflow d'infrastructure | 7 avril 2025 |
| `EC2_SSH_PRIVATE_KEY` | Clé SSH privée pour se connecter aux instances EC2 | Workflows de déploiement | 11 avril 2025 |
| `EC2_SSH_PUBLIC_KEY` | Clé SSH publique pour configurer l'accès SSH aux instances EC2 | Workflow d'infrastructure | 12 avril 2025 |
| `EC2_KEY_PAIR_NAME` | Nom de la paire de clés EC2 dans AWS | Workflow d'infrastructure | 10 avril 2025 |
| `GH_PAT` | Token d'accès personnel GitHub pour les intégrations | Workflow d'infrastructure | 7 avril 2025 |
| `GF_SECURITY_ADMIN_PASSWORD` | Mot de passe administrateur pour Grafana | Workflow d'infrastructure | 7 avril 2025 |
| `TF_API_TOKEN` | Token d'API pour Terraform Cloud | Workflow d'infrastructure | 10 avril 2025 | **Obligatoire pour l'intégration avec Terraform Cloud** |

## Configuration des secrets GitHub

Pour configurer ces secrets dans votre dépôt GitHub :

1. Accédez à votre dépôt GitHub
2. Cliquez sur "Settings" (Paramètres)
3. Dans le menu de gauche, cliquez sur "Secrets and variables" puis "Actions"
4. Cliquez sur "New repository secret"
5. Entrez le nom du secret (par exemple, `DB_USERNAME`)
6. Entrez la valeur du secret
7. Cliquez sur "Add secret"

Répétez ces étapes pour chaque secret requis.

## Utilisation des secrets dans les workflows GitHub Actions

Les secrets sont référencés dans les workflows GitHub Actions en utilisant la syntaxe `${{ secrets.NOM_DU_SECRET }}`. Par exemple :

```yaml
- name: Terraform Plan
  run: |
    terraform plan \
      -var="db_username=${{ secrets.DB_USERNAME }}" \
      -var="db_password=${{ secrets.DB_PASSWORD }}" \
      -var="ec2_key_pair_name=${{ secrets.EC2_KEY_PAIR_NAME }}" \
      -var="github_token=${{ secrets.GH_PAT }}" \
      -out=tfplan
```

### Automatisation de la paire de clés EC2

Le workflow d'infrastructure a été mis à jour pour utiliser automatiquement le nom de la paire de clés EC2 stocké dans le secret GitHub `EC2_KEY_PAIR_NAME`. Cela élimine la nécessité de saisir manuellement ce paramètre lors de l'exécution du workflow.

## Secrets créés automatiquement

Certains secrets sont créés automatiquement par le workflow d'infrastructure lors de l'exécution de `terraform apply` :

| Nom du secret | Description | Date d'expiration | Environnement |
|---------------|-------------|------------------|---------------|
| `TF_EC2_PUBLIC_IP` | Adresse IP publique de l'instance EC2 hébergeant le backend | 12 avril 2025 | dev, pre-prod, prod |
| `TF_S3_BUCKET_NAME` | Nom du bucket S3 pour le stockage des médias et des builds | 12 avril 2025 | dev, pre-prod, prod |
| `TF_GRAFANA_URL` | URL d'accès à l'interface Grafana | 12 avril 2025 | dev, pre-prod, prod |
| `TF_RDS_ENDPOINT` | Point de terminaison de la base de données RDS | 12 avril 2025 | dev, pre-prod, prod |
| `TF_AMPLIFY_APP_URL` | URL de l'application déployée sur AWS Amplify | 12 avril 2025 | dev, pre-prod, prod |

Ces secrets sont utilisés par les workflows de déploiement des applications pour accéder aux ressources d'infrastructure sans avoir à saisir manuellement ces informations.

## Résolution des problèmes courants

### Erreur : "Error: No value for required variable"

Si vous rencontrez cette erreur lors de l'exécution de Terraform, cela signifie qu'une variable requise n'a pas été fournie. Vérifiez que :

1. Le secret correspondant est correctement configuré dans GitHub
2. Le secret est correctement référencé dans le workflow GitHub Actions
3. La variable est correctement définie dans les fichiers Terraform

### Erreur : "Error: Invalid AWS credentials"

Si vous rencontrez cette erreur, vérifiez que :

1. Les secrets `AWS_ACCESS_KEY_ID` et `AWS_SECRET_ACCESS_KEY` sont correctement configurés
2. Les identifiants AWS ont les permissions nécessaires pour créer les ressources
3. La région AWS spécifiée est correcte

### Erreur : "Error: Error connecting to DB"

Si vous rencontrez cette erreur, vérifiez que :

1. Les secrets `DB_USERNAME` et `DB_PASSWORD` sont correctement configurés
2. Les groupes de sécurité permettent l'accès à la base de données
3. La base de données est en cours d'exécution

## Configuration de Terraform Cloud

Le projet utilise Terraform Cloud pour stocker l'état de l'infrastructure (tfstate) de manière sécurisée. Voici comment cela fonctionne :

1. **Organisation** : L'organisation Terraform Cloud est `Med3Sin`
2. **Workspace** : Un workspace unique `Med3Sin-CLI` est utilisé pour stocker l'état Terraform
3. **Type de workflow** : Nous utilisons un workflow basé sur CLI (Command Line Interface) plutôt qu'un workflow basé sur VCS
4. **Intégration avec GitHub Actions** : Le workflow d'infrastructure utilise le token `TF_API_TOKEN` pour s'authentifier auprès de Terraform Cloud

### Gestion des environnements

Bien que nous utilisions un seul workspace Terraform Cloud, les environnements (dev, pre-prod, prod) sont gérés via la variable `environment` dans Terraform :

1. Lors de l'exécution du workflow, sélectionnez l'environnement souhaité dans le menu déroulant
2. Cette valeur est passée à Terraform via la variable `environment`
3. Toutes les ressources sont créées avec des noms incluant l'environnement (ex: `yourmedia-dev-ec2`, `yourmedia-prod-ec2`)

**Note importante** : Avec cette approche, il faut être prudent lors des opérations de destruction. Assurez-vous de sélectionner le bon environnement pour éviter de détruire des ressources d'un autre environnement.

### Particularités de l'intégration avec Terraform Cloud

Lorsque vous utilisez Terraform Cloud avec un workflow CLI, certaines particularités sont à noter :

1. **Workflow CLI vs VCS** : Nous utilisons un workflow CLI plutôt qu'un workflow VCS. Cela signifie que Terraform Cloud n'est pas directement connecté à notre dépôt GitHub, mais est plutôt contrôlé via les commandes CLI exécutées dans nos workflows GitHub Actions.

2. **Exécution distante** : Les commandes Terraform sont exécutées sur les serveurs de Terraform Cloud, pas localement. Cela signifie que les outputs ne sont pas toujours immédiatement disponibles.

3. **Variables d'environnement** : Les variables sensibles peuvent être stockées directement dans Terraform Cloud, mais nous préférons les gérer via GitHub Secrets pour plus de flexibilité.

4. **Fichiers de plan** : Avec un workflow CLI, nous pouvons utiliser des fichiers de plan sauvegardés (`terraform plan -out=tfplan`), contrairement aux workspaces avec connexion VCS.

### Avantages de cette approche

- **Sécurité** : L'état Terraform est stocké de manière sécurisée dans Terraform Cloud
- **Simplicité** : Un seul workspace à gérer
- **Flexibilité** : Possibilité de déployer plusieurs environnements sans créer de nouveaux workspaces
- **Traçabilité** : Terraform Cloud conserve un historique des exécutions

## Bonnes pratiques

1. **Rotation régulière des secrets** : Changez régulièrement vos secrets, en particulier les clés d'accès AWS et les mots de passe.
2. **Principe du moindre privilège** : Utilisez des identifiants avec le minimum de permissions nécessaires.
3. **Ne jamais exposer les secrets** : Ne jamais afficher les secrets dans les logs ou les outputs des workflows.
4. **Vérification des workflows** : Avant de fusionner des modifications dans les workflows, vérifiez qu'elles ne compromettent pas la sécurité des secrets.
5. **Utilisation des préfixes standardisés** : Tous les secrets générés par Terraform sont préfixés par `TF_` pour une meilleure organisation.
