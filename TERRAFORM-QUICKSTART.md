# Guide de démarrage - Terraform + GitHub Actions

## 📋 Prérequis

### Localement

```bash
# 1. Installer Terraform
# macOS
brew install terraform

# Linux
apt-get install terraform

# 2. Installer Azure CLI
# macOS
brew install azure-cli

# Linux
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# 3. Authentification Azure
az login
```

### GitHub

1. Fork le repository dans votre compte
2. Allez dans Settings > Secrets and variables > Actions
3. Créez les secrets suivants

## 🔑 Configuration des Secrets GitHub

### Étape 1 : Créer un Service Principal Azure

```bash
# Créer le Service Principal
az ad sp create-for-rbac --role Contributor --name srsran-terraform

# Résultat attendu :
{
  "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "displayName": "srsran-terraform",
  "password": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "tenant": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

### Étape 2 : Récupérer l'ID de souscription

```bash
az account show --query id --output tsv
# Résultat : xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### Étape 3 : Créer les secrets GitHub

Allez sur GitHub > Settings > Secrets and variables > Actions > New repository secret

Créez ces secrets :

| Secret Name | Valeur |
|-------------|--------|
| `AZURE_CLIENT_ID` | appId du Service Principal |
| `AZURE_CLIENT_SECRET` | password du Service Principal |
| `AZURE_SUBSCRIPTION_ID` | ID de souscription |
| `AZURE_TENANT_ID` | tenant du Service Principal |
| `AZURE_SSH_PRIVATE_KEY` | Contenu de ~/.ssh/id_rsa |

**Pour AZURE_SSH_PRIVATE_KEY :**

```bash
# Générer une clé SSH si elle n'existe pas
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

# Copier la clé privée
cat ~/.ssh/id_rsa
# Coller dans le secret GitHub
```

## 🚀 Premier déploiement

### Option 1 : Via GitHub Actions (recommandé)

1. Remplissez `terraform/terraform.tfvars` avec vos paramètres
2. Committez et pushez sur la branche `main`
3. GitHub Actions lancera automatiquement le pipeline
4. Approuvez le déploiement dans l'interface GitHub

### Option 2 : Via CLI local

```bash
cd terraform

# Initialiser
terraform init

# Prévisualiser
terraform plan

# Déployer
terraform apply

# Afficher les IPs
terraform output
```

## 📊 Pipeline GitHub Actions

### Branches

- **develop** : `plan` + `validate` (pas de déploiement)
- **main** : `plan` + `validate` + **approval** + `apply` + post-deploy

### Flux complet

```
1. git push origin main
   ↓
2. Format Check ✅
   ↓
3. Terraform Validate ✅
   ↓
4. Terraform Plan ✅
   ↓
5. Security Scan (tfsec) ✅
   ↓
6. [⏸️ Attendre approbation]
   ↓
7. Terraform Apply ✅
   ↓
8. Deploy Containers ✅
```

### Approuver un déploiement

1. Allez sur GitHub > Actions > Workflow en cours
2. Cliquez sur "Review deployments"
3. Sélectionnez l'environnement "production"
4. Cliquez "Approve and deploy"

## 🔧 Configuration locale

### 1. Cloner le repo

```bash
git clone https://github.com/yourusername/4g-5g-migration.git
cd 4g-5g-migration
```

### 2. Remplir les variables

```bash
cd terraform

# Copier le fichier de variables
cp terraform.tfvars.example terraform.tfvars

# Éditer avec vos valeurs
nano terraform.tfvars
```

### 3. Initialiser Terraform

```bash
terraform init
```

### 4. Vérifier le plan

```bash
terraform plan

# Vous devriez voir :
# Plan: 15 to add, 0 to change, 0 to destroy.
```

### 5. Appliquer

```bash
terraform apply

# Confirmez en tapant : yes
```

## 📡 Connexion aux VMs

### Après le déploiement

```bash
# Afficher les informations de connexion
terraform output

# Exemple de résultat :
# core_vm_public_ip = "4.178.56.24"
# ue_vm_public_ip = "4.233.85.160"
# ssh_connection_core = "ssh azureuser@4.178.56.24"
# ssh_connection_ue = "ssh azureuser@4.233.85.160"
```

### Se connecter

```bash
# Core VM
ssh azureuser@4.178.56.24

# UE VM
ssh azureuser@4.233.85.160
```

## ⚙️ Personnaliser le déploiement

### Changer la région

```hcl
# terraform/terraform.tfvars
location = "italynorth"  # Au lieu de francecentral
```

### Changer la taille de la VM

```hcl
# terraform/terraform.tfvars
vm_size = "Standard_D2s_v3"  # Au lieu de Standard_B2s
```

### Ajouter des tags

```hcl
# terraform/terraform.tfvars
tags = {
  Project     = "srsRAN"
  Environment = "4G/5G Migration"
  ManagedBy   = "Terraform"
  Owner       = "votre-nom"
  CostCenter  = "123456"
}
```

## 🗑️ Nettoyer les ressources

### Via CLI

```bash
cd terraform
terraform destroy

# Confirmez en tapant : yes
```

### Via GitHub Actions

Créez une branche et pushez un commit qui commente les ressources :

```bash
git checkout -b cleanup
# Commentez les ressources dans compute.tf
git push origin cleanup
# Approuvez dans GitHub
```

## 🐛 Troubleshooting

### Erreur : "authentication failed"

Vérifiez les secrets GitHub :

```bash
az account show  # Vérifier la connexion locale
```

### Erreur : "Location not allowed"

Changez la région dans `terraform.tfvars` :

```hcl
location = "francecentral"  # Région autorisée par la politique Azure
```

### Erreur : "SSH key not found"

Générez une clé SSH :

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

### Erreur : "State is already locked"

Quelqu'un d'autre applique des changements. Attendez que le pipeline se termine.

## 📚 Ressources

- [Documentation Terraform Azure](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Azure CLI Reference](https://docs.microsoft.com/cli/azure/reference-index)

## 🎯 Prochaines étapes

1. ✅ Configurer les secrets GitHub
2. ✅ Valider le plan Terraform
3. ✅ Approuver et déployer
4. ⏳ Déployer les conteneurs srsRAN
5. ⏳ Tester la connectivité 4G
6. ⏳ Planifier la migration 5G

## 📞 Support

En cas de problème :

1. Vérifiez les logs GitHub Actions
2. Consultez la documentation Terraform
3. Créez une issue dans le repository
