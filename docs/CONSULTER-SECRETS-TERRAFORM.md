# Guide pour consulter les secrets GitHub via Terraform Cloud

Ce document explique comment transférer de manière sécurisée les secrets GitHub vers Terraform Cloud pour les consulter.

## Pourquoi utiliser Terraform Cloud pour consulter les secrets ?

1. **Sécurité renforcée** : Les secrets ne sont jamais affichés dans les logs GitHub Actions
2. **Contrôle d'accès** : Terraform Cloud offre une gestion fine des accès aux variables sensibles
3. **Traçabilité** : Toutes les opérations sont enregistrées dans l'historique de Terraform Cloud
4. **Intégration** : Les secrets sont directement disponibles pour vos déploiements Terraform

## Prérequis

1. **Token d'API Terraform Cloud** : Vous devez disposer d'un token d'API Terraform Cloud avec les permissions appropriées
2. **Organisation et espace de travail** : Vous devez avoir créé une organisation et un espace de travail dans Terraform Cloud
3. **Secret GitHub `TF_API_TOKEN`** : Le token d'API Terraform Cloud doit être stocké comme secret GitHub

## Utilisation du workflow

### 1. Exécuter le workflow

1. Accédez à l'onglet "Actions" de votre dépôt GitHub
2. Sélectionnez le workflow "Synchroniser les secrets GitHub vers Terraform Cloud"
3. Cliquez sur "Run workflow"
4. Remplissez les champs suivants :
   - **Organization** : Nom de votre organisation Terraform Cloud (ex: `Med3Sin`)
   - **Workspace ID** : ID de votre espace de travail Terraform Cloud (ex: `ws-xxxxxxxx`)
   - **Secrets to sync** : Liste des secrets GitHub à synchroniser, séparés par des virgules (ex: `AWS_ACCESS_KEY_ID,AWS_SECRET_ACCESS_KEY,AWS_DEFAULT_REGION`)
5. Cliquez sur "Run workflow"

### 2. Consulter les secrets dans Terraform Cloud

1. Connectez-vous à [Terraform Cloud](https://app.terraform.io/)
2. Accédez à votre organisation et à votre espace de travail
3. Cliquez sur "Variables" dans le menu de gauche
4. Les secrets synchronisés apparaissent dans la section "Terraform Variables" ou "Environment Variables"
5. Cliquez sur "Show value" pour afficher la valeur d'un secret

## Mesures de sécurité

### Dans le workflow GitHub Actions

1. **Masquage des valeurs** : Les valeurs complètes des secrets ne sont jamais affichées dans les logs
2. **Fichier temporaire sécurisé** : Les secrets sont stockés dans un fichier temporaire avec des permissions restreintes
3. **Nettoyage automatique** : Le fichier temporaire est supprimé à la fin du workflow, même en cas d'échec
4. **Validation des entrées** : Les entrées utilisateur sont validées avant utilisation

### Dans Terraform Cloud

1. **Variables sensibles** : Les secrets sont marqués comme sensibles dans Terraform Cloud
2. **Contrôle d'accès** : Seuls les utilisateurs autorisés peuvent voir les valeurs des variables sensibles
3. **Audit trail** : Toutes les opérations sont enregistrées dans l'historique de Terraform Cloud

## Bonnes pratiques

1. **Limiter l'accès** : Limitez l'accès au workflow et à Terraform Cloud aux personnes qui en ont besoin
2. **Utiliser des tokens temporaires** : Utilisez des tokens d'API Terraform Cloud à durée limitée
3. **Auditer régulièrement** : Vérifiez régulièrement les accès et les secrets stockés
4. **Supprimer après utilisation** : Si vous n'avez besoin de consulter les secrets qu'une seule fois, supprimez le workflow après utilisation

## Dépannage

### Erreur "Secret not found"

Si un secret n'est pas trouvé, vérifiez que :
1. Le nom du secret est correctement orthographié
2. Le secret existe bien dans les secrets GitHub du dépôt
3. Le workflow a accès au secret (vérifiez les permissions)

### Erreur d'authentification Terraform Cloud

Si vous rencontrez une erreur d'authentification avec Terraform Cloud, vérifiez que :
1. Le token d'API Terraform Cloud est valide
2. Le token a les permissions nécessaires
3. Le secret `TF_API_TOKEN` est correctement configuré dans GitHub

### Erreur "Workspace not found"

Si l'espace de travail n'est pas trouvé, vérifiez que :
1. L'ID de l'espace de travail est correct
2. L'organisation est correcte
3. Le token a accès à cet espace de travail

## Exemple d'utilisation

### Synchroniser les secrets AWS

```
Organization: Med3Sin
Workspace ID: ws-xxxxxxxx
Secrets to sync: AWS_ACCESS_KEY_ID,AWS_SECRET_ACCESS_KEY,AWS_DEFAULT_REGION
```

### Synchroniser les secrets de base de données

```
Organization: Med3Sin
Workspace ID: ws-xxxxxxxx
Secrets to sync: DB_HOST,DB_USERNAME,DB_PASSWORD
```

## Sécurité et confidentialité

⚠️ **ATTENTION** : Ce workflow transfère des informations sensibles de GitHub vers Terraform Cloud. Bien que toutes les précautions soient prises pour garantir la sécurité de ce transfert, vous devez être conscient des risques potentiels :

1. Les secrets sont transmis via HTTPS à l'API Terraform Cloud
2. Les secrets sont stockés dans Terraform Cloud selon leurs politiques de sécurité
3. L'accès aux secrets dépend de la configuration de votre organisation Terraform Cloud

Il est recommandé de consulter les politiques de sécurité de Terraform Cloud et de configurer correctement les contrôles d'accès avant d'utiliser ce workflow.
