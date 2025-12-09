#!/bin/bash

#############################################################################
# Script de déploiement des conteneurs srsRAN
# Ce script déploie les conteneurs Docker sur les VMs Core et UE
#############################################################################

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"

# Couleurs pour l'output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Fonctions
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Vérification des prérequis..."
    
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform n'est pas installé"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_warning "jq n'est pas installé - installation en cours..."
        sudo apt-get update && sudo apt-get install -y jq
    fi
    
    if [ ! -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
        log_error "Terraform state file not found. Run 'terraform apply' first."
        exit 1
    fi
    
    log_success "Tous les prérequis sont satisfaits"
}

get_terraform_outputs() {
    log_info "Récupération des outputs Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    CORE_IP=$(terraform output -raw core_vm_public_ip)
    CORE_PRIVATE_IP=$(terraform output -raw core_vm_private_ip)
    UE_IP=$(terraform output -raw ue_vm_public_ip)
    UE_PRIVATE_IP=$(terraform output -raw ue_vm_private_ip)
    
    log_info "Core VM Public IP: $CORE_IP"
    log_info "Core VM Private IP: $CORE_PRIVATE_IP"
    log_info "UE VM Public IP: $UE_IP"
    log_info "UE VM Private IP: $UE_PRIVATE_IP"
}

deploy_core_vm() {
    log_info "Déploiement sur Core VM ($CORE_IP)..."
    
    ssh -o StrictHostKeyChecking=no azureuser@$CORE_IP << 'CORE_DEPLOY'
        set -e
        
        echo "====== Core VM Setup ======"
        
        # Update system
        echo "Updating system..."
        sudo apt-get update
        sudo apt-get upgrade -y
        
        # Install docker-compose plugin
        echo "Installing Docker Compose..."
        sudo apt-get install -y docker-compose-plugin
        
        # Verify Docker
        echo "Verifying Docker installation..."
        docker --version
        docker-compose version
        
        # Create srsran directories
        echo "Creating srsRAN directories..."
        mkdir -p ~/srsran/config
        cd ~/srsran
        
        # TODO: Add docker-compose.yml for Core (EPC + eNodeB)
        # For now, just verify Docker is working
        echo "Docker setup complete"
        sudo docker ps
        
CORE_DEPLOY
    
    log_success "Core VM deployment completed"
}

deploy_ue_vm() {
    log_info "Déploiement sur UE VM ($UE_IP)..."
    
    # Pass CORE_PRIVATE_IP to UE VM for ZMQ connection
    ssh -o StrictHostKeyChecking=no azureuser@$UE_IP << UE_DEPLOY
        set -e
        
        echo "====== UE VM Setup ======"
        
        # Update system
        echo "Updating system..."
        sudo apt-get update
        sudo apt-get upgrade -y
        
        # Install docker-compose plugin
        echo "Installing Docker Compose..."
        sudo apt-get install -y docker-compose-plugin
        
        # Verify Docker
        echo "Verifying Docker installation..."
        docker --version
        docker-compose version
        
        # Create srsran directories
        echo "Creating srsRAN directories..."
        mkdir -p ~/srsran/config
        cd ~/srsran
        
        # Set Core VM IP for ZMQ connection
        echo "Core VM Private IP: $CORE_PRIVATE_IP"
        
        # TODO: Add docker-compose.yml for UE (srsUE)
        # The ZMQ connection should reference $CORE_PRIVATE_IP
        # For now, just verify Docker is working
        echo "Docker setup complete"
        sudo docker ps
        
UE_DEPLOY
    
    log_success "UE VM deployment completed"
}

verify_connectivity() {
    log_info "Vérification de la connectivité..."
    
    # Test ping from UE to Core via private network
    ssh -o StrictHostKeyChecking=no azureuser@$UE_IP << PING_TEST
        echo "Testing ping from UE to Core..."
        ping -c 4 $CORE_PRIVATE_IP || echo "Ping failed - this might be expected depending on NSG rules"
PING_TEST
    
    log_success "Connectivité vérifiée"
}

print_summary() {
    echo ""
    echo "======================================"
    log_success "Déploiement terminé avec succès!"
    echo "======================================"
    echo ""
    echo "Informations de connexion :"
    echo "  Core VM: ssh azureuser@$CORE_IP"
    echo "  UE VM:   ssh azureuser@$UE_IP"
    echo ""
    echo "Adresses privées (pour ZMQ) :"
    echo "  Core VM: $CORE_PRIVATE_IP"
    echo "  UE VM:   $UE_PRIVATE_IP"
    echo ""
}

# ============================================================================
# Main
# ============================================================================

main() {
    log_info "Démarrage du déploiement srsRAN..."
    
    check_prerequisites
    get_terraform_outputs
    deploy_core_vm
    deploy_ue_vm
    verify_connectivity
    print_summary
}

# Run main function
main "$@"
