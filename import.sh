#!/bin/bash

# env-variable wird als appliance group genommen 
# diese env-variable wird beim anmelden durch eine batch script gesetzt

# func_init is setting all best-practice-standards 
# needed for the shell-script to run without
# any problems and catch errors 
func_init() {
  export PATH="${PATH}"
  export LANG=C.UTF-8
  export LC_NUMERIC="en_US.UTF-8"
  # -e any error means to exit the script
  # -u treat export -n variables and paramters as an error
  # -x what is getting executed
  set -e 
  # set -x
  set -u
  # UTF-8 as standard in the shell-Environment
}

infobold() {
  printf "\033[1m\033[34m${1}\033[0m\n"
}

error() {
  printf "\u274c\033[1m\033[31m ${1}\033[0m\n"
}

success() {
  printf "\033[1m\033[32m${1} \xE2\x9C\x94\033[0m\n"
}

func_osdefault() {
  if [[ "${CURRENT_OS}" == "microsoft" ]]; then
    APPLIANCESTORE="$(wslpath -w ${APPLIANCESTORE})"
  fi
}

func_validateenvvar() {
  APPLIANCE_NAME=${CURRENT_LESSON}

  if ! [[ -d "${APPLIANCESTORE}/${APPLIANCE_NAME}" ]]; then
    error "Appliance-group does not exist!"
    exit 1
  fi

  LATEST=$(ls ${APPLIANCESTORE}/${APPLIANCE_NAME} | sort -V | tail -n 1)
  success "Appliance exists. Importing newest version..."
  func_import

}

func_import() {
  func_osdefault
  if [[ ${CURRENT_OS} == "microsoft" ]]; then
    vboxmanage.exe import "${APPLIANCESTORE}/${APPLIANCE_NAME}/${LATEST}";
  else
    vboxmanage import "${APPLIANCESTORE}/${APPLIANCE_NAME}/${LATEST}";
  fi

  success "Imported and ready to go!"
}


main() {
  CURRENT_OS=$(uname -r | sed -n 's/.*\( *Microsoft *\).*/\1/ip')
  func_init
  func_validateenvvar

}


main "$@"