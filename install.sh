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

func_wslinstall() {
  sudo chmod u+x ./govm/init/wsl.sh
  source ./govm/init/wsl.sh
}


func_ubuntuinstall() {
  sudo chmod u+x ./govm/init/ubuntu.sh
  source ./govm/init/ubuntu.sh

}

func_ostype() {
  OS=$(uname -r | sed -n 's/.*\( *Microsoft *\).*/\1/ip')

  if [[ "${OS}" == "microsoft" ]]; then
    OS="wsl"
  else
    OS="ubuntu"
  fi
}

main() {
  func_ostype
  if [[ "${OS}" == "wsl" ]]; then
    func_wslinstall
  elif [[ "${OS}" == "ubuntu" ]]; then
    func_ubuntuinstall
  else
    error "missing first parameter. Possible options: ubuntu or wsl"  
    exit 1
  fi
}

main "$@"