# Guide de configuration Azure pour Terraform

## 📋 Ce qu'il faut faire avant le déploiement

### 1️⃣ Générer une clé SSH (si vous ne l'avez pas)

```powershell
# Sur Windows PowerShell
ssh-keygen -t rsa -b 4096 -f "$env:USERPROFILE\.ssh\id_rsa" -N ""

# Vérifier que la clé existe
type $env:USERPROFILE\.ssh\id_rsa.pub
```

**Résultat attendu :** Une clé publique ressemble à :
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDxyz...
```

### 2️⃣ Créer un Service Principal Azure

```powershell
# Vous devez d'abord vous connecter à Azure
az login

# Créer le Service Principal
az ad sp create-for-rbac --role Contributor --name srsran-terraform
```

**Résultat attendu :**
```json
{
  "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "displayName": "srsran-terraform",
  "password": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "tenant": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

**Sauvegardez ces valeurs :** appId, password, tenant

### 3️⃣ Récupérer l'ID de souscription

```powershell
az account show --query id --output tsv
```

Vous obtiendrez quelque chose comme : `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

### 4️⃣ Configurer les secrets GitHub

Allez sur votre repository GitHub et créez les secrets suivants :

**GitHub > Settings > Secrets and variables > Actions > New repository secret**

| Secret Name | Valeur |
|-------------|--------|
| `AZURE_CLIENT_ID` | appId du Service Principal |
| `AZURE_CLIENT_SECRET` | password du Service Principal |
| `AZURE_SUBSCRIPTION_ID` | Votre subscription ID |
| `AZURE_TENANT_ID` | tenant du Service Principal |
| `AZURE_SSH_PUBLIC_KEY` | Contenu de `~/.ssh/id_rsa.pub` |

**Pour `AZURE_SSH_PUBLIC_KEY` :**

```powershell
# Lire la clé publique
type $env:USERPROFILE\.ssh\id_rsa.pub

# Copier tout le contenu et le coller dans le secret GitHub
```

### 5️⃣ Remplir terraform.tfvars pour développement local

```bash
cd terraform

# Éditer terraform.tfvars
# Mettez vos valeurs dans les champs vides :
# azure_subscription_id = "votre-id-ici"
# azure_tenant_id = "votre-tenant-ici"
# azure_client_id = "votre-client-id-ici"
# azure_client_secret = "votre-secret-ici"
# ssh_public_key = "ssh-rsa AAAAB3Nza..."
```

## 🚀 Déploiement

### Via GitHub Actions (recommandé - pas de credentials locales)

```bash
# 1. Committez vos changements
git add .
git commit -m "chore: add Terraform config"

# 2. Pushez sur main pour déclencher le déploiement
git push origin main

# 3. Allez sur GitHub > Actions et approuvez le déploiement

# 4. Attendez la fin de l'apply
```

### Via Terraform CLI (développement local)

```bash
cd terraform

# 1. Initialiser
terraform init

# 2. Vérifier le plan
terraform plan

# 3. Appliquer
terraform apply

# 4. Afficher les IPs
terraform output
```

## ✅ Vérification après déploiement

```powershell
# Récupérer les IPs
terraform output

# Exemple :
# core_vm_public_ip = "4.178.56.24"
# ue_vm_public_ip = "4.233.85.160"

# Se connecter au Core VM
ssh azureuser@4.178.56.24

# Se connecter au UE VM
ssh azureuser@4.233.85.160

# Vérifier que Docker est installé
docker --version
docker-compose --version
```

## 🔐 Sécurité

⚠️ **IMPORTANT :**
- **Ne committez PAS `terraform.tfvars`** à Git - il contient vos credentials
- Utilisez GitHub Secrets pour la production
- Rotatez régulièrement votre Service Principal
- Ne partagez jamais vos credentials

## 🗑️ Nettoyage

```bash
cd terraform

# Supprimer toutes les ressources Azure
terraform destroy

# Confirmez avec : yes
```

## 🐛 Troubleshooting

### "subscription policy" error

La région que vous avez choisie n'est pas autorisée. Changez dans `terraform.tfvars` :

```
location = "francecentral"  # Ou : norwayeast, switzerlandnorth, italynorth, spaincentral
```

### "QuotaExceeded" error

Votre quota de vCPUs est dépassé. Changez la taille de VM dans `terraform.tfvars` :

```
vm_size = "Standard_B2s"  # Plus petite (2 vCPUs)
```

### "SSH key not found"

Assurez-vous que la clé SSH existe et que vous l'avez copiée correctement :

```powershell
# Regénérer la clé
ssh-keygen -t rsa -b 4096 -f "$env:USERPROFILE\.ssh\id_rsa" -N ""

# Copier dans le secret GitHub
type $env:USERPROFILE\.ssh\id_rsa.pub
```

### "Authentication failed"

Vérifiez vos credentials :

```powershell
# Tester Azure CLI
az account show

# Si erreur, reconnecter-vous
az login
```

## 📞 Aide supplémentaire

- [Documentation Terraform Azure](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Azure CLI Reference](https://docs.microsoft.com/cli/azure)

---

**Une fois que vous avez configuré tout cela, le déploiement est entièrement automatisé !** 🎉
