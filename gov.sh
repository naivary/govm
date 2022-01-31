#!/bin/bash
trap trapExit INT
MACHINES=/mnt/c/users/mh0071/


usage() {
  echo "-c [integer] is setting the count of CPUs"
  echo "-m [integer] is setting the RAM"
  echo "-i [integer] is setting the OS-Image"
  echo "-s [path] is setting the path to the provision-shell-script"
  echo "-h [ipv4] is setting the ip-adress for host-only of the type 192.168.56.0/24"
  echo "-f [path] is specifing the path to a *.config file with the parameters CPU, RAM, OS_IMAGE, IP and SCRIPT"
}

# init is settin gall standard needed for
# the shell-script to run smooth
init() {
  # -e any error means to exit the script
  # -u treat unset variables and paramters as an error
  # -x what is getting executed
  set -e 
  # set -x
  set -u
  # UTF-8 as standard in the shell-Environment
  export LANG=C.UTF-8
}

while getopts "c:m:i:f:s:h:connect:" OPT; do
  case "${OPT}" in
    c)
      CPU="${OPTARG}"
      ;;
    m)
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
    connect)
      CONNECT_TO=${OPTARG}
      ;;
    ?)
      usage
      exit 1
      ;;
  esac
done

# exits

trapExit() {
  echo "Graceful exiting..."
  if [[ -d "${MACHINES}/.machines/${ID}" ]]; then
    sudo rm -r "${MACHINES}/.machines/${ID}";
  fi 
  validateUsedIPFileState;
}

successExit() {
  mv "./.vagrant" "$SYNC_FOLDER";
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

# sourcing 

sourceConfigFile() {
  echo "Loading ${CONFIG_FILE}...";
  . "$CONFIG_FILE";
}

# validation

validateInput() {
  echo "Validating Paramaters..."
  
  if ! [[ "${CPU}" =~ ^[0-9]+$ && "${CPU}" -ge 1 ]]; then
    echo "CPU (${CPU}) may only contain numbers and shall be bigger than 1";
    exit 1;
  elif ! [[ "${RAM}" =~ ^[0-9]+$ && "${RAM}" -ge 4 ]]; then
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
  if grep -q "${HOST_ONLY_IP}" "used_ip.txt"; then
    sed -i "/${HOST_ONLY_IP}/d" "used_ip.txt";
  fi
}


main() {
  setDefaultValues
  if [[ ( "${CPU}" && "${RAM}" && "${OS_IMAGE}" && "${SCRIPT}" && "${HOST_ONLY_IP}" ) && ( -z "${CONFIG_FILE}") && ( -z "${CONNECT_TO}") ]]; then
    # ineraction 
    init;
    validateInput && createSyncFolder;
    setVagrantENV;
    createVM && successExit;
  elif [[ -s "${CONFIG_FILE}" && "${CONFIG_FILE}" == *.config && ( -z "${CONNECT_TO}" ) ]]; then
    # file
    sourceConfigFile;
    validateInput && createSyncFolder;
    setVagrantENV;
    createVM && successExit;
  elif [ "${CONNECT_TO}" ]; then
    echo "getting here"
    ssh gov@"${CONNECT_TO}"
  else 
    # error
    echo "Error: Not enough Arguments or *.config file not given."
    usage;
  fi
}

main;