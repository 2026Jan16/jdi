#! /bin/bash

. /etc/os-release
if [[ ! " jammy " =~ " ${VERSION_CODENAME} " ]]; then
    echo "Ubuntu version ${VERSION_CODENAME} not supported"
else
    wget https://repositories.intel.com/gpu/ubuntu/dists/jammy/lts/2350/intel-gpu-ubuntu-${VERSION_CODENAME}-2350.run
    chmod +x intel-gpu-ubuntu-${VERSION_CODENAME}-2350.run
    sudo ./intel-gpu-ubuntu-${VERSION_CODENAME}-2350.run
fi

