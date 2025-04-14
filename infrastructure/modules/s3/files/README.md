# Fichiers de configuration pour le monitoring

Les fichiers de configuration pour le monitoring sont maintenant définis dans le répertoire
`infrastructure/modules/ec2-monitoring/scripts` pour éviter la duplication.

Le module S3 référence ces fichiers directement depuis le module ec2-monitoring via la variable
`monitoring_scripts_path` qui est définie dans le fichier `infrastructure/main.tf`.

Ces fichiers ont été supprimés car ils étaient dupliqués avec ceux du répertoire
`infrastructure/modules/ec2-monitoring/scripts`.

## Considérations sur les coûts de transfert de données AWS

Le stockage S3 implique des coûts de transfert de données qu'il est important de comprendre :

### Principaux types de transferts de données facturés par AWS

- **Transfert sortant (Outbound)** : Données sortant d'AWS vers Internet
  - C'est généralement le transfert le plus coûteux
  - Les tarifs varient selon les régions et le volume

- **Transfert entrant (Inbound)** : Données entrantes dans AWS depuis Internet
  - Généralement gratuit dans la plupart des services

- **Transfert entre régions AWS** : Données transférées entre différentes régions AWS
  - Facturé dans les deux régions (source et destination)

- **Transfert entre zones de disponibilité** : Données transférées entre AZ d'une même région
  - Moins coûteux que le transfert entre régions, mais toujours facturé

- **Transfert entre services AWS** : Dans certains cas, le transfert entre services AWS peut être facturé

### Points à considérer pour le Free Tier

Dans le cadre du Free Tier AWS :
- 100 Go de transfert de données sortant est généralement gratuit par mois
- Le transfert entrant est généralement gratuit
- Le transfert entre instances EC2 dans la même zone de disponibilité via adresse IP privée est gratuit

### Optimisations pour notre architecture

Pour notre projet YourMedia, nous avons optimisé les coûts de transfert de données en :
- Plaçant les ressources qui communiquent fréquemment (EC2, RDS) dans la même zone de disponibilité
- Utilisant S3 principalement pour le stockage des fichiers de configuration et des artefacts de build
- Limitant les transferts entre régions
- Configurant des règles de cycle de vie pour nettoyer automatiquement les anciens fichiers
