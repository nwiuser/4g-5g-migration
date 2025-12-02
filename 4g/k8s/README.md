# Déploiement Kubernetes pour srsRAN 4G

Ce dossier contient les manifests Kubernetes pour déployer l'infrastructure srsRAN 4G.

## Prérequis

- Minikube installé et démarré
- kubectl configuré
- Image Docker `srsran:latest` chargée dans Minikube

## Architecture

```
┌─────────────────────────────────────────┐
│         Namespace: srsran               │
├─────────────────────────────────────────┤
│                                         │
│  ┌──────────┐      ┌──────────┐         │
│  │  srsepc  │◄────►│  srsenb  │         │
│  │  (EPC)   │ S1   │ (eNodeB) │         │
│  └──────────┘      └─────┬────┘         │
│                          │              │
│                          │ RF (ZMQ)     │
│                          ▼              │
│                    ┌──────────┐         │
│                    │  srsue   │         │
│                    │   (UE)   │         │
│                    └──────────┘         │
│                                         │
└─────────────────────────────────────────┘
```

## Structure des fichiers

```
k8s/
├── namespace.yaml                    # Namespace srsran
├── deployments/
│   ├── srsepc-deployment.yaml       # Déploiement EPC
│   ├── srsenb-deployment.yaml       # Déploiement eNodeB
│   └── srsue-deployment.yaml        # Déploiement UE
├── services/
│   ├── srsepc-service.yaml          # Service EPC
│   ├── srsenb-service.yaml          # Service eNodeB
│   └── srsue-service.yaml           # Service UE
├── deploy-all.sh                     # Script de déploiement automatique
└── README.md                         # Ce fichier
```

## Déploiement rapide

### Option 1 : Script automatique (Linux/Mac/Git Bash)

```bash
cd k8s
chmod +x deploy-all.sh
./deploy-all.sh
```

### Option 2 : Déploiement manuel (Windows PowerShell)

```powershell
# 1. Créer le namespace
kubectl apply -f namespace.yaml

# 2. Déployer srsepc
kubectl apply -f deployments/srsepc-deployment.yaml
kubectl apply -f services/srsepc-service.yaml

# Attendre que srsepc soit prêt
kubectl wait --for=condition=ready pod -l app=srsepc -n srsran --timeout=120s

# 3. Déployer srsenb
kubectl apply -f deployments/srsenb-deployment.yaml
kubectl apply -f services/srsenb-service.yaml

# Attendre que srsenb soit prêt
kubectl wait --for=condition=ready pod -l app=srsenb -n srsran --timeout=120s

# 4. Déployer srsue
kubectl apply -f deployments/srsue-deployment.yaml
kubectl apply -f services/srsue-service.yaml

# 5. Vérifier le statut
kubectl get all -n srsran
```

## Commandes de gestion

### Voir les ressources

```powershell
# Tous les pods
kubectl get pods -n srsran

# Tous les services
kubectl get services -n srsran

# Toutes les ressources
kubectl get all -n srsran

# Détails d'un pod
kubectl describe pod <pod-name> -n srsran
```

### Voir les logs

```powershell
# Logs srsepc
kubectl logs -f -l app=srsepc -n srsran

# Logs srsenb
kubectl logs -f -l app=srsenb -n srsran

# Logs srsue
kubectl logs -f -l app=srsue -n srsran

# Logs d'un pod spécifique
kubectl logs -f <pod-name> -n srsran
```

### Accéder à un pod

```powershell
# Shell interactif
kubectl exec -it <pod-name> -n srsran -- /bin/bash

# Exécuter une commande
kubectl exec <pod-name> -n srsran -- ps aux
```

### Redémarrer un déploiement

```powershell
kubectl rollout restart deployment/srsepc -n srsran
kubectl rollout restart deployment/srsenb -n srsran
kubectl rollout restart deployment/srsue -n srsran
```

### Mettre à l'échelle

```powershell
# Changer le nombre de replicas (attention : srsRAN n'est pas conçu pour le scaling)
kubectl scale deployment srsepc --replicas=1 -n srsran
```

### Supprimer le déploiement

```powershell
# Supprimer tout
kubectl delete namespace srsran

# Ou supprimer individuellement
kubectl delete -f deployments/ -n srsran
kubectl delete -f services/ -n srsran
```

## Vérification du déploiement

Après le déploiement, vérifiez que tout fonctionne :

```powershell
# 1. Vérifier que tous les pods sont en Running
kubectl get pods -n srsran

# 2. Vérifier les logs pour les erreurs
kubectl logs -l app=srsepc -n srsran | Select-String -Pattern "error|Error|ERROR"

# 3. Vérifier la connectivité réseau
kubectl exec -n srsran -it $(kubectl get pod -l app=srsue -n srsran -o jsonpath='{.items[0].metadata.name}') -- ping -c 4 srsepc
```

## Troubleshooting

### Les pods ne démarrent pas

```powershell
# Voir les événements
kubectl get events -n srsran --sort-by='.lastTimestamp'

# Décrire le pod problématique
kubectl describe pod <pod-name> -n srsran
```

### L'image n'est pas trouvée

```powershell
# Vérifier que l'image est chargée dans Minikube
minikube image ls | Select-String "srsran"

# Recharger l'image si nécessaire
docker build -t srsran:latest ..
minikube image load srsran:latest
```

### Erreur de permissions /dev/net/tun

Assurez-vous que :
- Le pod a `privileged: true`
- Le volume hostPath est correctement monté
- Minikube a accès à /dev/net/tun

### Les pods ne communiquent pas entre eux

```powershell
# Tester la connectivité DNS
kubectl exec -n srsran -it <pod-name> -- nslookup srsepc.srsran.svc.cluster.local

# Tester la connectivité réseau
kubectl exec -n srsran -it <pod-name> -- ping srsepc.srsran.svc.cluster.local
```

## Différences avec Docker Compose

| Docker Compose | Kubernetes |
|----------------|------------|
| IPs statiques (10.80.95.x) | DNS services (srsepc.srsran.svc.cluster.local) |
| Réseaux personnalisés | Services ClusterIP |
| docker-compose up | kubectl apply |
| docker-compose logs | kubectl logs |
| Scaling limité | Scaling natif (mais non applicable ici) |

## Notes importantes

1. **ZMQ Communication** : Les ports ZMQ (2000, 2001) utilisent maintenant les noms de services Kubernetes
2. **Ordre de démarrage** : Utilisez `kubectl wait` pour assurer le bon ordre
3. **Privilèges** : srsepc et srsue nécessitent `privileged: true` pour /dev/net/tun
4. **Image locale** : `imagePullPolicy: Never` force l'utilisation de l'image locale

## Prochaines étapes

- Ajouter des ConfigMaps pour les fichiers de configuration
- Implémenter des readinessProbes et livenessProbes
- Ajouter un Ingress pour l'accès externe
- Créer des PersistentVolumes pour les logs
- Configurer des NetworkPolicies pour la sécurité
