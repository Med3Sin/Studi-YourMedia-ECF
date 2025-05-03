# Plan de réorganisation de la documentation

## Problème actuel

La documentation du projet YourMedia est actuellement très fragmentée, avec plus de 40 fichiers Markdown distincts. Cette fragmentation rend difficile :
- La navigation dans la documentation
- La recherche d'informations spécifiques
- La maintenance et la mise à jour de la documentation
- L'identification des doublons et des incohérences

## Solution proposée

Réorganiser la documentation en une structure hiérarchique avec moins de documents mais plus complets, organisés par thèmes.

## Structure proposée

### 1. Documents principaux

1. **GUIDE-PRINCIPAL.md** - Point d'entrée unique avec liens vers tous les autres documents
2. **ARCHITECTURE.md** - Vue d'ensemble complète de l'architecture (fusion de plusieurs documents existants)
3. **INFRASTRUCTURE.md** - Documentation détaillée de l'infrastructure AWS
4. **OPERATIONS.md** - Guide des opérations quotidiennes
5. **SECURITE.md** - Toutes les informations relatives à la sécurité

### 2. Guides thématiques

1. **GUIDE-DOCKER.md** - Tout ce qui concerne Docker (installation, configuration, sécurité, dépannage)
2. **GUIDE-TERRAFORM.md** - Tout ce qui concerne Terraform (configuration, variables, secrets)
3. **GUIDE-GITHUB-ACTIONS.md** - Tout ce qui concerne les workflows GitHub Actions
4. **GUIDE-MONITORING.md** - Tout ce qui concerne le monitoring (Grafana, Prometheus, etc.)
5. **GUIDE-VARIABLES.md** - Gestion des variables d'environnement et standardisation

### 3. Rapports et optimisations

1. **RAPPORT-OPTIMISATIONS.md** - Fusion de tous les rapports d'optimisation (free tier, performances, etc.)
2. **RAPPORT-STANDARDISATION.md** - Fusion des rapports de standardisation des variables
3. **AMELIORATIONS-FUTURES.md** - Liste consolidée des améliorations futures

### 4. Dépannage et FAQ

1. **TROUBLESHOOTING.md** - Guide de dépannage complet (fusion de tous les guides de dépannage)
2. **FAQ.md** - Questions fréquemment posées

## Plan de migration

1. Créer la nouvelle structure de documentation
2. Fusionner les documents existants dans les nouveaux documents thématiques
3. Mettre à jour les références entre documents
4. Mettre à jour le README.md principal pour refléter la nouvelle structure
5. Archiver les anciens documents dans un sous-dossier `archive` pour référence

## Avantages de cette approche

- **Réduction du nombre de documents** : de 40+ à environ 15 documents
- **Navigation plus facile** : structure claire et hiérarchique
- **Maintenance simplifiée** : moins de documents à mettre à jour
- **Cohérence améliorée** : réduction des doublons et des incohérences
- **Recherche facilitée** : informations regroupées par thème
