#!/bin/bash
#==============================================================================
# Nom du script : fix-ssh-keys.sh
# Description   : Script pour vérifier et corriger les clés SSH dans le fichier authorized_keys.
#                 Ce script supprime les guillemets simples qui entourent les clés SSH et
#                 vérifie le format des clés pour s'assurer qu'elles sont valides.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2025-04-27
#==============================================================================
# Utilisation   : ./fix-ssh-keys.sh
#
# Exemples      :
#   ./fix-ssh-keys.sh
#==============================================================================
# Dépendances   :
#   - sed       : Pour supprimer les guillemets simples
#   - grep      : Pour extraire les parties des clés SSH
#==============================================================================
# Fichiers modifiés :
#   - ~/.ssh/authorized_keys : Fichier contenant les clés SSH autorisées
#==============================================================================

# Fonction pour corriger les clés SSH
fix_ssh_keys() {
    echo "[INFO] Vérification et correction des clés SSH..."

    # Vérifier si le fichier authorized_keys existe
    if [ ! -f ~/.ssh/authorized_keys ]; then
        echo "[WARN] Le fichier authorized_keys n'existe pas. Rien à faire."
        return
    fi

    # Sauvegarder le fichier original
    cp ~/.ssh/authorized_keys ~/.ssh/authorized_keys.bak

    # Supprimer les guillemets simples dans le fichier authorized_keys
    sed "s/'//g" ~/.ssh/authorized_keys.bak > ~/.ssh/authorized_keys.tmp

    # Vérifier le format des clés SSH
    > ~/.ssh/authorized_keys.new
    while IFS= read -r line; do
        # Ignorer les lignes vides ou commentées
        if [[ -z "$line" || "$line" == \#* ]]; then
            echo "$line" >> ~/.ssh/authorized_keys.new
            continue
        fi

        # Vérifier si la ligne commence par ssh-rsa, ssh-ed25519, etc.
        if [[ "$line" =~ ^(ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ]]; then
            echo "$line" >> ~/.ssh/authorized_keys.new
        else
            # Si la ligne ne commence pas par un type de clé SSH valide,
            # vérifier si elle contient un type de clé SSH valide
            if [[ "$line" =~ (ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ]]; then
                # Extraire la partie qui commence par le type de clé SSH
                key_part=$(echo "$line" | grep -o "ssh-[^ ]*.*")
                echo "$key_part" >> ~/.ssh/authorized_keys.new
            else
                # Si la ligne ne contient pas de type de clé SSH valide, l'ignorer
                echo "[WARN] Ligne ignorée (format non reconnu): $line"
            fi
        fi
    done < ~/.ssh/authorized_keys.tmp

    # Remplacer le fichier authorized_keys
    mv ~/.ssh/authorized_keys.new ~/.ssh/authorized_keys

    # Ajuster les permissions
    chmod 600 ~/.ssh/authorized_keys

    # Supprimer les fichiers temporaires
    rm -f ~/.ssh/authorized_keys.tmp

    echo "[INFO] Correction des clés SSH terminée."
}

# Exécuter la fonction de correction
fix_ssh_keys
