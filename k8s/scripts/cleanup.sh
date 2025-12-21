#!/bin/bash
#
# Script de nettoyage complet du déploiement
# Supprime tous les composants Kubernetes
#

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

print_header() {
    echo -e "\n${RED}========================================${NC}"
    echo -e "${RED}$1${NC}"
    echo -e "${RED}========================================${NC}\n"
}

# Confirmation
confirm_deletion() {
    print_warning "⚠️  ATTENTION ⚠️"
    echo ""
    print_warning "Cette opération va supprimer:"
    echo "  - Tous les déploiements Helm (4G, 5G, IMS, Monitoring)"
    echo "  - Tous les services partagés (MongoDB, DNS)"
    echo "  - Tous les namespaces et leurs données"
    echo "  - Toutes les données des abonnés (SIM)"
    echo "  - Tous les PersistentVolumeClaims"
    echo ""
    
    read -p "Êtes-vous ABSOLUMENT sûr? Tapez 'YES' pour confirmer: " confirmation
    
    if [ "$confirmation" != "YES" ]; then
        print_info "Opération annulée"
        exit 0
    fi
}

# Supprimer les releases Helm
delete_helm_releases() {
    print_header "Suppression des Releases Helm"
    
    # Liste des releases
    local releases=(
        "open5gs-5g:5g-core"
        "open5gs-4g:4g-core"
        "ims:ims"
        "monitoring:monitoring"
    )
    
    for release_ns in "${releases[@]}"; do
        local release=$(echo $release_ns | cut -d: -f1)
        local namespace=$(echo $release_ns | cut -d: -f2)
        
        if helm list -n $namespace 2>/dev/null | grep -q $release; then
            echo -n "Suppression de $release (namespace: $namespace)... "
            if helm uninstall $release -n $namespace 2>/dev/null; then
                print_success "OK"
            else
                print_warning "Déjà supprimé ou erreur"
            fi
        fi
    done
}

# Supprimer les manifests des services partagés
delete_shared_services() {
    print_header "Suppression des Services Partagés"
    
    local manifests=(
        "manifests/shared/dns.yaml"
        "manifests/shared/mongodb.yaml"
    )
    
    for manifest in "${manifests[@]}"; do
        local full_path="$(dirname "$(dirname "$0")")/$manifest"
        if [ -f "$full_path" ]; then
            echo -n "Suppression de $manifest... "
            if kubectl delete -f "$full_path" --ignore-not-found=true 2>/dev/null; then
                print_success "OK"
            else
                print_warning "Erreur ou déjà supprimé"
            fi
        fi
    done
}

# Supprimer les PVC
delete_pvcs() {
    print_header "Suppression des PersistentVolumeClaims"
    
    local namespaces=("shared-services" "4g-core" "5g-core" "ims" "monitoring")
    
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace $ns &>/dev/null; then
            echo -n "Suppression des PVCs dans $ns... "
            local pvc_count=$(kubectl get pvc -n $ns --no-headers 2>/dev/null | wc -l)
            if [ "$pvc_count" -gt 0 ]; then
                kubectl delete pvc --all -n $ns --ignore-not-found=true --timeout=60s 2>/dev/null
                print_success "OK ($pvc_count PVCs)"
            else
                print_info "Aucun PVC"
            fi
        fi
    done
}

# Forcer la suppression des pods restants
force_delete_pods() {
    print_header "Suppression Forcée des Pods Restants"
    
    local namespaces=("4g-core" "5g-core" "ims" "monitoring" "shared-services")
    
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace $ns &>/dev/null; then
            local pod_count=$(kubectl get pods -n $ns --no-headers 2>/dev/null | wc -l)
            if [ "$pod_count" -gt 0 ]; then
                echo -n "Suppression forcée des pods dans $ns... "
                kubectl delete pods --all -n $ns --force --grace-period=0 --ignore-not-found=true 2>/dev/null
                print_success "OK ($pod_count pods)"
            fi
        fi
    done
}

# Supprimer les namespaces
delete_namespaces() {
    print_header "Suppression des Namespaces"
    
    local namespace_file="$(dirname "$(dirname "$0")")/manifests/namespaces/namespaces.yaml"
    
    if [ -f "$namespace_file" ]; then
        echo -n "Suppression des namespaces... "
        kubectl delete -f "$namespace_file" --ignore-not-found=true --timeout=120s 2>/dev/null &
        local delete_pid=$!
        
        # Attendre avec timeout
        local timeout=60
        local elapsed=0
        while kill -0 $delete_pid 2>/dev/null && [ $elapsed -lt $timeout ]; do
            sleep 2
            elapsed=$((elapsed + 2))
            echo -n "."
        done
        
        if kill -0 $delete_pid 2>/dev/null; then
            print_warning "Timeout, suppression forcée..."
            kill $delete_pid 2>/dev/null
            
            # Forcer la suppression
            local namespaces=("4g-core" "5g-core" "ims" "monitoring" "shared-services")
            for ns in "${namespaces[@]}"; do
                kubectl delete namespace $ns --force --grace-period=0 --ignore-not-found=true 2>/dev/null &
            done
        fi
        
        print_success "OK"
    fi
}

# Nettoyer les finalizers bloquants
cleanup_finalizers() {
    print_header "Nettoyage des Finalizers Bloquants"
    
    local namespaces=("4g-core" "5g-core" "ims" "monitoring" "shared-services")
    
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace $ns &>/dev/null; then
            # Supprimer les finalizers des PVCs
            for pvc in $(kubectl get pvc -n $ns -o name 2>/dev/null); do
                kubectl patch $pvc -n $ns -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
            done
            
            # Supprimer les finalizers du namespace
            kubectl patch namespace $ns -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
        fi
    done
    
    print_success "Finalizers nettoyés"
}

# Vérifier la suppression complète
verify_cleanup() {
    print_header "Vérification de la Suppression"
    
    local remaining_resources=0
    
    # Vérifier les namespaces
    for ns in 4g-core 5g-core ims monitoring shared-services; do
        if kubectl get namespace $ns &>/dev/null; then
            print_warning "Namespace $ns encore présent"
            ((remaining_resources++))
        fi
    done
    
    # Vérifier les releases Helm
    local helm_count=$(helm list -A 2>/dev/null | grep -E 'open5gs|ims|monitoring' | wc -l)
    if [ "$helm_count" -gt 0 ]; then
        print_warning "$helm_count release(s) Helm encore présente(s)"
        ((remaining_resources++))
    fi
    
    if [ $remaining_resources -eq 0 ]; then
        print_success "Nettoyage complet réussi!"
        return 0
    else
        print_warning "$remaining_resources ressource(s) restante(s)"
        print_info "Vous pouvez les supprimer manuellement ou réexécuter ce script"
        return 1
    fi
}

# Afficher le résumé
show_summary() {
    print_header "Résumé"
    
    echo "Ressources restantes:"
    echo ""
    
    echo -e "${BLUE}Namespaces:${NC}"
    kubectl get namespaces | grep -E '4g-core|5g-core|ims|monitoring|shared-services' || echo "  Aucun"
    echo ""
    
    echo -e "${BLUE}Releases Helm:${NC}"
    helm list -A | grep -E 'open5gs|ims|monitoring' || echo "  Aucune"
    echo ""
    
    echo -e "${BLUE}PVCs:${NC}"
    for ns in 4g-core 5g-core ims monitoring shared-services; do
        if kubectl get namespace $ns &>/dev/null; then
            kubectl get pvc -n $ns 2>/dev/null || true
        fi
    done
}

# Menu d'options
show_menu() {
    cat << EOF

╔════════════════════════════════════════════════════════╗
║   Nettoyage du Déploiement Kubernetes                 ║
║   Migration 4G vers 5G - Open5GS                      ║
╚════════════════════════════════════════════════════════╝

Options:
  1) Nettoyage complet (recommandé)
  2) Supprimer uniquement les releases Helm
  3) Supprimer uniquement les services partagés
  4) Supprimer uniquement les PVCs
  5) Forcer la suppression des ressources bloquées
  6) Afficher l'état actuel
  7) Quitter

EOF
    read -p "Choisissez une option [1-7]: " choice
    
    case $choice in
        1)
            confirm_deletion
            delete_helm_releases
            delete_shared_services
            delete_pvcs
            force_delete_pods
            cleanup_finalizers
            delete_namespaces
            sleep 5
            verify_cleanup
            show_summary
            ;;
        2)
            confirm_deletion
            delete_helm_releases
            ;;
        3)
            confirm_deletion
            delete_shared_services
            ;;
        4)
            confirm_deletion
            delete_pvcs
            ;;
        5)
            confirm_deletion
            force_delete_pods
            cleanup_finalizers
            ;;
        6)
            show_summary
            ;;
        7)
            print_info "Au revoir!"
            exit 0
            ;;
        *)
            print_error "Option invalide"
            exit 1
            ;;
    esac
}

# Main
main() {
    echo -e "${RED}"
    cat << "EOF"
╔════════════════════════════════════════════════════════╗
║   ⚠️  NETTOYAGE DU DÉPLOIEMENT  ⚠️                    ║
║   Migration 4G vers 5G - Open5GS                      ║
╚════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    # Mode automatique avec --force
    if [ "$1" == "--force" ]; then
        print_warning "Mode automatique activé (--force)"
        confirmation="YES"
        delete_helm_releases
        delete_shared_services
        delete_pvcs
        force_delete_pods
        cleanup_finalizers
        delete_namespaces
        sleep 5
        verify_cleanup
        show_summary
    else
        show_menu
    fi
}

main "$@"
