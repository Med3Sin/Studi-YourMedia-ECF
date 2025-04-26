# Mise à jour des GitHub Actions

Ce document décrit les mises à jour apportées aux workflows GitHub Actions pour résoudre les problèmes de dépréciation.

## Problème identifié

GitHub a déprécié la commande `set-output` utilisée par certaines actions, comme indiqué dans l'avertissement suivant :

```
Warning: The `set-output` command is deprecated and will be disabled soon. Please upgrade to using Environment Files. For more information see: https://github.blog/changelog/2022-10-11-github-actions-deprecating-save-state-and-set-output-commands/
```

L'action `gliech/create-github-secret-action@v1` utilisait cette commande dépréciée, ce qui générait des avertissements lors de l'exécution des workflows.

## Solution mise en œuvre

Nous avons remplacé l'action `gliech/create-github-secret-action@v1` par une implémentation personnalisée utilisant directement l'API GitHub pour créer des secrets. Cette approche présente plusieurs avantages :

1. Elle n'utilise pas de commandes dépréciées
2. Elle offre plus de contrôle sur le processus de création de secrets
3. Elle est plus transparente et maintenable

### Modifications apportées

Dans le workflow `1-infra-deploy-destroy.yml`, nous avons remplacé :

```yaml
- name: Update S3 Bucket Name Secret
  id: update_secret
  if: github.event.inputs.action == 'apply' && env.S3_BUCKET_NAME != '' && env.UPDATE_SECRET == 'true'
  uses: gliech/create-github-secret-action@v1
  with:
    name: TF_S3_BUCKET_NAME
    value: ${{ env.S3_BUCKET_NAME }}
    pa_token: ${{ secrets.GH_PAT }}
```

Par une implémentation personnalisée :

```yaml
- name: Update S3 Bucket Name Secret
  id: update_secret
  if: github.event.inputs.action == 'apply' && env.S3_BUCKET_NAME != '' && env.UPDATE_SECRET == 'true'
  env:
    GH_TOKEN: ${{ secrets.GH_PAT }}
    SECRET_NAME: TF_S3_BUCKET_NAME
    SECRET_VALUE: ${{ env.S3_BUCKET_NAME }}
    REPO: ${{ github.repository }}
  run: |
    # Récupérer la clé publique du dépôt
    echo "Récupération de la clé publique pour le dépôt '$REPO'..."
    PUBLIC_KEY_RESPONSE=$(curl -s -X GET \
      -H "Authorization: token $GH_TOKEN" \
      -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/repos/$REPO/actions/secrets/public-key")
    
    # Extraire la clé publique et son ID
    KEY_ID=$(echo "$PUBLIC_KEY_RESPONSE" | jq -r '.key_id')
    PUBLIC_KEY=$(echo "$PUBLIC_KEY_RESPONSE" | jq -r '.key')
    
    if [ -z "$KEY_ID" ] || [ "$KEY_ID" == "null" ]; then
      echo "Erreur: Impossible de récupérer la clé publique. Réponse: $PUBLIC_KEY_RESPONSE"
      exit 1
    fi
    
    echo "Clé publique récupérée avec succès."
    
    # Installer les dépendances nécessaires pour le chiffrement
    echo "Installation des dépendances pour le chiffrement..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq python3-pip libsodium-dev
    pip3 install -q pynacl
    
    # Chiffrer la valeur du secret
    echo "Chiffrement de la valeur du secret..."
    ENCRYPTED_VALUE=$(python3 -c "
    import base64
    import json
    from nacl import encoding, public
    
    def encrypt(public_key, secret_value):
        public_key = public.PublicKey(public_key.encode('utf-8'), encoding.Base64Encoder())
        sealed_box = public.SealedBox(public_key)
        encrypted = sealed_box.encrypt(secret_value.encode('utf-8'))
        return base64.b64encode(encrypted).decode('utf-8')
    
    print(encrypt('$PUBLIC_KEY', '$SECRET_VALUE'))
    ")
    
    # Mettre à jour le secret
    echo "Mise à jour du secret '$SECRET_NAME'..."
    curl -s -X PUT \
      -H "Authorization: token $GH_TOKEN" \
      -H "Accept: application/vnd.github.v3+json" \
      -H "Content-Type: application/json" \
      -d "{\"encrypted_value\":\"$ENCRYPTED_VALUE\",\"key_id\":\"$KEY_ID\"}" \
      "https://api.github.com/repos/$REPO/actions/secrets/$SECRET_NAME"
    
    echo "Secret '$SECRET_NAME' mis à jour avec succès."
```

### Autres modifications

Nous avons également corrigé l'utilisation de `${{ env.S3_BUCKET_NAME }}` dans les scripts shell en remplaçant par `${S3_BUCKET_NAME}` pour éviter les avertissements de l'IDE.

## Comment tester les modifications

1. Exécutez le workflow `1-infra-deploy-destroy.yml` avec l'action `apply` pour créer l'infrastructure
2. Vérifiez que le secret `TF_S3_BUCKET_NAME` est correctement créé dans les secrets du dépôt GitHub
3. Vérifiez qu'aucun avertissement concernant `set-output` n'apparaît dans les logs du workflow

## Références

- [GitHub Blog: Deprecating save-state and set-output commands](https://github.blog/changelog/2022-10-11-github-actions-deprecating-save-state-and-set-output-commands/)
- [GitHub API: Create or update a repository secret](https://docs.github.com/en/rest/actions/secrets#create-or-update-a-repository-secret)
- [GitHub API: Get a repository public key](https://docs.github.com/en/rest/actions/secrets#get-a-repository-public-key)
