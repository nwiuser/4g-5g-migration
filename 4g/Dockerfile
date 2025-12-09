# =============================================================================
# Dockerfiles pour srsRAN 4G
# Utilisation des images pré-construites depuis Docker Hub
# =============================================================================

# -----------------------------------------------------------------------------
# Image de base pour srsepc (EPC - Evolved Packet Core)
# -----------------------------------------------------------------------------
FROM nouisser1/srsepc-4g:latest AS srsepc
RUN apt-get update && apt-get install -y libsctp1 lksctp-tools
ENTRYPOINT [ "stdbuf", "-o", "L" ]

# -----------------------------------------------------------------------------
# Image de base pour srsenb (eNodeB - Station de base)
# -----------------------------------------------------------------------------
FROM nouisser1/srsenb-4g:latest AS srsenb

# Entrypoint avec buffer de ligne pour logs en temps réel
ENTRYPOINT [ "stdbuf", "-o", "L" ]

# -----------------------------------------------------------------------------
# Image de base pour srsue (User Equipment - Terminal utilisateur)
# -----------------------------------------------------------------------------
FROM nouisser1/srsue-4g:latest AS srsue

# Entrypoint avec buffer de ligne pour logs en temps réel
ENTRYPOINT [ "stdbuf", "-o", "L" ]
