# Fichiers de configuration pour le monitoring

Les fichiers de configuration pour le monitoring sont maintenant définis dans le répertoire
`infrastructure/modules/ec2-monitoring/scripts` pour éviter la duplication.

Le module S3 référence ces fichiers directement depuis le module ec2-monitoring via la variable
`monitoring_scripts_path` qui est définie dans le fichier `infrastructure/main.tf`.

Ces fichiers ont été supprimés car ils étaient dupliqués avec ceux du répertoire
`infrastructure/modules/ec2-monitoring/scripts`.
