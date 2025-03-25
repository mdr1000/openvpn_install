#!/bin/bash


# 1.Update the machine, install OpenVPN and Easy-RSA
echo "NOTICE
------
Now this script install OpenVPN and Easy-RSA on your machine."

read -rp "Do you want to continue? [y/n]: " -e -i y CONTINUE

if [[ $CONTINUE == "n" ]]; then
        exit 1
fi

if [[ $CONTINUE == "y" ]]; then
      sudo apt-get update
        sudo apt-get -y install openvpn easy-rsa;
      if [ $? -eq 0 ]; then
        echo "Successful installation. Proceed to configuring the Openvpn-server"
      else
        exit 1
      fi
fi

# 2.Creating work directory for Easy-RSA
mkdir -p /home/damir/easy-rsa

# 3.Creating a symlink
ln -s /usr/share/easy-rsa/* /home/damir/easy-rsa
chmod 700 /home/damir/easy-rsa

# 4.Movie in easy-rsa directory and creating PKI for OpenVPN
cd /home/damir/easy-rsa
cat <<EOF> /home/damir/easy-rsa/vars
set_var EASYRSA_REQ_COUNTRY    "RUS"
set_var EASYRSA_REQ_PROVINCE   "Bashkortostan"
set_var EASYRSA_REQ_CITY       "Ufa City"
set_var EASYRSA_REQ_ORG        "Company"
set_var EASYRSA_REQ_EMAIL      "admin@company.ru"
set_var EASYRSA_REQ_OU         "LLC"
set_var EASYRSA_ALGO           "ec"
set_var EASYRSA_DIGEST         "sha512"
EOF
./easyrsa init-pki

# 5.Creating a certificate request and a private key for the OpenVPN-server
cd /home/damir/easy-rsa
./easyrsa gen-req server nopass

# 6.Copy this in Openvpn server directory
sudo cp /home/damir/easy-rsa/pki/private/server.key /etc/openvpn/server/

# 7.Send certificate request to CA
echo "NOTICE
------
Now we will transfer the certificate request from the OpenVPN-server to the CA-server."
read -p "Write the IP address of the CA server: " ip1
scp /home/damir/easy-rsa/pki/reqs/server.req $ip1:/tmp

# 8.Creating a tls-crypt key for better security and copy in OpenVPN-server directory
cd /home/damir/easy-rsa
/usr/sbin/openvpn --genkey --secret ta.key
sudo cp ta.key /etc/openvpn/server

# 9.Make clients directory
mkdir /home/damir/client-configs
mkdir /home/damir/client-configs/keys
chmod -R 700 /home/damir/client-configs

# 10.Copy server.conf and configuring the OpenVPN service
sudo cp /usr/share/doc/openvpn/examples/sample-config-files/server.conf /etc/openvpn/server/

# 11.Adding changes to the configuration file
sudo sed -i '93a\dh none' /etc/openvpn/server/server.conf
sudo sed -i '100a\cipher AES-256-GCM' /etc/openvpn/server/server.conf
sudo sed -i '101a\auth SHA256' /etc/openvpn/server/server.conf
sudo sed -i 's/;push "redirect-gateway def1 bypass-dhcp"/push "redirect-gateway def1 bypass-dhcp"/g' /etc/openvpn/server/server.conf
sudo sed -i 's/;tls-auth ta.key 0 # This file is secret/tls-crypt ta.key # This file is secret/g' /etc/openvpn/server/server.conf
sudo sed -i 's/;user openvpn/user nobody/g' /etc/openvpn/server/server.conf
sudo sed -i 's/;group openvpn/group nogroup/g' /etc/openvpn/server/server.conf

# 12.OpenVPN Server Network Configurations
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sudo sysctl -p

# 13.Configuring the ufw firewall
#sudo sed -i "s/\# Don't delete these required/OPENVPN config\n\n\# Don't delete these required/g" /etc/ufw/before.rules
#sudo sed -i "s/OPENVPN config/\# START OPENVPN RULES\n\# NAT table rules\n\*nat\n:POSTROUTING ACCEPT [0:0]\nOPENVPN config/g" /etc/ufw/before.rules
#sudo sed -i "s/OPENVPN config/# Allow traffic from OpenVPN client to "`ip route list default | awk '{print $5}'`" (change to the interface you discovered\!)\nOPENVPN config/g" /etc/ufw/before.rules
#sudo sed -i "s/OPENVPN config/\-A POSTROUTING \-s 10.8.0.0\/8 \-o "`ip route list default | awk '{print $5}'`" \-j MASQUERADE\nCOMMIT\n# END OPENVPN RULES/g" /etc/ufw/before.rules
#sudo sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/g' /etc/default/ufw
#sudo ufw allow 1194/udp
#sudo ufw allow OpenSSH
#sudo ufw disable
#sudo ufw enable
# 
#sudo systemctl -f enable openvpn-server@server.service
#sudo systemctl start openvpn-server@server.service
#sudo systemctl status openvpn-server@server.service

# 14.Configuring the iptables firewall
ip a
echo "NOTICE
------
Now we will start configuring the iptables firewall for the OpenVPN server."
read -p "Specify eth, proto, and port in the sequence provided: " eth proto port

# OpenVPN
sudo iptables -A INPUT -i $eth -m state --state NEW -p $proto --dport $port -j ACCEPT
# Allow TUN interface connections to OpenVPN server
sudo iptables -A INPUT -i tun+ -j ACCEPT
# Allow TUN interface connections to be forwarded through other interfaces
sudo iptables -A FORWARD -i tun+ -j ACCEPT
echo "NOTICE
------"
read -p "Specify eth: " eth
sudo iptables -A FORWARD -i tun+ -o $eth -m state --state RELATED,ESTABLISHED -j ACCEPT
echo "NOTICE
------"
read -p "Specify eth: " eth
sudo iptables -A FORWARD -i $eth -o tun+ -m state --state RELATED,ESTABLISHED -j ACCEPT
# NAT the VPN client traffic to the internet
echo "NOTICE
------"
read -p "Specify eth: " eth
sudo iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $eth -j MASQUERADE


sudo systemctl -f enable openvpn-server@server.service
sudo systemctl start openvpn-server@server.service
sudo systemctl status openvpn-server@server.service


# 15.Creating a client configuration infrastructure
mkdir /home/damir/client-configs/files
sudo cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf /home/damir/client-configs/base.conf
echo "NOTICE
------
To create a client configuration, you must specify the IP address of the OpenVPN-server."
read -rp "Write the IP address of the OpenVPN-server: " ip2
sed -i "s/remote my-server-1 1194/remote $ip2 1194/g" /home/damir/client-configs/base.conf
sed -i 's/;user openvpn/user nobody/g' /home/damir/client-configs/base.conf
sed -i 's/;group openvpn/group nogroup/g' /home/damir/client-configs/base.conf
sed -i 's/ca ca.crt/;ca ca.crt/g' /home/damir/client-configs/base.conf
sed -i 's/cert client.crt/;cert client.crt/g' /home/damir/client-configs/base.conf
sed -i 's/key client.key/;key client.key/g' /home/damir/client-configs/base.conf
sed -i 's/;tls-auth ta.key 1/;tls-crypt ta.key 1/g' /home/damir/client-configs/base.conf
echo "cipher AES-256-GCM" >> /home/damir/client-configs/base.conf
echo "auth SHA256" >> /home/damir/client-configs/base.conf
#
echo "key-direction 1" >> /home/damir/client-configs/base.conf
#
echo "redirect-gateway def1" >> /home/damir/client-configs/base.conf
# Также добавьте строки, которые нужно будет раскомментировать только для Linux клиентов:
echo "; script-security 2" >> /home/damir/client-configs/base.conf
echo "; up /etc/openvpn/update-resolv-conf" >> /home/damir/client-configs/base.conf
echo "; down /etc/openvpn/update-resolv-conf" >> /home/damir/client-configs/base.conf

# Плюс ко всему добавьте строки настроек для клиентов, которые планируют использовать systemd-resolved:
echo "; script-security 2" >> /home/damir/client-configs/base.conf
echo "; up /etc/openvpn/update-systemd-resolved" >> /home/damir/client-configs/base.conf
echo "; down /etc/openvpn/update-systemd-resolved" >> /home/damir/client-configs/base.conf
echo "; down-pre" >> /home/damir/client-configs/base.conf
echo "; dhcp-option DOMAIN-ROUTE" >> /home/damir/client-configs/base.conf

# 16. Let's create a script to compile the basic configuration with the appropriate certificates, keys, and encryption files.
touch /home/damir/client-configs/make_config.sh
cat <<EOF> /home/damir/client-configs/make_config.sh
#!/bin/bash
# First argument: Client identifier
KEY_DIR=~/client-configs/keys
OUTPUT_DIR=~/client-configs/files
BASE_CONFIG=~/client-configs/base.conf
cat \${BASE_CONFIG} \\
<(echo -e '<ca>') \\
\${KEY_DIR}/ca.crt \\
<(echo -e '</ca>\n<cert>') \\
\${KEY_DIR}/\${1}.crt \\
<(echo -e '</cert>\n<key>') \\
\${KEY_DIR}/\${1}.key \\
<(echo -e '</key>\n<tls-crypt>') \\
\${KEY_DIR}/ta.key \\
<(echo -e '</tls-crypt>') \\
> \${OUTPUT_DIR}/\${1}.ovpn
EOF
chmod 700 /home/damir/client-configs/make_config.sh
