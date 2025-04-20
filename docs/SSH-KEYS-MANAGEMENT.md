# Gestion des clés SSH dans YourMedia

Ce document explique comment les clés SSH sont gérées dans le projet YourMedia, en particulier comment les problèmes de formatage des clés SSH sont automatiquement corrigés lors du déploiement de l'infrastructure.

## Table des matières

1. [Introduction](#introduction)
2. [Problème des guillemets dans les clés SSH](#problème-des-guillemets-dans-les-clés-ssh)
3. [Solution automatisée](#solution-automatisée)
4. [Fonctionnement du script de correction](#fonctionnement-du-script-de-correction)
5. [Exécution manuelle du script](#exécution-manuelle-du-script)
6. [Vérification des clés SSH](#vérification-des-clés-ssh)

## Introduction

Les clés SSH sont utilisées dans le projet YourMedia pour permettre une connexion sécurisée aux instances EC2 sans mot de passe. Ces clés sont stockées dans le fichier `~/.ssh/authorized_keys` sur les instances EC2.

## Problème des guillemets dans les clés SSH

Un problème courant est l'apparition de guillemets simples (') entourant les clés SSH dans le fichier `authorized_keys`. Ces guillemets peuvent être ajoutés lors du déploiement de l'infrastructure, notamment lorsque les clés SSH sont passées via des variables d'environnement ou des secrets GitHub.

Ces guillemets empêchent la reconnaissance correcte des clés SSH par le serveur SSH, ce qui peut entraîner des problèmes de connexion.

## Solution automatisée

Pour résoudre ce problème, nous avons mis en place une solution automatisée qui :

1. **Prévient le problème** : Les scripts d'initialisation des instances EC2 ont été modifiés pour supprimer automatiquement les guillemets simples des clés SSH avant de les ajouter au fichier `authorized_keys`.

2. **Corrige le problème existant** : Un script de correction des clés SSH est exécuté automatiquement après le déploiement de l'infrastructure pour nettoyer les fichiers `authorized_keys` existants.

3. **Vérifie périodiquement** : Un service systemd est installé sur les instances EC2 pour vérifier et corriger périodiquement le format des clés SSH.

## Fonctionnement du script de correction

Le script de correction des clés SSH (`scripts/fix-ssh-keys.sh`) effectue les opérations suivantes :

1. Se connecte aux instances EC2 via SSH
2. Sauvegarde le fichier `authorized_keys` original
3. Supprime les guillemets simples des clés SSH
4. Vérifie le format des clés SSH et ne conserve que les clés valides
5. Remplace le fichier `authorized_keys` par la version corrigée

## Exécution manuelle de la correction

Si vous souhaitez exécuter manuellement la correction des clés SSH sur une instance EC2, vous pouvez vous connecter à l'instance et exécuter la commande suivante :

```bash
# Se connecter à l'instance EC2
ssh -i votre_cle.pem ec2-user@adresse_ip_instance

# Exécuter le script de correction des clés SSH
/usr/local/bin/fix-ssh-keys.sh
```

Vous pouvez également déclencher le service systemd :

```bash
sudo systemctl start ssh-key-checker.service
```

## Vérification des clés SSH

Pour vérifier que les clés SSH sont correctement formatées sur une instance EC2, vous pouvez vous connecter à l'instance et exécuter la commande suivante :

```bash
cat ~/.ssh/authorized_keys
```

Les clés SSH valides doivent commencer par `ssh-rsa`, `ssh-ed25519`, etc., sans guillemets simples au début ou à la fin.

Si vous constatez des problèmes avec les clés SSH, vous pouvez exécuter manuellement le script de correction ou attendre qu'il soit exécuté automatiquement par le service systemd (toutes les heures par défaut).
