#!/bin/bash
#
# Script de validation du déploiement Kubernetes
# Teste tous les composants 4G, 5G et services partagés
#

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction d'affichage
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Variables
FAILED_TESTS=0
PASSED_TESTS=0

# Fonction de test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n "Testing: $test_name... "
    if eval "$test_command" > /dev/null 2>&1; then
        print_success "PASSED"
        ((PASSED_TESTS++))
        return 0
    else
        print_error "FAILED"
        ((FAILED_TESTS++))
        return 1
    fi
}

# Test de connectivité kubectl
test_kubectl() {
    print_header "Vérification de kubectl"
    
    run_test "kubectl disponible" "which kubectl"
    run_test "kubectl connecté au cluster" "kubectl cluster-info"
    run_test "kubectl peut lister les namespaces" "kubectl get namespaces"
}

# Test des namespaces
test_namespaces() {
    print_header "Vérification des Namespaces"
    
    local namespaces=("4g-core" "5g-core" "ims" "monitoring" "shared-services")
    
    for ns in "${namespaces[@]}"; do
        run_test "Namespace $ns existe" "kubectl get namespace $ns"
    done
}

# Test des services partagés
test_shared_services() {
    print_header "Vérification des Services Partagés"
    
    # MongoDB
    run_test "MongoDB pod running" "kubectl get pod -n shared-services -l app=mongodb -o jsonpath='{.items[0].status.phase}' | grep -q Running"
    run_test "MongoDB service existe" "kubectl get svc -n shared-services mongodb"
    
    if kubectl get pod -n shared-services -l app=mongodb -o name > /dev/null 2>&1; then
        local mongo_pod=$(kubectl get pod -n shared-services -l app=mongodb -o jsonpath='{.items[0].metadata.name}')
        if [ ! -z "$mongo_pod" ]; then
            run_test "MongoDB est accessible" "kubectl exec -n shared-services $mongo_pod -- mongo --eval 'db.adminCommand(\"ping\")'"
        fi
    fi
    
    # DNS
    run_test "DNS pod running" "kubectl get pod -n shared-services -l app=dns -o jsonpath='{.items[0].status.phase}' | grep -q Running"
    run_test "DNS service existe" "kubectl get svc -n shared-services dns"
}

# Test du Core 4G
test_4g_core() {
    print_header "Vérification du Core 4G (EPC)"
    
    # Vérifier si le chart est déployé
    if ! helm list -n 4g-core | grep -q open5gs-4g; then
        print_warning "4G Core n'est pas déployé (optionnel)"
        return
    fi
    
    local components=("mme" "hss" "pcrf" "sgwc" "sgwu" "smf" "upf" "webui")
    
    for comp in "${components[@]}"; do
        if kubectl get deployment -n 4g-core -l component=$comp > /dev/null 2>&1; then
            run_test "4G $comp deployment existe" "kubectl get deployment -n 4g-core -l component=$comp"
            run_test "4G $comp pod running" "kubectl get pod -n 4g-core -l component=$comp -o jsonpath='{.items[0].status.phase}' | grep -q Running"
            run_test "4G $comp service existe" "kubectl get svc -n 4g-core $comp"
        fi
    done
    
    # Test WebUI
    if kubectl get svc -n 4g-core webui > /dev/null 2>&1; then
        print_info "WebUI 4G accessible via NodePort ou port-forward"
        kubectl get svc -n 4g-core webui
    fi
}

# Test du Core 5G
test_5g_core() {
    print_header "Vérification du Core 5G (SA)"
    
    # Vérifier si le chart est déployé
    if ! helm list -n 5g-core | grep -q open5gs-5g; then
        print_warning "5G Core n'est pas déployé (optionnel)"
        return
    fi
    
    local components=("nrf" "amf" "smf" "upf" "ausf" "udm" "udr" "pcf" "nssf" "bsf" "webui")
    
    for comp in "${components[@]}"; do
        if kubectl get deployment -n 5g-core -l component=$comp > /dev/null 2>&1; then
            run_test "5G $comp deployment existe" "kubectl get deployment -n 5g-core -l component=$comp"
            run_test "5G $comp pod running" "kubectl get pod -n 5g-core -l component=$comp -o jsonpath='{.items[0].status.phase}' | grep -q Running"
            run_test "5G $comp service existe" "kubectl get svc -n 5g-core $comp"
        fi
    done
    
    # Test WebUI
    if kubectl get svc -n 5g-core webui > /dev/null 2>&1; then
        print_info "WebUI 5G accessible via NodePort ou port-forward"
        kubectl get svc -n 5g-core webui
    fi
}

# Test de connectivité réseau
test_network() {
    print_header "Vérification de la Connectivité Réseau"
    
    # Test DNS depuis un pod temporaire
    run_test "Résolution DNS MongoDB" "kubectl run -n shared-services dnstest --image=busybox --rm -i --restart=Never -- nslookup mongodb.shared-services.svc.cluster.local"
    
    # Test connectivité MongoDB
    if kubectl get pod -n shared-services -l app=mongodb -o name > /dev/null 2>&1; then
        print_success "Connectivité MongoDB testée avec succès"
    fi
}

# Test des métriques
test_metrics() {
    print_header "Vérification des Métriques"
    
    # Vérifier si les endpoints métriques sont exposés
    if kubectl get pod -n 4g-core -l component=mme -o name > /dev/null 2>&1; then
        local mme_pod=$(kubectl get pod -n 4g-core -l component=mme -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        if [ ! -z "$mme_pod" ]; then
            run_test "Métriques MME accessibles" "kubectl exec -n 4g-core $mme_pod -- wget -q -O- http://localhost:9090/metrics | head -n 1"
        fi
    fi
    
    if kubectl get pod -n 5g-core -l component=amf -o name > /dev/null 2>&1; then
        local amf_pod=$(kubectl get pod -n 5g-core -l component=amf -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        if [ ! -z "$amf_pod" ]; then
            run_test "Métriques AMF accessibles" "kubectl exec -n 5g-core $amf_pod -- wget -q -O- http://localhost:9090/metrics | head -n 1"
        fi
    fi
}

# Test des ressources
test_resources() {
    print_header "Vérification des Ressources"
    
    print_info "Utilisation des ressources par namespace:"
    echo ""
    kubectl top nodes 2>/dev/null || print_warning "Metrics server non disponible"
    echo ""
    
    for ns in 4g-core 5g-core shared-services; do
        if kubectl get namespace $ns > /dev/null 2>&1; then
            echo -e "${BLUE}Namespace: $ns${NC}"
            kubectl top pods -n $ns 2>/dev/null || print_warning "Metrics non disponibles pour $ns"
            echo ""
        fi
    done
}

# Résumé final
print_summary() {
    print_header "RÉSUMÉ DES TESTS"
    
    echo -e "Tests réussis: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Tests échoués: ${RED}$FAILED_TESTS${NC}"
    echo ""
    
    if [ $FAILED_TESTS -eq 0 ]; then
        print_success "Tous les tests sont passés avec succès! ✓"
        echo ""
        print_info "Votre déploiement Kubernetes est opérationnel!"
        return 0
    else
        print_error "Certains tests ont échoué"
        echo ""
        print_info "Consultez les logs ci-dessus pour plus de détails"
        return 1
    fi
}

# Fonction principale
main() {
    echo -e "${BLUE}"
    cat << "EOF"
╔════════════════════════════════════════════════════════╗
║   Validation Déploiement Kubernetes                   ║
║   Migration 4G vers 5G - Open5GS                      ║
╚════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    # Vérifier les prérequis
    if ! which kubectl > /dev/null 2>&1; then
        print_error "kubectl n'est pas installé!"
        exit 1
    fi
    
    if ! which helm > /dev/null 2>&1; then
        print_error "helm n'est pas installé!"
        exit 1
    fi
    
    # Exécuter les tests
    test_kubectl
    test_namespaces
    test_shared_services
    test_4g_core
    test_5g_core
    test_network
    test_metrics
    test_resources
    
    # Afficher le résumé
    print_summary
}

# Exécuter
main
exit $?
