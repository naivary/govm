echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/90force-ipv4
sudo apt-get upgrade -y && sudo apt-get update;
