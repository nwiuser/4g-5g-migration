# Guide de Déploiement Kubernetes - Migration 4G vers 5G

Ce guide vous accompagne pas à pas dans le déploiement de votre infrastructure de migration 4G vers 5G sur Kubernetes.

## 📋 Prérequis

### Cluster Kubernetes
- Kubernetes v1.24 ou supérieur
- Minimum 4 nœuds (workers)
- 8 CPU et 16GB RAM par nœud
- Storage class configuré (ex: `standard`, `gp2`, `local-path`)

### Outils nécessaires
```bash
# Vérifier kubectl
kubectl version --client

# Installer Helm 3.x
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

# Vérifier la connexion au cluster
kubectl cluster-info
kubectl get nodes
```

## 🚀 Déploiement Étape par Étape

### Étape 1 : Créer les Namespaces

```bash
cd k8s/
kubectl apply -f manifests/namespaces/namespaces.yaml

# Vérifier
kubectl get namespaces
```

Namespaces créés :
- `4g-core` - Core réseau 4G (EPC)
- `5g-core` - Core réseau 5G SA
- `ims` - IMS pour VoLTE/VoNR
- `monitoring` - Prometheus, Grafana
- `shared-services` - MongoDB, DNS

### Étape 2 : Déployer les Services Partagés

```bash
# Déployer MongoDB
kubectl apply -f manifests/shared/mongodb.yaml

# Déployer DNS
kubectl apply -f manifests/shared/dns.yaml

# Vérifier les pods
kubectl get pods -n shared-services
kubectl get svc -n shared-services
```

Attendre que tous les pods soient en état `Running` :
```bash
kubectl wait --for=condition=ready pod -l app=mongodb -n shared-services --timeout=300s
kubectl wait --for=condition=ready pod -l app=dns -n shared-services --timeout=300s
```

### Étape 3 : Déployer le Core 4G

```bash
# Déploiement avec Helm (environnement dev)
helm install open5gs-4g ./helm/open5gs-4g \
  -n 4g-core \
  --create-namespace \
  -f values/dev.yaml

# Vérifier le déploiement
kubectl get pods -n 4g-core
kubectl get svc -n 4g-core

# Voir les logs MME
kubectl logs -f -n 4g-core -l component=mme

# Voir les logs de tous les composants
kubectl logs -f -n 4g-core -l network-type=4g-epc --all-containers=true
```

Composants 4G déployés :
- MME (Mobility Management Entity)
- HSS (Home Subscriber Server)
- PCRF (Policy and Charging Rules Function)
- SGWC/SGWU (Serving Gateway)
- SMF (Session Management Function - PGW-C)
- UPF (User Plane Function - PGW-U)
- WebUI

### Étape 4 : Déployer le Core 5G

```bash
# Déploiement avec Helm (environnement dev)
helm install open5gs-5g ./helm/open5gs-5g \
  -n 5g-core \
  --create-namespace \
  -f values/dev.yaml

# Vérifier le déploiement
kubectl get pods -n 5g-core
kubectl get svc -n 5g-core

# Voir les logs AMF
kubectl logs -f -n 5g-core -l component=amf
```

Composants 5G déployés :
- NRF (Network Repository Function)
- AMF (Access and Mobility Management)
- SMF (Session Management Function)
- UPF (User Plane Function)
- AUSF (Authentication Server Function)
- UDM (Unified Data Management)
- UDR (Unified Data Repository)
- PCF (Policy Control Function)
- NSSF (Network Slice Selection Function)
- BSF (Binding Support Function)
- WebUI

### Étape 5 : Accéder au WebUI

#### WebUI 4G
```bash
# Port-forward
kubectl port-forward -n 4g-core svc/webui 9999:9999

# Ou utiliser NodePort
kubectl get svc -n 4g-core webui
# Accéder via http://<node-ip>:30999
```

Ouvrir dans le navigateur : `http://localhost:9999`
- Username: `admin`
- Password: `1423`

#### WebUI 5G
```bash
# Port-forward
kubectl port-forward -n 5g-core svc/webui 10000:9999

# Ou utiliser NodePort
kubectl get svc -n 5g-core webui
# Accéder via http://<node-ip>:31999
```

Ouvrir dans le navigateur : `http://localhost:10000`

### Étape 6 : Provisionner les Abonnés (SIM)

Via WebUI ou API REST :

#### Ajouter un abonné 4G/5G
```bash
# Exemple avec curl
SUBSCRIBER_IMSI="001010000000001"
SUBSCRIBER_KEY="465B5CE8B199B49FAA5F0A2EE238A6BC"
SUBSCRIBER_OPC="E8ED289DEBA952E4283B54E88E6183CA"

curl -X POST http://localhost:9999/api/subscriber/imsi-${SUBSCRIBER_IMSI} \
  -H 'Content-Type: application/json' \
  -d '{
    "imsi": "'${SUBSCRIBER_IMSI}'",
    "subscriber_status": 0,
    "network_access_mode": 0,
    "subscribed_rau_tau_timer": 12,
    "k": "'${SUBSCRIBER_KEY}'",
    "opc": "'${SUBSCRIBER_OPC}'",
    "ambr": {
      "downlink": 1000000,
      "uplink": 1000000
    },
    "pdn": [{
      "apn": "internet",
      "qos": {
        "qci": 9,
        "arp": {
          "priority_level": 8,
          "pre_emption_capability": 1,
          "pre_emption_vulnerability": 1
        }
      },
      "ambr": {
        "downlink": 1000000,
        "uplink": 1000000
      },
      "pcc_rule": [],
      "type": 0
    }]
  }'
```

## 🔍 Vérification et Tests

### Vérifier tous les pods
```bash
kubectl get pods -A | grep -E '4g-core|5g-core|shared-services'
```

### Vérifier les services
```bash
kubectl get svc -A | grep -E '4g-core|5g-core|shared-services'
```

### Tester la connectivité DNS
```bash
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup mongodb.shared-services.svc.cluster.local
```

### Vérifier les métriques
```bash
# Métriques MME (4G)
kubectl port-forward -n 4g-core svc/mme 9090:9090
curl http://localhost:9090/metrics

# Métriques AMF (5G)
kubectl port-forward -n 5g-core svc/amf 9091:9090
curl http://localhost:9091/metrics
```

## 🔄 Scénarios de Migration

### Scénario 1 : 4G Standalone
```bash
helm install open5gs-4g ./helm/open5gs-4g -n 4g-core -f values/dev.yaml
```

### Scénario 2 : 5G Standalone
```bash
helm install open5gs-5g ./helm/open5gs-5g -n 5g-core -f values/dev.yaml
```

### Scénario 3 : Dual-Stack avec Interworking (N26)
```bash
# Déployer 4G avec N26 activé
helm install open5gs-4g ./helm/open5gs-4g \
  -n 4g-core \
  -f values/dev.yaml \
  --set interworking.enabled=true \
  --set interworking.amfAddress=amf.5g-core.svc.cluster.local

# Déployer 5G avec N26 activé
helm install open5gs-5g ./helm/open5gs-5g \
  -n 5g-core \
  -f values/dev.yaml \
  --set interworking.enabled=true \
  --set interworking.mmeAddress=mme.4g-core.svc.cluster.local
```

## 🛠️ Mise à Jour et Maintenance

### Mettre à jour la configuration
```bash
# Modifier values/dev.yaml puis
helm upgrade open5gs-4g ./helm/open5gs-4g -n 4g-core -f values/dev.yaml
helm upgrade open5gs-5g ./helm/open5gs-5g -n 5g-core -f values/dev.yaml
```

### Redémarrer un composant
```bash
kubectl rollout restart deployment/mme -n 4g-core
kubectl rollout restart deployment/amf -n 5g-core
```

### Voir l'historique des déploiements
```bash
helm history open5gs-4g -n 4g-core
helm history open5gs-5g -n 5g-core
```

### Rollback
```bash
helm rollback open5gs-4g -n 4g-core
helm rollback open5gs-5g -n 5g-core
```

## 🗑️ Nettoyage

### Supprimer tout
```bash
# Supprimer les déploiements Helm
helm uninstall open5gs-5g -n 5g-core
helm uninstall open5gs-4g -n 4g-core

# Supprimer les services partagés
kubectl delete -f manifests/shared/

# Supprimer les namespaces
kubectl delete -f manifests/namespaces/namespaces.yaml
```

## 📚 Prochaines Étapes

1. **Monitoring** : Déployer Prometheus + Grafana
2. **IMS** : Ajouter VoLTE/VoNR
3. **CI/CD** : Automatiser avec GitHub Actions
4. **Tests** : Scripts de test automatisés
5. **Production** : Déployer avec `values/prod.yaml`

## 🐛 Troubleshooting

### Les pods ne démarrent pas
```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

### Problème de connexion MongoDB
```bash
kubectl exec -it -n shared-services mongodb-<pod-id> -- mongo --eval "db.adminCommand('ping')"
```

### Problème DNS
```bash
kubectl exec -it -n shared-services dns-<pod-id> -- nslookup epc.mnc001.mcc001.3gppnetwork.org localhost
```

## 📞 Support

Pour plus d'informations :
- Documentation Open5GS : https://open5gs.org/open5gs/docs/
- Issues GitHub : https://github.com/open5gs/open5gs/issues
