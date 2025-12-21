# Guide de Test Complet - Déploiement Kubernetes

Ce guide vous permet de tester exhaustivement votre déploiement Kubernetes de migration 4G vers 5G.

## 🎯 Objectifs des Tests

1. **Validation Infrastructure** : Vérifier que Kubernetes fonctionne
2. **Test Services Partagés** : MongoDB et DNS opérationnels
3. **Test Core 4G** : Tous les composants EPC fonctionnels
4. **Test Core 5G** : Tous les composants 5GC fonctionnels
5. **Test Connectivité** : Communication inter-composants
6. **Test End-to-End** : Simulation d'attachement UE

---

## 📋 Prérequis

```bash
# Vérifier les outils
kubectl version --client
helm version
curl --version

# Vérifier la connexion au cluster
kubectl cluster-info
kubectl get nodes
```

---

## 🔧 Phase 1 : Tests d'Infrastructure

### 1.1 Validation Automatique

```bash
# Exécuter le script de validation complet
cd k8s/scripts
chmod +x validate-deployment.sh
./validate-deployment.sh
```

**Résultat attendu** :
- ✓ Tous les tests passent
- ✓ Pods en état `Running`
- ✓ Services accessibles

### 1.2 Vérification Manuelle des Namespaces

```bash
# Lister tous les namespaces
kubectl get namespaces

# Vérifier chaque namespace
kubectl get all -n shared-services
kubectl get all -n 4g-core
kubectl get all -n 5g-core
```

**Résultat attendu** :
```
NAME                READY   STATUS    RESTARTS   AGE
pod/mongodb-xxx     1/1     Running   0          5m
pod/dns-xxx         1/1     Running   0          5m
```

### 1.3 Vérification des Ressources

```bash
# Utilisation CPU/Mémoire des nœuds
kubectl top nodes

# Utilisation par pods
kubectl top pods -n shared-services
kubectl top pods -n 4g-core
kubectl top pods -n 5g-core
```

---

## 🗄️ Phase 2 : Tests Services Partagés

### 2.1 Test MongoDB

```bash
# Vérifier le pod MongoDB
kubectl get pod -n shared-services -l app=mongodb

# Tester la connexion MongoDB
POD_MONGO=$(kubectl get pod -n shared-services -l app=mongodb -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it -n shared-services $POD_MONGO -- mongosh --eval "db.adminCommand('ping')"
```

**Résultat attendu** :
```javascript
{ ok: 1 }
```

### 2.2 Test DNS

```bash
# Vérifier le pod DNS
kubectl get pod -n shared-services -l app=dns

# Tester la résolution DNS
kubectl run dnstest --image=busybox --rm -it --restart=Never -- nslookup mongodb.shared-services.svc.cluster.local 10.45.0.10
```

**Résultat attendu** :
```
Server:    10.45.0.10
Address:   10.45.0.10:53

Name:      mongodb.shared-services.svc.cluster.local
Address:   <MongoDB-ClusterIP>
```

### 2.3 Test Connectivité Inter-Namespace

```bash
# Test depuis 4g-core vers MongoDB
kubectl run mongotest --image=mongo:6.0 --rm -it --restart=Never -n 4g-core -- \
  mongosh "mongodb://mongodb.shared-services.svc.cluster.local:27017" --eval "db.adminCommand('ping')"
```

---

## 📱 Phase 3 : Tests Core 4G (EPC)

### 3.1 Vérifier les Composants 4G

```bash
# Liste tous les composants 4G
kubectl get pods -n 4g-core -o wide

# Vérifier les services
kubectl get svc -n 4g-core
```

**Composants attendus** :
- MME, HSS, PCRF, SGWC, SGWU, SMF, UPF, WebUI

### 3.2 Test Logs 4G

```bash
# Logs MME (Access Stratum)
kubectl logs -f -n 4g-core -l component=mme --tail=50

# Logs HSS (Subscriber Database)
kubectl logs -f -n 4g-core -l component=hss --tail=50

# Logs UPF (User Plane)
kubectl logs -f -n 4g-core -l component=upf --tail=50
```

**Résultat attendu** :
- Pas d'erreurs critiques
- Logs indiquant "Initialization complete" ou similaire

### 3.3 Test WebUI 4G

```bash
# Port-forward vers WebUI
kubectl port-forward -n 4g-core svc/webui 9999:9999 &

# Tester l'accès HTTP
curl -I http://localhost:9999

# Ou ouvrir dans le navigateur
# http://localhost:9999
# Username: admin / Password: 1423
```

### 3.4 Test Métriques Prometheus (4G)

```bash
# Vérifier endpoint métriques MME
POD_MME=$(kubectl get pod -n 4g-core -l component=mme -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n 4g-core $POD_MME -- wget -q -O- http://localhost:9090/metrics | head -20
```

---

## 🚀 Phase 4 : Tests Core 5G (SA)

### 4.1 Vérifier les Composants 5G

```bash
# Liste tous les composants 5G
kubectl get pods -n 5g-core -o wide

# Vérifier les services
kubectl get svc -n 5g-core
```

**Composants attendus** :
- NRF, AMF, SMF, UPF, AUSF, UDM, UDR, PCF, NSSF, BSF, WebUI

### 4.2 Test Logs 5G

```bash
# Logs AMF (Core Access and Mobility)
kubectl logs -f -n 5g-core -l component=amf --tail=50

# Logs SMF (Session Management)
kubectl logs -f -n 5g-core -l component=smf --tail=50

# Logs NRF (Network Repository)
kubectl logs -f -n 5g-core -l component=nrf --tail=50
```

### 4.3 Test WebUI 5G

```bash
# Port-forward vers WebUI
kubectl port-forward -n 5g-core svc/webui 10000:9999 &

# Tester l'accès HTTP
curl -I http://localhost:10000
```

### 4.4 Test SBI (Service Based Interface)

```bash
# Vérifier NRF Discovery
POD_NRF=$(kubectl get pod -n 5g-core -l component=nrf -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n 5g-core $POD_NRF -- wget -q -O- http://localhost:7777/nnrf-nfm/v1/nf-instances

# Tester AMF -> NRF
POD_AMF=$(kubectl get pod -n 5g-core -l component=amf -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n 5g-core $POD_AMF -- nc -zv nrf.5g-core.svc.cluster.local 7777
```

---

## 🌐 Phase 5 : Tests de Connectivité

### 5.1 Script Automatisé

```bash
cd k8s/scripts
chmod +x test-connectivity.sh
./test-connectivity.sh
```

### 5.2 Tests Manuels Inter-Composants

#### Test 4G : MME ↔ HSS (S6a Diameter)

```bash
POD_MME=$(kubectl get pod -n 4g-core -l component=mme -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n 4g-core $POD_MME -- nc -zv hss.4g-core.svc.cluster.local 3868
```

#### Test 4G : MME ↔ SGWC (S11 GTP-C)

```bash
kubectl exec -n 4g-core $POD_MME -- nc -zuv sgwc.4g-core.svc.cluster.local 2123
```

#### Test 5G : AMF ↔ AUSF (SBI)

```bash
POD_AMF=$(kubectl get pod -n 5g-core -l component=amf -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n 5g-core $POD_AMF -- nc -zv ausf.5g-core.svc.cluster.local 7777
```

#### Test 5G : SMF ↔ UPF (PFCP)

```bash
POD_SMF=$(kubectl get pod -n 5g-core -l component=smf -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n 5g-core $POD_SMF -- nc -zuv upf.5g-core.svc.cluster.local 8805
```

---

## 👥 Phase 6 : Provisioning Abonnés (SIM)

### 6.1 Provisionner via Script

```bash
cd k8s/scripts
chmod +x provision-sim.sh

# Assurez-vous que WebUI est accessible
kubectl port-forward -n 4g-core svc/webui 9999:9999 &

# Exécuter le script
./provision-sim.sh 4g http://localhost:9999
```

### 6.2 Provisionner Manuellement via WebUI

1. Ouvrir http://localhost:9999
2. Login : `admin` / `1423`
3. Aller dans **Subscriber** > **Create**
4. Remplir :
   - IMSI: `001010000000001`
   - K: `465B5CE8B199B49FAA5F0A2EE238A6BC`
   - OPc: `E8ED289DEBA952E4283B54E88E6183CA`
   - APN: `internet`

### 6.3 Vérifier les Abonnés dans MongoDB

```bash
POD_MONGO=$(kubectl get pod -n shared-services -l app=mongodb -o jsonpath='{.items[0].metadata.name}')

kubectl exec -it -n shared-services $POD_MONGO -- mongosh open5gs --eval "db.subscribers.find().pretty()"
```

---

## 🧪 Phase 7 : Tests End-to-End (avec Simulateur)

### 7.1 Déployer UERANSIM (Simulateur 5G)

```bash
# Créer un pod UERANSIM
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ueransim-gnb
  namespace: 5g-core
spec:
  containers:
  - name: gnb
    image: docker_ueransim:latest
    command: ["sleep", "infinity"]
EOF

# Accéder au pod
kubectl exec -it -n 5g-core ueransim-gnb -- bash

# À l'intérieur du pod, configurer et lancer gNB puis UE
```

### 7.2 Test Attachement 4G (avec srsRAN - si disponible)

```bash
# Voir les logs MME pendant l'attachement
kubectl logs -f -n 4g-core -l component=mme | grep -i "attach"
```

### 7.3 Test Registration 5G

```bash
# Voir les logs AMF pendant la registration
kubectl logs -f -n 5g-core -l component=amf | grep -i "registration"
```

---

## 📊 Phase 8 : Monitoring et Métriques

### 8.1 Vérifier les Métriques Prometheus

```bash
# Liste des endpoints métriques
kubectl get svc -A | grep metrics

# Scraper les métriques MME
kubectl port-forward -n 4g-core svc/mme 9090:9090 &
curl http://localhost:9090/metrics
```

### 8.2 Dashboard Grafana (si déployé)

```bash
kubectl port-forward -n monitoring svc/grafana 3000:3000 &
# Ouvrir http://localhost:3000
```

---

## ✅ Checklist Complète

### Infrastructure
- [ ] Cluster Kubernetes accessible
- [ ] Tous les namespaces créés
- [ ] kubectl et helm fonctionnels

### Services Partagés
- [ ] MongoDB running et accessible
- [ ] DNS running et résolvant correctement
- [ ] Connectivité inter-namespace OK

### Core 4G
- [ ] Tous les pods 4G running
- [ ] WebUI 4G accessible
- [ ] Logs sans erreurs critiques
- [ ] Métriques exposées

### Core 5G
- [ ] Tous les pods 5G running
- [ ] WebUI 5G accessible
- [ ] NRF discovery fonctionnel
- [ ] Métriques exposées

### Connectivité
- [ ] DNS resolution OK
- [ ] MME ↔ HSS (Diameter)
- [ ] AMF ↔ NRF (SBI)
- [ ] SMF ↔ UPF (PFCP)

### Provisioning
- [ ] Au moins 1 abonné provisionné
- [ ] Données visibles dans MongoDB
- [ ] WebUI affiche les abonnés

### Tests E2E
- [ ] UE attach/registration testé (si simulateur)
- [ ] Session PDN/PDU établie
- [ ] Trafic data OK

---

## 🐛 Troubleshooting

### Pod ne démarre pas

```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous
```

### Service non accessible

```bash
kubectl get endpoints <service-name> -n <namespace>
kubectl describe svc <service-name> -n <namespace>
```

### MongoDB connection refused

```bash
# Vérifier le service
kubectl get svc -n shared-services mongodb

# Test direct
kubectl run mongotest --image=mongo:6.0 --rm -it -n shared-services -- \
  mongosh mongodb://mongodb.shared-services.svc.cluster.local:27017
```

### DNS ne résout pas

```bash
# Vérifier les logs DNS
kubectl logs -f -n shared-services -l app=dns

# Test avec dig
kubectl run dnstest --image=tutum/dnsutils --rm -it -- \
  dig @10.45.0.10 mongodb.shared-services.svc.cluster.local
```

---

## 📚 Prochaines Étapes

Après avoir validé tous les tests :

1. **Déployer Monitoring** (Prometheus + Grafana)
2. **Déployer IMS** (VoLTE/VoNR)
3. **Configurer CI/CD**
4. **Tests de charge**
5. **Migration vers production**

---

## 📞 Support

- Documentation Open5GS : https://open5gs.org
- Issues GitHub : https://github.com/open5gs/open5gs/issues
- Scripts de test : `k8s/scripts/`
