#!/bin/bash
#==============================================================================
# Nom du script : prepare-terraform-scripts.sh
# Description   : Script pour préparer les scripts à utiliser avec Terraform.
#                 Ce script lit le contenu des scripts et le stocke dans des
#                 variables d'environnement Terraform.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2025-05-01
#==============================================================================
# Utilisation   : ./prepare-terraform-scripts.sh
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

# Vérifier si le répertoire scripts existe
if [ ! -d "scripts" ]; then
    error_exit "Le répertoire scripts n'existe pas. Exécutez ce script depuis la racine du projet."
fi

# Créer le fichier terraform.tfvars
log "Création du fichier terraform.tfvars..."
cat > infrastructure/terraform.tfvars.scripts << EOF
# Contenu des scripts pour le module S3
# Ce fichier est généré automatiquement par le script prepare-terraform-scripts.sh
# Ne pas modifier manuellement

EOF

# Fonction pour échapper le contenu d'un fichier pour terraform.tfvars
escape_for_tfvars() {
    # Échapper les guillemets et les backslashes
    sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\$/\\$/g' -e 's/`/\\`/g' "$1" | awk '{printf "%s\\n", $0}'
}

# Lire le contenu des scripts et l'ajouter au fichier terraform.tfvars
log "Lecture des scripts..."

# Scripts de monitoring
if [ -f "scripts/ec2-monitoring/setup-monitoring.sh" ]; then
    log "Ajout de scripts/ec2-monitoring/setup-monitoring.sh..."
    echo -n 'monitoring_setup_script_content = "' >> infrastructure/terraform.tfvars.scripts
    escape_for_tfvars "scripts/ec2-monitoring/setup-monitoring.sh" >> infrastructure/terraform.tfvars.scripts
    echo '"' >> infrastructure/terraform.tfvars.scripts
    echo "" >> infrastructure/terraform.tfvars.scripts
else
    log "AVERTISSEMENT: Le fichier scripts/ec2-monitoring/setup-monitoring.sh n'existe pas."
fi

if [ -f "scripts/ec2-monitoring/init-monitoring.sh" ]; then
    log "Ajout de scripts/ec2-monitoring/init-monitoring.sh..."
    echo -n 'monitoring_init_script_content = "' >> infrastructure/terraform.tfvars.scripts
    escape_for_tfvars "scripts/ec2-monitoring/init-monitoring.sh" >> infrastructure/terraform.tfvars.scripts
    echo '"' >> infrastructure/terraform.tfvars.scripts
    echo "" >> infrastructure/terraform.tfvars.scripts
else
    log "AVERTISSEMENT: Le fichier scripts/ec2-monitoring/init-monitoring.sh n'existe pas."
fi

if [ -f "scripts/ec2-monitoring/docker-compose.yml" ]; then
    log "Ajout de scripts/ec2-monitoring/docker-compose.yml..."
    echo -n 'monitoring_docker_compose_content = "' >> infrastructure/terraform.tfvars.scripts
    escape_for_tfvars "scripts/ec2-monitoring/docker-compose.yml" >> infrastructure/terraform.tfvars.scripts
    echo '"' >> infrastructure/terraform.tfvars.scripts
    echo "" >> infrastructure/terraform.tfvars.scripts
else
    log "AVERTISSEMENT: Le fichier scripts/ec2-monitoring/docker-compose.yml n'existe pas."
fi

# Scripts Java/Tomcat
if [ -f "scripts/ec2-java-tomcat/setup-java-tomcat.sh" ]; then
    log "Ajout de scripts/ec2-java-tomcat/setup-java-tomcat.sh..."
    echo -n 'java_tomcat_setup_script_content = "' >> infrastructure/terraform.tfvars.scripts
    escape_for_tfvars "scripts/ec2-java-tomcat/setup-java-tomcat.sh" >> infrastructure/terraform.tfvars.scripts
    echo '"' >> infrastructure/terraform.tfvars.scripts
    echo "" >> infrastructure/terraform.tfvars.scripts
else
    log "AVERTISSEMENT: Le fichier scripts/ec2-java-tomcat/setup-java-tomcat.sh n'existe pas."
fi

if [ -f "scripts/ec2-java-tomcat/init-java-tomcat.sh" ]; then
    log "Ajout de scripts/ec2-java-tomcat/init-java-tomcat.sh..."
    echo -n 'java_tomcat_init_script_content = "' >> infrastructure/terraform.tfvars.scripts
    escape_for_tfvars "scripts/ec2-java-tomcat/init-java-tomcat.sh" >> infrastructure/terraform.tfvars.scripts
    echo '"' >> infrastructure/terraform.tfvars.scripts
    echo "" >> infrastructure/terraform.tfvars.scripts
else
    log "AVERTISSEMENT: Le fichier scripts/ec2-java-tomcat/init-java-tomcat.sh n'existe pas."
fi

if [ -f "scripts/ec2-java-tomcat/deploy-war.sh" ]; then
    log "Ajout de scripts/ec2-java-tomcat/deploy-war.sh..."
    echo -n 'deploy_war_script_content = "' >> infrastructure/terraform.tfvars.scripts
    escape_for_tfvars "scripts/ec2-java-tomcat/deploy-war.sh" >> infrastructure/terraform.tfvars.scripts
    echo '"' >> infrastructure/terraform.tfvars.scripts
    echo "" >> infrastructure/terraform.tfvars.scripts
else
    log "AVERTISSEMENT: Le fichier scripts/ec2-java-tomcat/deploy-war.sh n'existe pas."
fi

# Scripts Docker
if [ -f "scripts/utils/docker-manager.sh" ]; then
    log "Ajout de scripts/utils/docker-manager.sh..."
    echo -n 'docker_manager_script_content = "' >> infrastructure/terraform.tfvars.scripts
    escape_for_tfvars "scripts/utils/docker-manager.sh" >> infrastructure/terraform.tfvars.scripts
    echo '"' >> infrastructure/terraform.tfvars.scripts
    echo "" >> infrastructure/terraform.tfvars.scripts
else
    log "AVERTISSEMENT: Le fichier scripts/utils/docker-manager.sh n'existe pas."
fi

log "Terminé. Le fichier infrastructure/terraform.tfvars.scripts a été créé."
log "Pour utiliser ce fichier avec Terraform, exécutez:"
log "  cd infrastructure && terraform apply -var-file=terraform.tfvars.scripts"

exit 0
