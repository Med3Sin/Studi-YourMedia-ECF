FROM node:16-alpine

# Installer les dépendances nécessaires
RUN apk add --no-cache bash curl tini

# Définir le répertoire de travail
WORKDIR /app

# Installer un serveur web léger
RUN npm install -g serve

# Créer une application React simple
RUN npx create-react-app my-app --template minimal

# Aller dans le répertoire de l'application
WORKDIR /app/my-app

# Modifier le fichier App.js pour afficher un message personnalisé
RUN sed -i 's|<p>Edit <code>src/App.js</code> and save to reload.</p>|<h1>YourMedia Mobile App</h1><p>Application mobile pour YourMedia</p>|g' src/App.js

# Construire l'application
RUN npm run build

# Créer un utilisateur non-root pour des raisons de sécurité
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
RUN chown -R appuser:appgroup /app
USER appuser

# Exposer le port 8080
EXPOSE 8080

# Variables d'environnement
ENV NODE_ENV=production
ENV HOST=0.0.0.0

# Health check pour vérifier que l'application est en cours d'exécution
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1

# Démarrer le serveur sur le port 8080
CMD ["serve", "-s", "build", "-l", "8080"]
