# Guide de test de Tomcat sur Amazon Linux 2

Ce guide explique comment vérifier si Tomcat est correctement installé et fonctionne sur votre instance EC2 Amazon Linux 2.

## 1. Vérification via le navigateur web

La méthode la plus simple est d'accéder à Tomcat via un navigateur web :

1. Obtenez l'adresse IP publique de votre instance EC2 depuis la console AWS ou via Terraform
2. Ouvrez votre navigateur et accédez à l'URL : `http://[ADRESSE_IP_EC2]:8080`

Si Tomcat est correctement installé et en cours d'exécution, vous devriez voir la page d'accueil de Tomcat.

## 2. Vérification via SSH

### 2.1. Connexion SSH à l'instance EC2

Connectez-vous à votre instance EC2 via SSH :

```bash
ssh -i votre-cle.pem ec2-user@[ADRESSE_IP_EC2]
```

Remplacez `votre-cle.pem` par le chemin vers votre fichier de clé privée et `[ADRESSE_IP_EC2]` par l'adresse IP publique de votre instance EC2.

### 2.2. Vérification du statut du service Tomcat

Une fois connecté, vérifiez si le service Tomcat est en cours d'exécution :

```bash
sudo systemctl status tomcat
```

Vous devriez voir une sortie indiquant que le service est actif (running).

### 2.3. Vérification des journaux Tomcat

Consultez les journaux Tomcat pour voir s'il y a des erreurs ou des avertissements :

```bash
sudo tail -f /opt/tomcat/logs/catalina.out
```

### 2.4. Vérification des ports d'écoute

Vérifiez si Tomcat écoute bien sur le port 8080 :

```bash
sudo netstat -tulpn | grep 8080
```

Si netstat n'est pas installé, vous pouvez l'installer avec :

```bash
sudo yum install -y net-tools
```

### 2.5. Vérification de l'installation de Java

Vérifiez si Java est correctement installé :

```bash
java -version
```

Vous devriez voir une sortie indiquant que Java 11 (Amazon Corretto) est installé.

## 3. Vérification via une requête HTTP

### 3.1. Depuis votre machine locale

```bash
curl -I http://[ADRESSE_IP_EC2]:8080
```

### 3.2. Depuis l'instance EC2 elle-même

```bash
curl -I http://localhost:8080
```

## 4. Vérification de l'application déployée

Si vous avez déjà déployé votre application WAR sur Tomcat, vérifiez si elle est correctement déployée :

### 4.1. Vérification des applications déployées

```bash
ls -la /opt/tomcat/webapps/
```

### 4.2. Accès à l'application via le navigateur

Ouvrez votre navigateur et accédez à l'URL : `http://[ADRESSE_IP_EC2]:8080/[NOM_APPLICATION]`

## 5. Résolution des problèmes courants

### 5.1. Tomcat ne démarre pas

Si Tomcat ne démarre pas, vérifiez les journaux pour identifier le problème :

```bash
sudo journalctl -u tomcat
```

### 5.2. Problèmes de permissions

Vérifiez que les permissions sont correctes :

```bash
sudo ls -la /opt/tomcat
sudo ls -la /opt/tomcat/webapps
```

### 5.3. Problèmes de groupe de sécurité

Vérifiez que le groupe de sécurité associé à votre instance EC2 autorise le trafic entrant sur le port 8080.

### 5.4. Redémarrage de Tomcat

Si nécessaire, redémarrez Tomcat :

```bash
sudo systemctl restart tomcat
```

## 6. Script de test automatisé

Voici un script shell que vous pouvez utiliser pour tester automatiquement l'installation de Tomcat :

```bash
#!/bin/bash

# Vérification du statut de Tomcat
echo "Vérification du statut de Tomcat..."
systemctl status tomcat | grep "active (running)" > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Tomcat est en cours d'exécution."
else
    echo "❌ Tomcat n'est pas en cours d'exécution."
    exit 1
fi

# Vérification du port 8080
echo "Vérification du port 8080..."
netstat -tulpn | grep 8080 > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Tomcat écoute sur le port 8080."
else
    echo "❌ Tomcat n'écoute pas sur le port 8080."
    exit 1
fi

# Vérification de l'accès HTTP
echo "Vérification de l'accès HTTP..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 | grep "200" > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Tomcat répond aux requêtes HTTP."
else
    echo "❌ Tomcat ne répond pas aux requêtes HTTP."
    exit 1
fi

echo "Toutes les vérifications sont passées avec succès!"
exit 0
```

Enregistrez ce script sur l'instance EC2, rendez-le exécutable avec `chmod +x script.sh`, puis exécutez-le avec `sudo ./script.sh`.
