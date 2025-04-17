# Module Terraform : Network

Ce module est responsable de la configuration des groupes de sécurité pour les différentes ressources de l'infrastructure YourMédia.

## Ressources Créées

* **`aws_security_group.ec2_sg`**: Groupe de sécurité pour l'instance EC2 Java/Tomcat.
  * Autorise le trafic SSH entrant (port 22) depuis l'adresse IP de l'opérateur ou depuis Internet.
  * Autorise le trafic HTTP entrant (port 8080) depuis Internet pour l'accès à Tomcat.
  * Autorise le trafic sortant vers toutes les destinations.

* **`aws_security_group.monitoring_sg`**: Groupe de sécurité pour l'instance EC2 de monitoring.
  * Autorise le trafic SSH entrant (port 22) depuis l'adresse IP de l'opérateur ou depuis Internet.
  * Autorise le trafic HTTP entrant (port 3000) depuis Internet pour l'accès à Grafana.
  * Autorise le trafic HTTP entrant (port 9090) depuis Internet pour l'accès à Prometheus.
  * Autorise le trafic sortant vers toutes les destinations.

* **`aws_security_group.rds_sg`**: Groupe de sécurité pour l'instance RDS MySQL.
  * Autorise le trafic MySQL entrant (port 3306) depuis le groupe de sécurité de l'instance EC2 Java/Tomcat.
  * Autorise le trafic sortant vers toutes les destinations.

## Variables d'Entrée

* `project_name` (String): Nom du projet utilisé pour taguer les ressources.
* `environment` (String): Environnement de déploiement (dev, pre-prod, prod).
* `vpc_id` (String): ID du VPC où créer les groupes de sécurité.
* `operator_ip` (String): Adresse IP de l'opérateur pour l'accès SSH (optionnel).

## Sorties

* `ec2_security_group_id`: ID du groupe de sécurité pour l'instance EC2 Java/Tomcat.
* `monitoring_security_group_id`: ID du groupe de sécurité pour l'instance EC2 de monitoring.
* `rds_security_group_id`: ID du groupe de sécurité pour l'instance RDS MySQL.

## Règles de Sécurité

### EC2 Java/Tomcat

* **Entrée**:
  * SSH (port 22) depuis l'adresse IP de l'opérateur ou depuis Internet.
  * HTTP (port 8080) depuis Internet pour l'accès à Tomcat.
  * Prometheus (port 9100) depuis le groupe de sécurité de l'instance EC2 de monitoring.
* **Sortie**:
  * Tout le trafic vers toutes les destinations.

### EC2 Monitoring

* **Entrée**:
  * SSH (port 22) depuis l'adresse IP de l'opérateur ou depuis Internet.
  * HTTP (port 3000) depuis Internet pour l'accès à Grafana.
  * HTTP (port 9090) depuis Internet pour l'accès à Prometheus.
* **Sortie**:
  * Tout le trafic vers toutes les destinations.

### RDS MySQL

* **Entrée**:
  * MySQL (port 3306) depuis le groupe de sécurité de l'instance EC2 Java/Tomcat.
* **Sortie**:
  * Tout le trafic vers toutes les destinations.

## Notes Importantes

1. **Sécurité**: Les groupes de sécurité sont configurés pour permettre l'accès depuis Internet pour faciliter le développement et les tests. Pour un environnement de production, il est recommandé de restreindre l'accès aux adresses IP spécifiques.

2. **Dépendances**: Les groupes de sécurité sont créés dans le VPC spécifié et dépendent les uns des autres pour certaines règles (par exemple, l'accès à RDS depuis l'instance EC2).

3. **Adresse IP de l'opérateur**: Si l'adresse IP de l'opérateur est fournie, l'accès SSH est restreint à cette adresse IP. Sinon, l'accès SSH est autorisé depuis n'importe quelle adresse IP.

4. **Ports**: Les ports utilisés sont les ports par défaut pour les services correspondants (SSH: 22, Tomcat: 8080, MySQL: 3306, Grafana: 3000, Prometheus: 9090).
