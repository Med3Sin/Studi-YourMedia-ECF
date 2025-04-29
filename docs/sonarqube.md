# SonarQube

## Description

SonarQube est une plateforme d'analyse de code qui permet de détecter les bugs, les vulnérabilités et les problèmes de qualité du code. Dans ce projet, SonarQube est déployé sur une instance EC2 dédiée pour garantir des performances optimales.

## Architecture

SonarQube est déployé sur une instance EC2 dédiée avec les caractéristiques suivantes :
- Type d'instance : t2.small (2 vCPU, 2 Go de RAM)
- Système d'exploitation : Amazon Linux 2023
- Base de données : PostgreSQL 15 (installée localement sur l'instance)
- Volume EBS : 30 Go (gp3)

## Déploiement

Le déploiement de SonarQube est géré par Terraform via le module `ec2-sonarqube`. Ce module crée l'instance EC2, configure les groupes de sécurité, et installe SonarQube et ses dépendances.

### Prérequis

- Un VPC avec au moins un sous-réseau public
- Une paire de clés SSH pour l'accès à l'instance
- Un bucket S3 pour stocker les scripts de configuration

### Variables Terraform

Les principales variables du module `ec2-sonarqube` sont :

| Variable | Description | Valeur par défaut |
|----------|-------------|------------------|
| `project_name` | Nom du projet | - |
| `environment` | Environnement (dev, pre-prod, prod) | `dev` |
| `instance_type` | Type d'instance EC2 | `t2.small` |
| `root_volume_size` | Taille du volume racine en Go | `30` |
| `db_username` | Nom d'utilisateur pour la base de données PostgreSQL | `sonar` |
| `db_password` | Mot de passe pour la base de données PostgreSQL | - |
| `sonar_admin_password` | Mot de passe administrateur SonarQube | `admin` |

## Accès à SonarQube

Une fois déployé, SonarQube est accessible à l'adresse suivante :
```
http://<IP_PUBLIQUE_INSTANCE>:9000
```

Les identifiants par défaut sont :
- Utilisateur : `admin`
- Mot de passe : `admin`

**Important** : Lors de la première connexion, vous devez changer le mot de passe administrateur.

## Configuration

### Configuration de SonarQube

SonarQube est configuré avec les paramètres suivants :
- Base de données : PostgreSQL local
- Mémoire JVM : 512 Mo pour le serveur web, 512 Mo pour le moteur de calcul, 512 Mo pour Elasticsearch

### Configuration de la base de données

La base de données PostgreSQL est configurée avec les paramètres suivants :
- Nom de la base de données : `sonar`
- Utilisateur : défini par la variable `db_username`
- Mot de passe : défini par la variable `db_password`

## Sécurité

L'instance SonarQube est sécurisée avec les mesures suivantes :
- Groupe de sécurité dédié qui limite l'accès aux ports 22 (SSH) et 9000 (SonarQube)
- Accès SSH limité aux adresses IP autorisées
- Volumes EBS chiffrés

## Maintenance

### Sauvegarde

Pour sauvegarder SonarQube, vous devez sauvegarder :
1. La base de données PostgreSQL
2. Le répertoire `/opt/sonarqube/data`
3. Le répertoire `/opt/sonarqube/extensions`

### Mise à jour

Pour mettre à jour SonarQube :
1. Arrêtez le service SonarQube : `sudo systemctl stop sonarqube`
2. Sauvegardez les données (voir ci-dessus)
3. Téléchargez la nouvelle version de SonarQube
4. Remplacez les fichiers de l'installation
5. Démarrez le service SonarQube : `sudo systemctl start sonarqube`

## Intégration avec CI/CD

Pour intégrer SonarQube à votre pipeline CI/CD, vous devez :
1. Générer un token d'accès dans SonarQube
2. Configurer votre pipeline CI/CD pour utiliser ce token
3. Ajouter l'analyse SonarQube à votre pipeline

Exemple de configuration pour GitHub Actions :
```yaml
jobs:
  sonarqube:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0
      - name: SonarQube Scan
        uses: SonarSource/sonarqube-scan-action@master
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
          SONAR_HOST_URL: http://<IP_PUBLIQUE_INSTANCE>:9000
```

## Dépannage

### Problèmes courants

1. **SonarQube ne démarre pas**
   - Vérifiez les logs : `sudo journalctl -u sonarqube`
   - Vérifiez les limites système : `sysctl -a | grep vm.max_map_count`

2. **Impossible de se connecter à SonarQube**
   - Vérifiez que le service est en cours d'exécution : `sudo systemctl status sonarqube`
   - Vérifiez que le port 9000 est ouvert dans le groupe de sécurité

3. **Problèmes de base de données**
   - Vérifiez que PostgreSQL est en cours d'exécution : `sudo systemctl status postgresql`
   - Vérifiez les logs PostgreSQL : `sudo tail -f /var/log/postgresql/postgresql-15-main.log`
