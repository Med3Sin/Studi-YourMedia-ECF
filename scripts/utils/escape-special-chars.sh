#!/bin/bash
#==============================================================================
# Nom du script : escape-special-chars.sh
# Description   : Script pour échapper correctement les caractères spéciaux dans les variables.
#                 Ce script prend une variable et sa valeur en entrée et génère différentes
#                 versions échappées pour différents contextes (sed, shell, URL).
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.1
# Date          : 2023-11-15
#==============================================================================
# Utilisation   : ./escape-special-chars.sh <variable> <valeur>
#
# Arguments     :
#   variable    : Nom de la variable à échapper
#   valeur      : Valeur de la variable à échapper
#
# Exemples      :
#   ./escape-special-chars.sh PASSWORD 'mon_mot_de_passe!@#'
#==============================================================================
# Dépendances   :
#   - sed       : Pour échapper les caractères spéciaux
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

# Vérifier si un argument a été fourni
if [ $# -ne 2 ]; then
    echo "Usage: $0 <variable> <valeur>"
    echo "Exemple: $0 PASSWORD 'mon_mot_de_passe!@#'"
    exit 1
fi

VARIABLE_NAME=$1
VARIABLE_VALUE=$2

# Échapper les caractères spéciaux pour sed
ESCAPED_VALUE=$(echo "$VARIABLE_VALUE" | sed -e 's/[\/&]/\\&/g')

# Échapper les caractères spéciaux pour les scripts shell
SHELL_ESCAPED_VALUE=$(echo "$VARIABLE_VALUE" | sed -e 's/[\"\\$`!]/\\&/g')

# Échapper les caractères spéciaux pour les URLs
URL_ESCAPED_VALUE=$(echo "$VARIABLE_VALUE" | sed -e 's/[\/&]/\\&/g')

log "Variable originale: $VARIABLE_NAME=$VARIABLE_VALUE"
log "Échappée pour sed: $VARIABLE_NAME=$ESCAPED_VALUE"
log "Échappée pour shell: $VARIABLE_NAME=$SHELL_ESCAPED_VALUE"
log "Échappée pour URL: $VARIABLE_NAME=$URL_ESCAPED_VALUE"

# Exemples d'utilisation
log ""
log "Exemples d'utilisation:"
log "1. Pour remplacer une variable dans un fichier avec sed:"
log "   sed -i \"s/PLACEHOLDER_$VARIABLE_NAME/$ESCAPED_VALUE/g\" fichier.txt"
log ""
log "2. Pour définir une variable dans un script shell:"
log "   $VARIABLE_NAME=\"$SHELL_ESCAPED_VALUE\""
log ""
log "3. Pour utiliser dans une URL:"
log "   http://example.com/api?param=$URL_ESCAPED_VALUE"
log ""
log "4. Pour utiliser avec des variables d'environnement (recommandé):"
log "   export $VARIABLE_NAME=\"$VARIABLE_VALUE\""
log "   echo \"\${$VARIABLE_NAME}\""

exit 0
