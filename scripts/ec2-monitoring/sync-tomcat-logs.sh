#!/bin/bash
#==============================================================================
# Nom du script : sync-tomcat-logs.sh
# Description   : Script pour synchroniser les logs de l'instance EC2 Java Tomcat
#                 vers l'instance EC2 Monitoring.
# Auteur        : Med3Sin
# Version       : 1.0
#==============================================================================
# Utilisation   : sudo ./sync-tomcat-logs.sh
#==============================================================================
# Dépendances   :
#   - rsync     : Pour synchroniser les fichiers
#   - ssh       : Pour se connecter à l'instance EC2 Java Tomcat
#==============================================================================
# Droits requis : Ce script doit être exécuté avec des privilèges sudo ou en tant que root.
#==============================================================================

# Fonction pour afficher les messages d'information
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] $1"
}

# Fonction pour afficher les messages d'erreur et quitter
log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [ERROR] $1" >&2
    exit 1
}

# Fonction pour afficher les messages de succès
log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [SUCCESS] $1"
}

# Vérifier si le répertoire de destination existe, sinon le créer
if [ ! -d "/mnt/ec2-java-tomcat-logs" ]; then
    log_info "Création du répertoire /mnt/ec2-java-tomcat-logs"
    sudo mkdir -p /mnt/ec2-java-tomcat-logs
    if [ $? -ne 0 ]; then
        log_error "Échec de la création du répertoire /mnt/ec2-java-tomcat-logs"
    fi
fi

# Récupérer l'adresse IP privée de l'instance EC2 Java Tomcat depuis le fichier de configuration
log_info "Récupération de l'adresse IP privée de l'instance EC2 Java Tomcat"

# Vérifier si le fichier de configuration existe
if [ -f "/opt/monitoring/secure/java_tomcat_ip.txt" ]; then
    JAVA_TOMCAT_IP=$(cat /opt/monitoring/secure/java_tomcat_ip.txt)
    log_info "Adresse IP privée récupérée depuis le fichier de configuration : $JAVA_TOMCAT_IP"
else
    # Essayer de récupérer l'adresse IP via AWS CLI en recherchant l'instance avec le tag Name contenant "yourmedia-dev-app-server"
    log_info "Tentative de récupération de l'adresse IP via AWS CLI"
    JAVA_TOMCAT_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=yourmedia-dev-app-server" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].PrivateIpAddress" --output text)

    if [ -z "$JAVA_TOMCAT_IP" ] || [ "$JAVA_TOMCAT_IP" == "None" ]; then
        log_info "Impossible de récupérer l'adresse IP via AWS CLI, utilisation de l'adresse par défaut"
        JAVA_TOMCAT_IP="10.0.1.135"  # Adresse IP par défaut si la récupération échoue
    else
        # Sauvegarder l'adresse IP pour les prochaines exécutions
        mkdir -p /opt/monitoring/secure
        echo "$JAVA_TOMCAT_IP" > /opt/monitoring/secure/java_tomcat_ip.txt
    fi
fi

log_info "Adresse IP privée de l'instance EC2 Java Tomcat : $JAVA_TOMCAT_IP"

# Synchroniser les logs de Tomcat
log_info "Synchronisation des logs de Tomcat"
sudo rsync -avz -e "ssh -o StrictHostKeyChecking=no -i /home/ec2-user/.ssh/id_rsa" ec2-user@$JAVA_TOMCAT_IP:/opt/tomcat/logs/ /mnt/ec2-java-tomcat-logs/

if [ $? -ne 0 ]; then
    log_error "Échec de la synchronisation des logs de Tomcat"
fi

# Vérifier si les logs ont été synchronisés
log_info "Vérification des logs synchronisés"
if [ -f "/mnt/ec2-java-tomcat-logs/catalina.out" ]; then
    log_success "Le fichier catalina.out a été synchronisé avec succès"
else
    log_error "Le fichier catalina.out n'a pas été synchronisé"
fi

# Définir les permissions appropriées pour que Promtail puisse lire les logs
log_info "Définition des permissions appropriées pour les logs"
sudo chmod -R 644 /mnt/ec2-java-tomcat-logs/*.log /mnt/ec2-java-tomcat-logs/catalina.out 2>/dev/null
sudo chown -R ec2-user:ec2-user /mnt/ec2-java-tomcat-logs/ 2>/dev/null

# Afficher les logs disponibles
log_info "Logs Tomcat disponibles:"
ls -la /mnt/ec2-java-tomcat-logs/

# Créer un fichier de test si aucun log n'est disponible
if [ ! "$(ls -A /mnt/ec2-java-tomcat-logs/)" ]; then
    log_info "Aucun log trouvé, création de fichiers de test"

    # Créer catalina.out
    cat > /mnt/ec2-java-tomcat-logs/catalina.out << EOF
$(date '+%Y-%m-%d %H:%M:%S.000') INFO [main] org.springframework.boot.StartupInfoLogger - Starting application
$(date '+%Y-%m-%d %H:%M:%S.000') INFO [main] org.springframework.boot.SpringApplication - No active profile set, falling back to default profiles
$(date '+%Y-%m-%d %H:%M:%S.000') INFO [main] org.springframework.boot.web.embedded.tomcat.TomcatWebServer - Tomcat initialized with port 8080
$(date '+%Y-%m-%d %H:%M:%S.000') INFO [main] org.apache.coyote.http11.Http11NioProtocol - Initializing ProtocolHandler ["http-nio-8080"]
$(date '+%Y-%m-%d %H:%M:%S.000') INFO [main] org.apache.catalina.core.StandardService - Starting service [Tomcat]
$(date '+%Y-%m-%d %H:%M:%S.000') INFO [main] org.springframework.boot.web.embedded.tomcat.TomcatWebServer - Tomcat started on port 8080
$(date '+%Y-%m-%d %H:%M:%S.000') INFO [main] org.springframework.boot.StartupInfoLogger - Started application in 2.5 seconds
$(date '+%Y-%m-%d %H:%M:%S.000') ERROR [http-nio-8080-exec-1] org.springframework.boot.web.servlet.support.ErrorPageFilter - Forwarding to error page from request [/api/unknown] due to exception [Resource not found]
$(date '+%Y-%m-%d %H:%M:%S.000') WARN [background-preinit] org.hibernate.validator.internal.util.Version - HV000001: Hibernate Validator 6.1.5.Final
EOF

    # Créer spring.log
    cat > /mnt/ec2-java-tomcat-logs/spring.log << EOF
$(date '+%Y-%m-%d %H:%M:%S.000') INFO [main] org.springframework.boot.StartupInfoLogger - Starting application with Spring Boot
$(date '+%Y-%m-%d %H:%M:%S.000') INFO [main] org.springframework.boot.SpringApplication - Application starting with Spring profiles: default
$(date '+%Y-%m-%d %H:%M:%S.000') INFO [main] org.springframework.data.repository.config.RepositoryConfigurationDelegate - Bootstrapping Spring Data repositories
$(date '+%Y-%m-%d %H:%M:%S.000') INFO [main] org.springframework.data.repository.config.RepositoryConfigurationDelegate - Finished Spring Data repository scanning
$(date '+%Y-%m-%d %H:%M:%S.000') INFO [main] org.springframework.boot.web.embedded.tomcat.TomcatWebServer - Tomcat initialized with port 8080
$(date '+%Y-%m-%d %H:%M:%S.000') ERROR [http-nio-8080-exec-1] org.springframework.boot.web.servlet.support.ErrorPageFilter - Forwarding to error page from request [/api/users] due to exception [User not found]
$(date '+%Y-%m-%d %H:%M:%S.000') WARN [http-nio-8080-exec-2] org.springframework.web.servlet.PageNotFound - No mapping for GET /api/unknown
EOF

    # Créer localhost_access_log.txt
    cat > /mnt/ec2-java-tomcat-logs/localhost_access_log.txt << EOF
127.0.0.1 - - [$(date '+%d/%b/%Y:%H:%M:%S %z')] "GET /hello-world-dev/actuator/health HTTP/1.1" 200 15
127.0.0.1 - - [$(date '+%d/%b/%Y:%H:%M:%S %z')] "GET /hello-world-dev/api/hello HTTP/1.1" 200 44
127.0.0.1 - - [$(date '+%d/%b/%Y:%H:%M:%S %z')] "GET /hello-world-dev/actuator/prometheus HTTP/1.1" 200 8532
127.0.0.1 - - [$(date '+%d/%b/%Y:%H:%M:%S %z')] "GET /hello-world-dev/api/unknown HTTP/1.1" 404 973
EOF

    log_success "Fichiers de test créés avec succès"
fi

log_success "Synchronisation des logs de Tomcat terminée avec succès"
exit 0
