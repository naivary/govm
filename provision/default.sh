echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/90force-ipv4
sudo apt upgrade -y && sudo apt update;
