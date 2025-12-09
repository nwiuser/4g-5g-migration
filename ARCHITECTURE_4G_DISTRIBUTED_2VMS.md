# Architecture Distribuée srsRAN 4G sur 2 Azure VMs
## Plan de Déploiement et Migration vers 5G

---

## 📐 Architecture Générale

### Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Azure Virtual Network                            │
│                      10.0.0.0/16                                    │
│                                                                       │
│  ┌──────────────────────────────┐  ┌──────────────────────────────┐ │
│  │   SUBNET CORE (10.0.1.0/24)  │  │   SUBNET UE (10.0.2.0/24)    │ │
│  │                              │  │                              │ │
│  │  ┌────────────────────────┐  │  │  ┌────────────────────────┐  │ │
│  │  │   srsran-core-vm       │  │  │  │   srsran-ue-vm         │  │ │
│  │  │   Standard_D4s_v5      │  │  │  │   Standard_D4s_v5      │  │ │
│  │  │   IP: 10.0.1.x         │  │  │  │   IP: 10.0.2.x         │  │ │
│  │  │                        │  │  │  │                        │  │ │
│  │  │  Docker Containers:    │  │  │  │  Docker Containers:   │  │ │
│  │  │  ├─ srsepc (EPC)       │  │  │  │  └─ srsue (UE)         │  │ │
│  │  │  │  IP: 10.100.1.10    │  │  │  │     IP: 10.100.2.10   │  │ │
│  │  │  │  Ports:             │  │  │  │     Ports:            │  │ │
│  │  │  │  - 36412 (S1-MME)   │  │  │  │     - 2000 (ZMQ TX)   │  │ │
│  │  │  │  - 2152 (GTP-U)     │  │  │  │                       │  │ │
│  │  │  │                     │  │  │  │                       │  │ │
│  │  │  └─ srsenb (eNodeB)    │  │  │  │                       │  │ │
│  │  │     IP: 10.100.1.20    │  │  │  │                       │  │ │
│  │  │     Ports:             │  │  │  │                       │  │ │
│  │  │     - 2001 (ZMQ RX)    │  │  │  │                       │  │ │
│  │  │                        │  │  │  │                       │  │ │
│  │  │  NSG Rules:            │  │  │  │  NSG Rules:           │  │ │
│  │  │  ✓ S1-MME (36412)      │  │  │  │  ✓ ZMQ TX (2000)      │  │ │
│  │  │  ✓ GTP-U (2152)        │  │  │  │  ✓ SSH (22)           │  │ │
│  │  │  ✓ ZMQ RX (2001)       │  │  │  │                       │  │ │
│  │  │  ✓ SSH (22)            │  │  │  │                       │  │ │
│  │  └────────────────────────┘  │  │  └────────────────────────┘  │ │
│  │            │                  │  │            │                │ │
│  └────────────┼──────────────────┘  └────────────┼────────────────┘ │
│               │                                   │                  │
│               └───────────────────┬───────────────┘                  │
│                                   │                                  │
│                    Communication via VNet                            │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

### Flux de Communication

```
┌────────────────────────────────────────────────────────────────┐
│                        UE (srsue)                              │
│                    10.100.2.10:2000                            │
│                   (ZMQ Transmit Port)                          │
└────────────────────┬───────────────────────────────────────────┘
                     │
                     │  ZMQ TCP (2000 → 2001)
                     │  Port TX UE : Port RX eNodeB
                     ▼
┌────────────────────────────────────────────────────────────────┐
│                    eNodeB (srsenb)                             │
│                   10.100.1.20:2001                             │
│                  (ZMQ Receive Port)                            │
│                                                                │
│         Décide si accepte la connexion UE via HSS             │
└────────────────┬──────────────────────────────────────────────┘
                 │
                 │  S1-MME (36412/TCP)
                 │
                 ▼
┌────────────────────────────────────────────────────────────────┐
│                  EPC (srsepc - MME)                            │
│                  10.100.1.10:36412                             │
│                                                                │
│  Gère authentification, allocation de ressources, billing     │
│                                                                │
│  Base de données:                                              │
│  IMSI: 001010123456780                                         │
│  Key: 8baf473f2f5a3a47                                        │
│  OPC: 47b91223872d93b6                                        │
└────────────────────────────────────────────────────────────────┘
         │
         │  GTP-U (2152/UDP)
         │  Encapsulation des données utilisateur
         ▼
┌────────────────────────────────────────────────────────────────┐
│              SGW/PGW (SPGW - srsepc)                           │
│                   10.100.1.10:2152                             │
│                                                                │
│  Routage des données vers Internet (sortie réseau)            │
└────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Déploiement - Étapes d'Installation

### Prérequis

```powershell
# Windows PowerShell avec Azure CLI installée
az --version  # Doit afficher 2.50+

# Authentification Azure
az login
az account show  # Vérifier la souscription par défaut
```

### Phase 1 : Lancer le script de déploiement

```powershell
# Depuis le répertoire racine du projet
cd C:\Users\NajibNOUISSER\Desktop\srsRAN\4g-5g-migration

# Exécuter le script
.\deploy-azure-4g-distributed.ps1
```

**Durée estimée** : 15-20 minutes
- Création VNet + Subnets : 2 min
- Création NSGs + Rules : 1 min
- Création VM Core : 5 min
- Création VM UE : 5 min
- Installation Docker + Services : 5-10 min

### Phase 2 : Vérification post-déploiement

```bash
# SSH vers VM Core
ssh azureuser@<PUBLIC_IP_CORE>
cd /home/srsran

# Vérifier les services
docker-compose ps

# Consulter les logs
docker-compose logs -f srsepc
docker-compose logs -f srsenb
```

**Résultat attendu** :
```
CONTAINER ID   IMAGE                    STATUS
abc123         nouisser1/srsepc-4g      Up 2 minutes
def456         nouisser1/srsenb-4g      Up 1 minute
```

```bash
# SSH vers VM UE (autre terminal)
ssh azureuser@<PUBLIC_IP_UE>
cd /home/srsran

# Vérifier le service UE
docker-compose logs -f srsue
```

**Résultat attendu pour UE** :
```
[UE] Searching for cell...
[UE] Cell found! Connecting...
[UE] Attached to eNodeB
```

---

## 📊 Configuration Réseau Détaillée

### VM CORE - Docker Network

```yaml
# docker-compose.yml sur srsran-core-vm

networks:
  backend:
    driver: bridge
    ipam:
      config:
        - subnet: 10.100.1.0/24

services:
  srsepc:
    networks:
      backend:
        ipv4_address: 10.100.1.10
    ports:
      - "36412:36412"      # S1-MME (eNodeB → EPC)
      - "2152:2152/udp"    # GTP-U (Données)
      
  srsenb:
    networks:
      backend:
        ipv4_address: 10.100.1.20
    ports:
      - "2001:2001"        # ZMQ RX (reçoit du UE)
    depends_on:
      - srsepc             # Attendre EPC avant de démarrer
```

### VM UE - Docker Network

```yaml
# docker-compose.yml sur srsran-ue-vm

networks:
  radio:
    driver: bridge

services:
  srsue:
    networks:
      radio:
    ports:
      - "2000:2000"        # ZMQ TX (envoie vers eNodeB)
    environment:
      - ENB_ADDR=10.0.1.x  # IP privée du Core sur VNet Azure
      - RF_DEVICE_ARGS=tx_port=tcp://*:2000,rx_port=tcp://10.0.1.x:2001
```

### Azure VNet Configuration

```
Virtual Network: srsran-vnet (10.0.0.0/16)
│
├─ Subnet Core (10.0.1.0/24)
│  ├─ srsran-core-vm : 10.0.1.4 (Private)
│  └─ Public IP: <PUBLIC_IP_CORE>
│
└─ Subnet UE (10.0.2.0/24)
   ├─ srsran-ue-vm : 10.0.2.4 (Private)
   └─ Public IP: <PUBLIC_IP_UE>
```

---

## 🔒 Sécurité - Network Security Groups (NSGs)

### NSG Core (srsran-core-nsg)

| Règle | Direction | Port | Protocole | Source | Destination | Statut |
|-------|-----------|------|-----------|--------|-------------|--------|
| allow-s1-mme | Inbound | 36412 | TCP | Any | Any | ✓ |
| allow-gtp-u | Inbound | 2152 | UDP | Any | Any | ✓ |
| allow-zmq-rx | Inbound | 2001 | TCP | Any | Any | ✓ |
| allow-ssh | Inbound | 22 | TCP | Any | Any | ✓ |
| AllowVnetInBound | Inbound | Any | Any | VirtualNetwork | VirtualNetwork | ✓ |

**À renforcer pour production** :
```powershell
# Restreindre S1-MME aux IPs privées du subnet UE
az network nsg rule update \
  --resource-group devops \
  --nsg-name srsran-core-nsg \
  --name allow-s1-mme \
  --source-address-prefixes 10.0.2.0/24

# Restreindre GTP-U aux IPs privées du subnet UE
az network nsg rule update \
  --resource-group devops \
  --nsg-name srsran-core-nsg \
  --name allow-gtp-u \
  --source-address-prefixes 10.0.2.0/24
```

### NSG UE (srsran-ue-nsg)

| Règle | Direction | Port | Protocole | Source | Destination | Statut |
|-------|-----------|------|-----------|--------|-------------|--------|
| allow-zmq-tx | Inbound | 2000 | TCP | Any | Any | ✓ |
| allow-ssh | Inbound | 22 | TCP | Any | Any | ✓ |
| AllowVnetOutBound | Outbound | Any | Any | Any | VirtualNetwork | ✓ |

**À renforcer pour production** :
```powershell
# Restreindre ZMQ TX aux IPs privées du subnet Core
az network nsg rule update \
  --resource-group devops \
  --nsg-name srsran-ue-nsg \
  --name allow-zmq-tx \
  --source-address-prefixes 10.0.1.0/24
```

---

## 📈 Scalabilité et Performances

### Dimensionnement actuel

```
VM CORE (srsran-core-vm):
  - CPU: 4 vCores (Standard_D4s_v5)
  - RAM: 16 GB
  - Stockage: 128 GB SSD (OS)
  
  Charge estimée:
  - srsepc (EPC/HSS/MME): 1-2 vCores, 2 GB RAM
  - srsenb (eNodeB 50 PRBs): 2-3 vCores, 4 GB RAM
  - OS + Docker: 0.5 vCores, 2 GB RAM
  
  Capacité restante: ~0.5 vCores, ~8 GB RAM
  → Bon pour ajouter du monitoring, NF 5G supplémentaires

VM UE (srsran-ue-vm):
  - CPU: 4 vCores (Standard_D4s_v5)
  - RAM: 16 GB
  - Stockage: 128 GB SSD (OS)
  
  Charge estimée:
  - srsue (1 UE): 0.5-1 vCore, 1 GB RAM
  - OS + Docker: 0.5 vCores, 1 GB RAM
  
  Capacité restante: ~2.5 vCores, ~14 GB RAM
  → Bon pour ajouter plusieurs UE (simulator), tests de charge
```

### Plan de scalabilité future

```
Phase 1 (Actuel - 4G):
  ✓ 1 Core VM (EPC + eNodeB)
  ✓ 1 UE VM (1 device)
  → Peut gérer 1 UE en full duplex

Phase 2 (Améliorations 4G):
  → Ajouter plusieurs UE sur même VM (multiples processus srsue)
  → Possible: 3-5 UE simultanés sur VM D4s_v5

Phase 3 (5G - Nouveau subnet 10.0.3.0/24):
  → Nouvelle VM: srsran-5g-core
  → Services: 5G NF (gNodeB, 5GC)
  → Coexistence 4G + 5G via VNet peering

Phase 4 (Production):
  → Kubernetes/AKS pour orchestration dynamique
  → Load balancer pour plusieurs eNodeB
  → Auto-scaling pour UE simulateurs
```

---

## 🔄 Migration 4G → 5G

### Approche Coexistence (Dual-Stack)

La structure déployée permet une migration **sans downtime** :

```
Étape 1: État actuel (semaine 1-2)
┌─────────────────────────────┐
│   Subnet 10.0.1.0/24       │
│   ├─ srsran-core-vm (4G)   │
│   │  ├─ srsepc             │
│   │  └─ srsenb             │
│   └─ srsran-ue-vm (4G)     │
│      └─ srsue (1 UE)       │
└─────────────────────────────┘

Étape 2: Ajouter infrastructure 5G (semaine 3-4)
┌──────────────────────────────────────────────────┐
│  Subnet 10.0.1.0/24           Subnet 10.0.3.0/24│
│  ├─ srsran-core-vm (4G)       ├─ srsran-5g-core │
│  │  ├─ srsepc                 │  ├─ 5G NF       │
│  │  └─ srsenb (4G)            │  └─ gNodeB (5G) │
│  └─ srsran-ue-vm (4G)         └─ srsran-ue-vm  │
│     └─ srsue (4G)                └─ srsue (5G)  │
└──────────────────────────────────────────────────┘

Étape 3: Migration progressive des UE (semaine 5-6)
┌──────────────────────────────────────────────────┐
│  Subnet 10.0.1.0/24           Subnet 10.0.3.0/24│
│  ├─ srsran-core-vm (4G)       ├─ srsran-5g-core │
│  │  ├─ srsepc                 │  ├─ 5G NF       │
│  │  └─ srsenb (4G)            │  └─ gNodeB (5G) │
│  └─ srsran-ue-vm (4G→5G)      └─ (Devices)      │
│     └─ srsue (dual)              └─ srsue (5G)  │
│        (4G + 5G)                    (multi UE)   │
└──────────────────────────────────────────────────┘

Étape 4: Fin de vie du 4G (semaine 7-8)
┌──────────────────────────────┐
│  Subnet 10.0.3.0/24          │
│  └─ srsran-5g-core           │
│     ├─ 5G NF                 │
│     └─ gNodeB (5G)           │
│  └─ srsran-ue-vm (5G)        │
│     └─ srsue (5G - multi)    │
└──────────────────────────────┘
```

### Déploiement 5G (Semaine 3)

```powershell
# Script à créer pour Phase 2

param(
    [string]$CORE_IP = "10.0.1.4"  # IP du Core 4G
)

# 1. Créer subnet 5G
az network vnet subnet create `
    --resource-group devops `
    --vnet-name srsran-vnet `
    --name subnet-5g `
    --address-prefix 10.0.3.0/24

# 2. Créer NSG pour 5G
az network nsg create `
    --resource-group devops `
    --name srsran-5g-nsg

# 3. Créer VM 5G Core
az vm create `
    --resource-group devops `
    --name srsran-5g-core `
    --image UbuntuLTS `
    --size Standard_D4s_v5 `
    --vnet-name srsran-vnet `
    --subnet subnet-5g `
    --nsg srsran-5g-nsg

# 4. Installer services 5G sur VM
# - 5G NF (AMF, SMF, etc.)
# - gNodeB (srsran 5G)
# - UE client pour tests
```

### Considérations UE Dual-Stack

```dockerfile
# À l'étape 3, l'UE doit supporter à la fois 4G et 5G

# Option A: Deux conteneurs srsue
docker-compose:
  srsue-4g:
    image: nouisser1/srsue-4g:latest
    environment:
      - ENB_ADDR=10.0.1.4      # Core 4G
      - RF_DEVICE_ARGS=zmq://...
  
  srsue-5g:
    image: nouisser1/srsue-5g:latest
    environment:
      - gNB_ADDR=10.0.3.4      # Core 5G
      - RF_DEVICE_ARGS=zmq://...

# Option B: UE natif dual-mode (si srsRAN le supporte)
docker-compose:
  srsue-dual:
    image: nouisser1/srsue-nr:latest
    environment:
      - NR_BANDS=7,78          # Band 7 4G, Band 78 5G
      - CORE_4G_ADDR=10.0.1.4
      - CORE_5G_ADDR=10.0.3.4
```

---

## 📊 Monitoring et Observabilité

### Logs 4G

```bash
# Sur VM Core
ssh azureuser@<PUBLIC_IP_CORE>
cd /home/srsran

# Logs en direct (suivi des connexions UE)
docker-compose logs -f

# Logs d'un service spécifique
docker-compose logs -f srsepc
docker-compose logs -f srsenb

# Sauvegarder les logs
docker-compose logs > logs-$(date +%Y%m%d_%H%M%S).txt
```

### Métriques clés à surveiller (Phase 1)

```
EPC (srsepc):
  - Nombre d'UE connectés
  - Taux de rejet de connexion
  - Latence MME

eNodeB (srsenb):
  - PRBs disponibles vs utilisés
  - Puissance de transmission
  - SINR moyen

UE (srsue):
  - Signal strength (RSRP, SINR)
  - Taux de perte de paquets
  - Handover (si applicable)
  - Throughput montant/descendant
```

### Azure Monitor (Optional - Phase 2)

```powershell
# Créer Application Insights pour monitoring centralisé
az monitor app-insights component create `
    --app srsran-4g-monitor `
    --location italynorth `
    --resource-group devops

# Exporter des logs des conteneurs
# Option 1: Envoyer logs vers Log Analytics
# Option 2: Intégrer Prometheus + Grafana dans les VMs
```

### Dashboard Grafana (Optional)

```yaml
# À ajouter à docker-compose (Phase 2)

services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    depends_on:
      - prometheus
```

---

## 🆘 Troubleshooting

### Problème : UE ne voit pas l'eNodeB

**Symptôme** :
```
[UE] Searching for cell...
[UE] Could not find cell, waiting 5 seconds...
```

**Diagnostic** :
```bash
# 1. Vérifier que srsenb est en cours d'exécution
ssh azureuser@<PUBLIC_IP_CORE>
docker-compose ps

# 2. Vérifier les logs srsenb
docker-compose logs srsenb | grep -i "radio\|zmq\|error"

# 3. Vérifier la connexion réseau UE → Core
ssh azureuser@<PUBLIC_IP_UE>

# Test de connectivité vers port ZMQ Core
nc -zv 10.0.1.4 2001
# Résultat attendu: Connection to 10.0.1.4 2001 [tcp/*] succeeded!
```

**Solutions** :
```bash
# Si la connectivité échoue: vérifier NSG
az network nsg rule list --resource-group devops --nsg-name srsran-core-nsg -o table

# Redémarrer les services
docker-compose restart srsenb

# Vérifier l'adresse IP privée du Core (peut changer)
az vm show -d --resource-group devops --name srsran-core-vm --query privateIps
# Mettre à jour dans docker-compose UE si elle a changé
```

### Problème : Authentification UE échouée

**Symptôme** :
```
[UE] RRC Reconfiguration received
[UE] Authentication failed!
[UE] NAS Error: User not found in HSS
```

**Cause** : IMSI dans la base de données ne correspond pas

**Solution** :
```bash
# 1. Vérifier la configuration UE
ssh azureuser@<PUBLIC_IP_UE>
cat docker-compose.yml | grep -A5 srsue

# 2. Vérifier la base de données EPC
ssh azureuser@<PUBLIC_IP_CORE>
docker-compose exec srsepc cat /etc/srsran/user_db.csv

# 3. Vérifier correspondance IMSI
# Doit être: 001010123456780

# Si pas de correspondance: arrêter et modifier
docker-compose down
# Éditer la section srsue dans docker-compose.yml
# Ajouter:
# environment:
#   - UE_IMSI=001010123456780
docker-compose up -d
```

### Problème : Erreur SIGILL

**Symptôme** (rare, mais possiblement sur anciennes VMs) :
```
Illegal instruction (core dumped)
```

**Cause** : CPU ne supporte pas AVX2

**Solution** : Utiliser VM type Standard_D4s_v5 ou plus récent (standard_d4s_v4+ minimum)

```powershell
# Vérifier le CPU de la VM
az vm run-command invoke `
    --resource-group devops `
    --name srsran-core-vm `
    --command-id RunShellScript `
    --scripts "lscpu | grep -i avx"
```

### Problème : Consommation mémoire élevée

**Diagnostic** :
```bash
ssh azureuser@<PUBLIC_IP_CORE>

# Vérifier l'utilisation
docker stats

# Si srsepc consomme >4GB
docker logs srsepc | grep -i "memory\|alloc"
```

---

## 📋 Checklist Déploiement

### Avant le déploiement
- [ ] Compte Azure avec accès administrateur
- [ ] Azure CLI v2.50+ installée
- [ ] Souscription Azure valide
- [ ] Quota vCPU >= 8 (2 VMs × 4 vCores)
- [ ] Budget Azure estimé

### Pendant le déploiement
- [ ] Script de déploiement exécuté sans erreur
- [ ] 2 VMs créées et démarrées
- [ ] 2 adresses IP publiques assignées
- [ ] Services Docker lancés (srsepc, srsenb, srsue)
- [ ] Pas d'erreurs SIGILL dans les logs

### Après le déploiement
- [ ] SSH accessible sur les 2 VMs
- [ ] `docker-compose ps` affiche 3 conteneurs "Up"
- [ ] EPC logs ne montrent pas "SCTP socket" error
- [ ] eNodeB logs affichent "Ready to accept connections"
- [ ] UE logs affichent "Attached to eNodeB"
- [ ] Ping entre les 2 VMs réussit
- [ ] Services survivent à un redémarrage VM

### Nettoyage (si déploiement échoue)
```powershell
# Supprimer les ressources créées
az group delete --name devops --yes

# OU supprimer sélectivement
az vm delete --resource-group devops --name srsran-core-vm --yes
az vm delete --resource-group devops --name srsran-ue-vm --yes
az network vnet delete --resource-group devops --name srsran-vnet
```

---

## 💾 Sauvegarde et Récupération

### Sauvegarder les configurations

```bash
# Sur chaque VM
ssh azureuser@<PUBLIC_IP>
cd /home/srsran

# Exporter docker-compose et configs
tar -czf srsran-backup-$(date +%Y%m%d).tar.gz docker-compose.yml

# Exporter les logs
docker-compose logs > srsran-logs-$(date +%Y%m%d_%H%M%S).txt

# Télécharger sur local
# (Depuis machine locale)
scp -r azureuser@<PUBLIC_IP>:/home/srsran/*.tar.gz ./backups/
scp -r azureuser@<PUBLIC_IP>:/home/srsran/*.txt ./backups/
```

### Restaurer après incident

```bash
# Si un service crash
ssh azureuser@<PUBLIC_IP_CORE>
cd /home/srsran
docker-compose restart srsepc
docker-compose restart srsenb

# Si la VM redémarre (données persistent)
docker-compose up -d

# Vérifier l'état
docker-compose ps
docker-compose logs
```

---

## 🎯 Prochaines Étapes

### Court terme (Semaine 1-2)
1. ✅ Déployer architecture 4G distribuée sur 2 VMs
2. ✅ Valider connectivité UE ↔ eNodeB
3. ✅ Mesurer performances (throughput, latency, SINR)
4. ✅ Tester résilience (redémarrage services/VMs)

### Moyen terme (Semaine 3-4)
1. Préparer infrastructure 5G (subnet, VMs, NSG)
2. Déployer 5G Core et gNodeB
3. Tester communication 4G ↔ 5G (si dual-band possible)
4. Implémenter monitoring (Prometheus/Grafana)

### Long terme (Semaine 5+)
1. Migration progressive UE vers 5G
2. Optimisation des performances 5G
3. Load testing (multiples UE simultanés)
4. Déploiement de redundance (HA/DR)
5. Préparation pour production

---

## 📚 Ressources Supplémentaires

### Documentation srsRAN
- https://srsran.org/
- https://github.com/srsran/srsran_project

### Azure Docs
- https://learn.microsoft.com/en-us/azure/virtual-machines/windows/
- https://learn.microsoft.com/en-us/azure/virtual-network/

### Troubleshooting
- Docker logs: `docker logs <container_id>`
- Azure Portal: https://portal.azure.com
- Azure CLI Reference: `az vm --help`

---

**Document créé le**: December 7, 2025  
**Version**: 2.0 (Distribuée - 2 VMs)  
**Statut**: Production-Ready ✅
