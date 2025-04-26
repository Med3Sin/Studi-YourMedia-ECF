# Guide de déploiement d'applications WAR sur Tomcat

Ce document explique comment les applications WAR sont déployées sur l'instance EC2 Java Tomcat dans l'infrastructure YourMedia. Cette instance est dédiée à l'exécution de l'application backend Java via Tomcat et ne contient pas Docker.

## Problématique des permissions

L'un des défis courants lors du déploiement d'applications WAR sur Tomcat est la gestion des permissions. Le serveur Tomcat s'exécute sous l'utilisateur `tomcat`, tandis que les connexions SSH se font généralement avec l'utilisateur `ec2-user`. Cela crée un problème de permissions, car `ec2-user` n'a pas les droits nécessaires pour écrire dans le répertoire `/opt/tomcat/webapps/` qui appartient à l'utilisateur `tomcat`.

## Configuration de l'instance EC2 Java Tomcat

L'instance EC2 Java Tomcat est configurée avec les composants suivants :

1. **Java** : Amazon Corretto 17
2. **Tomcat** : Version 9.0.87 (installée par défaut)
3. **Node Exporter** : Pour la collecte de métriques système par Prometheus

Cette instance ne contient pas Docker et n'exécute pas de conteneurs. Elle est dédiée uniquement à l'exécution de l'application Java via Tomcat.

## Solution mise en place pour le déploiement

Pour résoudre le problème des permissions lors du déploiement d'applications WAR, nous avons implémenté une solution basée sur un script de déploiement dédié qui s'exécute avec les privilèges `sudo`. Cette approche offre plusieurs avantages :

1. **Sécurité** : Limite les commandes sudo à un script spécifique
2. **Fiabilité** : Garantit que les fichiers WAR sont correctement déployés avec les bonnes permissions
3. **Maintenabilité** : Centralise la logique de déploiement dans un seul endroit

### Script de déploiement WAR

Le script `/usr/local/bin/deploy-war.sh` est automatiquement créé lors de l'initialisation de l'instance EC2 via le script `install_java_tomcat.sh`. Ce script :

1. Copie le fichier WAR dans le répertoire `/opt/tomcat/webapps/`
2. Change le propriétaire du fichier WAR pour `tomcat:tomcat`
3. Redémarre le service Tomcat pour appliquer les changements

```bash
#!/bin/bash
# Script pour déployer un fichier WAR dans Tomcat
# Ce script doit être exécuté avec sudo

# Vérifier si un argument a été fourni
if [ $# -ne 1 ]; then
  echo "Usage: $0 <chemin_vers_war>"
  exit 1
fi

WAR_PATH=$1
WAR_NAME=$(basename $WAR_PATH)
TARGET_NAME="yourmedia-backend.war"

echo "Déploiement du fichier WAR: $WAR_PATH vers /opt/tomcat/webapps/$TARGET_NAME"

# Vérifier si le fichier existe
if [ ! -f "$WAR_PATH" ]; then
  echo "ERREUR: Le fichier $WAR_PATH n'existe pas"
  exit 1
fi

# Copier le fichier WAR dans webapps
cp $WAR_PATH /opt/tomcat/webapps/$TARGET_NAME

# Changer le propriétaire
chown tomcat:tomcat /opt/tomcat/webapps/$TARGET_NAME

# Redémarrer Tomcat
systemctl restart tomcat

echo "Déploiement terminé avec succès"
exit 0
```

### Configuration de sudoers

Pour permettre à l'utilisateur `ec2-user` d'exécuter le script de déploiement sans mot de passe, une entrée est ajoutée dans le fichier `/etc/sudoers.d/deploy-war` :

```
ec2-user ALL=(ALL) NOPASSWD: /usr/local/bin/deploy-war.sh
```

Cette configuration permet à `ec2-user` d'exécuter uniquement le script `/usr/local/bin/deploy-war.sh` avec `sudo` sans avoir à fournir de mot de passe.

## Workflow de déploiement

Le workflow GitHub Actions `2-backend-deploy.yml` utilise cette solution pour déployer l'application WAR sur l'instance EC2 :

1. Le fichier WAR est compilé avec Maven
2. Le WAR est téléchargé sur S3
3. Le workflow se connecte à l'instance EC2 via SSH
4. Le WAR est téléchargé depuis S3 vers un emplacement temporaire sur l'instance EC2
5. Le script `deploy-war.sh` est exécuté avec `sudo` pour déployer le WAR dans Tomcat
6. Le fichier temporaire est supprimé

```yaml
# Extrait du workflow
ssh -o StrictHostKeyChecking=no ec2-user@${{ secrets.EC2_HOST }} << EOF
  # Télécharger le WAR depuis S3
  aws s3 cp s3://$BUCKET_NAME/builds/backend/$DEPLOY_WAR_NAME /tmp/$DEPLOY_WAR_NAME

  # Utiliser le script de déploiement WAR
  sudo /usr/local/bin/deploy-war.sh /tmp/$DEPLOY_WAR_NAME

  # Supprimer le fichier temporaire
  rm /tmp/$DEPLOY_WAR_NAME
EOF
```

## Avantages de cette approche

1. **Sécurité renforcée** : L'utilisateur `ec2-user` n'a pas besoin d'avoir des droits d'écriture dans le répertoire `/opt/tomcat/webapps/`
2. **Simplicité** : Le workflow de déploiement est simplifié et plus robuste
3. **Auditabilité** : Les opérations de déploiement sont clairement définies dans un script dédié
4. **Automatisation** : Le script est automatiquement installé lors de l'initialisation de l'instance EC2

## Dépannage

Si vous rencontrez des problèmes lors du déploiement, vérifiez les points suivants :

1. **Permissions du script** : Vérifiez que le script `/usr/local/bin/deploy-war.sh` est exécutable et appartient à `root:root`
   ```bash
   ls -la /usr/local/bin/deploy-war.sh
   ```

2. **Configuration de sudoers** : Vérifiez que l'entrée dans `/etc/sudoers.d/deploy-war` est correcte
   ```bash
   sudo cat /etc/sudoers.d/deploy-war
   ```

3. **Logs Tomcat** : Consultez les logs Tomcat pour voir si des erreurs se produisent lors du déploiement
   ```bash
   sudo tail -f /opt/tomcat/logs/catalina.out
   ```

4. **Permissions du répertoire webapps** : Vérifiez que le répertoire `/opt/tomcat/webapps/` appartient à `tomcat:tomcat`
   ```bash
   ls -la /opt/tomcat/webapps/
   ```
