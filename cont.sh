# Build docker image for open5gs EPC/5GC components       <----- checked  
git clone https://github.com/herlesupreeth/docker_open5gs
cd docker_open5gs/base
docker build --no-cache --force-rm -t docker_open5gs .

# Build docker image for kamailio IMS components           <----- checked  
cd ../ims_base
docker build --no-cache --force-rm -t docker_kamailio .

# Build docker image for srsRAN_4G eNB + srsUE (4G+5G)     <----- checked
cd ../srslte
docker build --no-cache --force-rm -t docker_srslte .

# Build docker image for srsRAN_Project gNB                <----- checked
cd ../srsran
docker build --force-rm -t docker_srsran .

# Build docker image for UERANSIM (gNB + UE)               <----- checked
cd ../ueransim
docker build --no-cache --force-rm -t docker_ueransim .

# Build docker image for EUPF                              <----- checked
cd ../eupf
docker build --no-cache --force-rm -t docker_eupf .

# Build docker image for OpenSIPS IMS                      <----- checked   
cd ../opensips_ims_base
docker build --no-cache --force-rm -t docker_opensips .

# Build docker image for Osmo-epdg + Strongswan-epdg       <----- checked
cd ../osmoepdg
docker build --no-cache --force-rm -t docker_osmoepdg .

# Build docker image for SWu-IKEv2                         <----- checked
cd ../swu_client
docker build --no-cache --force-rm -t docker_swu_client .