# Guide pour consulter les secrets GitHub en toute sécurité

Ce document explique comment consulter les secrets GitHub de manière sécurisée à l'aide du workflow temporaire `view-secret-securely.yml`.

## Avertissement de sécurité

⚠️ **ATTENTION** ⚠️

La consultation des secrets GitHub doit être effectuée avec une extrême prudence :

- Les secrets sont des informations sensibles qui doivent rester confidentielles
- La consultation d'un secret l'expose temporairement dans les logs du workflow
- Cette exposition est journalisée et peut être auditée
- Utilisez cette fonctionnalité uniquement lorsque c'est absolument nécessaire
- Supprimez le workflow immédiatement après utilisation

## Prérequis

- Avoir les permissions d'administrateur sur le dépôt GitHub
- Avoir activé l'authentification multi-facteurs (MFA) sur votre compte GitHub
- Utiliser un ordinateur personnel sécurisé et une connexion réseau privée

## Procédure pour consulter un secret

1. **Accédez à l'onglet Actions de votre dépôt GitHub**
   - Allez sur `https://github.com/Med3Sin/Studi-YourMedia-ECF/actions`

2. **Sélectionnez le workflow "Consulter un Secret en Toute Sécurité"**
   - Cliquez sur "Consulter un Secret en Toute Sécurité" dans la liste des workflows

3. **Lancez le workflow**
   - Cliquez sur le bouton "Run workflow"
   - Dans le champ "Nom du secret à consulter", entrez le nom exact du secret (ex: `AWS_ACCESS_KEY_ID`)
   - Dans le champ "Tapez CONFIRMER pour confirmer", entrez exactement `CONFIRMER` (en majuscules)
   - Cliquez sur le bouton "Run workflow" vert

4. **Consultez le résultat**
   - Attendez que le workflow se termine (généralement moins d'une minute)
   - Cliquez sur l'exécution du workflow qui vient de se terminer
   - Développez la section "view-secret" puis "Afficher le secret de manière sécurisée"
   - La valeur du secret sera affichée dans cette section

5. **Supprimez immédiatement le workflow après utilisation**
   - Retournez à la racine de votre dépôt
   - Accédez au fichier `.github/workflows/view-secret-securely.yml`
   - Cliquez sur l'icône de suppression (corbeille)
   - Ajoutez un message de commit comme "Suppression du workflow temporaire de consultation des secrets"
   - Cliquez sur "Commit changes"

## Bonnes pratiques de sécurité

1. **Limitez la fréquence de consultation des secrets** au strict minimum
2. **Changez les secrets** après les avoir consultés si possible
3. **Ne partagez jamais les valeurs des secrets** via des canaux non sécurisés
4. **Vérifiez les logs d'audit GitHub** pour surveiller l'accès aux secrets
5. **Utilisez des secrets temporaires** lorsque c'est possible
6. **Supprimez immédiatement ce workflow** après chaque utilisation

## Alternatives plus sécurisées

Dans la mesure du possible, privilégiez ces alternatives plus sécurisées :

1. **Régénérer le secret** plutôt que de consulter sa valeur actuelle
2. **Utiliser des variables d'environnement** pour passer les secrets aux applications
3. **Utiliser un gestionnaire de secrets** comme HashiCorp Vault ou AWS Secrets Manager
4. **Mettre en place une rotation automatique des secrets** pour éviter d'avoir à les consulter

## En cas de compromission d'un secret

Si vous pensez qu'un secret a été compromis :

1. **Désactivez immédiatement le secret** auprès du service concerné
2. **Générez un nouveau secret** pour remplacer l'ancien
3. **Mettez à jour le secret dans GitHub** avec la nouvelle valeur
4. **Vérifiez les logs d'activité** pour détecter toute utilisation non autorisée
5. **Documentez l'incident** et les mesures prises
