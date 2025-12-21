#!/bin/bash
#
# Script de provisioning automatique de SIM cards
# Ajoute des abonnés dans MongoDB via WebUI API
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

# Configuration par défaut
NETWORK_TYPE="${1:-4g}"  # 4g ou 5g
WEBUI_URL="${2:-http://localhost:9999}"
NUM_SUBSCRIBERS="${3:-5}"

# Générer un abonné
generate_subscriber() {
    local index=$1
    local imsi=$(printf "001010000000%03d" $index)
    
    # Keys (peuvent être générés aléatoirement)
    local k="465B5CE8B199B49FAA5F0A2EE238A6BC"
    local opc="E8ED289DEBA952E4283B54E88E6183CA"
    
    # MSISDN
    local msisdn=$(printf "33612345%03d" $index)
    
    cat <<EOF
{
  "imsi": "$imsi",
  "msisdn": ["$msisdn"],
  "security": {
    "k": "$k",
    "opc": "$opc",
    "amf": "8000",
    "sqn": 0
  },
  "ambr": {
    "downlink": {"value": 1, "unit": 3},
    "uplink": {"value": 1, "unit": 3}
  },
  "slice": [
    {
      "sst": 1,
      "default_indicator": true,
      "session": [
        {
          "name": "internet",
          "type": 3,
          "qos": {
            "index": 9,
            "arp": {
              "priority_level": 8,
              "pre_emption_capability": 1,
              "pre_emption_vulnerability": 1
            }
          },
          "ambr": {
            "downlink": {"value": 1, "unit": 3},
            "uplink": {"value": 1, "unit": 3}
          }
        }
      ]
    }
  ],
  "access_restriction_data": 32,
  "subscriber_status": 0,
  "network_access_mode": 0,
  "subscribed_rau_tau_timer": 12
}
EOF
}

# Provisionner un abonné via API
provision_subscriber() {
    local imsi=$1
    local data=$2
    
    echo -n "Provisioning IMSI: $imsi... "
    
    local response=$(curl -s -w "\n%{http_code}" -X POST \
        "$WEBUI_URL/api/db/Subscriber" \
        -H "Content-Type: application/json" \
        -d "$data")
    
    local http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" == "201" ] || [ "$http_code" == "200" ]; then
        print_success "OK"
        return 0
    else
        print_error "FAILED (HTTP $http_code)"
        return 1
    fi
}

# Vérifier l'accessibilité du WebUI
check_webui() {
    print_info "Vérification de l'accessibilité du WebUI..."
    
    if ! curl -s -f "$WEBUI_URL" > /dev/null; then
        print_error "WebUI non accessible à $WEBUI_URL"
        print_info ""
        print_info "Assurez-vous que le port-forward est actif:"
        
        if [ "$NETWORK_TYPE" == "4g" ]; then
            echo "  kubectl port-forward -n 4g-core svc/webui 9999:9999"
        else
            echo "  kubectl port-forward -n 5g-core svc/webui 9999:9999"
        fi
        
        exit 1
    fi
    
    print_success "WebUI accessible"
}

# Lister les abonnés existants
list_subscribers() {
    print_info "Récupération des abonnés existants..."
    
    local response=$(curl -s "$WEBUI_URL/api/db/Subscriber")
    local count=$(echo "$response" | jq '. | length' 2>/dev/null || echo "0")
    
    print_info "Nombre d'abonnés existants: $count"
    
    if [ "$count" -gt 0 ]; then
        echo ""
        echo "IMSI existants:"
        echo "$response" | jq -r '.[].imsi' 2>/dev/null || echo "Impossible de parser la réponse"
    fi
}

# Provisionner plusieurs abonnés
provision_batch() {
    local num=$1
    local success=0
    local failed=0
    
    print_info "Provisioning de $num abonnés..."
    echo ""
    
    for i in $(seq 1 $num); do
        local imsi=$(printf "001010000000%03d" $i)
        local data=$(generate_subscriber $i)
        
        if provision_subscriber "$imsi" "$data"; then
            ((success++))
        else
            ((failed++))
        fi
        
        sleep 0.5  # Éviter de surcharger l'API
    done
    
    echo ""
    print_info "Résumé:"
    echo "  Succès: $success"
    echo "  Échecs: $failed"
}

# Supprimer tous les abonnés
delete_all_subscribers() {
    print_warning "Suppression de tous les abonnés..."
    
    read -p "Êtes-vous sûr? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Opération annulée"
        return
    fi
    
    local response=$(curl -s "$WEBUI_URL/api/db/Subscriber")
    local imsis=$(echo "$response" | jq -r '.[].imsi' 2>/dev/null)
    
    for imsi in $imsis; do
        echo -n "Suppression IMSI: $imsi... "
        if curl -s -X DELETE "$WEBUI_URL/api/db/Subscriber/$imsi" > /dev/null; then
            print_success "OK"
        else
            print_error "FAILED"
        fi
    done
}

# Exemples de SIM pour tests
provision_test_sims() {
    print_info "Provisioning de SIM cards de test..."
    echo ""
    
    # SIM 1 - Test basique
    print_info "SIM 1: Test basique (eMBB)"
    local sim1='{
  "imsi": "001010000000001",
  "msisdn": ["33612340001"],
  "security": {
    "k": "465B5CE8B199B49FAA5F0A2EE238A6BC",
    "opc": "E8ED289DEBA952E4283B54E88E6183CA",
    "amf": "8000",
    "sqn": 0
  },
  "ambr": {
    "downlink": {"value": 1, "unit": 3},
    "uplink": {"value": 1, "unit": 3}
  },
  "slice": [
    {
      "sst": 1,
      "sd": "000001",
      "default_indicator": true,
      "session": [
        {
          "name": "internet",
          "type": 3,
          "qos": {"index": 9, "arp": {"priority_level": 8}},
          "ambr": {
            "downlink": {"value": 1, "unit": 3},
            "uplink": {"value": 1, "unit": 3}
          }
        }
      ]
    }
  ],
  "access_restriction_data": 32,
  "subscriber_status": 0,
  "network_access_mode": 0,
  "subscribed_rau_tau_timer": 12
}'
    provision_subscriber "001010000000001" "$sim1"
    
    # SIM 2 - URLLC (5G seulement)
    if [ "$NETWORK_TYPE" == "5g" ]; then
        print_info "SIM 2: Test URLLC (faible latence)"
        local sim2='{
  "imsi": "001010000000002",
  "msisdn": ["33612340002"],
  "security": {
    "k": "465B5CE8B199B49FAA5F0A2EE238A6BC",
    "opc": "E8ED289DEBA952E4283B54E88E6183CA",
    "amf": "8000",
    "sqn": 0
  },
  "ambr": {
    "downlink": {"value": 500, "unit": 2},
    "uplink": {"value": 500, "unit": 2}
  },
  "slice": [
    {
      "sst": 2,
      "sd": "000002",
      "default_indicator": true,
      "session": [
        {
          "name": "urllc",
          "type": 3,
          "qos": {"index": 1, "arp": {"priority_level": 1}},
          "ambr": {
            "downlink": {"value": 500, "unit": 2},
            "uplink": {"value": 500, "unit": 2}
          }
        }
      ]
    }
  ],
  "access_restriction_data": 32,
  "subscriber_status": 0,
  "network_access_mode": 0,
  "subscribed_rau_tau_timer": 12
}'
        provision_subscriber "001010000000002" "$sim2"
        
        # SIM 3 - mMTC (IoT)
        print_info "SIM 3: Test mMTC (IoT)"
        local sim3='{
  "imsi": "001010000000003",
  "msisdn": ["33612340003"],
  "security": {
    "k": "465B5CE8B199B49FAA5F0A2EE238A6BC",
    "opc": "E8ED289DEBA952E4283B54E88E6183CA",
    "amf": "8000",
    "sqn": 0
  },
  "ambr": {
    "downlink": {"value": 10, "unit": 2},
    "uplink": {"value": 10, "unit": 2}
  },
  "slice": [
    {
      "sst": 3,
      "sd": "000003",
      "default_indicator": true,
      "session": [
        {
          "name": "mmtc",
          "type": 3,
          "qos": {"index": 9, "arp": {"priority_level": 15}},
          "ambr": {
            "downlink": {"value": 10, "unit": 2},
            "uplink": {"value": 10, "unit": 2}
          }
        }
      ]
    }
  ],
  "access_restriction_data": 32,
  "subscriber_status": 0,
  "network_access_mode": 0,
  "subscribed_rau_tau_timer": 12
}'
        provision_subscriber "001010000000003" "$sim3"
    fi
    
    echo ""
    print_success "SIM cards de test provisionnées!"
}

# Menu
show_menu() {
    cat << EOF

╔════════════════════════════════════════════════════════╗
║   Provisioning de SIM Cards                           ║
║   Open5GS - $NETWORK_TYPE                                          ║
╚════════════════════════════════════════════════════════╝

WebUI URL: $WEBUI_URL

Options:
  1) Provisionner des SIM de test (recommandé)
  2) Provisionner N abonnés (batch)
  3) Lister les abonnés existants
  4) Supprimer tous les abonnés
  5) Quitter

EOF
    read -p "Choisissez une option [1-5]: " choice
    
    case $choice in
        1)
            check_webui
            provision_test_sims
            list_subscribers
            ;;
        2)
            check_webui
            read -p "Nombre d'abonnés à créer: " num
            provision_batch $num
            list_subscribers
            ;;
        3)
            check_webui
            list_subscribers
            ;;
        4)
            check_webui
            delete_all_subscribers
            ;;
        5)
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
    echo -e "${BLUE}"
    cat << "EOF"
╔════════════════════════════════════════════════════════╗
║   Provisioning Automatique de SIM                     ║
║   Migration 4G vers 5G - Open5GS                      ║
╚════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    # Vérifier jq
    if ! command -v jq &> /dev/null; then
        print_warning "jq n'est pas installé (recommandé pour parser JSON)"
        print_info "Installation: apt-get install jq (Linux) ou brew install jq (Mac)"
    fi
    
    # Mode interactif
    show_menu
}

main
