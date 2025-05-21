#!/bin/bash
#==============================================================================
# Nom du script : standardize-scripts.sh
# Description   : Script de standardisation des scripts shell du projet
# Auteur        : Med3Sin
# Version       : 1.0
# Date          : 2024-01-15
#==============================================================================

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Fonction pour standardiser un script
standardize_script() {
    local script=$1
    local script_name=$(basename "$script")
    local script_dir=$(dirname "$script")
    
    # Vérifier si le fichier existe
    if [ ! -f "$script" ]; then
        log "ERREUR: Le fichier $script n'existe pas"
        return 1
    }
    
    # Créer un fichier temporaire
    local temp_file=$(mktemp)
    
    # Ajouter l'en-tête standard
    cat > "$temp_file" << EOF
#!/bin/bash
#==============================================================================
# Nom du script : $script_name
# Description   : $(grep -m 1 "^# Description" "$script" | cut -d':' -f2- || echo "À compléter")
# Auteur        : $(grep -m 1 "^# Auteur" "$script" | cut -d':' -f2- || echo "Med3Sin")
# Version       : $(grep -m 1 "^# Version" "$script" | cut -d':' -f2- || echo "1.0")
# Date          : $(date '+%Y-%m-%d')
#==============================================================================

EOF
    
    # Ajouter le contenu du script (sans l'en-tête existant)
    sed '1,/^#==*$/d' "$script" >> "$temp_file"
    
    # Remplacer le fichier original
    mv "$temp_file" "$script"
    chmod +x "$script"
    
    log "Script $script_name standardisé avec succès"
}

# Fonction pour trouver tous les scripts shell
find_shell_scripts() {
    find . -type f -name "*.sh" -o -name "*.bash" | grep -v "node_modules" | grep -v ".git"
}

# Fonction principale
main() {
    log "Démarrage de la standardisation des scripts"
    
    # Trouver tous les scripts shell
    local scripts=$(find_shell_scripts)
    
    # Standardiser chaque script
    for script in $scripts; do
        standardize_script "$script"
    done
    
    log "Standardisation des scripts terminée"
}

# Exécution du script
main 