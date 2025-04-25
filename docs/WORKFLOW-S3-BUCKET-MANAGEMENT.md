# Gestion du Bucket S3 dans les Workflows GitHub Actions

Ce document décrit les améliorations apportées à la gestion du bucket S3 dans les workflows GitHub Actions du projet YourMédia.

## Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Problème initial](#problème-initial)
3. [Solution implémentée](#solution-implémentée)
4. [Étapes du workflow](#étapes-du-workflow)
5. [Gestion des secrets](#gestion-des-secrets)
6. [Avantages de cette approche](#avantages-de-cette-approche)
7. [Dépannage](#dépannage)

## Vue d'ensemble

Les workflows GitHub Actions du projet YourMédia utilisent un bucket S3 pour stocker et récupérer des scripts et des artefacts. Pour garantir un déploiement fiable, il est essentiel que le bucket S3 soit créé et disponible avant que les scripts ne soient téléchargés.

## Problème initial

Le problème initial était que le workflow tentait de télécharger des scripts dans le bucket S3 avant que celui-ci ne soit créé, ce qui entraînait des erreurs comme :

```
Warning: No outputs found

The state file either has no outputs defined, or all the defined outputs
are empty. Please define an output in your configuration with the `output`
keyword and run `terraform refresh` for it to become available.
```

## Solution implémentée

La solution implémentée consiste en une approche en trois étapes :

1. **Vérification de l'existence du bucket S3** : Vérifier si le bucket S3 existe déjà, soit via les outputs Terraform, soit via le secret GitHub `TF_S3_BUCKET_NAME`.
2. **Création du bucket S3 si nécessaire** : Si le bucket n'existe pas, le créer via Terraform en appliquant spécifiquement le module S3.
3. **Mise à jour du secret GitHub** : Stocker le nom du bucket S3 dans un secret GitHub pour les futures exécutions du workflow.

## Étapes du workflow

### 1. Vérification et création du bucket S3

```yaml
# Étape 7.5: Vérification et création du bucket S3 si nécessaire
- name: Ensure S3 Bucket Exists
  id: ensure_s3
  if: github.event.inputs.action == 'apply'
  run: |
    echo "::group::Vérification et création du bucket S3"
    # Exporter les variables d'environnement AWS
    export AWS_ACCESS_KEY_ID="${{ secrets.AWS_ACCESS_KEY_ID }}"
    export AWS_SECRET_ACCESS_KEY="${{ secrets.AWS_SECRET_ACCESS_KEY }}"
    export AWS_DEFAULT_REGION="${{ env.AWS_REGION }}"

    # Vérifier si le secret TF_S3_BUCKET_NAME est disponible
    if [ ! -z "${{ secrets.TF_S3_BUCKET_NAME }}" ]; then
      echo "Secret TF_S3_BUCKET_NAME trouvé: ${{ secrets.TF_S3_BUCKET_NAME }}"
      S3_BUCKET_NAME="${{ secrets.TF_S3_BUCKET_NAME }}"

      # Vérifier si le bucket existe réellement
      if aws s3api head-bucket --bucket $S3_BUCKET_NAME 2>/dev/null; then
        echo "Le bucket S3 existe: $S3_BUCKET_NAME"
      else
        echo "Le bucket S3 n'existe pas malgré le secret. Création nécessaire..."
        S3_BUCKET_NAME=""
      fi
    else
      echo "Secret TF_S3_BUCKET_NAME non trouvé. Création nécessaire..."
      S3_BUCKET_NAME=""
    fi

    # Si le bucket n'existe pas, le créer via Terraform
    if [ -z "$S3_BUCKET_NAME" ]; then
      echo "Création du bucket S3 via Terraform..."
      # Appliquer uniquement le module S3
      terraform apply -auto-approve -target=module.s3 \
        -var="aws_access_key=${{ secrets.AWS_ACCESS_KEY_ID }}" \
        -var="aws_secret_key=${{ secrets.AWS_SECRET_ACCESS_KEY }}" \
        -var="db_username=${{ secrets.DB_USERNAME }}" \
        -var="db_password=${{ secrets.DB_PASSWORD }}" \
        -var="environment=${{ github.event.inputs.environment || 'dev' }}"

      # Récupérer le nom du bucket S3 après la création
      S3_BUCKET_NAME=$(terraform output -raw s3_bucket_name)

      if [ -z "$S3_BUCKET_NAME" ]; then
        echo "ERREUR: Impossible de récupérer le nom du bucket S3 après création."
        exit 1
      fi

      echo "Bucket S3 créé avec succès: $S3_BUCKET_NAME"
    fi

    # Stocker le nom du bucket pour les étapes suivantes
    echo "S3_BUCKET_NAME=$S3_BUCKET_NAME" >> $GITHUB_ENV
    echo "::endgroup::"
```

### 2. Vérification et mise à jour du secret GitHub

```yaml
# Étape 7.6: Vérifier si le secret doit être mis à jour
- name: Check if Secret Needs Update
  id: check_secret
  if: github.event.inputs.action == 'apply' && env.S3_BUCKET_NAME != ''
  run: |
    # Stocker la valeur du secret dans une variable
    SECRET_VALUE="${{ secrets.TF_S3_BUCKET_NAME }}"

    # Comparer avec la valeur actuelle du bucket S3
    if [ "$SECRET_VALUE" != "${{ env.S3_BUCKET_NAME }}" ]; then
      echo "UPDATE_SECRET=true" >> $GITHUB_ENV
      echo "Le secret TF_S3_BUCKET_NAME doit être mis à jour."
    else
      echo "UPDATE_SECRET=false" >> $GITHUB_ENV
      echo "Le secret TF_S3_BUCKET_NAME est déjà à jour."
    fi

# Étape 7.7: Mise à jour du secret GitHub avec le nom du bucket S3
- name: Update S3 Bucket Name Secret
  id: update_secret
  if: github.event.inputs.action == 'apply' && env.S3_BUCKET_NAME != '' && env.UPDATE_SECRET == 'true'
  uses: gliech/create-github-secret-action@v1
  with:
    name: TF_S3_BUCKET_NAME
    value: ${{ env.S3_BUCKET_NAME }}
    pa_token: ${{ secrets.GH_PAT }}
```

### 3. Téléchargement des scripts dans S3

```yaml
# Étape 7.8: Téléchargement des scripts dans S3
- name: Upload Scripts to S3
  id: upload_scripts
  if: github.event.inputs.action == 'apply' && env.S3_BUCKET_NAME != ''
  run: |
    echo "::group::Téléchargement des scripts dans S3"
    # Créer le fichier de clé SSH si le secret est disponible
    if [ ! -z "${{ secrets.EC2_SSH_PRIVATE_KEY }}" ]; then
      mkdir -p ~/.ssh
      echo "${{ secrets.EC2_SSH_PRIVATE_KEY }}" > ~/.ssh/id_rsa
      chmod 600 ~/.ssh/id_rsa
      echo "Clé SSH privée configurée."
    fi

    echo "Téléchargement des scripts dans le bucket S3: ${{ env.S3_BUCKET_NAME }}"

    # Télécharger les scripts de monitoring
    echo "Téléchargement des scripts de monitoring..."
    aws s3 cp --recursive ./scripts/ec2-monitoring/ s3://${{ env.S3_BUCKET_NAME }}/scripts/ec2-monitoring/

    # Télécharger les scripts Java/Tomcat
    echo "Téléchargement des scripts Java/Tomcat..."
    aws s3 cp --recursive ./scripts/ec2-java-tomcat/ s3://${{ env.S3_BUCKET_NAME }}/scripts/ec2-java-tomcat/

    # Télécharger les scripts Docker
    echo "Téléchargement des scripts Docker..."
    aws s3 cp --recursive ./scripts/docker/ s3://${{ env.S3_BUCKET_NAME }}/scripts/docker/

    echo "Scripts téléchargés avec succès dans le bucket S3: ${{ env.S3_BUCKET_NAME }}"
    echo "::endgroup::"
```

## Gestion des secrets

Le workflow utilise le secret GitHub `TF_S3_BUCKET_NAME` pour stocker le nom du bucket S3 entre les exécutions du workflow. Ce secret est mis à jour automatiquement lorsque le bucket S3 est créé ou modifié.

Pour mettre à jour le secret GitHub, le workflow utilise l'action `gliech/create-github-secret-action@v1` qui nécessite un token d'accès personnel (PAT) avec les permissions appropriées. Ce token est stocké dans le secret GitHub `GH_PAT`.

## Avantages de cette approche

1. **Robustesse** : Vérifie à la fois l'existence du secret et du bucket réel
2. **Efficacité** : Crée uniquement le bucket S3 si nécessaire
3. **Persistance** : Met à jour le secret GitHub pour les futures exécutions
4. **Conditionnalité** : Télécharge les scripts uniquement si le bucket existe
5. **Traçabilité** : Utilise des groupes de logs pour une meilleure lisibilité

## Dépannage

Si vous rencontrez des problèmes avec la gestion du bucket S3 dans le workflow, voici quelques étapes de dépannage :

1. **Vérifier les secrets GitHub** : Assurez-vous que les secrets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` et `GH_PAT` sont correctement configurés.
2. **Vérifier les permissions AWS** : Assurez-vous que l'utilisateur AWS a les permissions nécessaires pour créer et gérer des buckets S3.
3. **Vérifier le module S3 Terraform** : Assurez-vous que le module S3 est correctement configuré et qu'il expose l'output `s3_bucket_name`.
4. **Vérifier les logs du workflow** : Examinez les logs du workflow pour identifier les erreurs spécifiques.

Si le problème persiste, vous pouvez toujours créer manuellement le bucket S3 et configurer le secret GitHub `TF_S3_BUCKET_NAME` avec le nom du bucket.
