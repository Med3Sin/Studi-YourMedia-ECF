# Templates pour l'infrastructure YourMedia

Ce dossier contient les templates utilisés par Terraform pour générer les scripts d'initialisation des instances EC2 et autres ressources.

## Structure

- `ec2-java-tomcat/` : Templates pour l'instance EC2 exécutant Java et Tomcat
  - `user_data.sh.tpl` : Script d'initialisation exécuté au démarrage de l'instance

- `ec2-monitoring/` : Templates pour l'instance EC2 de monitoring
  - `user_data.sh.tpl` : Script d'initialisation exécuté au démarrage de l'instance

- `s3/` : Templates pour les ressources S3 (dossier maintenu pour cohérence)

## Utilisation

Ces templates sont utilisés par les modules Terraform dans le dossier `infrastructure/modules/`. Ils sont référencés dans les fichiers `main.tf` de chaque module.

Les templates sont centralisés dans ce dossier pour faciliter leur maintenance et éviter la duplication de code.
