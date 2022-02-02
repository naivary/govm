#!/bin/bash

trap trapExit INT;

usage() {
  echo "-c [integer] is setting the count of CPUs"
  echo "-m [integer] is setting the RAM"
  echo "-i [integer] is setting the OS-Image"
  echo "-s [path] is setting the path to the provision-shell-script"
  echo "-h [ipv4] is setting the ip-adress for host-only of the type 192.168.56.0/24"
  echo "-f [path] is specifing the path to a *.config file with the parameters CPU, RAM, OS_IMAGE, IP and SCRIPT"
  echo "-v [up/halt/start/ssh/destroy] is setting the vagrant command you want to run"
}

MANUAL_GROUP=("-c" "-m" "-i" "-s" "-h" "-v")
FILE_GROUP=("-f" "-v")
VAGRANT_COMMANDS=("-v" "-vm")
OPTIONS=(
    "CPU"
    "RAM"
    "OS_IMAGE"
    "SCRIPT"
    "HOST_ONLY_IP"
)

# init is settin gall standard needed for
# the shell-script to run smooth
init() {
  MACHINES=/mnt/c/Users/mh0071
  export PATH="${PATH}"
  export LANG=C.UTF-8
  export LC_NUMERIC="en_US.UTF-8"
  # -e any error means to exit the script
  # -u treat unset variables and paramters as an error
  # -x what is getting executed
  set -e 
  # set -x
  set -u
  # UTF-8 as standard in the shell-Environment
}

while getopts "c:r:i:s:h:f:v:m:l" OPT; do
  case "${OPT}" in
    c)
      CPU="${OPTARG}"
      ;;
    r)
      RAM=${OPTARG}
      ;;
    i)
      OS_IMAGE=${OPTARG}
      ;;
    f)
      CONFIG_FILE=${OPTARG}
      ;;
    s)
      SCRIPT=${OPTARG}
      ;;
    h)
      HOST_ONLY_IP=${OPTARG}
      ;;
    v)
      VAGRANT_CMD=${OPTARG}
      ;;
    m)
      VIRTUAL_MACHINE=${OPTARG}
      ;;
    l)
      VM_LIST="show"
      ;;
    ?)
      usage
      exit 1
      ;;
  esac
done

# remove

rmSyncFolder() {
  if [[ -d "${MACHINES}/.machines/${ID}" ]]; then
    sudo rm -r "${MACHINES}/.machines/${ID}";
  fi 
}


clean() {
  rmSyncFolder;
  removeIP;
}

IPtoID() {
  IP_TO_ID="$(grep ${1} used_ip.txt && cut -d '=' -f 1 used_ip.txt)"
}

IDtoIP() {
  ID_TO_IP="$(grep ${1} used_ip.txt && cut -d '=' -f 2 used_ip.txt)"
}

removeIP() {
  IDtoIP "${VIRTUAL_MACHINE}";
  if grep -q "${HOST_ONLY_IP}" "used_ip.txt"; then
    sed -i "/${HOST_ONLY_IP}/d" "used_ip.txt";
  fi
}


# exits

trapExit() {
  echo "Graceful exiting..."
  rmSyncFolder;
  validateUsedIPFileState;
}

successExitAfterCreation() {
  cd ${MACHINES}/vagrant-ptb
  createConfigFile;
  validateUsedIPFileState; 
  echo ${HOST_ONLY_IP} >> "used_ip.txt";
}

# setter

setDefaultValues() {
  CPU="${CPU:-1}"
  RAM="${RAM:-1048}"
  OS_IMAGE=${OS_IMAGE:-"ubuntu/trusty64"}
  SCRIPT=${SCRIPT:-"provision/default.sh"}
}

setVagrantENV() {
  export CPU;
  export RAM;
  export OS_IMAGE;
  export SCRIPT;
  export HOST_ONLY_IP;
  # not set by User
  export SYNC_FOLDER;
  export VM_NAME;
}


# creation of X

createSyncFolder() {
  if [ ! -d "${MACHINES}/.machines" ]; then
    mkdir -p "${MACHINES}/.machines"
  fi
  ID="$(openssl rand -hex 5)" 
  VM_NAME="${HOST_ONLY_IP}_${ID}"
  mkdir -p -- "${MACHINES}/.machines/${ID}"
  SYNC_FOLDER="${MACHINES}/.machines/${ID}"
}

createVM() {
  echo "Creating Virtual-Machine with the ID: $ID"
  vagrant up;
}

createConfigFile() {
cat << EOF > ${MACHINES}/.machines/${ID}/.config
CPU=${CPU}
RAM=${RAM}
OS_IMAGE=${OS_IMAGE}
SCRIPT=${SCRIPT}
SYNC_FOLDER=${SYNC_FOLDER}
VM_NAME=${VM_NAME}
HOST_ONLY_IP=${HOST_ONLY_IP}
ID=${ID}
EOF
}


createNeededFilesForVagrant() {
  setVagrantENV;
  cp "./Vagrantfile" "${MACHINES}/.machines/${ID}/Vagrantfile"
  mkdir "${MACHINES}/.machines/${ID}/provision"
  cp "${SCRIPT}" "${MACHINES}/.machines/${ID}/${SCRIPT}"
}


# sourcing 

#sourceConfigFile is sourcing the
# given config-file into the current
# shell-ENV
sourceConfigFile() {
  . "${CONFIG_FILE}"
}

# validation
validateAndSourceConfigFile() {
  echo "Loading ${CONFIG_FILE}...";

  while read LINE
  do
    VALUE="$(echo -e "${LINE}" | tr -d '[:space:]')"
    if ! [[ "${VALUE}" =~ ^([^'#']+)=(.+) ]]; then
      echo "DID not match ${VALUE}"
      exit 1
    else
      NAME="${BASH_REMATCH[1]}"
      if ! [[ "${OPTIONS[*]}" =~ "${NAME}" ]]; then
        echo "Unexpected KEY: ${NAME}"
        exit 1
      fi
    fi
  done < .config
  sourceConfigFile;
}


validateInput() {
  echo "Validating Paramaters..."
  if ! [[ "${CPU}" =~ ^[0-9]+$ && "${CPU}" -ge 1 && "${CPU}" -le 100 ]]; then
    echo "CPU (${CPU}) may only contain numbers and shall be bigger than 1";
    exit 1;
  elif ! [[ "${RAM}" =~ ^[0-9]+$ && "${RAM}" -ge 512  && "${RAM}" -le 16000 ]]; then
    echo "Memory may only contain numbers and shall be bigger than 4";
    exit 1;
  elif ! [[ -s "${SCRIPT}" ]]; then
    echo "Shell-script not found or empty";
    exit 1;
  elif ! [[ "${HOST_ONLY_IP}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "Invalid IP-Adress";
    exit 1;
  elif ping -w 1 "${HOST_ONLY_IP}" &> /dev/null; then
    echo "IP:${HOST_ONLY_IP} already in use. Choose another IP-Adress"
    exit 1
  else 
    echo "Everthing fine!" 
    return 0
  fi
}



validateUsedIPFileState() {
}

# commands

createVagrantENV() {
  init;
  cd ${MACHINES}/.machines/${VIRTUAL_MACHINE}
  . .config;
  setVagrantENV;
}

destroy() {
  echo "Destroying ${VIRTUAL_MACHINE}.."
  createVagrantENV;
  cd "${MACHINES}/.machines/${VIRTUAL_MACHINE}/"
  vagrant destroy --force && clean; 
}

fileUp() {
 init;
 validateAndSourceConfigFile;
 validateInput && createSyncFolder;
 createNeededFilesForVagrant
 cd ${MACHINES}/.machines/${ID};
 createVM && successExitAfterCreation;

}

manualUp() {
  init;
  validateInput && createSyncFolder;
  createNeededFilesForVagrant;
  cd ${MACHINES}/.machines/${ID};
  createVM && successExitAfterCreation;
}


up() {
  if [[ ( "${CPU}" && "${RAM}" && "${OS_IMAGE}" && "${SCRIPT}" && "${HOST_ONLY_IP}" ) && ( -z "${CONFIG_FILE}") ]]; then
    manualUp
  elif [[ -s "${CONFIG_FILE}" && "${CONFIG_FILE}" == *.config ]]; then
    fileUp;
  else 
    echo "Error"
    usage
  fi
}

halt() {
  echo "Shutting down ${VIRTUAL_MACHINE}"
  createVagrantENV;
  vagrant halt
}

vssh() {
  echo "SSH into the virtual machine ${VIRTUAL_MACHINE}"
  createVagrantENV;
  vagrant ssh;
}

start() {
  echo "Starting ${VIRTUAL_MACHINE}..."
  createVagrantENV;
  vagrant up;
}

list() {
  
  if [ ! -d ${MACHINES}/.machines/* ]; then
    echo "No Machines have been created yet!"
    exit 1
  fi
     
  init;

  divider===============================;
  divider=$divider$divider$divider;
  header="\n %-10s %11s %14s %21s %8s\n";
  format="%11s %15s %17s %3d %17d\n";
  width=70;

  printf "$header" "VM-ID" "IP-Adress" "OS-Image" "Processor(s)" "Memory";
  printf "%$width.${width}s\n" "$divider";

  for DIR in ${MACHINES}/.machines/*; do
    cd ${DIR}
    . .config
    printf "$format" \
    "${ID}" "${HOST_ONLY_IP}" "${OS_IMAGE}" "${CPU}" "${RAM}" 
  done

}

#entering point
main() {
  setDefaultValues
  if [[ "${VAGRANT_CMD}" == "destroy" && "${VIRTUAL_MACHINE}" ]]; then 
    destroy;
  elif [[ "${VAGRANT_CMD}" == "halt" && "${VIRTUAL_MACHINE}" ]]; then
    halt;
  elif [[ "${VAGRANT_CMD}" == "start" && "${VIRTUAL_MACHINE}" ]]; then
    start
  elif [[ "${VAGRANT_CMD}" == "up" ]]; then
    up
  elif [[ "${VAGRANT_CMD}" == "ssh" && "${VIRTUAL_MACHINE}" ]]; then
    vssh
  elif [[ "${VM_LIST}" ]]; then
    list
  else 
    # error
    echo "Error: Not enough Arguments or unknown command"
    usage;
  fi
}

main;