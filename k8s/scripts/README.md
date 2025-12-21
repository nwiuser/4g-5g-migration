# Scripts Kubernetes - Guide d'Utilisation

Ce dossier contient tous les scripts utilitaires pour gérer votre déploiement Kubernetes de migration 4G vers 5G.

## 📜 Scripts Disponibles

### 🚀 `deploy.sh` - Déploiement Automatisé
Script principal pour installer l'infrastructure complète.

**Usage :**
```bash
./deploy.sh                    # Mode interactif
./deploy.sh --auto             # Mode automatique (tout installer)
ENVIRONMENT=prod ./deploy.sh   # Déployer en production
```

**Fonctionnalités :**
- Vérification des prérequis (kubectl, helm)
- Installation des namespaces
- Déploiement des services partagés (MongoDB, DNS)
- Déploiement Core 4G et/ou 5G
- Configuration post-déploiement
- Mode dual-stack avec interworking N26

---

### ✅ `validate-deployment.sh` - Validation Complète
Valide que tous les composants sont opérationnels.

**Usage :**
```bash
./validate-deployment.sh
```

**Tests effectués :**
- Connectivité kubectl et cluster
- Vérification des namespaces
- État des services partagés (MongoDB, DNS)
- État du Core 4G (tous composants)
- État du Core 5G (tous composants)
- Connectivité réseau
- Endpoints métriques
- Utilisation des ressources

**Sortie :**
- ✓ Tests réussis en vert
- ✗ Tests échoués en rouge
- Résumé final avec statistiques

---

### 🌐 `test-connectivity.sh` - Tests de Connectivité
Teste la communication entre tous les composants.

**Usage :**
```bash
./test-connectivity.sh
```

**Tests inclus :**
- Résolution DNS de tous les services
- Connectivité MongoDB depuis différents namespaces
- Communication inter-composants 4G (MME↔HSS, MME↔SGWC, etc.)
- Communication inter-composants 5G (AMF↔NRF, SMF↔UPF, etc.)
- Interworking 4G-5G (N26)
- Endpoints WebUI
- Endpoints métriques Prometheus

---

### 📱 `provision-sim.sh` - Provisioning SIM Cards
Provisionne automatiquement des abonnés dans le système.

**Usage :**
```bash
# Mode interactif
./provision-sim.sh

# Avec paramètres
./provision-sim.sh 4g http://localhost:9999 5
# Arguments: [4g|5g] [webui-url] [nombre-abonnés]
```

**Options du menu :**
1. **SIM de test** : Provisionne 3 SIM pré-configurées (eMBB, URLLC, mMTC pour 5G)
2. **Batch** : Provisionne N abonnés avec IMSI séquentiels
3. **Lister** : Affiche tous les abonnés existants
4. **Supprimer** : Supprime tous les abonnés

**Prérequis :**
- WebUI accessible (via port-forward ou NodePort)
- `jq` installé (recommandé pour parsing JSON)

**Port-forward requis :**
```bash
# Pour 4G
kubectl port-forward -n 4g-core svc/webui 9999:9999 &

# Pour 5G
kubectl port-forward -n 5g-core svc/webui 9999:9999 &
```

---

### 🗑️ `cleanup.sh` - Nettoyage Complet
Supprime tous les composants déployés.

**Usage :**
```bash
./cleanup.sh          # Mode interactif avec menu
./cleanup.sh --force  # Mode automatique (suppression immédiate)
```

**Options du menu :**
1. **Nettoyage complet** : Supprime tout (recommandé)
2. **Helm uniquement** : Supprime les releases Helm
3. **Services partagés** : Supprime MongoDB et DNS
4. **PVCs** : Supprime les volumes persistants
5. **Forcer** : Supprime les ressources bloquées
6. **État actuel** : Affiche ce qui est déployé

**⚠️ ATTENTION :** Cette opération supprime :
- Toutes les releases Helm
- Tous les services partagés
- Tous les namespaces
- Toutes les données (SIM, logs, etc.)
- Tous les PersistentVolumeClaims

---

## 🔧 Utilisation Typique

### Installation Initiale

```bash
# 1. Rendre les scripts exécutables
chmod +x *.sh

# 2. Déployer l'infrastructure
./deploy.sh

# 3. Valider le déploiement
./validate-deployment.sh

# 4. Tester la connectivité
./test-connectivity.sh

# 5. Provisionner des SIM
kubectl port-forward -n 4g-core svc/webui 9999:9999 &
./provision-sim.sh
```

### Mise à Jour

```bash
# Mettre à jour via Helm
helm upgrade open5gs-4g ../helm/open5gs-4g -n 4g-core -f ../values/dev.yaml

# Valider après mise à jour
./validate-deployment.sh
```

### Dépannage

```bash
# Voir l'état actuel
kubectl get all -A | grep -E '4g-core|5g-core|shared-services'

# Tester la connectivité
./test-connectivity.sh

# Voir les logs
kubectl logs -f -n 4g-core -l component=mme
kubectl logs -f -n 5g-core -l component=amf
```

### Suppression Complète

```bash
# Nettoyage complet
./cleanup.sh

# Ou forcer sans confirmation
./cleanup.sh --force
```

---

## 📋 Prérequis

### Outils Requis

```bash
# kubectl (Kubernetes CLI)
kubectl version --client

# helm (Package manager)
helm version

# curl (HTTP client)
curl --version

# jq (JSON parser - optionnel mais recommandé)
jq --version

# nc/netcat (Network testing - inclus dans la plupart des images)
nc -h
```

### Installation des Outils

**Ubuntu/Debian :**
```bash
sudo apt-get update
sudo apt-get install -y kubectl helm curl jq netcat
```

**macOS :**
```bash
brew install kubectl helm curl jq netcat
```

**Windows (WSL) :**
```bash
# Installer WSL et Ubuntu d'abord
sudo apt-get update
sudo apt-get install -y kubectl helm curl jq netcat
```

---

## 🎯 Workflows Recommandés

### Workflow de Développement

```bash
# 1. Déployer en dev
ENVIRONMENT=dev ./deploy.sh

# 2. Valider
./validate-deployment.sh

# 3. Provisionner SIM de test
./provision-sim.sh

# 4. Développer et tester
# ... vos tests ...

# 5. Nettoyer
./cleanup.sh
```

### Workflow de Production

```bash
# 1. Déployer en production
ENVIRONMENT=prod ./deploy.sh

# 2. Valider exhaustivement
./validate-deployment.sh
./test-connectivity.sh

# 3. Monitorer
kubectl top nodes
kubectl top pods -A

# 4. Provisionner les abonnés réels
./provision-sim.sh
```

### Workflow CI/CD

```yaml
# .github/workflows/deploy.yml
steps:
  - name: Deploy
    run: ./k8s/scripts/deploy.sh --auto
    
  - name: Validate
    run: ./k8s/scripts/validate-deployment.sh
    
  - name: Test Connectivity
    run: ./k8s/scripts/test-connectivity.sh
```

---

## 🐛 Troubleshooting

### Script ne s'exécute pas

```bash
# Donner les permissions d'exécution
chmod +x script.sh

# Vérifier le shebang
head -n 1 script.sh  # Doit être #!/bin/bash
```

### kubectl: command not found

```bash
# Installer kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

### helm: command not found

```bash
# Installer Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### WebUI non accessible

```bash
# Vérifier le service
kubectl get svc -n 4g-core webui

# Port-forward manuel
kubectl port-forward -n 4g-core svc/webui 9999:9999

# Vérifier les logs WebUI
kubectl logs -f -n 4g-core -l component=webui
```

---

## 📚 Ressources Supplémentaires

- [DEPLOYMENT_GUIDE.md](../DEPLOYMENT_GUIDE.md) - Guide de déploiement détaillé
- [TESTING_GUIDE.md](../TESTING_GUIDE.md) - Guide de test complet
- [README.md](../README.md) - Documentation principale

---

## 🔐 Sécurité

**⚠️ Notes de Sécurité :**

- Les credentials par défaut sont dans les scripts (à changer en production)
- MongoDB n'a pas d'authentification forte par défaut
- WebUI accessible sans TLS par défaut
- Secrets Kubernetes utilisent `stringData` (à encoder en base64 en prod)

**Pour la production :**
1. Modifier tous les mots de passe par défaut
2. Activer TLS/mTLS sur toutes les interfaces
3. Utiliser des Secrets Kubernetes chiffrés
4. Implémenter RBAC strict
5. Activer NetworkPolicies

---

## 📞 Support

Pour toute question ou problème :
1. Consulter les logs : `kubectl logs <pod> -n <namespace>`
2. Vérifier l'état : `kubectl describe pod <pod> -n <namespace>`
3. Exécuter les tests : `./validate-deployment.sh`
4. Consulter la documentation Open5GS : https://open5gs.org
