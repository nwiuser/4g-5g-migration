#!/bin/bash
#
# Script de test de connectivité réseau
# Teste la communication entre composants 4G/5G
#

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

# Test DNS
test_dns_resolution() {
    print_header "Test de Résolution DNS"
    
    local services=(
        "mongodb.shared-services.svc.cluster.local"
        "dns.shared-services.svc.cluster.local"
        "mme.4g-core.svc.cluster.local"
        "amf.5g-core.svc.cluster.local"
        "webui.4g-core.svc.cluster.local"
        "webui.5g-core.svc.cluster.local"
    )
    
    for service in "${services[@]}"; do
        echo -n "Testing DNS: $service... "
        if kubectl run dnstest-$RANDOM --image=busybox:latest --rm -i --restart=Never \
            --namespace=shared-services \
            --timeout=30s \
            -- nslookup "$service" > /dev/null 2>&1; then
            print_success "OK"
        else
            print_error "FAILED"
        fi
    done
}

# Test connectivité MongoDB
test_mongodb_connectivity() {
    print_header "Test de Connectivité MongoDB"
    
    local mongo_pod=$(kubectl get pod -n shared-services -l app=mongodb -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$mongo_pod" ]; then
        print_error "MongoDB pod non trouvé"
        return 1
    fi
    
    print_info "MongoDB pod: $mongo_pod"
    
    # Test ping
    echo -n "Test ping MongoDB... "
    if kubectl exec -n shared-services "$mongo_pod" -- mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
        print_success "OK"
    else
        print_error "FAILED"
    fi
    
    # Test connexion depuis autre namespace
    echo -n "Test connexion depuis 4g-core... "
    if kubectl run mongotest-$RANDOM --image=mongo:6.0 --rm -i --restart=Never \
        --namespace=4g-core \
        --timeout=30s \
        -- mongosh "mongodb://mongodb.shared-services.svc.cluster.local:27017" --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
        print_success "OK"
    else
        print_error "FAILED"
    fi
}

# Test connectivité inter-composants 4G
test_4g_connectivity() {
    print_header "Test de Connectivité 4G (Inter-Composants)"
    
    if ! helm list -n 4g-core | grep -q open5gs-4g; then
        print_info "4G Core non déployé, test ignoré"
        return
    fi
    
    # Test MME -> HSS (S6a Diameter)
    echo -n "Test MME -> HSS... "
    local mme_pod=$(kubectl get pod -n 4g-core -l component=mme -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    local hss_svc="hss.4g-core.svc.cluster.local"
    
    if [ ! -z "$mme_pod" ]; then
        if kubectl exec -n 4g-core "$mme_pod" -- nc -zv -w5 "$hss_svc" 3868 2>&1 | grep -q succeeded; then
            print_success "OK (Diameter port 3868)"
        else
            print_error "FAILED"
        fi
    fi
    
    # Test MME -> SGWC (S11 GTP-C)
    echo -n "Test MME -> SGWC... "
    local sgwc_svc="sgwc.4g-core.svc.cluster.local"
    
    if [ ! -z "$mme_pod" ]; then
        if kubectl exec -n 4g-core "$mme_pod" -- nc -zuv -w5 "$sgwc_svc" 2123 2>&1 | grep -q succeeded; then
            print_success "OK (GTP-C port 2123)"
        else
            print_error "FAILED"
        fi
    fi
    
    # Test SGWU -> UPF (S5-U GTP-U)
    echo -n "Test SGWU -> UPF... "
    local sgwu_pod=$(kubectl get pod -n 4g-core -l component=sgwu -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    local upf_svc="upf.4g-core.svc.cluster.local"
    
    if [ ! -z "$sgwu_pod" ]; then
        if kubectl exec -n 4g-core "$sgwu_pod" -- nc -zuv -w5 "$upf_svc" 2152 2>&1 | grep -q succeeded; then
            print_success "OK (GTP-U port 2152)"
        else
            print_error "FAILED"
        fi
    fi
}

# Test connectivité inter-composants 5G
test_5g_connectivity() {
    print_header "Test de Connectivité 5G (Inter-Composants)"
    
    if ! helm list -n 5g-core | grep -q open5gs-5g; then
        print_info "5G Core non déployé, test ignoré"
        return
    fi
    
    # Test AMF -> NRF (SBI HTTP/2)
    echo -n "Test AMF -> NRF... "
    local amf_pod=$(kubectl get pod -n 5g-core -l component=amf -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    local nrf_svc="nrf.5g-core.svc.cluster.local"
    
    if [ ! -z "$amf_pod" ]; then
        if kubectl exec -n 5g-core "$amf_pod" -- nc -zv -w5 "$nrf_svc" 7777 2>&1 | grep -q succeeded; then
            print_success "OK (SBI port 7777)"
        else
            print_error "FAILED"
        fi
    fi
    
    # Test AMF -> AUSF (SBI)
    echo -n "Test AMF -> AUSF... "
    local ausf_svc="ausf.5g-core.svc.cluster.local"
    
    if [ ! -z "$amf_pod" ]; then
        if kubectl exec -n 5g-core "$amf_pod" -- nc -zv -w5 "$ausf_svc" 7777 2>&1 | grep -q succeeded; then
            print_success "OK (SBI port 7777)"
        else
            print_error "FAILED"
        fi
    fi
    
    # Test SMF -> UPF (PFCP)
    echo -n "Test SMF -> UPF... "
    local smf_pod=$(kubectl get pod -n 5g-core -l component=smf -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    local upf_svc="upf.5g-core.svc.cluster.local"
    
    if [ ! -z "$smf_pod" ]; then
        if kubectl exec -n 5g-core "$smf_pod" -- nc -zuv -w5 "$upf_svc" 8805 2>&1 | grep -q succeeded; then
            print_success "OK (PFCP port 8805)"
        else
            print_error "FAILED"
        fi
    fi
    
    # Test UDM -> UDR (SBI)
    echo -n "Test UDM -> UDR... "
    local udm_pod=$(kubectl get pod -n 5g-core -l component=udm -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    local udr_svc="udr.5g-core.svc.cluster.local"
    
    if [ ! -z "$udm_pod" ]; then
        if kubectl exec -n 5g-core "$udm_pod" -- nc -zv -w5 "$udr_svc" 7777 2>&1 | grep -q succeeded; then
            print_success "OK (SBI port 7777)"
        else
            print_error "FAILED"
        fi
    fi
}

# Test interworking 4G-5G (N26)
test_interworking() {
    print_header "Test Interworking 4G-5G (N26)"
    
    local mme_pod=$(kubectl get pod -n 4g-core -l component=mme -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    local amf_svc="amf.5g-core.svc.cluster.local"
    
    if [ -z "$mme_pod" ] || ! kubectl get svc -n 5g-core amf > /dev/null 2>&1; then
        print_info "Interworking non déployé ou composants manquants"
        return
    fi
    
    echo -n "Test MME -> AMF (N26)... "
    if kubectl exec -n 4g-core "$mme_pod" -- nc -zv -w5 "$amf_svc" 38412 2>&1 | grep -q succeeded; then
        print_success "OK (SCTP port 38412)"
    else
        print_error "FAILED (vérifier configuration interworking)"
    fi
}

# Test endpoints WebUI
test_webui_endpoints() {
    print_header "Test des Endpoints WebUI"
    
    # WebUI 4G
    if kubectl get svc -n 4g-core webui > /dev/null 2>&1; then
        local webui_4g_pod=$(kubectl get pod -n 4g-core -l component=webui -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        
        echo -n "Test WebUI 4G health... "
        if [ ! -z "$webui_4g_pod" ]; then
            if kubectl exec -n 4g-core "$webui_4g_pod" -- wget -q -O- http://localhost:9999 > /dev/null 2>&1; then
                print_success "OK (port 9999)"
                print_info "  Accès: kubectl port-forward -n 4g-core svc/webui 9999:9999"
            else
                print_error "FAILED"
            fi
        fi
    fi
    
    # WebUI 5G
    if kubectl get svc -n 5g-core webui > /dev/null 2>&1; then
        local webui_5g_pod=$(kubectl get pod -n 5g-core -l component=webui -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        
        echo -n "Test WebUI 5G health... "
        if [ ! -z "$webui_5g_pod" ]; then
            if kubectl exec -n 5g-core "$webui_5g_pod" -- wget -q -O- http://localhost:9999 > /dev/null 2>&1; then
                print_success "OK (port 9999)"
                print_info "  Accès: kubectl port-forward -n 5g-core svc/webui 10000:9999"
            else
                print_error "FAILED"
            fi
        fi
    fi
}

# Test métriques Prometheus
test_metrics_endpoints() {
    print_header "Test des Endpoints Métriques"
    
    # Métriques MME
    local mme_pod=$(kubectl get pod -n 4g-core -l component=mme -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ ! -z "$mme_pod" ]; then
        echo -n "Test Métriques MME... "
        if kubectl exec -n 4g-core "$mme_pod" -- wget -q -O- http://localhost:9090/metrics | head -n 1 > /dev/null 2>&1; then
            print_success "OK (http://localhost:9090/metrics)"
        else
            print_error "FAILED"
        fi
    fi
    
    # Métriques AMF
    local amf_pod=$(kubectl get pod -n 5g-core -l component=amf -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ ! -z "$amf_pod" ]; then
        echo -n "Test Métriques AMF... "
        if kubectl exec -n 5g-core "$amf_pod" -- wget -q -O- http://localhost:9090/metrics | head -n 1 > /dev/null 2>&1; then
            print_success "OK (http://localhost:9090/metrics)"
        else
            print_error "FAILED"
        fi
    fi
}

# Résumé réseau
show_network_summary() {
    print_header "Résumé de la Topologie Réseau"
    
    print_info "Services exposés:"
    echo ""
    kubectl get svc -n shared-services -o wide
    echo ""
    kubectl get svc -n 4g-core -o wide 2>/dev/null || true
    echo ""
    kubectl get svc -n 5g-core -o wide 2>/dev/null || true
    
    echo ""
    print_info "Endpoints disponibles:"
    echo ""
    kubectl get endpoints -n shared-services
    echo ""
    kubectl get endpoints -n 4g-core 2>/dev/null || true
    echo ""
    kubectl get endpoints -n 5g-core 2>/dev/null || true
}

# Main
main() {
    echo -e "${BLUE}"
    cat << "EOF"
╔════════════════════════════════════════════════════════╗
║   Test de Connectivité Réseau                         ║
║   Migration 4G vers 5G - Open5GS                      ║
╚════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    test_dns_resolution
    test_mongodb_connectivity
    test_4g_connectivity
    test_5g_connectivity
    test_interworking
    test_webui_endpoints
    test_metrics_endpoints
    show_network_summary
    
    echo ""
    print_success "Tests de connectivité terminés!"
}

main
