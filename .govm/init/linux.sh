#!/bin/bash

infobold() {
  printf "\033[1m\033[34m${1}\033[0m\n"
}

error() {
  printf "\u274c\033[1m\033[31m ${1}\033[0m\n"
}

success() {
  printf "\033[1m\033[32m${1} \xE2\x9C\x94\033[0m\n"
}

infobold "Installing virtualbox..."
sudo apt-get install virtualbox -y
infobold "Installing vagrant..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install vagrant

infobold  "Finishing touches..."
BASHFILE="${HOME}/.bashrc"
if grep -w -q '# CREATED BY GOVM. DO NOT EDIT' ${BASHFILE}; then
  infobold "Path and vagrant env-variables already set"
else
  infobold "Adding needed ENV-Variables..."
  echo "# CREATED BY GOVM. DO NOT EDIT" >> ${BASHFILE}
  echo "# BEGIN" >> ${BASHFILE}
  echo "export PATH=\"\$PATH:${HOME}/vagrant-wrapper\"" >> "${BASHFILE}"
  echo "# END" >> ${BASHFILE}
  echo "" >> ${BASHFILE}
fi

if ! sudo grep -w -q "${USER} ALL = (ALL) NOPASSWD:ALL" /etc/sudoers.d/${USER}; then
  infobold "Setting sudo-priviliges without password"
  sudo touch /etc/sudoers.d/${USER}
  sudo chmod 0440 "/etc/sudoers.d/${USER}"
  echo "${USER} ALL = (ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/${USER}
fi

if ! [[ -f ../../govm ]]; then
  cp ../../govm.sh ../../govm
fi

sudo apt install realpath;
sudo apt install git -y;
sudo apt-get update -y;