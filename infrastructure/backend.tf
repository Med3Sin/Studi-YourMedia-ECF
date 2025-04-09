# Configuration du backend pour stocker le tfstate
# Pour utiliser ce backend, vous devez initialiser Terraform avec les options suivantes :
# terraform init \
#   -backend-config="address=https://api.github.com/repos/OWNER/REPO/contents/terraform.tfstate" \
#   -backend-config="lock_address=https://api.github.com/repos/OWNER/REPO/contents/terraform.tfstate.lock" \
#   -backend-config="unlock_address=https://api.github.com/repos/OWNER/REPO/contents/terraform.tfstate.lock" \
#   -backend-config="username=GITHUB_USERNAME" \
#   -backend-config="password=GITHUB_TOKEN"

terraform {
  backend "http" {}
}
