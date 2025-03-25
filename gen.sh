#!/bin/bash


# 1.Generating OpenVPN-client certificates and keys
# Copy
sudo cp /tmp/{server.crt,ca.crt} /etc/openvpn/server

# Change directory
cd ~/easy-rsa
# 
read -p "Enter the name of the OpenVPN-client: " name
./easyrsa gen-req $name nopass
# Copy
cp /home/damir/easy-rsa/pki/private/$name.key ~/client-configs/keys/
# 
read -p "Enter the name of the OpenVPN-client and the IP address of the CA: " name ip
scp /home/damir/easy-rsa/pki/reqs/$name.req $ip:/tmp