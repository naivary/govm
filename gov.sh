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
  echo "-g is setting the path to tje gov.cfg file (default ./gov.cfg)"
}

MANUAL_GROUP=("-c" "-r" "-i" "-s" "-h" "-v" "-n")
FILE_GROUP=("-f" "-v")
VAGRANT_GROUP=("-v" "-m")
LIST_GROUP=("-l")
VALID_CONFIG_PARAMS_VM=(
    "CPU"
    "RAM"
    "OS_IMAGE"
    "SCRIPT"
    "HOST_ONLY_IP"
    "VM_NAME"
    "GIT_USERNAME"
    "GIT_PASSWORD"
    "OS_USERNAME"
    "OS_PASSWORD"
)
VALID_CONFIG_PARAMS_APP=(
  "LOG"
  "VMSTORE"
)
IS_MANUAL="false"
IS_FILE="false"

# init is setting all best-practice-standards 
# needed for the shell-script to run without
# any problems
init() {
  BASE_DIR=".govm"
  VMSTORE=${VMSTORE:-""}
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

while getopts "c:r:i:s:h:f:g:v:n:m:ld" OPT; do
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
      VM_CONFIG=${OPTARG}
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
  if [[ -d "${VMSTORE}/${ID}" ]]; then
    sudo rm -r "${VMSTORE}/${ID}";
  fi 
}


clean() {
  printf "\033[1m\033[31mCleaning up..."
  rmSyncFolder;
  removeIPFromFile;
  printf "\033[1m\033[32mFinished! \xE2\x9C\x94\n"
}

IPID() {
  IP_TO_ID="$(grep ${1} used_ip.txt | cut -d '=' -f 1)"
}

IDtoIP() {
  IDIP="$(grep ${1} used_ip.txt | cut -d '=' -f 2)"
}

removeIPFromFile() {
  if grep -q -w "${HOST_ONLY_IP}" "./used_ip.txt"; then
    sed -i "/${HOST_ONLY_IP}/d" "./used_ip.txt";
  fi
}

# exits
trapExit() {
  printf "\033[1m\033[31mGraceful exiting...\n"
  rmSyncFolder;
}

successExitAfterCreation() {
  printf "\033[1m\033[34mFinishing touches...\n"
  createConfigFile;
  echo "${ID}=${HOST_ONLY_IP}" >> "${BASEDIR}/used_ip.txt";
  printf "\033[1m\033[32mVM ${ID} is set and ready to go :) \xE2\x9C\x94\n"
}


setDefaultValues() {
  REALPATH=$(realpath ${0})
  BASEDIR=$(dirname ${REALPATH})
  CPU="${CPU:-1}"
  RAM="${RAM:-1048}"
  OS_IMAGE=${OS_IMAGE:-"ubuntu/trusty64"}
  SCRIPT=${SCRIPT:-"provision/default.sh"}
  VIRTUAL_MACHINE=${VIRTUAL_MACHINE:-""}
  VM_CONFIG=${VM_CONFIG:-""}
  ID=${ID:-0}
  VM_NAME=${VM_NAME:-""}
  GOV_CONFIG=${GOV_CONFIG:-"./gov.cfg"}
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



createVM() {
  printf "\033[1m\033[34mCreating Virtual-Machine $ID. This may take a while...\n"
  vagrant up &> ${LOG}/vagrant_up.log 
}

createConfigFile() {
cat << EOF > ${VMSTORE}/${ID}/${BASE_DIR}/vm.cfg
CPU=${CPU}
RAM=${RAM}
OS_IMAGE=${OS_IMAGE}
SCRIPT=${SCRIPT}
SYNC_FOLDER=${SYNC_FOLDER}
VM_NAME=${VM_NAME}
HOST_ONLY_IP=${HOST_ONLY_IP}
ID=${ID}
LOG=${LOG}
GOV_CONFIG=${GOV_CONFIG}
EOF
}

# preVagrantENV is creating the
# syncFolder for the VM and also
# the log folder to log to
preVagrantENV() {
  ID="$(openssl rand -hex 5)" 
  mkdir -p -- "${VMSTORE}/${ID}/${BASE_DIR}"
  
  if [[ ${LOG} == "/log" ]]; then
    mkdir -p -- ${VMSTORE}/${ID}/${BASE_DIR}/logs
  fi

  LOG=${VMSTORE}/${ID}/${BASE_DIR}/logs
  SYNC_FOLDER="${VMSTORE}/${ID}"
  SCRIPT_NAME=$(basename ${SCRIPT})
}

# postVagrantENV is creating 
# directories and copying 
# all needed vagrant-files so that
# the vagrant commands can run in the
# newly created directory
postVagrantENV() {
  setVagrantENV;
  cp "Vagrantfile" "${VMSTORE}/${ID}/${BASE_DIR}/Vagrantfile"
  mkdir "${VMSTORE}/${ID}/${BASE_DIR}/provision"
  cp "${SCRIPT}" "${VMSTORE}/${ID}/${BASE_DIR}/provision/${SCRIPT_NAME}"
}


# sourcing 

#sourceFile is sourcing the
# given file into the current
# shell-ENV
sourceFile() {
  . "${1}"
}

# validateAndSourceVMConfig
# is validating the config file
# for the virtual-machine (syntax only)
# and if the config file is valid 
# it is getting sourced.
validateAndSourceVMConfig() {
  GIVEN_PARAMS=()
  printf "\033[0m\033[34mLoading ${VM_CONFIG}...\n";
  if [[  -s "${VM_CONFIG}" && "${VM_CONFIG}" == *.cfg ]]; then
    while read LINE
    do
      VALUE="$(echo -e "${LINE}" | tr -d '[:space:]')"
      if ! [[ "${VALUE}" =~ ^([A-Za-z0-9_]+)=([^'#'$%'&''*'^]+$) ]]; then
        [[ "${LINE}" =~ ^\#.*$ || -z "${LINE}" ]] && continue
        printf "\u274c DID not match ${VALUE}\n"
        exit 1
      else
        NAME="${BASH_REMATCH[1]}"
        if ! [[ "${VALID_CONFIG_PARAMS_VM[*]}" =~ "${NAME}" || "${GIVEN_PARAMS[*]}" =~ ${NAME} ]]; then
          printf "\u274c Unexpected Key ${NAME}\n"
          exit 1
        else 
          GIVEN_PARAMS+=("${NAME}")
        fi
      fi
    done < ${VM_CONFIG}

  if [[ ${#GIVEN_PARAMS[@]} -eq ${#VALID_CONFIG_PARAMS_VM[@]} ]]; then
    printf "\033[1m\033[32mValid! Sourcing ${VM_CONFIG} \xE2\x9C\x94\n" 
    sourceFile ${VM_CONFIG}
  else 
    printf "\033[1m\033[31mNot Enough Arguments\n\033[0m"
    echo "Expected: ${VALID_CONFIG_PARAMS_VM[@]}"
    exit 1
  fi

  else 

    printf "\u274c .config is not existing or is empty or has the wrong extension (expected: .config)"
    exit 1
  fi
}

# validateAndSourceAppConfig
# is validating the config file
# for the application (syntax only)
# and if the config file is valid 
# it is getting sourced.
validateAndSourceAppConfig() {
  GIVEN_PARAMS=()
  printf "\033[0m\033[34mLoading ${GOV_CONFIG}...\n";
  if [[  -s "${GOV_CONFIG}" ]]; then
    while read LINE
    do
      VALUE="$(echo -e "${LINE}" | tr -d '[:space:]')"
      if ! [[ "${VALUE}" =~ ^([^'#']+)=([^'#'$%'&''*'^]+$) ]]; then
        [[ "${LINE}" =~ ^\#.*$ || -z "${LINE}" ]] && continue
        printf "\u274c Did not match ${NAME}\n"
        exit 1
      else
        NAME="${BASH_REMATCH[1]}"
        if ! [[ "${VALID_CONFIG_PARAMS_APP[*]}" =~ "${NAME}" || "${GIVEN_PARAMS[*]}" =~ ${NAME} ]]; then
          printf "\u274c Unexpected Key ${NAME}\n"
          exit 1
        else 
          GIVEN_PARAMS+=("${NAME}")
        fi
      fi
    done < ${GOV_CONFIG}

    if [[ ${#GIVEN_PARAMS[@]} -eq ${#VALID_CONFIG_PARAMS_APP[@]} ]]; then
      printf "\033[1m\033[32mValid! Sourcing ${GOV_CONFIG} \xE2\x9C\x94\n" 
      sourceFile ${GOV_CONFIG}
    else 
      printf "\033[1m\033[31mNot Enough Arguments\n\033[0m"
      echo "Expected: ${VALID_CONFIG_PARAMS_APP[@]}"
      exit 1
    fi

  else 
    printf " \u274c gov.cfg is not existing or is empty or has the wrong extension (expected: .cfg)\n"
    exit 1
  fi
}


# validateVMInput is  checking if 
# all given VM-Configs are the type 
# that they has to be like 
# CPU should be an integer not 
# a word etc.
validateVMInput() {
  printf "\033[0m\033[34mValidating Virtual-Machine parameters...\n"
  if ! [[ "${CPU}" =~ ^[0-9]+$ && "${CPU}" -ge 1 && "${CPU}" -le 100 ]]; then
    printf "\u274c CPU (${CPU}) may only contain numbers and shall be bigger than 1\n";
    exit 1;
  elif ! [[ "${RAM}" =~ ^[0-9]+$ && "${RAM}" -ge 512  && "${RAM}" -le 16000 ]]; then
    printf "\u274c Memory may only contain numbers and shall be bigger than 4\n";
    exit 1;
  elif ! [[ -s "${SCRIPT}" ]]; then
    printf "\u274c Shell-script not found or empty\n";
    exit 1;
  elif ! [[ "${HOST_ONLY_IP}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    printf "\u274c Invalid IP-Adress\n";
    exit 1;
  elif ! validateIP;then
    exit 1
  elif ! [[ ${GIT_PASSWORD} =~ ^(ghp_)([A-Za-z0-9]{36})$ ]];then
    printf "\u274c Invalid Git-Password\n"
  else 
    printf "\033[1m\033[32mValid VM-Values!\xE2\x9C\x94\n" 
    return 0
  fi
}

# validateAppInput is checking if 
# the given values are valid and is setting 
# defaults if needed
validateAppInput() {
  printf "\033[34mValidating App-Configuration parameters..."
  if ! [[ -d ${VMSTORE} ]]; then
    mkdir -p -- ${VMSTORE}
  elif ! [[ ${LOG} == "/log" && -d ${LOG} ]]; then
    mkdir -p -- ${LOG}
  else
    printf "\033[1m\033[31mInvalid Input!\n"
  fi
}


# validateIP is validating the given ip
# if its already in use or not by following 2 steps:
# First we ping the given IP-Adress. If it is reachable
# then the IP adress is in use in (but it does not have to 
# a virtual-machine but still cant be used for a 
# virtual-machine). Second we check if the IP-Adress
# is existing in our system. If it does we exit. A recreation 
# can be forced with -d flag
validateIP() {
  # check if ip is used in any way
  ping -w 1 "${HOST_ONLY_IP}" &> /dev/null;

  if [[ "$?" -eq 0  && -z "${FORCE_DESTROY}" ]]; then
    printf "\033[1m\033[31m\u274c Machine with the IP: ${HOST_ONLY_IP} exists. Choose an other IP-Adress. (Ping successfull)\n"
    exit 1
  fi

  # check if ip exist within machine-ecosystem
  grep -q "${HOST_ONLY_IP}" used_ip.txt  

  if [[ "$?" -eq 0 && -z "${FORCE_DESTROY}" ]]; then
    IPID ${HOST_ONLY_IP}
    printf "\033[1m\033[31m\u274c Machine still existing in our system ID: ${IP_TO_ID}. Run Command with -d to force recreation.\n"    
    exit 1
  fi

  grep -q -w ${HOST_ONLY_IP} used_ip.txt

  IS_SUCCESS=${?}

  if [[ ${FORCE_DESTROY}  && "${IS_SUCCESS}" -eq 0 ]]; then
    IPID ${HOST_ONLY_IP}
    VIRTUAL_MACHINE=${IP_TO_ID}
    destroy
    if [ "${VM_CONFIG}" ]; then
      sourceFile
    fi
  fi 
}

# validateArgs is validatin
# all given flags but not the values
# of the given flags. These are validate in
# validateInput. Here we validate the given flags
# and if they can be used together 
# using groups.
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
      elif [[ "${VAGRANT_GROUP[*]}" =~ "${ARG}" && "${ARG}" != "-v" ]]; then
        CHECK_VAGRANT=("${ARG}")
      elif [[ "${ARG}" == "-v" ]]; then
        VAGRANT_COMMAND_GIVEN="true"
      elif [[ "${LIST_GROUP[*]}" =~ "${ARG}" && "${ARG}" != "-v" ]]; then
        CHECK_LIST+=("${ARG}")
      fi
    fi
  done

  if [[ "${#CHECK_MANUAL[@]}" -eq $(( ${#MANUAL_GROUP[@]} -1 )) && "${#CHECK_FILE[@]}" -eq 0 && "${#CHECK_VAGRANT[@]}" -eq 0 && "${#CHECK_LIST[@]}" -eq 0 && "${VAGRANT_COMMAND_GIVEN}" == "true" ]]; then
    printf "\033[1m\033[34m Starting creation process...\n" 
    IS_MANUAL="true"
  elif [[ "${#CHECK_MANUAL[@]}" -eq 0 && "${#CHECK_FILE[@]}" -eq $(( ${#FILE_GROUP[@]} -1 )) && "${#CHECK_VAGRANT[@]}" -eq 0 && "${#CHECK_LIST[@]}" -eq 0 && "${VAGRANT_COMMAND_GIVEN}" == "true" ]]; then
    printf "\033[1m\033[34mStarting creation process...\n" 
    IS_FILE="true"
  elif [[ "${#CHECK_MANUAL[@]}" -eq 0 && "${#CHECK_FILE[@]}" -eq 0 && "${#CHECK_VAGRANT[@]}" -eq $(( ${#VAGRANT_GROUP[@]} -1 )) && "${#CHECK_LIST[@]}" -eq 0 && "${VAGRANT_COMMAND_GIVEN}" == "true" ]]; then
    echo "\n"
  elif [[ "${#CHECK_MANUAL[@]}" -eq 0 && "${#CHECK_FILE[@]}" -eq 0 && "${#CHECK_VAGRANT[@]}" -eq 0 && "${#CHECK_LIST[@]}" -eq ${#LIST_GROUP[@]} && "${VAGRANT_COMMAND_GIVEN}" == "false" ]]; then
    printf "\033[34m\033[34mListing all virtual machines..._\n"
  else
    printf "\033[1m\033[31mToo Many or not enough arguments\033[0m\n"
    usage;
    exit 1
  fi


}

# createVagrantENV is
# sourcing the config file
# in the ${VMSTORE}/${ID}
# and is running the given command afterwards
createVagrantENV() {
  init;
  cd ${VMSTORE}/${VIRTUAL_MACHINE}
  . vm.cfg;
  setVagrantENV;
}

destroy() {
  echo "Destroying ${VIRTUAL_MACHINE}.."
  createVagrantENV;
  vagrant destroy --force &> /dev/null
  cd ${VMSTORE}/vagrant-wrapper; 
  clean;
}

fileUp() {  
  init;
  validateAndSourceVMConfig;
  validateVMInput && preVagrantENV;
  postVagrantENV;
  cd ${VMSTORE}/${ID}/${BASE_DIR};
  createVM && successExitAfterCreation;
}

manualUp() {
  init;
  validateVMInput && preVagrantENV;
  postVagrantENV;
  cd ${VMSTORE}/${ID}/${BASE_DIR};
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
  printf "\033[34m\033[34mStopping ${VIRTUAL_MACHINE}..."
  createVagrantENV;
  vagrant halt;
}

vssh() {
  printf "\033[34m\033[34mecho SSH into ${VIRTUAL_MACHINE}"
  createVagrantENV;
  vagrant ssh;
}

start() {
  printf "\033[34m\033[34mStarting ${VIRTUAL_MACHINE}..."
  createVagrantENV;
  vagrant up &> ${LOG}/start.log
}

list() {
  init 
  if [ -z "$(ls -A ${VMSTORE})" ]; then
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

  for DIR in ${VMSTORE}/*; do
    cd ${DIR}/${BASE_DIR}
    . vm.cfg
    printf "$format" \
    "${ID}" "${VM_NAME}" "${HOST_ONLY_IP}" "${OS_IMAGE}" "${CPU}" "${RAM}" 
  done

}


# main is the entering point
# of the application
main() {
  setDefaultValues
  validateArgs "$@"
  validateAndSourceAppConfig
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
  fi
}

main "$@"