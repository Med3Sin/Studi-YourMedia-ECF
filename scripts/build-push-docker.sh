#!/bin/bash

# Script pour construire et pousser les images Docker vers Docker Hub
# Utilisation: ./build-push-docker.sh [mobile|monitoring|all]

# Variables
DOCKER_USERNAME=${DOCKERHUB_USERNAME:-medsin}
DOCKER_REPO=${DOCKERHUB_REPO:-yourmedia-ecf}
VERSION=$(date +%Y%m%d%H%M%S)
TARGET=${1:-all}

# Vérifier si Docker est installé
if ! command -v docker &> /dev/null; then
    echo "Docker n'est pas installé. Veuillez l'installer avant d'exécuter ce script."
    exit 1
fi

# Connexion à Docker Hub
echo "Connexion à Docker Hub..."
echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

# Fonction pour construire et pousser l'image mobile
build_push_mobile() {
    echo "Construction de l'image Docker pour l'application mobile..."
    cd ../app-react
    docker build -t $DOCKER_USERNAME/$DOCKER_REPO:mobile-$VERSION -t $DOCKER_USERNAME/$DOCKER_REPO:mobile-latest .

    echo "Publication de l'image mobile sur Docker Hub..."
    docker push $DOCKER_USERNAME/$DOCKER_REPO:mobile-$VERSION
    docker push $DOCKER_USERNAME/$DOCKER_REPO:mobile-latest

    echo "Image mobile publiée avec succès!"
    cd -
}

# Fonction pour construire et pousser les images de monitoring
build_push_monitoring() {
    echo "Construction de l'image Docker pour Grafana..."
    cd ../infrastructure/modules/ec2-monitoring/docker/grafana
    docker build -t $DOCKER_USERNAME/$DOCKER_REPO:grafana-$VERSION -t $DOCKER_USERNAME/$DOCKER_REPO:grafana-latest .

    echo "Publication de l'image Grafana sur Docker Hub..."
    docker push $DOCKER_USERNAME/$DOCKER_REPO:grafana-$VERSION
    docker push $DOCKER_USERNAME/$DOCKER_REPO:grafana-latest

    echo "Construction de l'image Docker pour Prometheus..."
    cd ../prometheus
    docker build -t $DOCKER_USERNAME/$DOCKER_REPO:prometheus-$VERSION -t $DOCKER_USERNAME/$DOCKER_REPO:prometheus-latest .

    echo "Publication de l'image Prometheus sur Docker Hub..."
    docker push $DOCKER_USERNAME/$DOCKER_REPO:prometheus-$VERSION
    docker push $DOCKER_USERNAME/$DOCKER_REPO:prometheus-latest

    echo "Construction de l'image Docker pour SonarQube..."
    cd ../sonarqube
    docker build -t $DOCKER_USERNAME/$DOCKER_REPO:sonarqube-$VERSION -t $DOCKER_USERNAME/$DOCKER_REPO:sonarqube-latest .

    echo "Publication de l'image SonarQube sur Docker Hub..."
    docker push $DOCKER_USERNAME/$DOCKER_REPO:sonarqube-$VERSION
    docker push $DOCKER_USERNAME/$DOCKER_REPO:sonarqube-latest

    echo "Images de monitoring publiées avec succès!"
    cd -
}

# Exécution en fonction de la cible
case $TARGET in
    mobile)
        build_push_mobile
        ;;
    monitoring)
        build_push_monitoring
        ;;
    all)
        build_push_mobile
        build_push_monitoring
        ;;
    *)
        echo "Cible inconnue: $TARGET"
        echo "Utilisation: ./build-push-docker.sh [mobile|monitoring|all]"
        exit 1
        ;;
esac

echo "Toutes les images ont été construites et publiées avec succès!"
