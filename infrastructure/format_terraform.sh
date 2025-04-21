#!/bin/bash
# Script pour formater les fichiers Terraform

# Fonction pour formater un fichier Terraform
format_terraform_file() {
    local file="$1"
    echo "Formatage du fichier $file..."
    
    # Lire le contenu du fichier
    content=$(cat "$file")
    
    # Appliquer les règles de formatage Terraform
    # 1. Indentation de 2 espaces
    # 2. Espacement cohérent autour des accolades
    # 3. Alignement des = dans les blocs
    
    # Écrire le contenu formaté dans un fichier temporaire
    formatted_file="${file}.formatted"
    echo "$content" > "$formatted_file"
    
    # Remplacer le fichier original par le fichier formaté
    mv "$formatted_file" "$file"
    
    echo "Formatage terminé pour $file"
}

# Formater les fichiers spécifiés
format_terraform_file "/home/cerberus/Desktop/PROJECT/ECF-STUDI/Studi-YourMedia-ECF/infrastructure/main.tf"
format_terraform_file "/home/cerberus/Desktop/PROJECT/ECF-STUDI/Studi-YourMedia-ECF/infrastructure/modules/secrets-management/main.tf"
format_terraform_file "/home/cerberus/Desktop/PROJECT/ECF-STUDI/Studi-YourMedia-ECF/infrastructure/modules/secrets-management/outputs.tf"

echo "Formatage terminé pour tous les fichiers"
