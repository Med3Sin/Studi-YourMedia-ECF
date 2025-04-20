-- Script pour sécuriser la base de données MySQL
-- Ce script révoque les privilèges de l'utilisateur root et crée un utilisateur dédié pour l'application

-- Créer un nouvel utilisateur dédié avec un mot de passe fort
-- IMPORTANT: Remplacez 'StrongPassword123!' par un mot de passe fort généré aléatoirement
CREATE USER IF NOT EXISTS 'yourmedia_user'@'%' IDENTIFIED BY 'StrongPassword123!';

-- Accorder uniquement les privilèges nécessaires sur la base de données yourmedia
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, REFERENCES, CREATE TEMPORARY TABLES ON yourmedia.* TO 'yourmedia_user'@'%';

-- Révoquer tous les privilèges de l'utilisateur root depuis les hôtes distants
-- Note: Cela ne révoque pas les privilèges de l'utilisateur root local, qui est nécessaire pour l'administration
REVOKE ALL PRIVILEGES ON yourmedia.* FROM 'root'@'%';

-- Appliquer les changements
FLUSH PRIVILEGES;

-- Afficher les utilisateurs et leurs privilèges pour vérification
SELECT user, host FROM mysql.user;
SHOW GRANTS FOR 'yourmedia_user'@'%';
