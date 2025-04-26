#!/bin/bash

# Script simplifié de correction des permissions pour Java/Tomcat
# Résout les problèmes de permissions pour les scripts et les répertoires
#
# EXIGENCES EN MATIÈRE DE DROITS :
# Ce script doit être exécuté avec des privilèges sudo ou en tant que root.
# Exemple d'utilisation : sudo ./fix_permissions.sh
#
# Le script vérifie automatiquement les droits et affichera une erreur si nécessaire.

# Afficher l'aide
if [ "$1" = "--help" ]; then
    echo "Usage: sudo $0"
    echo ""
    echo "Ce script corrige les permissions pour Java/Tomcat"
    exit 0
fi

# Fonctions simplifiées pour les messages
info() { echo "[INFO] $1"; }
success() { echo "[SUCCÈS] $1"; }
error() { echo "[ERREUR] $1" >&2; }

# Vérifier si l'utilisateur a les droits sudo
if [ "$(id -u)" -ne 0 ]; then
    error "Ce script doit être exécuté avec sudo"
    error "Exemple: sudo $0 $*"

    # Tentative d'obtention des droits sudo
    info "Tentative d'obtention des privilèges sudo..."
    if sudo -n true 2>/dev/null; then
        info "Relancement du script avec sudo..."
        exec sudo "$0" "$@"
    else
        error "Impossible d'obtenir les privilèges sudo automatiquement."
        exit 1
    fi
fi

# ÉTAPE 1: S'assurer que tous les scripts sont exécutables
info "S'assurer que tous les scripts sont exécutables..."
find /opt/yourmedia -name "*.sh" -exec chmod +x {} \;
find /usr/local/bin -name "deploy-war.sh" -exec chmod +x {} \;

# ÉTAPE 2: Corriger les permissions pour les répertoires
info "Configuration des permissions pour les répertoires..."
# Permissions pour le répertoire principal
chown -R ec2-user:ec2-user /opt/yourmedia
chmod -R 755 /opt/yourmedia

# Permissions spéciales pour le répertoire sécurisé
if [ -d "/opt/yourmedia/secure" ]; then
    info "Configuration des permissions pour le répertoire sécurisé..."
    chmod 700 /opt/yourmedia/secure
    chmod 600 /opt/yourmedia/secure/*.sh 2>/dev/null || true
    chmod 600 /opt/yourmedia/secure/*.txt 2>/dev/null || true
fi

# ÉTAPE 3: Corriger les permissions pour Tomcat
if [ -d "/opt/tomcat" ]; then
    info "Configuration des permissions pour Tomcat..."
    # Permissions pour les répertoires Tomcat
    chown -R tomcat:tomcat /opt/tomcat
    chmod -R 755 /opt/tomcat
    
    # Permissions spéciales pour les répertoires de configuration
    chmod -R g+r /opt/tomcat/conf
    chmod g+x /opt/tomcat/conf
    
    # Permissions pour les répertoires de travail
    chown -R tomcat:tomcat /opt/tomcat/webapps
    chown -R tomcat:tomcat /opt/tomcat/work
    chown -R tomcat:tomcat /opt/tomcat/temp
    chown -R tomcat:tomcat /opt/tomcat/logs
fi

# ÉTAPE 4: Vérification
info "Vérification des permissions..."
ls -la /opt/yourmedia
if [ -d "/opt/yourmedia/secure" ]; then
    ls -la /opt/yourmedia/secure
fi

if [ -d "/opt/tomcat" ]; then
    ls -la /opt/tomcat
    # Vérifier le statut de Tomcat
    systemctl status tomcat
fi

success "Correction des permissions terminée"
