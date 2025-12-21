# Architecture des Composants 4G/5G SA dans le Projet Open5GS

Ce projet déploie un réseau mobile complet (4G EPC et 5G Core) avec IMS pour VoLTE/VoNR. Voici l'explication détaillée des composants.

---

## 🔵 **Composants Communs (4G + 5G)**

### **MongoDB**
- Base de données NoSQL qui stocke les informations des abonnés (SIM, profils, APN, etc.)
- Utilisé par HSS (4G) et UDR (5G)
- Port: 27017

### **WebUI** 
- Interface web (port 9999) pour gérer les abonnés
- Permet d'ajouter/modifier/supprimer des SIM cards
- Gestion des profils d'accès (APN, QoS, etc.)
- URL d'accès: `http://localhost:9999`

### **DNS**
- Serveur DNS interne pour résoudre les noms de domaine IMS et EPC
- Essentiel pour VoLTE/VoNR (résolution des domaines IMS)
- Résolution des zones: epc, ims, pub.3gpp, e164.arpa

### **Grafana + Metrics**
- Monitoring et visualisation des métriques du réseau
- Prometheus pour collecter les données de performance
- Tableaux de bord pour surveiller les KPI du réseau

---

## 📱 **Composants 4G (EPC - Evolved Packet Core)**

### **Plan de Contrôle (Control Plane)**

#### **MME** (Mobility Management Entity)
- **Rôle**: Cerveau du réseau 4G
- **Fonctions**:
  - Gère l'authentification, l'attachement et la mobilité des UE
  - Gestion des zones de tracking (Tracking Area)
  - Paging des UE en mode idle
  - Bearer management
- **Interfaces**:
  - S1-MME avec eNodeB (SCTP port 36412)
  - S6a avec HSS (Diameter)
  - S11 avec SGWC (GTPv2-C)

#### **HSS** (Home Subscriber Server)
- **Rôle**: Base de données centrale des abonnés 4G
- **Fonctions**:
  - Stocke IMSI, K (clé d'authentification), OPc
  - Profils d'abonnement (APN, QoS)
  - Authentification AKA (Authentication and Key Agreement)
  - Génération des vecteurs d'authentification
- **Interfaces**:
  - S6a avec MME (Diameter port 3868)
  - Cx/Dx avec IMS (pour VoLTE)

#### **PCRF** (Policy and Charging Rules Function)
- **Rôle**: Gestion des politiques QoS et facturation
- **Fonctions**:
  - Contrôle du débit par APN
  - Règles de gestion du trafic
  - Deep Packet Inspection (DPI)
  - Charging rules
- **Interfaces**:
  - Gx avec PGW/SMF (Diameter)
  - Rx avec P-CSCF (pour IMS QoS)

#### **SGWC** (Serving Gateway - Control)
- **Rôle**: Point d'ancrage de mobilité pour le plan utilisateur
- **Fonctions**:
  - Gère les sessions PDN (Packet Data Network)
  - Handover inter-eNodeB
  - Buffering des paquets en downlink
- **Interfaces**:
  - S11 avec MME (GTPv2-C port 2123)
  - S5-C avec SMF/PGW (GTPv2-C)

### **Plan Utilisateur (User Plane)**

#### **SGWU** (Serving Gateway - User)
- **Rôle**: Transfert des paquets de données utilisateur
- **Fonctions**:
  - Tunnel GTP-U avec eNodeB et PGW
  - Comptabilisation du trafic pour facturation
  - Marquage QoS des paquets
- **Interfaces**:
  - S1-U avec eNodeB (GTP-U port 2152)
  - S5-U avec UPF/PGW (GTP-U)

#### **SMF** (Session Management Function)
- **Rôle**: Gestion des sessions PDN/PDU
- **Fonctions**:
  - Allocation d'adresses IP aux UE
  - Configuration des tunnels GTP
  - Sélection d'UPF/PGW
  - Gestion des APN (Access Point Name)
- **Interfaces**:
  - N4/PFCP avec UPF (port 8805)
  - N7 avec PCF (HTTP/2)
  - Gx avec PCRF (Diameter en mode 4G)

#### **UPF** (User Plane Function)
- **Rôle**: Routage des paquets de données utilisateur
- **Fonctions**:
  - Point de sortie vers Internet (Data Network)
  - Filtrage de paquets, QoS enforcement
  - NAT/Firewall pour les UE
  - Traffic shaping
- **Interfaces**:
  - S1-U/N3 avec eNodeB/gNodeB (GTP-U port 2152)
  - N4 avec SMF (PFCP port 8805)
  - N6 vers Internet (SGi interface)
- **Capacités**:
  - IP forwarding (net.ipv4.ip_forward=1)
  - Tunnel GTP encapsulation/decapsulation
  - Support du network slicing (5G)

---

## 🌐 **Composants 5G SA (5G Core - 5GC)**

### **Service-Based Architecture (SBA)**

#### **NRF** (Network Repository Function)
- **Rôle**: Annuaire de services pour architecture SBA
- **Fonctions**:
  - Enregistrement de tous les NF (Network Functions)
  - Service Discovery : permet aux composants de se trouver dynamiquement
  - Health check des NF enregistrés
  - Load balancing info
- **API**: HTTP/2 RESTful (port 7777)
- **Utilisé par**: Tous les NF 5G pour découvrir d'autres services

#### **SCP** (Service Communication Proxy)
- **Rôle**: Proxy de communication entre NF
- **Fonctions**:
  - Load balancing et routage intelligent
  - Découplage des NF pour scalabilité
  - Message filtering et routing
  - Service mesh capabilities
- **Avantages**: 
  - NF n'ont pas besoin de connaître les adresses directes
  - Simplification de la configuration

### **Plan de Contrôle**

#### **AMF** (Access and Mobility Management Function)
- **Rôle**: Équivalent 5G du MME
- **Fonctions**:
  - Gère l'enregistrement (Registration) des UE
  - Authentification 5G AKA
  - Gestion de la mobilité (handover, tracking area)
  - Connection management (CM-IDLE, CM-CONNECTED)
  - Paging
  - Sécurité NAS (Non-Access Stratum)
- **Interfaces**:
  - N2 avec gNodeB (SCTP port 38412)
  - N11 avec SMF (HTTP/2)
  - N8, N12, N14 avec UDM (HTTP/2)

#### **AUSF** (Authentication Server Function)
- **Rôle**: Serveur d'authentification 5G
- **Fonctions**:
  - Implémente 5G AKA (Authentication and Key Agreement)
  - Support EAP-AKA'
  - SUPI concealment (protection de l'identité)
  - Plus sécurisé que 4G (meilleure cryptographie)
- **Interfaces**:
  - Nausf avec AMF
  - Nudm avec UDM

#### **UDM** (Unified Data Management)
- **Rôle**: Gestion unifiée des données d'abonnés
- **Fonctions**:
  - Frontend pour accéder aux données du UDR
  - Génération des vecteurs d'authentification
  - Credential processing
  - Gestion des identités (SUPI, SUCI, GPSI)
  - Subscription management
- **Interfaces**:
  - Nudm avec AMF, SMF, AUSF
  - Nudr vers UDR (backend)

#### **UDR** (Unified Data Repository)
- **Rôle**: Base de données unifiée (équivalent 5G du HSS)
- **Fonctions**:
  - Stocke profils d'abonnés dans MongoDB
  - Données de politique (policies)
  - Application data
  - Structured data for exposure
- **Données stockées**:
  - IMSI/SUPI, clés K/OPc
  - Profils d'abonnement (slices, DNN)
  - Session management data

#### **PCF** (Policy Control Function)
- **Rôle**: Équivalent 5G du PCRF
- **Fonctions**:
  - Politiques QoS (QoS Flows)
  - Contrôle de flux, facturation
  - Network slicing policies (S-NSSAI)
  - Application-based traffic steering
  - UE policy management
- **Interfaces**:
  - N7 avec SMF
  - N5 avec AF (Application Function)
  - Npcf service-based interface

#### **NSSF** (Network Slice Selection Function)
- **Rôle**: Sélection de tranches réseau (Network Slicing)
- **Fonctions**:
  - Sélection de slice (S-NSSAI) pour le UE
  - Permet de dédier des ressources virtuelles par service
  - AMF selection pour le slice approprié
- **Use cases**:
  - eMBB (Enhanced Mobile Broadband)
  - URLLC (Ultra-Reliable Low-Latency)
  - mMTC (Massive Machine Type Communications)

#### **BSF** (Binding Support Function)
- **Rôle**: Gestion des liaisons entre sessions et politiques
- **Fonctions**:
  - Binding entre PCF et sessions PDU
  - Support pour le PCF
  - Session binding discovery

### **Plan de Données**

#### **SMF** (Session Management Function)
- **Rôle**: Gestion des sessions PDU
- **Fonctions**:
  - Allocation d'adresses IP UE
  - Configuration N4 (PFCP) vers UPF
  - Sélection d'UPF et de Data Network Name (DNN)
  - QoS flow management
  - Traffic steering
  - Session establishment/modification/release
- **Mode déploiement**:
  - 4G mode: utilise GTPv2-C
  - 5G mode: utilise HTTP/2 SBA
- **Interfaces**:
  - N4 avec UPF (PFCP)
  - N7 avec PCF
  - N11 avec AMF

#### **UPF** (User Plane Function)
- **Rôle**: Routage et transfert de paquets de données
- **Fonctions**:
  - Ancrage de session PDU
  - Inspection de paquets (DPI - Deep Packet Inspection)
  - QoS enforcement par flow
  - Traffic routing et forwarding
  - Support du network slicing
  - Buffering downlink
  - Multicast/broadcast
- **Interfaces**:
  - N3 avec gNodeB (GTP-U)
  - N4 avec SMF (PFCP port 8805)
  - N6 vers Data Network (Internet)
  - N9 inter-UPF (pour mobilité)
- **Capacités avancées**:
  - Edge computing support
  - Local breakout
  - UL/DL classification

---

## 📞 **Composants IMS (IP Multimedia Subsystem)**

### **PyHSS**
- **Rôle**: HSS IMS pour les services voix/vidéo
- **Fonctions**:
  - Stocke les profils IMS (IMPU, IMPI, iFCs)
  - Authentification Diameter pour CSCF
  - User profile management
  - Service triggers
- **Interfaces**:
  - Cx/Dx avec I-CSCF/S-CSCF (Diameter)
  - Sh avec AS (Application Server)

### **P-CSCF** (Proxy-Call Session Control Function)
- **Rôle**: Premier point de contact SIP pour les UE
- **Fonctions**:
  - Proxy SIP pour enregistrement et appels
  - Compression SIP (SigComp)
  - IPsec security association avec UE
  - Emergency call handling
  - Interface avec PGW/UPF pour QoS IMS
- **Protocole**: SIP (Session Initiation Protocol)
- **Ports**: 5060 (UDP/TCP), 5061 (TLS)

### **I-CSCF** (Interrogating-CSCF)
- **Rôle**: Point d'entrée dans le domaine IMS
- **Fonctions**:
  - Interroge HSS pour localiser le S-CSCF
  - Routage des requêtes SIP entrantes
  - Topology hiding
  - THIG (Topology Hiding Inter-network Gateway)
- **Interfaces**:
  - Cx avec HSS (Diameter)
  - SIP avec P-CSCF/S-CSCF

### **S-CSCF** (Serving-CSCF)
- **Rôle**: Serveur SIP central pour enregistrement et sessions
- **Fonctions**:
  - Contrôle des appels, logique de service
  - Session control
  - Application de services (call forwarding, voicemail, conference)
  - Interaction avec Application Servers
  - Charging (CTF - Charging Trigger Function)
- **Interfaces**:
  - Cx avec HSS (Diameter)
  - ISC avec AS (SIP)
  - SIP avec P-CSCF/I-CSCF

### **RTPEngine**
- **Rôle**: Relais média RTP pour les appels voix/vidéo
- **Fonctions**:
  - Media relay/proxy RTP/RTCP
  - Transcodage audio/vidéo
  - NAT traversal (ICE, STUN, TURN)
  - DTLS-SRTP support
  - Recording
  - Gestion des flux média (audio/vidéo)
- **Codecs supportés**: AMR, AMR-WB, EVS, G.711, Opus, H.264, VP8

### **Osmo-HLR + Osmo-MSC**
- **Osmo-HLR** (Home Location Register):
  - Stockage IMSI, MSISDN pour SMS
  - Authentication vectors pour 2G/3G
  - Subscriber location tracking
- **Osmo-MSC** (Mobile Switching Center):
  - Gestion des services CS (Circuit Switched)
  - Support SMS over SGs interface (LTE)
  - Call control pour 2G/3G
  - USSD (Unstructured Supplementary Service Data)
- **Interface**: SGs entre MSC et MME

### **SMSC** (Short Message Service Center)
- **Rôle**: Centre de messages pour SMS
- **Fonctions**:
  - Stockage et routage des SMS
  - Store-and-forward messaging
  - SMS delivery retry
  - Message concatenation
- **Protocoles**: 
  - SMPP (Short Message Peer-to-Peer)
  - MAP (Mobile Application Part)

### **IBCF** (Interconnection Border Control Function)
- **Rôle**: Interconnexion avec d'autres réseaux IMS
- **Fonctions**:
  - SIP trunk avec opérateurs externes
  - Security (SIP firewall)
  - NAT/Topology hiding
  - Protocol conversion
- **Basé sur**: Asterisk

### **OCS** (Online Charging System)
- **Rôle**: Facturation en temps réel
- **Fonctions**:
  - Credit control en temps réel
  - Quota management
  - Balance checking
  - Prepaid/postpaid charging
- **Protocole**: Diameter Ro/Gy interface

---

## 🎯 **Composants Radio Access Network (RAN)**

### **srsRAN_4G**
- **Composants**: eNodeB (station de base 4G LTE)
- **Fonctions**:
  - Gestion de la couche radio LTE
  - Scheduler (PDSCH, PUSCH)
  - HARQ, ARQ, RLC, PDCP
  - Handover inter-cell
- **Hardware supporté**:
  - USRP B210, B200, N310
  - LimeSDR, LimeSDR-Mini
  - BladeRF
- **Mode simulation**: ZMQ (sans radio physique)
- **Bandes**: Band 3 (1800MHz), Band 7 (2600MHz), etc.

### **srsRAN_Project (srsRAN_5G)**
- **Composants**: gNodeB (station de base 5G NR)
- **Fonctions**:
  - Support SA (Standalone) et NSA (Non-Standalone)
  - Interface N2/N3 avec 5GC
  - 5G NR PHY layer
  - Beam management
  - Massive MIMO support
- **Bandes**: FR1 (sub-6GHz) - Band 41, Band 78
- **Configuration**: TDD et FDD

### **UERANSIM**
- **Rôle**: Simulateur 5G open-source
- **Composants**:
  - gNodeB virtuel
  - UE (User Equipment) virtuel
- **Avantages**:
  - Pas besoin de hardware radio
  - Parfait pour tests et développement
  - Multi-UE simulation
  - Support des procédures 5G complètes
- **Use cases**:
  - Testing 5G core
  - Load testing
  - Protocol validation

### **OpenAirInterface (OAI)**
- **Rôle**: Alternative à srsRAN pour eNB/gNB
- **Composants**:
  - OAI eNB (4G)
  - OAI gNB (5G)
  - OAI UE
- **Support**: OTA avec SDR (USRP)
- **Features**:
  - Full protocol stack
  - L1/L2/L3 implementation
  - Research-oriented

---

## 🔐 **Composants VoWiFi (Voice over WiFi)**

### **ePDG** (Evolved Packet Data Gateway)
- **Rôle**: Passerelle pour accès WiFi au réseau mobile
- **Fonctions**:
  - Tunnel IPsec entre UE (WiFi) et réseau core
  - Interface SWu avec UE (IKEv2/IPsec)
  - Interface S2b avec PGW/UPF
  - Authentication via AAA server
- **Protocoles**: 
  - IKEv2 (Internet Key Exchange v2)
  - EAP-AKA' (authentication)
  - IPsec ESP

### **StrongSwan-ePDG**
- **Rôle**: Serveur IKEv2 pour IPsec
- **Fonctions**:
  - Authentification EAP-AKA'
  - IPsec tunnel establishment
  - Certificate management
  - NAT traversal
- **Intégration**: Osmo-ePDG + StrongSwan

### **SWu Client**
- **Rôle**: Client IKEv2 pour tests VoWiFi
- **Fonctions**:
  - Simuler un UE VoWiFi
  - Établir tunnel IPsec vers ePDG
  - Testing de la chaîne VoWiFi complète

---

## 🔄 **Flux de Communication**

### **4G - Attachement UE (Attach Procedure)**

```
1. UE → eNodeB: RRC Connection Request
2. eNodeB → MME: S1-AP Initial UE Message
3. MME → HSS: Authentication Request (Diameter S6a)
4. HSS → MME: Authentication Vectors
5. MME → UE: Authentication Request (NAS)
6. UE → MME: Authentication Response
7. MME → HSS: Update Location Request
8. HSS → MME: Insert Subscriber Data
9. MME → SGWC: Create Session Request (GTPv2-C)
10. SGWC → SMF: Create Session Request
11. SMF → UPF: PFCP Session Establishment (N4)
12. UPF → SMF: PFCP Session Establishment Response
13. SMF → SGWC: Create Session Response
14. SGWC → MME: Create Session Response
15. MME → eNodeB: S1-AP Initial Context Setup
16. eNodeB → UE: RRC Connection Reconfiguration
17. UE ← → Internet (via eNodeB → SGWU → UPF)
```

**Résultat**: UE obtient une adresse IP et peut accéder à Internet

### **5G SA - Enregistrement UE (Registration)**

```
1. UE → gNodeB: RRC Setup Request
2. gNodeB → AMF: N2 Initial UE Message (NGAP)
3. AMF → AUSF: Authentication Request
4. AUSF → UDM: Get Authentication Data
5. UDM → UDR: Query Subscriber Data
6. UDR → UDM: Subscriber Data (K, OPc, SUPI)
7. UDM → AUSF: Authentication Vectors
8. AUSF → AMF: Authentication Vector
9. AMF → UE: Authentication Request (5G AKA)
10. UE → AMF: Authentication Response
11. AMF → UDM: SDM Subscribe (get subscription data)
12. UDM → UDR: Query Subscription
13. UDR → UDM: Subscription Data (slices, DNN)
14. UDM → AMF: Subscription Data
15. AMF → UE: Registration Accept
16. UE → AMF: Registration Complete

Pour établir une session PDU:
17. UE → AMF: PDU Session Establishment Request
18. AMF → SMF: Create SM Context
19. SMF → UPF: PFCP Session Establishment (N4)
20. UPF → SMF: Response
21. SMF → AMF: SM Context Created
22. AMF → gNodeB: PDU Session Resource Setup (N2)
23. gNodeB → UE: RRC Reconfiguration (bearer setup)
24. UE ← → Internet (via gNodeB → UPF)
```

**Résultat**: UE enregistré sur réseau 5G avec session PDU active

### **VoLTE - Établissement d'appel vocal**

```
Signaling (SIP):
1. UE → P-CSCF: REGISTER (enregistrement IMS)
2. P-CSCF → I-CSCF: REGISTER
3. I-CSCF → HSS: User Authorization Request (Diameter Cx)
4. HSS → I-CSCF: S-CSCF address
5. I-CSCF → S-CSCF: REGISTER
6. S-CSCF → HSS: Server Assignment Request
7. HSS → S-CSCF: User Profile (iFCs, services)
8. S-CSCF → UE: 200 OK (registration successful)

Lors d'un appel:
9. UE-A → P-CSCF: INVITE (appeler UE-B)
10. P-CSCF → S-CSCF: INVITE
11. S-CSCF → S-CSCF (autre domaine): INVITE
12. S-CSCF → P-CSCF → UE-B: INVITE
13. UE-B → P-CSCF → S-CSCF → UE-A: 180 Ringing
14. UE-B → P-CSCF → S-CSCF → UE-A: 200 OK (décroché)
15. UE-A → S-CSCF → UE-B: ACK

Media (RTP):
16. UE-A ← → RTPEngine ← → UE-B (flux audio AMR-WB)

QoS:
17. P-CSCF → PCRF: AA-Request (Diameter Rx)
18. PCRF → PGW/SMF: Policy update (Diameter Gx)
19. PGW/SMF → SGWU/UPF: Create dedicated bearer (GTP/PFCP)
20. Réseau établit QCI 1 bearer (VoIP prioritaire)
```

**Résultat**: Appel vocal HD établi avec QoS garantie

### **VoWiFi - Connexion via WiFi**

```
1. UE (WiFi) → ePDG: IKE_SA_INIT (IKEv2)
2. ePDG → UE: IKE_SA_INIT Response
3. UE → ePDG: IKE_AUTH (EAP-AKA' Identity)
4. ePDG → AAA Server: RADIUS Access-Request
5. AAA → HSS: Diameter Authentication Request
6. HSS → AAA: Authentication Vectors
7. AAA → ePDG: RADIUS Challenge (AKA challenge)
8. ePDG → UE: IKE_AUTH (EAP-Request/AKA-Challenge)
9. UE → ePDG: IKE_AUTH (EAP-Response/AKA-Challenge)
10. ePDG → AAA: RADIUS Access-Request (AKA response)
11. AAA → ePDG: RADIUS Access-Accept
12. ePDG → UE: IKE_AUTH (EAP-Success)
13. IPsec tunnel établi (ESP)
14. ePDG → PGW: Create Session Request (S2b GTPv2-C)
15. PGW → ePDG: Create Session Response
16. UE ← → Internet (via WiFi → ePDG → PGW → UPF)

Ensuite, procédure IMS normale pour VoLTE
```

**Résultat**: UE sur WiFi peut passer des appels VoLTE

---

## 📊 **Fichiers de Déploiement Disponibles**

| Fichier | Description | Composants clés |
|---------|-------------|-----------------|
| `4g-volte-deploy.yaml` | 4G EPC + VoLTE (Kamailio IMS) | MME, HSS, SGWC/U, SMF, UPF, P/I/S-CSCF, PyHSS |
| `sa-deploy.yaml` | 5G SA Core uniquement | AMF, SMF, UPF, AUSF, UDM, UDR, NRF, SCP, PCF, NSSF, BSF |
| `sa-vonr-deploy.yaml` | 5G SA + VoNR (Voice over NR) | 5GC + IMS complet (VoNR) |
| `sa-vonr-ibcf-deploy.yaml` | 5G SA + VoNR + IBCF | 5GC + IMS + Interconnexion externe |
| `4g-volte-vowifi-deploy.yaml` | 4G + VoLTE + VoWiFi (ePDG) | EPC + IMS + ePDG + StrongSwan |
| `4g-volte-ocs-deploy.yaml` | 4G + VoLTE + OCS (charging) | EPC + IMS + Sigscale OCS |
| `4g-external-ims-deploy.yaml` | 4G EPC avec IMS externe | EPC seulement, IMS ailleurs |
| `4g-volte-opensips-ims-deploy.yaml` | 4G + VoLTE (OpenSIPS IMS) | EPC + OpenSIPS P/I/S-CSCF |
| `sa-vonr-opensips-ims-deploy.yaml` | 5G SA + VoNR (OpenSIPS) | 5GC + OpenSIPS IMS |
| `deploy-all.yaml` | Déploiement complet 4G+5G | Tous les composants |
| `srsenb.yaml` | srsRAN eNodeB (4G OTA) | eNodeB avec SDR hardware |
| `srsenb_zmq.yaml` | srsRAN eNodeB simulation | eNodeB + UE simulation ZMQ |
| `srsgnb.yaml` | srsRAN gNodeB (5G OTA) | gNodeB avec SDR hardware |
| `srsgnb_zmq.yaml` | srsRAN gNodeB simulation | gNodeB + UE simulation ZMQ |
| `nr-gnb.yaml` | UERANSIM gNodeB | gNodeB virtuel |
| `nr-ue.yaml` | UERANSIM UE | UE virtuel 5G |
| `oaienb.yaml` | OAI eNodeB (4G) | OpenAirInterface eNB |
| `oaignb.yaml` | OAI gNodeB (5G) | OpenAirInterface gNB |

---

## 🎓 **Protocoles et Interfaces Clés**

### **Protocoles de Transport**

| Protocole | Port | Description | Utilisation |
|-----------|------|-------------|-------------|
| **GTP-C** | 2123/UDP | GPRS Tunneling Protocol - Control | Signaling entre MME-SGW-PGW |
| **GTP-U** | 2152/UDP | GPRS Tunneling Protocol - User | Transport données utilisateur eNB-SGW-PGW-UPF |
| **PFCP** | 8805/UDP | Packet Forwarding Control Protocol | Control SMF → UPF (5G) |
| **Diameter** | 3868/TCP,SCTP | Authentication, Authorization, Accounting | HSS, PCRF, IMS (S6a, Gx, Cx, Rx) |
| **SCTP** | 36412, 38412 | Stream Control Transmission Protocol | Signaling eNB/gNB (S1-MME, N2) |
| **HTTP/2** | 7777/TCP | Service-Based Interface | Communication entre NF 5G (SBA) |
| **SIP** | 5060/UDP,TCP | Session Initiation Protocol | Signaling VoIP IMS |
| **SIP-TLS** | 5061/TCP | SIP over TLS | SIP sécurisé |
| **RTP** | Dynamic | Real-time Transport Protocol | Transport média voix/vidéo |
| **RTCP** | Dynamic | RTP Control Protocol | Contrôle qualité RTP |

### **Interfaces 4G (LTE)**

| Interface | Entre | Protocole | Description |
|-----------|-------|-----------|-------------|
| **S1-MME** | eNodeB ↔ MME | SCTP/S1AP | Signaling control plane |
| **S1-U** | eNodeB ↔ SGWU | GTP-U | User plane data |
| **S6a** | MME ↔ HSS | Diameter | Authentication, subscription |
| **S11** | MME ↔ SGWC | GTPv2-C | Session management |
| **S5/S8** | SGWU ↔ PGW | GTP-U, GTPv2-C | Inter-gateway |
| **SGi** | PGW ↔ Internet | IP | Data network interface |
| **Gx** | PCRF ↔ PGW | Diameter | Policy and charging |
| **Rx** | PCRF ↔ P-CSCF | Diameter | IMS QoS policy |
| **SGs** | MME ↔ MSC | SCTP | SMS, CSFB (Circuit Switched Fallback) |

### **Interfaces 5G (NR)**

| Interface | Entre | Protocole | Description |
|-----------|-------|-----------|-------------|
| **N1** | UE ↔ AMF | NAS | Non-Access Stratum signaling |
| **N2** | gNodeB ↔ AMF | NGAP/SCTP | Control plane signaling |
| **N3** | gNodeB ↔ UPF | GTP-U | User plane data |
| **N4** | SMF ↔ UPF | PFCP | Session management |
| **N6** | UPF ↔ DN | IP | Data Network (Internet) |
| **N8** | AMF ↔ UDM | HTTP/2 | Subscription data |
| **N9** | UPF ↔ UPF | GTP-U | Inter-UPF (mobility) |
| **N11** | AMF ↔ SMF | HTTP/2 | Session management |
| **N7** | SMF ↔ PCF | HTTP/2 | Policy control |
| **Nausf** | AMF ↔ AUSF | HTTP/2 | Authentication |
| **Nnrf** | Any NF ↔ NRF | HTTP/2 | Service discovery |

### **Interfaces IMS**

| Interface | Entre | Protocole | Description |
|-----------|-------|-----------|-------------|
| **Gm** | UE ↔ P-CSCF | SIP | UE to IMS entry |
| **Mw** | P-CSCF ↔ I/S-CSCF | SIP | Inter-CSCF |
| **Cx/Dx** | I/S-CSCF ↔ HSS | Diameter | Profile, routing info |
| **ISC** | S-CSCF ↔ AS | SIP | Application Server |
| **Rx** | P-CSCF ↔ PCRF | Diameter | QoS authorization |
| **Sh** | AS ↔ HSS | Diameter | User data access |
| **Mr** | CSCF ↔ MGCF | SIP | Media Gateway Control |
| **SWu** | UE ↔ ePDG | IKEv2/IPsec | VoWiFi authentication |
| **S2b** | ePDG ↔ PGW | GTPv2-C | VoWiFi data path |

---

## 🔧 **Configuration et Provisioning**

### **Variables d'environnement clés (.env)**

```bash
# Réseau mobile
MCC=001                          # Mobile Country Code
MNC=01                           # Mobile Network Code
DOCKER_HOST_IP=192.168.0.100     # IP de l'hôte Docker

# Plages IP UE
UE_IPV4_INTERNET=10.45.0.0/16    # APN Internet
UE_IPV4_IMS=10.46.0.0/16         # APN IMS (VoLTE)

# Composants 4G
MME_IP=192.168.70.131
HSS_IP=192.168.70.132
SGWC_IP=192.168.70.133
SGWU_IP=192.168.70.134
SMF_IP=192.168.70.135
UPF_IP=192.168.70.136
PCRF_IP=192.168.70.137

# Composants 5G
AMF_IP=192.168.70.138
AUSF_IP=192.168.70.139
NRF_IP=192.168.70.140
SCP_IP=192.168.70.141
UDM_IP=192.168.70.142
UDR_IP=192.168.70.143
PCF_IP=192.168.70.144
NSSF_IP=192.168.70.145
BSF_IP=192.168.70.146

# IMS
PCSCF_IP=192.168.70.201
ICSCF_IP=192.168.70.202
SCSCF_IP=192.168.70.203
PYHSS_IP=192.168.70.204
RTPENGINE_IP=192.168.70.205
```

### **Provisioning d'un abonné (via WebUI)**

```
URL: http://localhost:9999
Default credentials: admin / 1423

Données SIM:
- IMSI: 001010123456789
- K (clé): 465B5CE8B199B49FAA5F0A2EE238A6BC
- OPc: E8ED289DEBA952E4283B54E88E6183CA
- APN: internet, ims
- QCI: 9 (Internet), 5 (IMS)
```

### **Provisioning d'un abonné IMS (PyHSS)**

```bash
# Ajouter subscriber IMS
docker exec -it pyhss /bin/bash
cd /pyhss
python3 hss.py --imsi 001010123456789 \
               --msisdn 9076543210 \
               --impi 001010123456789@ims.mnc001.mcc001.3gppnetwork.org \
               --impu sip:9076543210@ims.mnc001.mcc001.3gppnetwork.org
```

---

## 🧪 **Cas d'usage et Tests**

### **Test 1: Attachement 4G basique**
- Déployer: `4g-volte-deploy.yaml`
- UE: srsUE simulation (ZMQ)
- Vérifier: Obtention IP, ping 8.8.8.8

### **Test 2: Enregistrement 5G SA**
- Déployer: `sa-deploy.yaml`
- UE: UERANSIM
- Vérifier: Registration, PDU session, internet access

### **Test 3: Appel VoLTE**
- Déployer: `4g-volte-deploy.yaml`
- 2 UE avec profils IMS
- Vérifier: SIP REGISTER, INVITE, RTP media flow

### **Test 4: VoWiFi**
- Déployer: `4g-volte-vowifi-deploy.yaml`
- UE COTS (téléphone Android/iOS)
- Configurer DNS WiFi vers serveur DNS du projet
- Vérifier: IPsec tunnel, IMS registration, appel

### **Test 5: Network Slicing (5G)**
- Déployer: `sa-deploy.yaml`
- Configurer S-NSSAI (ex: SST=1 eMBB, SST=2 URLLC)
- Provisionner UE avec différents slices
- Vérifier: UE connecté au bon slice

---

## 📈 **Monitoring et Logs**

### **Logs des composants**
```bash
# Voir logs d'un composant
docker logs -f amf
docker logs -f mme
docker logs -f smf

# Logs Open5GS (dans conteneur)
docker exec -it amf tail -f /open5gs/install/var/log/open5gs/amf.log
```

### **Grafana Dashboards**
```
URL: http://localhost:3000
- Core Network KPIs
- Bearer statistics
- UE attachments/registrations
- Throughput graphs
```

### **Captures réseau**
```bash
# Capturer S1-MME
docker exec -it mme tcpdump -i eth0 -w /tmp/s1mme.pcap sctp port 36412

# Capturer GTP-U
docker exec -it upf tcpdump -i eth0 -w /tmp/gtpu.pcap udp port 2152

# Capturer SIP
docker exec -it pcscf tcpdump -i eth0 -w /tmp/sip.pcap port 5060
```

---

## 🚀 **Déploiement Rapide**

### **4G avec VoLTE**
```bash
cd docker_open5gs
docker compose -f 4g-volte-deploy.yaml up -d
```

### **5G SA**
```bash
docker compose -f sa-deploy.yaml up -d
```

### **5G avec VoNR**
```bash
docker compose -f sa-vonr-deploy.yaml up -d
```

### **Simulation complète (sans hardware)**
```bash
# 5G Core + gNB + UE simulés
docker compose -f sa-deploy.yaml up -d
docker compose -f nr-gnb.yaml up -d
docker compose -f nr-ue.yaml up -d
```

---

## 📚 **Références**

- **3GPP Specs**: 
  - TS 23.401 (EPC), TS 23.501 (5GC)
  - TS 23.228 (IMS), TS 24.229 (IMS protocols)
- **Open5GS**: https://open5gs.org
- **srsRAN**: https://www.srslte.com
- **UERANSIM**: https://github.com/aligungr/UERANSIM
- **Kamailio**: https://www.kamailio.org

---

## 🆘 **Troubleshooting Commun**

### **UE ne s'attache pas (4G)**
- Vérifier MME logs: `docker logs mme`
- Vérifier HSS: subscriber provisionné ?
- Vérifier S1-MME: eNodeB connecté au MME ?
- Vérifier MCC/MNC: correspondent entre UE, eNB, core ?

### **UE ne s'enregistre pas (5G)**
- Vérifier AMF logs: `docker logs amf`
- Vérifier NRF: tous les NF enregistrés ?
- Vérifier UDM/UDR: subscriber data présente ?
- Vérifier NGAP: gNB → AMF connection

### **Pas d'Internet**
- Vérifier UPF: `docker exec -it upf ip route`
- Vérifier NAT: `iptables -t nat -L`
- Vérifier DNS UE: 8.8.8.8 configuré ?
- Ping depuis UPF vers internet ?

### **VoLTE échoue**
- P-CSCF accessible depuis UE ?
- DNS résout domaine IMS ?
- PyHSS: IMPU/IMPI provisionnés ?
- S-CSCF: subscriber registered ? (check logs)
- Dedicated bearer créé (QCI 5) ?

---

**Dernière mise à jour**: Décembre 2025
**Auteur**: Documentation générée pour projet Open5GS Docker
