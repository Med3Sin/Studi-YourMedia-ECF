FROM node:16-alpine

# Installer les dépendances nécessaires
RUN apk add --no-cache bash curl

# Définir le répertoire de travail
WORKDIR /app

# Installer un serveur web léger
RUN npm install -g serve

# Créer un répertoire pour l'application
RUN mkdir -p /app/build

# Créer un fichier HTML simple pour l'application mobile
RUN echo '<!DOCTYPE html>\n\
<html lang="fr">\n\
<head>\n\
    <meta charset="UTF-8">\n\
    <meta name="viewport" content="width=device-width, initial-scale=1.0">\n\
    <title>YourMedia Mobile App</title>\n\
    <style>\n\
        body { font-family: Arial, sans-serif; margin: 0; padding: 0; display: flex; justify-content: center; align-items: center; height: 100vh; background-color: #f5f5f5; }\n\
        .container { text-align: center; padding: 20px; background-color: white; border-radius: 10px; box-shadow: 0 4px 8px rgba(0,0,0,0.1); }\n\
        h1 { color: #333; margin-bottom: 10px; }\n\
        p { color: #666; }\n\
        .logo { font-size: 48px; margin-bottom: 20px; }\n\
    </style>\n\
</head>\n\
<body>\n\
    <div class="container">\n\
        <div class="logo">📱</div>\n\
        <h1>Hello World!</h1>\n\
        <p>YourMedia Mobile Application</p>\n\
    </div>\n\
</body>\n\
</html>' > /app/build/index.html

# Créer un utilisateur non-root pour des raisons de sécurité
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
RUN chown -R appuser:appgroup /app
USER appuser

# Exposer le port 8080
EXPOSE 8080

# Variables d'environnement
ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV NODE_OPTIONS="--max-old-space-size=256"

# Health check pour vérifier que l'application est en cours d'exécution
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1

# Démarrer le serveur sur le port 8080
CMD ["serve", "-s", "build", "-l", "8080"]
