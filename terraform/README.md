# Terraform - srsRAN 4G/5G Migration on Azure

Ce répertoire contient la configuration Terraform pour déployer l'infrastructure Azure nécessaire au projet de migration 4G/5G srsRAN.

## Structure

```
terraform/
├── providers.tf          # Configuration du provider Azure
├── variables.tf          # Variables réutilisables
├── network.tf            # VNet, Subnets, NSGs
├── compute.tf            # VMs (Core et UE)
├── outputs.tf            # Outputs (IPs, noms, etc.)
├── terraform.tfvars      # Valeurs par défaut des variables
└── .gitignore           # Fichiers à ignorer
```

## Prérequis

- Terraform >= 1.0
- Azure CLI installé et authentifié
- Service Principal avec permissions Contributor

## Configuration

### 1. Authentification Azure

Créer un Service Principal :

```bash
az ad sp create-for-rbac --role Contributor --name srsran-terraform
```

Vous obtiendrez :
- appId (Client ID)
- password (Client Secret)
- tenant

### 2. Variables d'environnement

Remplissez `terraform.tfvars` avec vos credentials :

```hcl
azure_subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
azure_tenant_id       = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
azure_client_id       = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
azure_client_secret   = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

⚠️ **NE PAS commiter ce fichier dans Git** - Utilisez des secrets GitHub Actions.

### 3. GitHub Actions Secrets

Configurez les secrets dans Settings > Secrets and variables > Actions :

- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_TENANT_ID`
- `AZURE_SSH_PRIVATE_KEY` (pour la connexion SSH aux VMs)

## Utilisation

### Initialiser Terraform

```bash
cd terraform
terraform init
```

### Prévisualiser les changements

```bash
terraform plan
```

### Appliquer les changements

```bash
terraform apply
```

### Afficher les outputs

```bash
terraform output

# Ou en JSON
terraform output -json
```

### Détruire l'infrastructure

```bash
terraform destroy
```

## Variables personnalisables

| Variable | Défaut | Description |
|----------|--------|-------------|
| `environment` | dev | dev, staging, ou prod |
| `location` | francecentral | Région Azure (politique restreinte) |
| `vm_size` | Standard_B2s | Taille de la VM |
| `resource_group_name` | rg-srsran-4g | Nom du Resource Group |

## Workflow CI/CD

### Branches

- **develop** : Déclenche plan + validation
- **main** : Déclenche plan + validation + approval + apply

### Pipeline

1. ✅ **Format Check** - Vérifie le formatage du code
2. ✅ **Validate** - Valide la syntaxe Terraform
3. ✅ **Plan** - Génère le plan de déploiement
4. ✅ **Security** - Scan tfsec (optionnel)
5. 👤 **Approval** - Attendre l'approbation manuelle
6. ✅ **Apply** - Déploie les changements
7. ✅ **Post-Deploy** - Lance le déploiement des conteneurs

## Outputs

Après `terraform apply`, vous obtiendrez :

```
core_vm_public_ip = "4.178.56.24"
core_vm_private_ip = "10.0.1.10"
ue_vm_public_ip = "4.233.85.160"
ue_vm_private_ip = "10.0.2.10"
ssh_connection_core = "ssh azureuser@4.178.56.24"
ssh_connection_ue = "ssh azureuser@4.233.85.160"
```

## Architecture créée

```
┌─────────────────────────────────────────┐
│  Azure Resource Group (rg-srsran-4g)    │
├─────────────────────────────────────────┤
│  VNet: 10.0.0.0/16                      │
│  ├── Subnet-Core: 10.0.1.0/24           │
│  │   └── VM Core (srsEPC + srsENB)      │
│  │       IP: 10.0.1.10                  │
│  │       Public: 4.178.56.24            │
│  │                                       │
│  ├── Subnet-UE: 10.0.2.0/24             │
│  │   └── VM UE (srsUE)                  │
│  │       IP: 10.0.2.10                  │
│  │       Public: 4.233.85.160           │
│  │                                       │
│  ├── NSG Core: Ports 22, 36412, 2152    │
│  │   2001 (ZMQ RX from UE)              │
│  │                                       │
│  └── NSG UE: Ports 22                   │
│      2000 (ZMQ TX to Core)              │
└─────────────────────────────────────────┘
```

## Troubleshooting

### Erreur : "Location not allowed"

La politique Azure restreint les régions. Régions autorisées :
- norwayeast
- switzerlandnorth
- italynorth
- francecentral
- spaincentral

Mettez à jour `terraform.tfvars` avec l'une de ces régions.

### Erreur : "QuotaExceeded"

Votre quota de vCPU est insuffisant. Utilisez `Standard_B2s` au lieu de `Standard_D4s_v5`.

### Erreur SSH : "Host key verification failed"

Assurez-vous que la clé SSH publique existe :

```bash
cat ~/.ssh/id_rsa.pub
```

Sinon, générez-la :

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
```

## Améliorations futures

- [ ] Ajouter cloud-init pour déploiement automatique des conteneurs
- [ ] Importer données Terraform depuis infrastructure existante
- [ ] Configurer remote backend Azure Storage
- [ ] Ajouter workspaces pour multi-environnements
- [ ] Documenter migration 5G

## Références

- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure CLI Authentication](https://docs.microsoft.com/cli/azure/authenticate-azure-cli)
- [GitHub Actions - Terraform](https://github.com/hashicorp/setup-terraform)
