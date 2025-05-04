FROM node:20-alpine AS builder

# Installer les dépendances nécessaires pour React Native
RUN apk add --no-cache bash git openssh curl

# Définir le répertoire de travail
WORKDIR /app

# Copier les fichiers de configuration
COPY package.json package-lock.json ./

# Installer les dépendances en mode production pour réduire la taille
RUN npm ci --only=production

# Copier le reste du code source
COPY . .

# Installer Expo CLI globalement
RUN npm install -g expo-cli

# Construire l'application pour le web (version mobile-responsive)
RUN npm run build

# Étape finale pour réduire la taille de l'image
FROM node:20-alpine

# Installer un serveur web léger et les outils de diagnostic
RUN npm install -g serve && \
    apk add --no-cache curl tini

# Définir le répertoire de travail
WORKDIR /app

# Copier les fichiers de build depuis l'étape précédente
COPY --from=builder /app/dist /app/build

# Créer un utilisateur non-root pour des raisons de sécurité
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
RUN chown -R appuser:appgroup /app
USER appuser

# Exposer le port
EXPOSE 3000

# Variables d'environnement (seront remplacées lors du déploiement)
ENV API_URL=http://localhost:8080
ENV NODE_ENV=production

# Health check pour vérifier que l'application est en cours d'exécution
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:3000/ || exit 1

# Utiliser tini comme point d'entrée pour une meilleure gestion des signaux
ENTRYPOINT ["/sbin/tini", "--"]

# Commande de démarrage (écoute sur toutes les interfaces réseau)
CMD ["serve", "-s", "build", "-l", "0.0.0.0:3000"]
