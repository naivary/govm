#!/bin/bash

trap trapExit INT;

usage() {
  echo "-c [integer] is setting the count of CPUs"
  echo "-m [integer] is setting the RAM"
  echo "-i [integer] is setting the OS-Image"
  echo "-s [path] is setting the path to the provision-shell-script"
  echo "-h [ipv4] is setting the ip-adress for host-only of the type 192.168.56.0/24"
  echo "-f [path] is specifing the path to a *.config file with the parameters CPU, RAM, OS_IMAGE, IP and SCRIPT"
  echo "-v [up/halt/start/ssh/destroy] is setting the vagrant command you want to run (has to be present with every command )"
  echo "-d if this is present it will force destroy and replacing if there is a virtual machine registered but noch reachable"
}

MANUAL_GROUP=("-c" "-r" "-i" "-s" "-h" "-v" "-n")
FILE_GROUP=("-f" "-v")
VAGRANT_COMMANDS=("-v" "-m")
LIST_GROUP=("-l")
OPTIONS=(
    "CPU"
    "RAM"
    "OS_IMAGE"
    "SCRIPT"
    "HOST_ONLY_IP"
    "VM_NAME"
)
IS_MANUAL="false"
IS_FILE="false"
# init is settin gall standard needed for
# the shell-script to run smooth
init() {
  MACHINES=/mnt/c/Users/mh0071
  VM_LIST=${VM_LIST:-""}
  FORCE_DESTROY=${FORCE_DESTROY:-""}
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

while getopts "c:r:i:s:h:f:v:n:m:ld" OPT; do
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
    d)
      FORCE_DESTROY="force"
      ;;
    n)
      VM_NAME=${OPTARG}
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
  echo "Cleaning up..."
  rmSyncFolder;
  removeIPFromFile;
  removeVagrantDir
}

IPID() {
  IP_TO_ID="$(grep ${1} used_ip.txt | cut -d '=' -f 1)"
}

IDtoIP() {
  IDIP="$(grep ${1} used_ip.txt | cut -d '=' -f 2)"
}

removeIPFromFile() {
  if grep -q "${HOST_ONLY_IP}" "./used_ip.txt"; then
    sed -i "/${HOST_ONLY_IP}/d" "./used_ip.txt";
  fi
}

removeVagrantDir() {
  if [[ -d "./.vagrant" ]]; then
    rm -r "./.vagrant"
  fi
}

# exits
trapExit() {
  echo "Graceful exiting..."
  rmSyncFolder;
  removeVagrantDir
}

successExitAfterCreation() {
  cd ${MACHINES}/vagrant-ptb
  createConfigFile;
  removeVagrantDir;
  echo "${ID}=${HOST_ONLY_IP}" >> "used_ip.txt";
}

# setter

setDefaultValues() {
  CPU="${CPU:-1}"
  RAM="${RAM:-1048}"
  OS_IMAGE=${OS_IMAGE:-"ubuntu/trusty64"}
  SCRIPT=${SCRIPT:-"provision/default.sh"}
  VIRTUAL_MACHINE=${VIRTUAL_MACHINE:-""}
  CONFIG_FILE=${CONFIG_FILE:-""}
  ID=${ID:-0}
  VM_NAME=${VM_NAME:-""}
}

setVagrantENV() {
  export CPU;
  export RAM;
  export OS_IMAGE;
  export SCRIPT;
  export HOST_ONLY_IP;
  export VM_NAME;
  # not set by User
  export SYNC_FOLDER;
}


# creation of X

createSyncFolder() {
  if [ ! -d "${MACHINES}/.machines" ]; then
    mkdir -p "${MACHINES}/.machines"
  fi
  ID="$(openssl rand -hex 5)" 
  if [[ -z ${VM_NAME} ]]; then
    VM_NAME="${HOST_ONLY_IP}_${ID}" 
  fi
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
  cp "Vagrantfile" "${MACHINES}/.machines/${ID}/Vagrantfile"
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
  if [[  -s "${CONFIG_FILE}" ]]; then
    while read LINE
    do
      VALUE="$(echo -e "${LINE}" | tr -d '[:space:]')"
      if ! [[ "${VALUE}" =~ ^([^'#']+)=([^\#$%&*^]+$) ]]; then
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
  else 
    echo ".config is not existing or is empty or has the wrong extension (expected: .config)"
    exit 1
  fi
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
  elif ! validateIP;then
    exit 1
  else 
    echo "Everthing fine!" 
    return 0
  fi
}


# validateIP is validating the given ip
# if its already in use or not 
validateIP() {
  # check if ip is used in any way
  ping -w 1 "${HOST_ONLY_IP}" &> /dev/null;

  if [[ "$?" -eq 0  && -z "${FORCE_DESTROY}" ]]; then
    echo "Machine with the IP: ${HOST_ONLY_IP} exists. Choose an other IP-Adress."
    exit 1
  fi

  # check if ip exist within machine-ecosystem
  grep -q "${HOST_ONLY_IP}" used_ip.txt  

  if [[ "$?" -eq 0 && -z "${FORCE_DESTROY}" ]]; then
    IPID ${HOST_ONLY_IP}
    echo "Machine still existing in our system ID: ${IP_TO_ID}"    
    exit 1
  fi

  grep -w ${HOST_ONLY_IP} used_ip.txt

  IS_SUCCESS=${?}

  if [[ ${FORCE_DESTROY}  && "${IS_SUCCESS}" -eq 0 ]]; then
    IPID ${HOST_ONLY_IP}
    VIRTUAL_MACHINE=${IP_TO_ID}
    destroy
    if [ "${CONFIG_FILE}" ]; then
      sourceConfigFile
    fi
  fi
}

validateArgs() {
  CHECK_MANUAL=()
  CHECK_FILE=()
  CHECK_VAGRANT=()
  CHECK_LIST=()
  VAGRANT_COMMAND_GIVEN="false"

  for ARG in "$@"
  do
    if [[ "${ARG}" =~ ^-.$ ]]; then
      if [[ "${MANUAL_GROUP[*]}" =~ "${ARG}" && "${ARG}" != "-v" ]]; then
        CHECK_MANUAL+=("${ARG}")
      elif [[ "${FILE_GROUP[*]}" =~ "${ARG}" && "${ARG}" != "-v" ]]; then
        CHECK_FILE+=("${ARG}")
      elif [[ "${VAGRANT_COMMANDS[*]}" =~ "${ARG}" && "${ARG}" != "-v" ]]; then
        CHECK_VAGRANT=("${ARG}")
      elif [[ "${ARG}" == "-v" ]]; then
        VAGRANT_COMMAND_GIVEN="true"
      elif [[ "${LIST_GROUP[*]}" =~ "${ARG}" && "${ARG}" != "-v" ]]; then
        CHECK_LIST+=("${ARG}")
      fi
    fi
  done

  if [[ "${#CHECK_MANUAL[@]}" -eq 5 && "${#CHECK_FILE[@]}" -eq 0 && "${#CHECK_VAGRANT[@]}" -eq 0 && "${#CHECK_LIST[@]}" -eq 0 && "${VAGRANT_COMMAND_GIVEN}" == "true" ]]; then
    echo "Manual interaction started!"
    echo "Going forward..."
    IS_MANUAL="true"
  elif [[ "${#CHECK_MANUAL[@]}" -eq 0 && "${#CHECK_FILE[@]}" -eq 1 && "${#CHECK_VAGRANT[@]}" -eq 0 && "${#CHECK_LIST[@]}" -eq 0 && "${VAGRANT_COMMAND_GIVEN}" == "true" ]]; then
    echo "Config file interaction started!"
    echo "Going forward..."
    IS_FILE="true"
  elif [[ "${#CHECK_MANUAL[@]}" -eq 0 && "${#CHECK_FILE[@]}" -eq 0 && "${#CHECK_VAGRANT[@]}" -eq 1 && "${#CHECK_LIST[@]}" -eq 0 && "${VAGRANT_COMMAND_GIVEN}" == "true" ]]; then
    echo "Running vagrant command..."
  elif [[ "${#CHECK_MANUAL[@]}" -eq 0 && "${#CHECK_FILE[@]}" -eq 0 && "${#CHECK_VAGRANT[@]}" -eq 0 && "${#CHECK_LIST[@]}" -eq 1 && "${VAGRANT_COMMAND_GIVEN}" == "false" ]]; then
    echo "Listing all virtual machines..."
  else
    echo "Too Many or not enough arguments"
    usage;
    exit 1
  fi


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
  vagrant destroy --force;
  cd ${MACHINES}/vagrant-ptb; 
  clean;
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
  if [[ ${IS_MANUAL} == "true" ]]; then
     manualUp
  elif [[ ${IS_FILE} == "true" ]]; then
    fileUp;
  else 
    echo "Error"
    usage;
  fi
}

halt() {
  echo "Stopping ${VIRTUAL_MACHINE}..."
  createVagrantENV;
  vagrant halt
}

vssh() {
  echo "SSH into ${VIRTUAL_MACHINE}"
  createVagrantENV;
  vagrant ssh;
}

start() {
  echo "Starting ${VIRTUAL_MACHINE}..."
  createVagrantENV;
  vagrant up;
}

list() {
  init 
  if [ -z "$(ls -A ${MACHINES}/.machines)" ]; then
    echo "No Machines have been created yet!"
    exit 1
  fi

  divider===============================;
  divider=$divider$divider$divider;
  header="\n %-10s %10s %13s %14s %21s %8s\n";
  format="%11s %12s %15s %17s %3d %17d\n";
  width=85;

  printf "$header" "VM-ID" "VM-Name" "IP-Adress" "OS-Image" "Processor(s)" "Memory";
  printf "%$width.${width}s\n" "$divider";

  for DIR in ${MACHINES}/.machines/*; do
    cd ${DIR}
    . .config
    printf "$format" \
    "${ID}" "${VM_NAME}" "${HOST_ONLY_IP}" "${OS_IMAGE}" "${CPU}" "${RAM}" 
  done

}


#entering point
main() {
  setDefaultValues
  validateArgs "$@"
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

main "$@"