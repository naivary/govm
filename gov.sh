#!/bin/bash

trap trapExit INT;

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
    g)
      GROUP=${OPTARG}
      ;;
    ?)
      usage
      exit 1
      ;;
  esac
done


# <Groupname>_GROUP is the amount of POSIX-Arguments
# needed to run the group without any problems
MANUAL_GROUP=("-c" "-r" "-i" "-s" "-h" "-v" "-n")
FILE_GROUP=("-f" "-v")
GROUPUP_GROUP=("-g" "-v")
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
    "GIT_EMAIL"
    "GIT_NAME"
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

usage() {
  echo "-c [integer] is setting the count of CPUs"
  echo "-m [integer] is setting the RAM"
  echo "-i [integer] is setting the OS-Image"
  echo "-s [path] is setting the path to the provision-shell-script"
  echo "-h [ipv4] is setting the ip-adress for host-only of the type 192.168.56.0/24"
  echo "-f [path] is specifing the path to a *.config file with the parameters CPU, RAM, OS_IMAGE, IP and SCRIPT"
  echo "-v [up/halt/start/ssh/destroy] is setting the vagrant command you want to run (has to be present with every command.)"
  echo "You can also prefix any command with g for exampe gdestroy to destrpy a whole group (ssh is not possible)"
  echo "-d if this is present it will force a recreation of the vm if there is a virtual machine registered but not reachable"
  echo "-g [path] is setting the path to a directory with one or more *.cfg files to create a group of virtual-machines at once"
}

tips() {
  whiteBold "Thank you for using gov!"  
  whiteBold "Just a tip for the usage of gov: If you would like to interact"
  whiteBold "with a machine run gov -l get the machine-id and run the wished"
  whiteBold "command with -v and the machine id -m it is highly recommende to"
  whiteBold "run any command you want via gov and dont do it manualy so that"
  whiteBold "the data is always consistent with your current status."
  whiteBold "If you do anything manually gov can recover some but not all."
}

error() {
  printf "\u274c\033[1m\033[31m ${1}\033[0m\n"
}

infoBold() {
  printf "\033[1m\033[34m${1}\033[0m\n"
}

info() {
  printf "\033[34m${1}\033[0m\n"
}

success() {
  printf "\033[1m\033[32m${1} \xE2\x9C\x94\033[0m\n"
}

whiteBold() { 
  printf "\033[1m\033[37m${1}\033[0m\n"
}

setDefaultValues() {
  BASE_DIR=".govm"
  VMSTORE=${VMSTORE:-""}
  VM_LIST=${VM_LIST:-""}
  FORCE_DESTROY=${FORCE_DESTROY:-""}
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
  GOV_CONFIG=${BASEDIR}/${BASE_DIR}/gov.cfg
  IP_FILE=${BASEDIR}/${BASE_DIR}/used_ip.txt
  GROUP=${GROUP:-""}
}

rmSyncFolder() {
  if [[ -d "${VMSTORE}/${ID}" ]]; then
    sudo rm -r "${VMSTORE}/${ID}";
  fi 
}

clean() {
  infoBold "Cleaning up..."
  rmSyncFolder;
  removeIPFromFile;
  success "Destroyed ${ID}!"
}

IPID() {
  IP_TO_ID="$(grep ${1} ${IP_FILE} | cut -d '=' -f 1)"
}

IDIP() {
  IDIP="$(grep ${1} ${IP_FILE} | cut -d '=' -f 2)"
}

removeIPFromFile() {
  if grep -q -w "${HOST_ONLY_IP}" "${IP_FILE}"; then
    sed -i "/${HOST_ONLY_IP}/d" "${IP_FILE}";
  fi
}

trapExit() {
  infoBold "Graceful exiting...";
  rmSyncFolder;
}

successExitAfterCreation() {
  infoBold "Finishing touches...";
  createConfigFile;
  echo "${ID}=${HOST_ONLY_IP}" >> "${IP_FILE}";
  success "VM ${ID} is set and ready to go :)"
  tips;
}

successExitGroup() {
  infoBold "Finishing touches...";
  createConfigFile;
  echo "${ID}=${HOST_ONLY_IP}" >> "${IP_FILE}";
  success "VM ${ID} is set and ready to go :)"
}




setVagrantENV() {
  export CPU;
  export RAM;
  export OS_IMAGE;
  export SCRIPT;
  export HOST_ONLY_IP;
  export VM_NAME;
  export GIT_USERNAME;
  export GIT_PASSWORD;
  export GIT_NAME;
  export GIT_EMAIL;
  export OS_USERNAME;
  export OS_PASSWORD;
  # not set by User
  export SYNC_FOLDER;
}

resetVagrantENV() {
  export -n CPU;
  export -n RAM;
  export -n OS_IMAGE;
  export -n SCRIPT;
  export -n HOST_ONLY_IP;
  export -n VM_NAME;
  export -n GIT_USERNAME;
  export -n GIT_PASSWORD;
  export -n GIT_NAME;
  export -n GIT_EMAIL;
  export -n OS_USERNAME;
  export -n OS_PASSWORD;
  # not set by User
  export -n SYNC_FOLDER;

}



createConfigFile() {
  cd ${BASEDIR} 
  REALPATH_VM_CONFIG=$(realpath ${VM_CONFIG})
  cp ${REALPATH_VM_CONFIG} ${VMSTORE}/${ID}/${BASE_DIR}/vm.cfg
cat << EOF >> ${VMSTORE}/${ID}/${BASE_DIR}/vm.cfg
SYNC_FOLDER=${SYNC_FOLDER}
ID=${ID}
LOG_PATH=${LOG_PATH}
EOF
}

# preVagrantENV is creating the
# syncFolder for the VM and also
# the log folder to log to
preVagrantENV() {
  ID="$(openssl rand -hex 5)" 
  mkdir -p -- "${VMSTORE}/${ID}/${BASE_DIR}"
  mkdir -p -- "${VMSTORE}/${ID}/sync_folder"

  if [[ ${LOG} == "/log" ]]; then
    mkdir -p -- ${VMSTORE}/${ID}/${BASE_DIR}/logs
  fi

  LOG_PATH=${VMSTORE}/${ID}/${BASE_DIR}/logs
  SYNC_FOLDER="${VMSTORE}/${ID}/sync_folder"
  SCRIPT_NAME=$(basename ${SCRIPT})
}

# postVagrantENV is creating 
# directories and copying 
# all needed vagrant-files so that
# the vagrant commands can run in the
# newly created directory
postVagrantENV() {
  setVagrantENV;
  cp "${BASEDIR}/${BASE_DIR}/Vagrantfile" "${VMSTORE}/${ID}/${BASE_DIR}/Vagrantfile"
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
validateVMConfig() {
  GIVEN_PARAMS=()
  info "Loading ${VM_CONFIG}...";
  if [[  -s "${VM_CONFIG}" && "${VM_CONFIG}" == *.cfg ]]; then
    while read LINE
    do
      VALUE="$(echo -e "${LINE}" | tr -d '[:space:]')"
      if ! [[ "${VALUE}" =~ ^([A-Za-z0-9_]+)=([^'#'$%'&''*'^]+$) ]]; then
        [[ "${LINE}" =~ ^\#.*$ || -z "${LINE}" ]] && continue
        error "DID not match ${VALUE}"
        exit 1
      else
        NAME="${BASH_REMATCH[1]}"
        if ! [[ "${VALID_CONFIG_PARAMS_VM[*]}" =~ "${NAME}" || "${GIVEN_PARAMS[*]}" =~ ${NAME} ]]; then
          error "Unexpected Key ${NAME}"
          exit 1
        else 
          GIVEN_PARAMS+=("${NAME}")
        fi
      fi
    done < ${VM_CONFIG}

  if [[ ${#GIVEN_PARAMS[@]} -eq ${#VALID_CONFIG_PARAMS_VM[@]} ]]; then
    success "Valid! ${VM_CONFIG}" 
  else 
    error "Not Enough Arguments"
    echo "Expected: ${VALID_CONFIG_PARAMS_VM[@]}"
    exit 1
  fi
  
  else 
    error "*.cfg is not existing or is empty or has the wrong extension (expected: .cfg)"
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
  info "Loading ${GOV_CONFIG}...";
  if [[  -s "${GOV_CONFIG}" ]]; then
    while read LINE
    do
      VALUE="$(echo -e "${LINE}" | tr -d '[:space:]')"
      if ! [[ "${VALUE}" =~ ^([^'#']+)=([^'#'$%'&''*'^]+$) ]]; then
        [[ "${LINE}" =~ ^\#.*$ || -z "${LINE}" ]] && continue
        error "Did not match ${NAME}"
        exit 1
      else
        NAME="${BASH_REMATCH[1]}"
        if ! [[ "${VALID_CONFIG_PARAMS_APP[*]}" =~ "${NAME}" || "${GIVEN_PARAMS[*]}" =~ ${NAME} ]]; then
          error "Unexpected Key ${NAME}"
          exit 1
        else 
          GIVEN_PARAMS+=("${NAME}")
        fi
      fi
    done < ${GOV_CONFIG}

    if [[ ${#GIVEN_PARAMS[@]} -eq ${#VALID_CONFIG_PARAMS_APP[@]} ]]; then
      success "Valid! Sourcing ${GOV_CONFIG}" 
      sourceFile ${GOV_CONFIG}
    else 
      error "Not Enough Arguments"
      echo "Expected: ${VALID_CONFIG_PARAMS_APP[@]}"
      exit 1
    fi

  else 
    error "gov.cfg is not existing or is empty or has the wrong extension (expected: .cfg)"
    exit 1
  fi
}


# validateVMInput is  checking if 
# all given VM-Configs are the type 
# that they has to be like 
# CPU should be an integer not 
# a word etc.
validateVMInput() {
  info "Validating Virtual-Machine parameters..."
  if ! [[ "${CPU}" =~ ^[0-9]+$ && "${CPU}" -ge 1 && "${CPU}" -le 100 ]]; then
    error "CPU may only contain numbers and shall be bigger than 1";
    exit 1;
  elif ! [[ "${RAM}" =~ ^[0-9]+$ && "${RAM}" -ge 512  && "${RAM}" -le 16000 ]]; then
    error "Memory may only contain numbers and shall be bigger than 4";
    exit 1;
  elif ! [[ -s "${SCRIPT}" ]]; then
    error "Shell-script not found or empty";
    exit 1;
  elif ! [[ "${HOST_ONLY_IP}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    error "Invalid IP-Adress";
    exit 1;
  elif ! validateIP;then
    exit 1
  elif ! [[ ${GIT_PASSWORD} =~ ^(ghp_)([A-Za-z0-9]{36})$ ]];then
    error "Invalid Git-Password"
  else 
    success "Valid VM-Values!" 
    return 0
  fi
}

# validateAppInput is checking if 
# the given values are valid and is setting 
# defaults if needed
validateAppInput() {
  info "Validating App-Configuration parameters..."
  if ! [[ -d ${VMSTORE} ]]; then
    mkdir -p -- ${VMSTORE}
  elif ! [[ ${LOG} == "/log" ]]; then
    mkdir -p -- ${LOG}/log
  else
    success "Valid GOV-Values!"
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
    error "Machine with the IP: ${HOST_ONLY_IP} exists. Choose an other IP-Adress. (Ping successfull)"
    exit 1
  fi

  # check if ip exist within machine-ecosystem
  grep -q -w "${HOST_ONLY_IP}" ${IP_FILE}  

  if [[ "$?" -eq 0 && -z "${FORCE_DESTROY}" ]]; then
    IPID ${HOST_ONLY_IP}
    error "Machine still existing in our system ID: ${IP_TO_ID}. Run Command with -d to force recreation."    
    exit 1
  fi

  grep -q -w ${HOST_ONLY_IP} ${IP_FILE}

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
# of the given flags. These are validated in
# validateInput. Here we validate the given flags
# and if they can be used together 
# using groups.
validateArgs() {
  CHECK_MANUAL=()
  CHECK_FILE=()
  CHECK_VAGRANT=()
  CHECK_GROUPUP=()
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
      elif [[ "${GROUPUP_GROUP[*]}" =~ "${ARG}" && "${ARG}" != "-v" ]]; then
        CHECK_GROUPUP=("${ARG}")
      elif [[ "${ARG}" == "-v" ]]; then
        VAGRANT_COMMAND_GIVEN="true"
      elif [[ "${LIST_GROUP[*]}" =~ "${ARG}" && "${ARG}" != "-v" ]]; then
        CHECK_LIST+=("${ARG}")
      fi
    fi
  done

  if [[ "${#CHECK_MANUAL[@]}" -eq $(( ${#MANUAL_GROUP[@]} -1 )) && "${#CHECK_FILE[@]}" -eq 0 && "${#CHECK_VAGRANT[@]}" -eq 0 && "${#CHECK_LIST[@]}" -eq 0 && "${VAGRANT_COMMAND_GIVEN}" == "true" ]]; then
    infoBold "Starting creation process..."
    IS_MANUAL="true"
  elif [[ "${#CHECK_MANUAL[@]}" -eq 0 && "${#CHECK_FILE[@]}" -eq $(( ${#FILE_GROUP[@]} -1 )) && "${#CHECK_VAGRANT[@]}" -eq 0 && "${#CHECK_LIST[@]}" -eq 0 && "${VAGRANT_COMMAND_GIVEN}" == "true" ]]; then
    infoBold "Starting creation process"
    IS_FILE="true"
  elif [[ "${#CHECK_MANUAL[@]}" -eq 0 && "${#CHECK_FILE[@]}" -eq 0 && "${#CHECK_VAGRANT[@]}" -eq $(( ${#VAGRANT_GROUP[@]} -1 )) && "${#CHECK_LIST[@]}" -eq 0 && "${VAGRANT_COMMAND_GIVEN}" == "true" ]]; then
    infoBold "Running command..."
  elif [[ "${#CHECK_MANUAL[@]}" -eq 0 && "${#CHECK_FILE[@]}" -eq 0 && "${#CHECK_VAGRANT[@]}" -eq 0 && "${#CHECK_LIST[@]}" -eq ${#LIST_GROUP[@]} && "${VAGRANT_COMMAND_GIVEN}" == "false" ]]; then
    infoBold "Listing all virtual-machines..."
  elif [[ "${#CHECK_MANUAL[@]}" -eq 0 && "${#CHECK_FILE[@]}" -eq 0 && "${#CHECK_VAGRANT[@]}" -eq 0 && "${#CHECK_LIST[@]}" -eq 0 && "${VAGRANT_COMMAND_GIVEN}" == "true" && "${#CHECK_GROUPUP[@]}" -eq  $(( ${#GROUPUP_GROUP[@]} -1 )) ]]; then
    infoBold "Creating all given virtual-machines..."
  else
    error "Too many or not enough arguments"
    usage;
    exit 1
  fi

}

# createVagrantENV is
# sourcing the config file
# in the ${VMSTORE}/${ID}
# and is running the given command afterwards
# otherwise the Vagrantfile cannot pull
# the ENV-Variables
createVagrantENV() {
  grep -q -w "${VIRTUAL_MACHINE}" ${IP_FILE}  

  if [[ "${?}" -ne 0 ]]; then
    error "${VIRTUAL_MACHINE} does not exist!"
    infoBold "run gov -l for a listing of all virtual-machines"
    exit 1
  fi

  init;
  cd ${VMSTORE}/${VIRTUAL_MACHINE}/${BASE_DIR}
  sourceFile vm.cfg;
  setVagrantENV;
}

createVM() {
  infoBold "Creating Virtual-Machine ${ID}. This may take a while..."
  vagrant up &> ${LOG_PATH}/up.log 
}

# fileUp is creating
# a virtual-machine based
# on a given config file
# and the values 
fileUp() {  
  init;
  validateVMConfig;
  sourceFile ${VM_CONFIG}
  validateVMInput && preVagrantENV;
  postVagrantENV;
  cd ${VMSTORE}/${ID}/${BASE_DIR};
  createVM && successExitAfterCreation || error "Something went wrong. Debbuging information can be found at ${LOG_PATH}"

}

# manualUp is creating
# a virtual-machine based
# on the arguments given
# in the command-line
# NOTE: this is not recommended 
# because the commands will get 
# really big. fileUp is the recommend 
# way
manualUp() {
  init;
  validateVMInput && preVagrantENV;
  postVagrantENV;
  cd ${VMSTORE}/${ID}/${BASE_DIR};
  createVM && successExitAfterCreation || error "Something went wrong. Debbuging information can be found at ${LOG_PATH}"
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

# alias to vagrant destroy
destroy() {
  infoBold "Destroying ${VIRTUAL_MACHINE}..."
  createVagrantENV;
  vagrant destroy --force &> /dev/null;
  cd ${BASEDIR}; 
  clean;
}



halt() {
  info "Stopping ${VIRTUAL_MACHINE}..."
  createVagrantENV;
  vagrant halt &> /dev/null;
  success "Stopped ${VIRTUAL_MACHINE}!"
}

vssh() {
  info "SSH into ${VIRTUAL_MACHINE}"
  createVagrantENV;
  vagrant ssh;
}

start() {
  info "Starting ${VIRTUAL_MACHINE}. This may take some time..."
  createVagrantENV;
  vagrant up &> ${LOG_PATH}/start.log
  success "${VIRTUAL_MACHINE} up and running!"
}

list() {
  init; 
  if [ -z "$(ls -A ${VMSTORE})" ]; then
    infoBold "No Machines have been created yet!"
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

# groupUp is just a helper for 
# starting the virtual machines
# without the any validaton
# before it
groupUp() {
  preVagrantENV;
  postVagrantENV;
  cd ${VMSTORE}/${ID}/${BASE_DIR};
  createVM && successExitGroup || error "Something went wrong. Debbuging information can be found at ${LOG_PATH}"
}

# group is creating
# as many virtuals machines 
# as configs files given in the 
# given directory
gUp() {
  init
  IP_ADRESSES=()
  NAMES=()

  # checking syntax of all configs files
  for CFG in ${GROUP}/*.cfg; 
  do
    VM_CONFIG="${CFG}"
    validateVMConfig
  done

  # checking for duplication of ip or names in the given group
  for CFG in ${GROUP}/*.cfg;
  do
    sourceFile "${CFG}"
    if [[ "${IP_ADRESSES[*]}" =~ "${HOST_ONLY_IP}" ]]; then
      error "Duplicated IP-Adress ${HOST_ONLY_IP}"
      exit 1
    elif [[ "${NAMES[*]}" =~ "${VM_NAME}" ]]; then
      error "Duplicated name: ${VM_NAME}"
      exit 1
    else 
      IP_ADRESSES=("${HOST_ONLY_IP}")
      NAMES=("${VM_NAME}")
    fi
  done

  # checking if the values
  # files of the config
  for CFG in ${GROUP}/*.cfg; 
  do
    cd "${BASEDIR}"
    sourceFile "${CFG}"
    validateVMInput 
  done

  info "Starting creation process..."

  # starting creation of all
  # virtual machines
  for CFG in ${GROUP}/*.cfg; 
  do
    VM_CONFIG=${CFG}
    info "Creating $(basename ${CFG})..."
    cd "${BASEDIR}"
    resetVagrantENV
    sourceFile "${CFG}";
    groupUp
  done

}

# gDestroy is an alias
# for vagrant destroy 
# but build for a group
# destruction
gDestroy() {
  init
  for CFG in ${GROUP}/*.cfg; 
  do
    VM_CONFIG=${CFG}
    cd "${BASEDIR}"
    resetVagrantENV
    sourceFile "${CFG}";
    IPID "${HOST_ONLY_IP}"
    cd ${VMSTORE}/${IP_TO_ID}/${BASE_DIR}
    VIRTUAL_MACHINE=${IP_TO_ID}
    destroy
  done
}

# gDestroy is an alias
# for vagrant destroy 
# but build for a group
# destruction
gHalt() {
  init
  for CFG in ${GROUP}/*.cfg; 
  do
    VM_CONFIG=${CFG}
    cd "${BASEDIR}"
    resetVagrantENV
    sourceFile "${CFG}";
    if ! ping -c 2 "${HOST_ONLY_IP}" &> /dev/null; then
      error "Machine not reachable! Do they even run?"
      exit 1
    fi
    IPID "${HOST_ONLY_IP}"
    if [[ "${IP_TO_ID}" ]]; then
      cd ${VMSTORE}/${IP_TO_ID}/${BASE_DIR}
      VIRTUAL_MACHINE=${IP_TO_ID}
      halt
    else
      error "Did not find the machines! Do they even run?"
    fi
  done
}

gStart() {
  init
  for CFG in ${GROUP}/*.cfg; 
  do
    VM_CONFIG=${CFG}
    cd "${BASEDIR}"
    resetVagrantENV
    sourceFile "${CFG}";
    IPID "${HOST_ONLY_IP}"
    VIRTUAL_MACHINE=${IP_TO_ID}
    start
  done
}


# main is the entering point
# of the application
main() {
  setDefaultValues
  validateArgs "$@"
  validateAndSourceAppConfig;
  validateAppInput;
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
  elif [[ "${VAGRANT_CMD}" == "gup" && -d "${GROUP}" ]]; then
    gUp; 
  elif [[ "${VAGRANT_CMD}" == "gstart" && -d "${GROUP}" ]]; then
    gStart
  elif [[ "${VAGRANT_CMD}" == "gdestroy" && -d "${GROUP}" ]]; then
    gDestroy
  elif [[ "${VAGRANT_CMD}" == "ghalt" && -d "${GROUP}" ]]; then
    gHalt
  elif [[ "${VM_LIST}" ]]; then
    list
  else 
    error "Wrong arguments or not enough arguments"
    usage
  fi
}

main "$@"
