# Guide de dépannage complet pour YourMedia

Ce document centralise toutes les informations de dépannage pour le projet YourMedia.

## 1. Problèmes d'infrastructure AWS

### 1.1. Problèmes de déploiement Terraform

#### Erreur : "No valid credential sources found"

**Symptôme** : Terraform ne peut pas s'authentifier auprès d'AWS.

**Causes possibles** :
- Variables d'environnement AWS_ACCESS_KEY_ID et AWS_SECRET_ACCESS_KEY non définies
- Clés d'accès AWS expirées ou invalides
- Permissions insuffisantes pour le compte AWS

**Solutions** :
1. Vérifier que les variables d'environnement sont correctement définies :
   ```bash
   echo $AWS_ACCESS_KEY_ID
   echo $AWS_SECRET_ACCESS_KEY
   ```
2. Vérifier que les clés d'accès sont valides dans la console AWS
3. Vérifier les permissions IAM du compte utilisé

#### Erreur : "Error creating DB Instance"

**Symptôme** : Terraform ne peut pas créer l'instance RDS.

**Causes possibles** :
- Quota de service AWS atteint
- Groupe de sécurité mal configuré
- Sous-réseau non disponible

**Solutions** :
1. Vérifier les quotas de service dans la console AWS
2. Vérifier la configuration des groupes de sécurité
3. Vérifier la disponibilité des sous-réseaux

#### Erreur lors du vidage du bucket S3

**Problème** : Le workflow de destruction de l'infrastructure échoue avec l'erreur suivante lors de l'étape de vidage du bucket S3 :

```
Run echo "::group::Vidage du bucket S3"
Vidage du bucket S3
  /home/runner/work/_temp/da3b5d38-1c44-4c46-9acf-4545740c1bce.sh: line 3: cd: infrastructure: No such file or directory
  Error: Process completed with exit code 1.
```

**Cause** : Le workflow tente de changer de répertoire vers "infrastructure" alors qu'il est déjà dans ce répertoire. Cela est dû à la configuration du job qui définit déjà le répertoire de travail.

**Solution** : La ligne `cd infrastructure` a été supprimée du script de vidage du bucket S3 dans le fichier `.github/workflows/1-infra-deploy-destroy.yml`.

#### Échec de la destruction de l'infrastructure

**Problème** : La destruction de l'infrastructure échoue avec une erreur concernant le bucket S3 non vide.

**Cause** : Terraform ne peut pas détruire un bucket S3 qui contient des objets.

**Solution** : Le workflow a été modifié pour vider automatiquement le bucket S3 avant de tenter de le détruire. Si le problème persiste, vous pouvez vider manuellement le bucket S3 via la console AWS ou la commande AWS CLI :

```bash
aws s3 rm s3://<NOM_DU_BUCKET> --recursive
```

### 1.2. Problèmes d'instances EC2

#### Erreur : "Instance not reachable"

**Symptôme** : Impossible de se connecter à l'instance EC2 via SSH.

**Causes possibles** :
- Groupe de sécurité ne permettant pas le trafic SSH
- Clé SSH incorrecte
- Instance en cours d'initialisation

**Solutions** :
1. Vérifier les règles entrantes du groupe de sécurité pour le port 22
2. Vérifier que la clé SSH utilisée correspond à celle configurée pour l'instance
3. Vérifier les logs d'initialisation dans la console AWS

#### Erreur : "InvalidID" lors de la création de tags

**Symptôme** : Les scripts d'initialisation échouent avec une erreur "InvalidID" lors de la création de tags.

**Causes possibles** :
- L'ID de l'instance n'est pas correctement récupéré
- Permissions IAM insuffisantes

**Solutions** :
1. Utiliser la méthode IMDSv2 pour récupérer l'ID de l'instance :
   ```bash
   TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
   INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
   ```
2. Vérifier que le rôle IAM de l'instance a les permissions `ec2:DescribeTags` et `ec2:CreateTags`

### 1.3. Problèmes de base de données RDS

#### Erreur : "Cannot connect to database"

**Symptôme** : Les applications ne peuvent pas se connecter à la base de données RDS.

**Causes possibles** :
- Groupe de sécurité RDS mal configuré
- Identifiants de connexion incorrects
- Base de données non disponible

**Solutions** :
1. Vérifier les règles entrantes du groupe de sécurité RDS pour le port 3306
2. Vérifier les identifiants de connexion (RDS_USERNAME, RDS_PASSWORD)
3. Vérifier l'état de l'instance RDS dans la console AWS

## 2. Problèmes Docker

### 2.1. Problèmes de construction d'images

#### Erreur : "Error response from daemon: pull access denied"

**Symptôme** : Impossible de télécharger les images de base lors de la construction.

**Causes possibles** :
- Non authentifié auprès de Docker Hub
- Token Docker Hub expiré
- Limite de téléchargement atteinte pour les utilisateurs non authentifiés

**Solutions** :
1. S'authentifier auprès de Docker Hub :
   ```bash
   echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
   ```
2. Vérifier que le token Docker Hub est valide
3. Utiliser des images de base officielles ou publiques

#### Erreur : "No space left on device"

**Symptôme** : La construction de l'image échoue par manque d'espace disque.

**Causes possibles** :
- Espace disque insuffisant
- Trop d'images ou de conteneurs inutilisés

**Solutions** :
1. Nettoyer les images et conteneurs inutilisés :
   ```bash
   docker system prune -a
   ```
2. Augmenter la taille du volume EBS
3. Optimiser le Dockerfile pour réduire la taille de l'image

### 2.2. Problèmes d'exécution de conteneurs

#### Erreur : "Container exited with code 1"

**Symptôme** : Le conteneur démarre puis s'arrête immédiatement.

**Causes possibles** :
- Erreur dans la commande de démarrage
- Variables d'environnement manquantes
- Problème de permissions

**Solutions** :
1. Vérifier les logs du conteneur :
   ```bash
   docker logs <container_id>
   ```
2. Vérifier que toutes les variables d'environnement requises sont définies
3. Vérifier les permissions des fichiers et répertoires montés

#### Erreur : "Port is already allocated"

**Symptôme** : Impossible de démarrer le conteneur car le port est déjà utilisé.

**Causes possibles** :
- Un autre conteneur utilise déjà le port
- Un processus sur l'hôte utilise déjà le port

**Solutions** :
1. Vérifier les conteneurs en cours d'exécution :
   ```bash
   docker ps
   ```
2. Vérifier les processus utilisant le port :
   ```bash
   sudo lsof -i :<port>
   ```
3. Modifier le mapping de port dans le fichier docker-compose.yml

### 2.3. Problèmes de réseau Docker

#### Erreur : "Network timeout"

**Symptôme** : Les conteneurs ne peuvent pas communiquer entre eux.

**Causes possibles** :
- Réseau Docker mal configuré
- Règles de pare-feu bloquant le trafic
- Problème de résolution DNS

**Solutions** :
1. Vérifier la configuration du réseau Docker :
   ```bash
   docker network inspect bridge
   ```
2. Vérifier les règles de pare-feu
3. Vérifier la résolution DNS :
   ```bash
   docker exec <container_id> ping <other_container_name>
   ```

## 3. Problèmes d'application

### 3.1. Problèmes d'application Java

#### Erreur : "Connection refused to Tomcat"

**Symptôme** : Impossible de se connecter à l'application Java via Tomcat.

**Causes possibles** :
- Tomcat n'est pas démarré
- Port 8080 non ouvert dans le groupe de sécurité
- Application Java non déployée correctement

**Solutions** :
1. Vérifier l'état de Tomcat :
   ```bash
   sudo systemctl status tomcat
   ```
2. Vérifier les règles entrantes du groupe de sécurité pour le port 8080
3. Vérifier les logs Tomcat :
   ```bash
   sudo cat /opt/tomcat/logs/catalina.out
   ```

#### Erreur : "OutOfMemoryError: Java heap space"

**Symptôme** : L'application Java plante avec une erreur de mémoire.

**Causes possibles** :
- Taille du heap Java insuffisante
- Fuite de mémoire dans l'application
- Trop de connexions simultanées

**Solutions** :
1. Augmenter la taille du heap Java :
   ```bash
   export JAVA_OPTS="-Xms256m -Xmx512m"
   ```
2. Analyser l'application pour détecter les fuites de mémoire
3. Limiter le nombre de connexions simultanées dans Tomcat

### 3.2. Problèmes d'application React

#### Erreur : "Failed to compile"

**Symptôme** : L'application React ne se compile pas.

**Causes possibles** :
- Erreurs de syntaxe dans le code
- Dépendances manquantes ou incompatibles
- Configuration webpack incorrecte

**Solutions** :
1. Vérifier les erreurs de compilation dans la console
2. Vérifier les dépendances dans package.json
3. Vérifier la configuration webpack

#### Erreur : "Blank screen after deployment"

**Symptôme** : L'application React affiche un écran blanc après le déploiement.

**Causes possibles** :
- Erreur JavaScript non capturée
- Problème de routing
- Problème de chargement des ressources

**Solutions** :
1. Vérifier la console du navigateur pour les erreurs
2. Vérifier la configuration du routing
3. Vérifier que toutes les ressources sont correctement chargées

### 3.3. Échec du déploiement du backend

**Problème** : Le déploiement du backend échoue avec une erreur SSH.

**Cause** : Problème de connexion SSH à l'instance EC2.

**Solution** :
1. Vérifiez que l'instance EC2 est en cours d'exécution
2. Vérifiez que le groupe de sécurité autorise les connexions SSH (port 22)
3. Vérifiez que la clé SSH privée est correctement configurée dans les secrets GitHub
4. Vérifiez que l'utilisateur SSH est correct (ec2-user pour Amazon Linux)

### 3.4. Échec du déploiement du frontend

**Problème** : Le déploiement du frontend échoue avec une erreur de compilation.

**Cause** : Problème de compilation du code React.

**Solution** :
1. Vérifiez que les dépendances sont correctement installées
2. Vérifiez que le code ne contient pas d'erreurs de syntaxe
3. Vérifiez que les variables d'environnement sont correctement configurées

## 4. Problèmes de workflows GitHub Actions

### 4.1. Problèmes de déploiement

#### Erreur : "Terraform Cloud token is invalid"

**Symptôme** : Le workflow de déploiement échoue avec une erreur d'authentification Terraform Cloud.

**Causes possibles** :
- Token Terraform Cloud expiré ou invalide
- Workspace Terraform Cloud inexistant ou inaccessible

**Solutions** :
1. Vérifier et renouveler le token Terraform Cloud
2. Vérifier l'existence et l'accessibilité du workspace Terraform Cloud
3. Vérifier que le secret TF_API_TOKEN est correctement configuré dans GitHub

#### Erreur : "SSH connection failed"

**Symptôme** : Le workflow ne peut pas se connecter aux instances EC2 via SSH.

**Causes possibles** :
- Clé SSH incorrecte ou mal formatée
- Instance EC2 non accessible
- Problème de réseau

**Solutions** :
1. Vérifier le format de la clé SSH dans le secret EC2_SSH_PRIVATE_KEY
2. Vérifier que l'instance EC2 est en cours d'exécution et accessible
3. Vérifier les règles de groupe de sécurité pour le port 22

### 4.2. Problèmes de construction Docker

#### Erreur : "Docker login failed"

**Symptôme** : Le workflow ne peut pas s'authentifier auprès de Docker Hub.

**Causes possibles** :
- Identifiants Docker Hub incorrects
- Token Docker Hub expiré
- Problème de configuration des secrets GitHub

**Solutions** :
1. Vérifier les identifiants Docker Hub
2. Renouveler le token Docker Hub
3. Vérifier que les secrets DOCKERHUB_USERNAME et DOCKERHUB_TOKEN sont correctement configurés dans GitHub

#### Erreur : "Docker build failed"

**Symptôme** : La construction de l'image Docker échoue dans le workflow.

**Causes possibles** :
- Erreur dans le Dockerfile
- Problème d'accès aux ressources
- Problème de cache Docker

**Solutions** :
1. Vérifier le Dockerfile pour les erreurs
2. Vérifier l'accès aux ressources nécessaires
3. Nettoyer le cache Docker :
   ```yaml
   - name: Clear Docker cache
     run: docker builder prune -af
   ```

### 4.3. Avertissements de commandes dépréciées

**Problème** : Le workflow affiche des avertissements concernant l'utilisation de commandes dépréciées :

```
Warning: The `set-output` command is deprecated and will be disabled soon. Please upgrade to using Environment Files. For more information see: https://github.blog/changelog/2022-10-11-github-actions-deprecating-save-state-and-set-output-commands/
```

**Cause** : L'action `gliech/create-github-secret-action@v1` utilise la commande `set-output` qui est dépréciée par GitHub Actions.

**Solution** : Ces avertissements n'empêchent pas le workflow de fonctionner correctement. Pour les éliminer, il faudrait mettre à jour l'action vers une version plus récente ou utiliser une action alternative qui utilise les fichiers d'environnement au lieu de `set-output`.

## 5. Problèmes de monitoring

### 5.1. Problèmes Prometheus

#### Erreur : "Prometheus targets are down"

**Symptôme** : Les cibles Prometheus apparaissent comme "down" dans l'interface.

**Causes possibles** :
- Exporters non démarrés
- Problème de réseau
- Configuration incorrecte

**Solutions** :
1. Vérifier l'état des exporters :
   ```bash
   docker ps | grep exporter
   ```
2. Vérifier la connectivité réseau :
   ```bash
   docker exec prometheus wget -q -O- http://node-exporter:9100/metrics
   ```
3. Vérifier la configuration dans prometheus.yml

### 5.2. Problèmes Grafana

#### Erreur : "Cannot connect to Prometheus data source"

**Symptôme** : Grafana ne peut pas se connecter à la source de données Prometheus.

**Causes possibles** :
- URL Prometheus incorrecte
- Prometheus non accessible
- Problème d'authentification

**Solutions** :
1. Vérifier l'URL de la source de données Prometheus dans Grafana
2. Vérifier que Prometheus est accessible depuis Grafana
3. Vérifier les logs Grafana :
   ```bash
   docker logs grafana
   ```

#### Erreur : "Dashboard not loading"

**Symptôme** : Les tableaux de bord Grafana ne se chargent pas.

**Causes possibles** :
- Problème de source de données
- JSON du tableau de bord corrompu
- Permissions insuffisantes

**Solutions** :
1. Vérifier l'état des sources de données
2. Vérifier le JSON du tableau de bord
3. Vérifier les permissions de l'utilisateur Grafana

### 5.3. Problèmes de permissions Grafana/Prometheus

**Problème** : Les conteneurs Docker pour Grafana et Prometheus rencontrent des problèmes de permissions lorsqu'ils tentent d'écrire dans les volumes montés.

**Cause** : Les permissions des répertoires de données ne sont pas correctement configurées.

**Solution** : Exécutez le script de correction des permissions :

```bash
# Se connecter à l'instance EC2
ssh ec2-user@<IP_PUBLIQUE_DE_L_INSTANCE>

# Exécuter le script de correction des permissions
sudo /opt/monitoring/fix_permissions.sh
```

### 5.4. Métriques manquantes

**Problème** : Certaines métriques sont manquantes dans Grafana.

**Cause** : Problème de configuration de Prometheus ou des exportateurs.

**Solution** :
1. Vérifiez que Prometheus est en cours d'exécution
2. Vérifiez que les exportateurs sont en cours d'exécution
3. Vérifiez que les cibles sont correctement configurées dans Prometheus
4. Vérifiez que les dashboards Grafana sont correctement configurés

## 6. Problèmes de scripts

### 6.1. Problèmes de scripts d'initialisation

#### Erreur : "Permission denied"

**Symptôme** : Les scripts d'initialisation échouent avec une erreur de permission.

**Causes possibles** :
- Script non exécutable
- Utilisateur sans permissions suffisantes
- SELinux ou AppArmor bloquant l'exécution

**Solutions** :
1. Rendre le script exécutable :
   ```bash
   chmod +x script.sh
   ```
2. Exécuter le script avec sudo
3. Vérifier les logs SELinux ou AppArmor

#### Erreur : "Command not found"

**Symptôme** : Les scripts échouent avec une erreur "command not found".

**Causes possibles** :
- Commande non installée
- Chemin de la commande non dans PATH
- Erreur de syntaxe dans le script

**Solutions** :
1. Installer la commande manquante
2. Utiliser le chemin absolu de la commande
3. Vérifier la syntaxe du script

### 6.2. Problèmes de scripts de déploiement

#### Erreur : "File not found"

**Symptôme** : Les scripts de déploiement ne trouvent pas les fichiers nécessaires.

**Causes possibles** :
- Chemin de fichier incorrect
- Fichier non créé ou supprimé
- Problème de permissions

**Solutions** :
1. Vérifier le chemin du fichier
2. Vérifier que le fichier existe
3. Vérifier les permissions du fichier

#### Erreur : "Deployment failed"

**Symptôme** : Le déploiement échoue sans message d'erreur spécifique.

**Causes possibles** :
- Problème de connexion
- Erreur dans le script
- Problème d'environnement

**Solutions** :
1. Ajouter plus de logs dans le script
2. Exécuter le script avec l'option `-x` pour le débogage
3. Vérifier les variables d'environnement

### 6.3. Problèmes avec les variables dans les templates Terraform

**Problème** : Erreur lors de la validation Terraform indiquant qu'une variable référencée dans un template n'existe pas dans la map de variables.

```
Error: Invalid function argument

Invalid value for "vars" parameter: vars map does not contain key "ec2_java_tomcat_ip", referenced at modules/s3/../ec2-monitoring/scripts/setup.sh:27,14-32.
```

**Cause** : Une variable est référencée dans un template Terraform mais n'est pas définie dans la map de variables passée à la fonction `templatefile()`.

**Solution** : Assurez-vous que toutes les variables référencées dans les templates sont définies dans la map de variables passée à la fonction `templatefile()`.
