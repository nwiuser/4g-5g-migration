FROM ubuntu:bionic as base

# Install dependencies
# We need uhd so enb and ue are built
# Use curl and unzip to get a specific commit state from github
# Also install ping to test connections
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
     cmake \
     git \
     libuhd-dev \
     uhd-host \
     libboost-program-options-dev \
     libvolk1-dev \
     libfftw3-dev \
     libmbedtls-dev \
     libsctp-dev \
     libconfig++-dev \
     curl \
     ca-certificates \
     iputils-ping \
     iproute2 \
     iptables \
     libzmq3-dev \
 && rm -rf /var/lib/apt/lists/*

# Install docker-compose v2 (binaire officiel)
RUN mkdir -p /usr/local/lib/docker/cli-plugins \
 && curl -SL https://github.com/docker/compose/releases/download/v2.29.2/docker-compose-linux-x86_64 \
    -o /usr/local/lib/docker/cli-plugins/docker-compose \
 && chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    
WORKDIR /srsran

# Pinned git commit used for this example
ARG COMMIT=ce8a3cae171f08c9bce83ae3611e56f2d168d073

# Clone and checkout commit
RUN git clone https://github.com/srsran/srsRAN srsRAN-${COMMIT}

WORKDIR /srsran/srsRAN-${COMMIT}

RUN git checkout ${COMMIT}

WORKDIR /srsran/srsRAN-build

# build
RUN cmake ../srsRAN-${COMMIT} \
 && make \
 && make test

# install
RUN make install

# Update dynamic linker
RUN ldconfig

WORKDIR /srsran

# Copy all .example files and remove that suffix
RUN ls srsRAN-${COMMIT}/*/*.example
RUN cp srsRAN-${COMMIT}/*/*.example ./ \
 && bash -c 'for file in *.example; do mv "$file" "${file%.example}"; done'

# Run commands with line buffered standard output
# (-> get log messages in real time)
ENTRYPOINT [ "stdbuf", "-o", "L" ]
