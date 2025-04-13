#!/bin/bash

# Script pour nettoyer les fichiers dupliqués entre les répertoires
# infrastructure/modules/ec2-monitoring/scripts et infrastructure/modules/s3/files

echo "Nettoyage des fichiers dupliqués..."

# Vérifier si le répertoire infrastructure/modules/s3/files existe
if [ -d "infrastructure/modules/s3/files" ]; then
    # Créer un répertoire de sauvegarde
    mkdir -p infrastructure/modules/s3/files_backup

    # Déplacer les fichiers vers le répertoire de sauvegarde
    echo "Déplacement des fichiers vers le répertoire de sauvegarde..."
    mv infrastructure/modules/s3/files/* infrastructure/modules/s3/files_backup/

    # Créer un fichier README.md dans le répertoire files
    echo "Création d'un fichier README.md dans le répertoire files..."
    cat > infrastructure/modules/s3/files/README.md << 'EOL'
# Fichiers de configuration pour le monitoring

Les fichiers de configuration pour le monitoring sont maintenant définis dans le répertoire
`infrastructure/modules/ec2-monitoring/scripts` pour éviter la duplication.

Le module S3 référence ces fichiers directement depuis le module ec2-monitoring via la variable
`monitoring_scripts_path` qui est définie dans le fichier `infrastructure/main.tf`.

Les fichiers originaux ont été déplacés dans le répertoire `files_backup` pour référence.
EOL

    echo "Nettoyage terminé. Les fichiers originaux ont été déplacés dans infrastructure/modules/s3/files_backup."
    echo "Un fichier README.md a été créé dans infrastructure/modules/s3/files pour expliquer la nouvelle structure."
else
    echo "Le répertoire infrastructure/modules/s3/files n'existe pas. Aucune action nécessaire."
fi
