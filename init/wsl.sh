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


powershell.exe -File "../pkg/windows.ps1";

infobold  "Finishing touches..."
BASHFILE="${HOME}/.bashrc"
if grep -w -q '# CREATED BY GOVM. DO NOT EDIT' ${BASHFILE}; then
  infobold "Path and vagrant env-variables already set"
else
  echo "# CREATED BY GOVM. DO NOT EDIT" >> ${BASHFILE}
  echo "# BEGIN" >> ${BASHFILE}
  echo "export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS=\"1\"" >> "${BASHFILE}"
  echo "export PATH=\"\$PATH:/mnt/c/Program Files/Oracle/VirtualBox:${HOME}/vagrant-wrapper/govm\"" >> "${BASHFILE}"
  echo "# END" >> ${BASHFILE}
  echo "" >> ${BASHFILE}
fi

if ! sudo grep -w -q "${USER} ALL = (ALL) NOPASSWD:ALL" /etc/sudoers.d/musti; then
  infobold "Setting sudo-priviliges without password"
  sudo touch /etc/sudoers.d/${USER}
  sudo chmod 0440 "/etc/sudoers.d/${USER}"
  echo "${USER} ALL = (ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/musti
fi

success "Wait for the windows-powershell-prompt to close automatically and you are ready to go!"