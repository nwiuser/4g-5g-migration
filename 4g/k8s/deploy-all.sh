#!/bin/bash

# Script de déploiement complet pour srsRAN sur Kubernetes

echo "=== Déploiement de srsRAN sur Kubernetes ==="

# 1. Créer le namespace
echo "1. Création du namespace..."
kubectl apply -f namespace.yaml

# 2. Déployer srsepc (EPC - Core Network)
echo "2. Déploiement de srsepc..."
kubectl apply -f deployments/srsepc-deployment.yaml
kubectl apply -f services/srsepc-service.yaml

# Attendre que srsepc soit prêt
echo "   Attente que srsepc soit prêt..."
kubectl wait --for=condition=ready pod -l app=srsepc -n srsran --timeout=120s

# 3. Déployer srsenb (eNodeB)
echo "3. Déploiement de srsenb..."
kubectl apply -f deployments/srsenb-deployment.yaml
kubectl apply -f services/srsenb-service.yaml

# Attendre que srsenb soit prêt
echo "   Attente que srsenb soit prêt..."
kubectl wait --for=condition=ready pod -l app=srsenb -n srsran --timeout=120s

# 4. Déployer srsue (UE)
echo "4. Déploiement de srsue..."
kubectl apply -f deployments/srsue-deployment.yaml
kubectl apply -f services/srsue-service.yaml

# Attendre que srsue soit prêt
echo "   Attente que srsue soit prêt..."
kubectl wait --for=condition=ready pod -l app=srsue -n srsran --timeout=120s

# 5. Afficher le statut
echo ""
echo "=== Statut du déploiement ==="
kubectl get all -n srsran

echo ""
echo "=== Déploiement terminé avec succès ! ==="
echo ""
echo "Commandes utiles :"
echo "  - Voir les logs srsepc : kubectl logs -f -l app=srsepc -n srsran"
echo "  - Voir les logs srsenb : kubectl logs -f -l app=srsenb -n srsran"
echo "  - Voir les logs srsue  : kubectl logs -f -l app=srsue -n srsran"
echo "  - Voir tous les pods   : kubectl get pods -n srsran"
echo "  - Supprimer tout       : kubectl delete namespace srsran"
