# Module de gestion des secrets pour YourMédia
# Ce module gère les secrets générés automatiquement et les stocke dans Terraform Cloud
# Il inclut également une rotation automatique des secrets basée sur un calendrier

terraform {
  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.42.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Ressource de temps pour la rotation des secrets
# Cette ressource est utilisée pour déclencher la rotation des secrets selon un calendrier
resource "time_rotating" "secret_rotation" {
  rotation_days = var.secret_rotation_days
}

# Génération d'un mot de passe aléatoire pour la base de données SonarQube
resource "random_password" "sonar_jdbc_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_special      = 2
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2

  # Utiliser le timestamp de rotation pour déclencher la régénération du mot de passe
  keepers = {
    rotation_time = time_rotating.secret_rotation.id
  }
}

# Génération d'un mot de passe aléatoire pour l'administrateur Grafana
resource "random_password" "grafana_admin_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_special      = 2
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2

  # Utiliser le timestamp de rotation pour déclencher la régénération du mot de passe
  keepers = {
    rotation_time = time_rotating.secret_rotation.id
  }
}

# Stockage du mot de passe SonarQube dans Terraform Cloud
resource "tfe_variable" "sonar_jdbc_password" {
  workspace_id = var.workspace_id
  key          = "sonar_jdbc_password"
  value        = random_password.sonar_jdbc_password.result
  category     = "terraform"
  sensitive    = true
  description  = "Mot de passe généré automatiquement pour la base de données SonarQube"
}

# Stockage du nom d'utilisateur SonarQube dans Terraform Cloud
resource "tfe_variable" "sonar_jdbc_username" {
  workspace_id = var.workspace_id
  key          = "sonar_jdbc_username"
  value        = "sonar"
  category     = "terraform"
  sensitive    = false
  description  = "Nom d'utilisateur pour la base de données SonarQube"
}

# Stockage de l'URL de connexion SonarQube dans Terraform Cloud
resource "tfe_variable" "sonar_jdbc_url" {
  workspace_id = var.workspace_id
  key          = "sonar_jdbc_url"
  value        = "jdbc:postgresql://sonarqube-db:5432/sonar"
  category     = "terraform"
  sensitive    = false
  description  = "URL de connexion à la base de données SonarQube"
}

# Stockage du mot de passe administrateur Grafana dans Terraform Cloud
resource "tfe_variable" "grafana_admin_password" {
  workspace_id = var.workspace_id
  key          = "grafana_admin_password"
  value        = random_password.grafana_admin_password.result
  category     = "terraform"
  sensitive    = true
  description  = "Mot de passe généré automatiquement pour l'administrateur Grafana"
}

# Création d'une ressource SNS pour les notifications de rotation de secrets
resource "aws_sns_topic" "secret_rotation_notification" {
  count = var.enable_rotation_notifications ? 1 : 0
  name  = "secret-rotation-notifications"
  tags = {
    Name        = "secret-rotation-notifications"
    Environment = var.environment
    Project     = "YourMedia"
  }
}

# Création d'une politique pour autoriser l'envoi de notifications
data "aws_iam_policy_document" "sns_topic_policy" {
  count = var.enable_rotation_notifications ? 1 : 0
  statement {
    actions = [
      "SNS:Publish",
    ]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    resources = [
      aws_sns_topic.secret_rotation_notification[0].arn,
    ]
  }
}

# Attachement de la politique au topic SNS
resource "aws_sns_topic_policy" "default" {
  count  = var.enable_rotation_notifications ? 1 : 0
  arn    = aws_sns_topic.secret_rotation_notification[0].arn
  policy = data.aws_iam_policy_document.sns_topic_policy[0].json
}

# Abonnement à la notification par email
resource "aws_sns_topic_subscription" "email_subscription" {
  count     = var.enable_rotation_notifications && var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.secret_rotation_notification[0].arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# Création d'un événement CloudWatch pour déclencher une notification lors de la rotation des secrets
resource "aws_cloudwatch_event_rule" "secret_rotation" {
  count               = var.enable_rotation_notifications ? 1 : 0
  name                = "secret-rotation-notification"
  description         = "Déclenche une notification lors de la rotation des secrets"
  schedule_expression = "rate(${var.secret_rotation_days} days)"
}

# Cible de l'événement CloudWatch (SNS)
resource "aws_cloudwatch_event_target" "sns" {
  count     = var.enable_rotation_notifications ? 1 : 0
  rule      = aws_cloudwatch_event_rule.secret_rotation[0].name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.secret_rotation_notification[0].arn
  input     = jsonencode({
    message = "Les secrets de l'application YourMedia ont été automatiquement rotés. Veuillez vérifier que tous les services fonctionnent correctement."
    time    = "$${aws:time}"
  })
}

# Stockage de la date de dernière rotation dans Terraform Cloud
resource "tfe_variable" "last_rotation_date" {
  workspace_id = var.workspace_id
  key          = "last_rotation_date"
  value        = time_rotating.secret_rotation.id
  category     = "terraform"
  sensitive    = false
  description  = "Date de la dernière rotation des secrets"
}