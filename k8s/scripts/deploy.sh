#!/bin/bash
#
# Script d'installation automatisé pour le déploiement Kubernetes
# Déploie l'infrastructure 4G/5G complète
#

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(dirname "$SCRIPT_DIR")"
ENVIRONMENT="${ENVIRONMENT:-dev}"  # dev, staging, prod

# Fonctions d'affichage
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

# Vérifier les prérequis
check_prerequisites() {
    print_header "Vérification des Prérequis"
    
    local missing_tools=()
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    else
        print_success "kubectl installé: $(kubectl version --client --short 2>/dev/null | head -n1)"
    fi
    
    if ! command -v helm &> /dev/null; then
        missing_tools+=("helm")
    else
        print_success "helm installé: $(helm version --short)"
    fi
    
    if ! command -v docker &> /dev/null; then
        print_warning "docker non installé (optionnel pour build images)"
    else
        print_success "docker installé: $(docker --version)"
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Outils manquants: ${missing_tools[*]}"
        print_info "Installez-les avant de continuer"
        exit 1
    fi
    
    # Vérifier la connexion au cluster
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Impossible de se connecter au cluster Kubernetes"
        print_info "Configurez kubectl avec: kubectl config use-context <context-name>"
        exit 1
    fi
    
    print_success "Cluster Kubernetes accessible"
    kubectl cluster-info | head -n 2
}

# Créer les namespaces
deploy_namespaces() {
    print_header "Création des Namespaces"
    
    kubectl apply -f "$K8S_DIR/manifests/namespaces/namespaces.yaml"
    
    print_success "Namespaces créés"
    kubectl get namespaces | grep -E '4g-core|5g-core|ims|monitoring|shared-services'
}

# Déployer les services partagés
deploy_shared_services() {
    print_header "Déploiement des Services Partagés"
    
    # MongoDB
    print_info "Déploiement de MongoDB..."
    kubectl apply -f "$K8S_DIR/manifests/shared/mongodb.yaml"
    
    print_info "Attente du démarrage de MongoDB..."
    kubectl wait --for=condition=ready pod -l app=mongodb -n shared-services --timeout=300s
    print_success "MongoDB opérationnel"
    
    # DNS
    print_info "Déploiement du DNS..."
    kubectl apply -f "$K8S_DIR/manifests/shared/dns.yaml"
    
    print_info "Attente du démarrage du DNS..."
    kubectl wait --for=condition=ready pod -l app=dns -n shared-services --timeout=120s
    print_success "DNS opérationnel"
    
    echo ""
    kubectl get pods -n shared-services
}

# Déployer le Core 4G
deploy_4g_core() {
    print_header "Déploiement du Core 4G (EPC)"
    
    read -p "Voulez-vous déployer le Core 4G? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Déploiement 4G ignoré"
        return
    fi
    
    print_info "Installation avec Helm (environnement: $ENVIRONMENT)..."
    helm install open5gs-4g "$K8S_DIR/helm/open5gs-4g" \
        -n 4g-core \
        --create-namespace \
        -f "$K8S_DIR/values/${ENVIRONMENT}.yaml" \
        --wait \
        --timeout 10m
    
    print_success "Core 4G déployé"
    
    echo ""
    kubectl get pods -n 4g-core
    echo ""
    kubectl get svc -n 4g-core
}

# Déployer le Core 5G
deploy_5g_core() {
    print_header "Déploiement du Core 5G (SA)"
    
    read -p "Voulez-vous déployer le Core 5G? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Déploiement 5G ignoré"
        return
    fi
    
    print_info "Installation avec Helm (environnement: $ENVIRONMENT)..."
    helm install open5gs-5g "$K8S_DIR/helm/open5gs-5g" \
        -n 5g-core \
        --create-namespace \
        -f "$K8S_DIR/values/${ENVIRONMENT}.yaml" \
        --wait \
        --timeout 10m
    
    print_success "Core 5G déployé"
    
    echo ""
    kubectl get pods -n 5g-core
    echo ""
    kubectl get svc -n 5g-core
}

# Configuration post-déploiement
post_deployment() {
    print_header "Configuration Post-Déploiement"
    
    # Afficher les informations d'accès WebUI
    echo ""
    print_info "📱 Accès aux WebUI:"
    echo ""
    
    if helm list -n 4g-core | grep -q open5gs-4g; then
        echo -e "${BLUE}WebUI 4G:${NC}"
        echo "  kubectl port-forward -n 4g-core svc/webui 9999:9999"
        echo "  URL: http://localhost:9999"
        echo "  Username: admin / Password: 1423"
        echo ""
        
        # Afficher le NodePort si disponible
        local nodeport=$(kubectl get svc -n 4g-core webui -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "")
        if [ ! -z "$nodeport" ]; then
            echo "  Ou via NodePort: http://<node-ip>:$nodeport"
            echo ""
        fi
    fi
    
    if helm list -n 5g-core | grep -q open5gs-5g; then
        echo -e "${BLUE}WebUI 5G:${NC}"
        echo "  kubectl port-forward -n 5g-core svc/webui 10000:9999"
        echo "  URL: http://localhost:10000"
        echo "  Username: admin / Password: 1423"
        echo ""
        
        local nodeport=$(kubectl get svc -n 5g-core webui -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "")
        if [ ! -z "$nodeport" ]; then
            echo "  Ou via NodePort: http://<node-ip>:$nodeport"
            echo ""
        fi
    fi
    
    # Commandes utiles
    print_info "📋 Commandes Utiles:"
    echo ""
    echo "  # Voir tous les pods"
    echo "  kubectl get pods -A | grep -E '4g-core|5g-core|shared-services'"
    echo ""
    echo "  # Voir les logs MME (4G)"
    echo "  kubectl logs -f -n 4g-core -l component=mme"
    echo ""
    echo "  # Voir les logs AMF (5G)"
    echo "  kubectl logs -f -n 5g-core -l component=amf"
    echo ""
    echo "  # Valider le déploiement"
    echo "  ./k8s/scripts/validate-deployment.sh"
    echo ""
}

# Afficher le résumé
show_summary() {
    print_header "RÉSUMÉ DU DÉPLOIEMENT"
    
    echo ""
    echo -e "${GREEN}✓ Déploiement terminé avec succès!${NC}"
    echo ""
    
    # Statistiques
    local namespaces=$(kubectl get namespaces | grep -E '4g-core|5g-core|ims|monitoring|shared-services' | wc -l)
    local total_pods=$(kubectl get pods -A | grep -E '4g-core|5g-core|shared-services' | grep Running | wc -l)
    
    echo "Namespaces créés: $namespaces"
    echo "Pods en cours d'exécution: $total_pods"
    echo ""
    
    # Releases Helm
    echo -e "${BLUE}Releases Helm:${NC}"
    helm list -A | grep -E 'open5gs-4g|open5gs-5g' || echo "  Aucune release déployée"
    echo ""
    
    print_info "Prochaines étapes:"
    echo "  1. Valider le déploiement: ./k8s/scripts/validate-deployment.sh"
    echo "  2. Provisionner des SIM: ./k8s/scripts/provision-sim.sh"
    echo "  3. Accéder au WebUI pour ajouter des abonnés"
    echo "  4. Tester avec srsRAN ou UERANSIM"
    echo ""
}

# Menu interactif
show_menu() {
    cat << EOF
╔════════════════════════════════════════════════════════╗
║   Installation Kubernetes - Migration 4G vers 5G      ║
║   Open5GS                                              ║
╚════════════════════════════════════════════════════════╝

Environnement: $ENVIRONMENT

Options de déploiement:
  1) Installation complète (4G + 5G + Services partagés)
  2) Services partagés uniquement (MongoDB + DNS)
  3) Core 4G uniquement
  4) Core 5G uniquement
  5) Dual-stack 4G + 5G avec interworking
  6) Quitter

EOF
    read -p "Choisissez une option [1-6]: " choice
    
    case $choice in
        1)
            deploy_namespaces
            deploy_shared_services
            deploy_4g_core
            deploy_5g_core
            post_deployment
            show_summary
            ;;
        2)
            deploy_namespaces
            deploy_shared_services
            post_deployment
            ;;
        3)
            deploy_namespaces
            deploy_shared_services
            deploy_4g_core
            post_deployment
            show_summary
            ;;
        4)
            deploy_namespaces
            deploy_shared_services
            deploy_5g_core
            post_deployment
            show_summary
            ;;
        5)
            print_info "Déploiement Dual-stack avec interworking N26..."
            deploy_namespaces
            deploy_shared_services
            
            # 4G avec N26
            helm install open5gs-4g "$K8S_DIR/helm/open5gs-4g" \
                -n 4g-core \
                --create-namespace \
                -f "$K8S_DIR/values/${ENVIRONMENT}.yaml" \
                --set interworking.enabled=true \
                --set interworking.amfAddress=amf.5g-core.svc.cluster.local \
                --wait --timeout 10m
            
            # 5G avec N26
            helm install open5gs-5g "$K8S_DIR/helm/open5gs-5g" \
                -n 5g-core \
                --create-namespace \
                -f "$K8S_DIR/values/${ENVIRONMENT}.yaml" \
                --set interworking.enabled=true \
                --set interworking.mmeAddress=mme.4g-core.svc.cluster.local \
                --wait --timeout 10m
            
            post_deployment
            show_summary
            ;;
        6)
            print_info "Installation annulée"
            exit 0
            ;;
        *)
            print_error "Option invalide"
            exit 1
            ;;
    esac
}

# Fonction principale
main() {
    echo -e "${BLUE}"
    cat << "EOF"
╔════════════════════════════════════════════════════════╗
║   Installation Automatisée Kubernetes                 ║
║   Migration 4G vers 5G - Open5GS                      ║
╚════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    check_prerequisites
    
    # Mode interactif ou automatique
    if [ "$1" == "--auto" ]; then
        print_info "Mode automatique activé"
        deploy_namespaces
        deploy_shared_services
        deploy_4g_core
        deploy_5g_core
        post_deployment
        show_summary
    else
        show_menu
    fi
}

# Exécuter
main "$@"
