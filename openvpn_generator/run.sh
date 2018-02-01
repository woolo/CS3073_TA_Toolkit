#!/bin/bash

set -e
#set -x

while IFS='' read -r line || [[ -n "$line" ]]; do
    name=$(echo "$line" |  sed 's/@utulsa.edu//')
    (echo "1"; echo "$name") | sudo openvpn-install.sh    
    done < "$1"




