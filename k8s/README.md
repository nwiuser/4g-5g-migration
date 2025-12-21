# Déploiement Kubernetes - Migration 4G vers 5G

Cette structure contient tous les manifests et Helm charts nécessaires pour déployer l'infrastructure de migration 4G vers 5G sur Kubernetes.

## 📁 Structure

```
k8s/
├── helm/                    # Helm Charts
│   ├── open5gs-4g/         # Core 4G (EPC)
│   ├── open5gs-5g/         # Core 5G SA
│   ├── ims/                # IMS (VoLTE/VoNR)
│   └── monitoring/         # Prometheus + Grafana
├── manifests/              # Manifests Kubernetes bruts
│   ├── 4g-core/           
│   ├── 5g-core/
│   ├── shared/            # Services partagés (MongoDB, DNS)
│   └── namespaces/        # Définitions des namespaces
├── values/                # Fichiers de configuration
│   ├── dev.yaml
│   ├── staging.yaml
│   └── prod.yaml
└── README.md
```

## 🚀 Prérequis

- Kubernetes cluster v1.24+
- Helm 3.x
- kubectl configuré
- Minimum 8 CPU, 16GB RAM
- Storage class disponible (pour PVC)

## 📦 Installation

### 1. Créer les namespaces

```bash
kubectl apply -f manifests/namespaces/
```

### 2. Déployer les services partagés (MongoDB, DNS)

```bash
kubectl apply -f manifests/shared/
```

### 3. Déployer le monitoring

```bash
helm install monitoring ./helm/monitoring -n monitoring --create-namespace
```

### 4. Déployer le Core 4G

```bash
helm install open5gs-4g ./helm/open5gs-4g \
  -n 4g-core \
  --create-namespace \
  -f values/dev.yaml
```

### 5. Déployer le Core 5G

```bash
helm install open5gs-5g ./helm/open5gs-5g \
  -n 5g-core \
  --create-namespace \
  -f values/dev.yaml
```

### 6. Déployer IMS

```bash
helm install ims ./helm/ims \
  -n ims \
  --create-namespace \
  -f values/dev.yaml
```

## 🔍 Vérification

### Vérifier les pods

```bash
kubectl get pods -A
```

### Vérifier les services

```bash
kubectl get svc -A
```

### Accéder au WebUI

```bash
kubectl port-forward -n 4g-core svc/webui 9999:9999
# Ouvrir http://localhost:9999
```

### Accéder à Grafana

```bash
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Ouvrir http://localhost:3000
```

## 🔧 Configuration par environnement

### Développement (dev)
- Ressources minimales
- Single replica
- Logs debug activés

### Staging
- Ressources moyennes
- Multiple replicas
- Tests de charge

### Production
- Haute disponibilité
- Auto-scaling activé
- Monitoring renforcé

## 🎯 Scénarios de migration

### Déploiement 4G seul
```bash
helm install open5gs-4g ./helm/open5gs-4g -n 4g-core --create-namespace
```

### Déploiement 5G seul
```bash
helm install open5gs-5g ./helm/open5gs-5g -n 5g-core --create-namespace
```

### Dual-stack 4G+5G avec interworking
```bash
# Déployer les deux cores avec N26 interface activée
helm install open5gs-4g ./helm/open5gs-4g -n 4g-core --set interworking.enabled=true
helm install open5gs-5g ./helm/open5gs-5g -n 5g-core --set interworking.enabled=true
```

## 📊 Monitoring

Les métriques Prometheus sont exposées sur :
- 4G Core: `http://<service-ip>:9090/metrics`
- 5G Core: `http://<service-ip>:9090/metrics`

Dashboards Grafana disponibles :
- 4G EPC Overview
- 5G Core Overview
- Migration Progress
- Network Slicing (5G)

## 🔒 Sécurité

- Secrets Kubernetes pour credentials
- NetworkPolicies pour isolation
- RBAC configuré
- TLS pour communications inter-composants

## 🐛 Troubleshooting

### Les pods ne démarrent pas
```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

### Problèmes de réseau
```bash
kubectl get networkpolicy -A
kubectl describe networkpolicy <policy-name> -n <namespace>
```

### Problèmes de stockage
```bash
kubectl get pvc -A
kubectl describe pvc <pvc-name> -n <namespace>
```

## 📚 Documentation supplémentaire

- [Guide de migration 4G vers 5G](../docs/migration/migration-guide.md)
- [Architecture Kubernetes](../docs/architecture/kubernetes-architecture.md)
- [Runbook opérationnel](../docs/runbooks/kubernetes-operations.md)
