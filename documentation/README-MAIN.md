# Documentation Principale - Projet YourMédia

## Vue d'ensemble

Le projet YourMédia est une application de gestion de médias déployée sur AWS. L'infrastructure est entièrement gérée par Terraform et déployée via GitHub Actions.

## Architecture

L'architecture utilise une configuration spécifique de sous-réseaux pour optimiser les performances tout en respectant les contraintes AWS :

- **Sous-réseaux principaux dans eu-west-3a** : Les ressources principales (EC2, RDS, monitoring) sont placées dans la même zone de disponibilité (eu-west-3a) pour minimiser les coûts de transfert de données entre zones.

- **Sous-réseau RDS secondaire dans eu-west-3b** : Un sous-réseau supplémentaire est créé dans une seconde zone de disponibilité uniquement pour satisfaire l'exigence d'AWS RDS qui nécessite des sous-réseaux dans au moins deux zones de disponibilité différentes, même pour une instance mono-AZ.

Cette configuration permet de maintenir toutes les ressources actives dans la même zone de disponibilité tout en respectant les contraintes techniques d'AWS.

## Structure du Projet

```
.
├── app-java/                  # Application backend Java
├── app-react/                 # Application frontend React
├── documentation/             # Documentation centralisée
├── infrastructure/            # Code Terraform pour l'infrastructure
│   ├── modules/               # Modules Terraform réutilisables
│   │   ├── ec2-java-tomcat/   # Module pour l'instance EC2 Java/Tomcat
│   │   ├── ec2-monitoring/    # Module pour l'instance EC2 de monitoring
│   │   ├── network/           # Module pour la configuration réseau
│   │   ├── rds-mysql/         # Module pour la base de données RDS MySQL
│   │   └── s3/                # Module pour le bucket S3
│   ├── main.tf                # Configuration Terraform principale
│   ├── variables.tf           # Variables Terraform
│   └── outputs.tf             # Outputs Terraform
└── .github/workflows/         # Workflows GitHub Actions
```

## Modules Terraform

L'infrastructure est organisée en modules réutilisables pour faciliter la maintenance et l'évolution :

1. **ec2-java-tomcat** : Déploie une instance EC2 avec Java et Tomcat pour héberger l'application backend.
2. **ec2-monitoring** : Déploie une instance EC2 avec Docker, Prometheus et Grafana pour le monitoring.
3. **network** : Configure le VPC, les sous-réseaux, les groupes de sécurité et les tables de routage.
4. **rds-mysql** : Déploie une instance RDS MySQL pour la base de données.
5. **s3** : Crée un bucket S3 pour le stockage des médias et des artefacts de build.

## Optimisations pour le Free Tier AWS

L'architecture est optimisée pour rester dans les limites du Free Tier AWS :

1. **Instances t2.micro/t3.micro** : Utilisation d'instances éligibles au Free Tier.
2. **RDS Single-AZ** : Configuration mono-AZ pour RDS pour réduire les coûts.
3. **Placement des ressources** : Toutes les ressources qui communiquent fréquemment (EC2, RDS) sont placées dans la même zone de disponibilité.
4. **Utilisation de S3** : Le bucket S3 est utilisé principalement pour le stockage des fichiers de configuration et des artefacts de build.
5. **Règles de cycle de vie S3** : Configuration de règles pour nettoyer automatiquement les anciens fichiers.
6. **Conteneurs Docker sur EC2** : Alternative économique à ECS Fargate.

## Considérations sur les coûts de transfert de données AWS

Les frais de transfert de données sont un aspect important de la facturation AWS à prendre en compte :

### Principaux types de transferts de données facturés

- **Transfert sortant (Outbound)** : Données sortant d'AWS vers Internet
- **Transfert entrant (Inbound)** : Données entrantes dans AWS depuis Internet (généralement gratuit)
- **Transfert entre régions AWS** : Données transférées entre différentes régions AWS
- **Transfert entre zones de disponibilité** : Données transférées entre AZ d'une même région
- **Transfert entre services AWS** : Dans certains cas, le transfert entre services AWS peut être facturé

### Points à considérer pour le Free Tier

Dans le cadre du Free Tier AWS :
- 100 Go de transfert de données sortant est généralement gratuit par mois
- Le transfert entrant est généralement gratuit
- Le transfert entre instances EC2 dans la même zone de disponibilité via adresse IP privée est gratuit

## Déploiement

Le déploiement est entièrement automatisé via GitHub Actions :

1. **Workflow Infrastructure** : Déploie l'infrastructure AWS via Terraform.
2. **Workflow Backend** : Compile et déploie l'application Java sur l'instance EC2.
3. **Workflow Frontend** : Déploie l'application React sur AWS Amplify.

## Monitoring

Le monitoring est assuré par Prometheus et Grafana déployés sur une instance EC2 dédiée :

1. **Prometheus** : Collecte les métriques des instances EC2, RDS et de l'application.
2. **Grafana** : Visualise les métriques collectées par Prometheus.
3. **CloudWatch** : Collecte les métriques AWS natives.

## Documentation Détaillée

Pour plus de détails sur chaque composant, consultez les fichiers README spécifiques dans le dossier `documentation` :

- [README-EC2-JAVA-TOMCAT.md](README-EC2-JAVA-TOMCAT.md) : Documentation du module EC2 Java/Tomcat
- [README-EC2-MONITORING.md](README-EC2-MONITORING.md) : Documentation du module EC2 Monitoring
- [README-NETWORK.md](README-NETWORK.md) : Documentation du module Network
- [README-RDS-MYSQL.md](README-RDS-MYSQL.md) : Documentation du module RDS MySQL
- [README-S3.md](README-S3.md) : Documentation du module S3
