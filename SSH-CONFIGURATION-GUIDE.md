# Guide de configuration SSH pour le déploiement sur EC2

Ce guide explique comment configurer SSH pour permettre au workflow GitHub Actions de se connecter à l'instance EC2 et déployer l'application backend.

## Table des matières

1. [Prérequis](#prérequis)
2. [Génération d'une paire de clés SSH](#génération-dune-paire-de-clés-ssh)
3. [Configuration de la clé publique sur l'instance EC2](#configuration-de-la-clé-publique-sur-linstance-ec2)
4. [Configuration de la clé privée dans GitHub Secrets](#configuration-de-la-clé-privée-dans-github-secrets)
5. [Vérification de la configuration](#vérification-de-la-configuration)
6. [Résolution des problèmes](#résolution-des-problèmes)

## Prérequis

- Accès à l'instance EC2 via la console AWS
- Accès aux paramètres du dépôt GitHub

## Génération d'une paire de clés SSH

Vous pouvez générer une paire de clés SSH sur votre machine locale ou directement sur l'instance EC2.

### Sur votre machine locale

```bash
# Génération d'une paire de clés SSH
ssh-keygen -t rsa -b 4096 -f ~/.ssh/yourmedia_ec2_key -N ""

# Affichage de la clé publique
cat ~/.ssh/yourmedia_ec2_key.pub

# Affichage de la clé privée
cat ~/.ssh/yourmedia_ec2_key
```

### Sur l'instance EC2 via la console AWS

1. Connectez-vous à l'instance EC2 via la console AWS (Connect to instance)
2. Exécutez les commandes suivantes :

```bash
# Génération d'une paire de clés SSH
ssh-keygen -t rsa -b 4096 -f ~/.ssh/github_actions_key -N ""

# Affichage de la clé publique
cat ~/.ssh/github_actions_key.pub

# Affichage de la clé privée
cat ~/.ssh/github_actions_key
```

## Configuration de la clé publique sur l'instance EC2

Vous devez ajouter la clé publique au fichier `~/.ssh/authorized_keys` de l'utilisateur `ec2-user` sur l'instance EC2.

```bash
# Connectez-vous à l'instance EC2 via la console AWS

# Créer le répertoire .ssh s'il n'existe pas
mkdir -p ~/.ssh

# Créer ou ouvrir le fichier authorized_keys
nano ~/.ssh/authorized_keys

# Ajouter la clé publique (coller la clé publique générée précédemment)
# Sauvegarder le fichier (Ctrl+O, puis Entrée, puis Ctrl+X)

# Définir les permissions correctes
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

Si vous avez généré la clé sur l'instance EC2, vous pouvez ajouter la clé publique au fichier `authorized_keys` avec la commande suivante :

```bash
cat ~/.ssh/github_actions_key.pub >> ~/.ssh/authorized_keys
```

## Configuration de la clé privée dans GitHub Secrets

Vous devez ajouter la clé privée comme secret GitHub pour que le workflow puisse l'utiliser.

1. Allez dans les paramètres du dépôt GitHub (Settings)
2. Cliquez sur "Secrets and variables" puis "Actions"
3. Cliquez sur "New repository secret"
4. Nom du secret : `EC2_SSH_PRIVATE_KEY`
5. Valeur du secret : Collez la clé privée générée précédemment (contenu du fichier `~/.ssh/yourmedia_ec2_key` ou `~/.ssh/github_actions_key`)
6. Cliquez sur "Add secret"

## Vérification de la configuration

Pour vérifier que la configuration SSH fonctionne correctement, vous pouvez exécuter le workflow de déploiement backend.

1. Allez dans l'onglet "Actions" du dépôt GitHub
2. Sélectionnez le workflow "2 - Build and Deploy Backend (Java WAR)"
3. Cliquez sur "Run workflow"
4. Vérifiez que le workflow s'exécute correctement et que la connexion SSH fonctionne

## Résolution des problèmes

### Erreur "Permission denied (publickey,gssapi-keyex,gssapi-with-mic)"

Cette erreur indique que la clé SSH n'est pas autorisée à se connecter à l'instance EC2. Vérifiez que :

1. La clé publique est bien ajoutée au fichier `~/.ssh/authorized_keys` de l'utilisateur `ec2-user` sur l'instance EC2
2. Les permissions du répertoire `~/.ssh` et du fichier `authorized_keys` sont correctes
3. La clé privée est bien configurée dans le secret GitHub `EC2_SSH_PRIVATE_KEY`
4. La clé privée est au format correct (commence par `-----BEGIN RSA PRIVATE KEY-----` et se termine par `-----END RSA PRIVATE KEY-----`)

### Vérification des clés SSH sur l'instance EC2

Pour vérifier les clés SSH autorisées sur l'instance EC2, connectez-vous à l'instance et exécutez :

```bash
cat ~/.ssh/authorized_keys
```

### Vérification du format de la clé privée

La clé privée doit être au format PEM et commencer par `-----BEGIN RSA PRIVATE KEY-----`. Si ce n'est pas le cas, vous pouvez convertir la clé avec la commande suivante :

```bash
ssh-keygen -p -m PEM -f ~/.ssh/yourmedia_ec2_key
```

### Vérification des logs SSH sur l'instance EC2

Pour voir les logs SSH sur l'instance EC2 et identifier les problèmes de connexion, exécutez :

```bash
sudo tail -f /var/log/secure
```

Cela affichera les tentatives de connexion SSH et les erreurs éventuelles.
