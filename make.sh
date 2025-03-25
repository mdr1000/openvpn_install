#!/bin/bash


read -p "Enter the name of the OpenVPN-client: " name 
cp /tmp/$name.crt ~/client-configs/keys/
#
cp ~/easy-rsa/ta.key ~/client-configs/keys/
sudo cp /etc/openvpn/server/ca.crt ~/client-configs/keys/
sudo chown damir:damir ~/client-configs/keys/*
#
cd ~/client-configs
echo "To create a configuration for user credentials, run the script."
read -p "Enter the name of the OpenVPN-client: " name 
./make_config.sh $name
#
ls ~/client-configs/files