#!/bin/bash
#==============================================================================
# Nom du script : check-scripts.sh
# Description   : Script pour vérifier et corriger les problèmes potentiels dans les scripts shell.
#                 Ce script utilise shellcheck pour détecter les problèmes courants dans les
#                 scripts shell et vérifie également les permissions et les caractères spéciaux.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.1
# Date          : 2023-11-15
#==============================================================================
# Utilisation   : ./check-scripts.sh
#
# Exemples      :
#   ./check-scripts.sh
#==============================================================================
# Dépendances   :
#   - shellcheck : Pour analyser les scripts shell
#   - grep       : Pour rechercher des motifs dans les fichiers
#   - find       : Pour trouver les scripts shell
#==============================================================================

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Fonction pour afficher les erreurs et quitter
error_exit() {
    log "ERREUR: $1"
    exit 1
}

# Vérifier si shellcheck est installé
if ! command -v shellcheck &> /dev/null; then
    log "shellcheck n'est pas installé. Installation..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y shellcheck
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y shellcheck
    elif command -v yum &> /dev/null; then
        sudo yum install -y epel-release
        sudo yum install -y shellcheck
    else
        error_exit "Impossible d'installer shellcheck. Veuillez l'installer manuellement."
    fi
fi

# Trouver tous les scripts shell dans le projet
log "Recherche des scripts shell..."
SCRIPTS=$(find . -name "*.sh" -type f)

if [ -z "$SCRIPTS" ]; then
    error_exit "Aucun script shell trouvé."
fi

# Vérifier chaque script
log "Vérification des scripts shell..."
for script in $SCRIPTS; do
    log "Vérification de $script..."

    # Vérifier les permissions
    if [ ! -x "$script" ]; then
        log "Correction des permissions pour $script"
        chmod +x "$script"
    fi

    # Vérifier la présence du shebang
    if ! head -n 1 "$script" | grep -q "^#!/bin/bash"; then
        log "AVERTISSEMENT: $script ne commence pas par #!/bin/bash"
    fi

    # Vérifier les problèmes potentiels avec shellcheck
    SHELLCHECK_RESULT=$(shellcheck -f json "$script" 2>/dev/null)

    # Compter le nombre d'erreurs
    ERROR_COUNT=$(echo "$SHELLCHECK_RESULT" | grep -c "level\":\"error")
    WARNING_COUNT=$(echo "$SHELLCHECK_RESULT" | grep -c "level\":\"warning")
    INFO_COUNT=$(echo "$SHELLCHECK_RESULT" | grep -c "level\":\"info")

    if [ "$ERROR_COUNT" -gt 0 ] || [ "$WARNING_COUNT" -gt 0 ]; then
        log "Problèmes détectés dans $script: $ERROR_COUNT erreurs, $WARNING_COUNT avertissements, $INFO_COUNT informations"
        shellcheck "$script"
    else
        log "Aucun problème détecté dans $script"
    fi

    # Vérifier les caractères spéciaux dans les variables
    if grep -q "sed.*\${" "$script"; then
        log "AVERTISSEMENT: $script contient des remplacements sed avec des variables qui pourraient causer des problèmes"
        grep -n "sed.*\${" "$script"
    fi

    # Vérifier les guillemets simples dans les variables
    if grep -q "='.*'" "$script"; then
        log "AVERTISSEMENT: $script contient des guillemets simples dans des variables qui pourraient causer des problèmes"
        grep -n "='.*'" "$script"
    fi
done

log "Vérification terminée."
exit 0
