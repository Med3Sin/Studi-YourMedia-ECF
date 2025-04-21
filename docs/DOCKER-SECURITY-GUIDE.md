# Guide de Sécurité Docker

Ce document décrit les bonnes pratiques de sécurité pour les images Docker utilisées dans le projet YourMedia.

## Variables d'environnement sensibles

### Problème

Les variables d'environnement sensibles ne doivent pas être définies directement dans les Dockerfiles car :
- Elles sont visibles dans l'historique de l'image
- Elles sont accessibles à toute personne ayant accès à l'image
- Elles peuvent être exposées lors des scans de sécurité

### Solution

1. **Ne pas définir de variables sensibles dans le Dockerfile**
   - Évitez d'utiliser `ENV` pour les variables sensibles comme les mots de passe, les tokens, etc.
   - Exemple de variables sensibles pour Grafana :
     - `GF_SECURITY_ADMIN_PASSWORD`
     - `GF_AUTH_ANONYMOUS_ENABLED`
     - `GF_AUTH_ANONYMOUS_ORG_ROLE`

2. **Fournir les variables sensibles au moment de l'exécution**
   - Utilisez des variables d'environnement lors du déploiement
   - Utilisez des secrets Docker ou Kubernetes
   - Utilisez des fichiers de configuration montés en volume

3. **Exemple d'utilisation avec docker-compose**

```yaml
version: '3'
services:
  grafana:
    image: medsin/yourmedia-ecf:grafana-latest
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=MonMotDePasseSecurise
      - GF_AUTH_ANONYMOUS_ENABLED=false
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer
    ports:
      - "3000:3000"
```

4. **Exemple d'utilisation avec Kubernetes**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: grafana-secrets
type: Opaque
data:
  admin-password: TW9uTW90RGVQYXNzZVNlY3VyaXNl # Base64 encoded
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
spec:
  template:
    spec:
      containers:
      - name: grafana
        image: medsin/yourmedia-ecf:grafana-latest
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: grafana-secrets
              key: admin-password
        - name: GF_AUTH_ANONYMOUS_ENABLED
          value: "false"
        - name: GF_AUTH_ANONYMOUS_ORG_ROLE
          value: "Viewer"
```

## Scan de sécurité avec Trivy

### Options de scan optimisées

Trivy offre plusieurs options pour optimiser les scans de sécurité :

1. **Limiter le scan aux vulnérabilités uniquement**
   ```bash
   trivy image --scanners vuln <image>
   ```
   Cette option désactive le scan des secrets, ce qui peut accélérer considérablement le processus.

2. **Filtrer par niveau de sévérité**
   ```bash
   trivy image --severity HIGH,CRITICAL <image>
   ```
   Cette option limite le scan aux vulnérabilités de haute gravité et critiques.

3. **Combiner les options**
   ```bash
   trivy image --scanners vuln --severity HIGH,CRITICAL <image>
   ```
   Cette combinaison offre un bon équilibre entre performance et couverture.

4. **Générer des rapports détaillés**
   ```bash
   # Format HTML
   trivy image --format template --template "@/usr/local/share/trivy/templates/html.tpl" -o rapport.html <image>
   
   # Format JSON
   trivy image --format json -o rapport.json <image>
   ```
   Ces options permettent de générer des rapports détaillés pour une analyse approfondie.

### Workflow GitHub Actions

Le workflow GitHub Actions `security-scan.yml` a été mis à jour pour utiliser ces options optimisées :

- Utilisation de `--scanners vuln` pour désactiver le scan des secrets
- Utilisation de `--severity HIGH,CRITICAL` pour se concentrer sur les vulnérabilités importantes
- Génération de rapports au format HTML et JSON pour une analyse approfondie
- Affichage d'un résumé des résultats dans l'interface GitHub Actions

## Autres bonnes pratiques

1. **Utiliser des images de base officielles et à jour**
   - Préférez les images officielles (Docker Hub)
   - Utilisez des tags spécifiques plutôt que `latest`
   - Mettez régulièrement à jour vos images de base

2. **Minimiser la taille des images**
   - Utilisez des images de base légères (Alpine, slim, etc.)
   - Nettoyez les caches et les fichiers temporaires
   - Utilisez des builds multi-étapes

3. **Exécuter les conteneurs avec des utilisateurs non-root**
   - Évitez d'utiliser l'utilisateur `root` dans vos conteneurs
   - Créez et utilisez des utilisateurs spécifiques
   - Définissez les permissions appropriées

4. **Limiter les capacités et les ressources**
   - Limitez les capacités Linux avec `--cap-drop`
   - Définissez des limites de ressources (CPU, mémoire)
   - Utilisez des politiques de sécurité pour restreindre les actions dangereuses

5. **Scanner régulièrement les images**
   - Intégrez des scans de sécurité dans votre pipeline CI/CD
   - Effectuez des scans périodiques des images déployées
   - Mettez en place des politiques de correction des vulnérabilités
