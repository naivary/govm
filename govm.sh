#!/bin/bash

trap trapexit INT;

usage() {
  echo "-m [integer] is setting the Machine"
  echo "-f [path] is specifing the path to a *.config file with the parameters CPU, RAM, OS_IMAGE, IP and SCRIPT"
  echo "-v [up/halt/start/ssh/destroy] is setting the vagrant command you want to run (has to be present with every command.)"
  echo "You can also prefix any command with g for exampe gdestroy to destroy a whole group (ssh is not possible)"
  echo "-d if this is present it will force a recreation of the vm if there is a virtual machine registered but not reachable"
  echo "-g [path] is setting the path to a directory with one or more *.cfg files to create a group of virtual-machines at once"
}

while getopts "f:g:v:m:ld" OPT; do
  case "${OPT}" in
    f)
      VM_CONFIG=${OPTARG}
      ;;
    v)
      VAGRANT_CMD=${OPTARG}
      ;;
    m)
      ID=${OPTARG}
      ;;
    l)
      VM_LIST="show"
      ;;
    d)
      FORCE_DESTROY="force"
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
FILE_GROUP=("-f" "-v")
GROUPCMD_GROUP=("-g" "-v")
VAGRANT_GROUP=("-v" "-m")
LIST_GROUP=("-l")
VALID_CONFIG_PARAMS_VM=(
    "CPU"
    "RAM"
    "OS_IMAGE"
    "OS_TYPE"
    "SCRIPT"
    "SYNC_FOLDER"
    "HOST_ONLY_IP"
    "VM_NAME"
    "PROVISION_VARIABLES"
    "DISK_SIZE_PRIMARY"
    "DISK_SIZE_SECOND"
    "MOUNTING_POINT"
    "FILE_SYSTEM"
)

OPTIONAL_CONFIG_PARAMS_VM=(
  "CPU"
  "RAM"
  "OS_IMAGE"
  "OS_TYPE"
  "SCRIPT"
  "SYNC_FOLDER"
  "VM_NAME"
  "DISK_SIZE_PRIMARY"
  "DISK_SIZE_SECOND"
  "MOUNTING_POINT"
  "FILE_SYSTEM"
  "PROVISION_VARIABLES"
)

VALID_CONFIG_PARAMS_APP=(
  "VMSTORE"
  "VAGRANTFILE"
  "PROVISION_DIR"
  "CONFIG_DIR"
  "APPLIANCESTORE"
  "BRIDGE_OPTIONS"
  "LOG"
  "CPU"
  "RAM"
  "OS_IMAGE"
  "SCRIPT"
)

OPTIONAL_CONFIG_PARAMS_APP=(
  "VMSTORE"
  "VAGRANTFILE"
  "PROVISION_DIR"
  "CONFIG_DIR"
  "APPLIANCESTORE"
  "LOG"
)

SUPPORTED_FILE_SYSTEMS=(
  "ext3"
  "ext4"
  "xfs"
)
UNSUPPORTED_MOUNTING_POINTS=(
  "/"
  "/root"
  "/etc"
  "/var"
)

SUPPORTED_OS_TYPES=(
  "linux"
  "windows"
)
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


ads() {
  whitebold "Thank you for using govm!"  
  whitebold "For the usage read the README file."
  whitebold "If you would like to support me, star"
  whitebold "the repository!"
}


error() {
  printf "\u274c\033[1m\033[31m ${1}\033[0m\n"
}

infobold() {
  printf "\033[1m\033[34m${1}\033[0m\n"
}

info() {
  printf "\033[34m${1}\033[0m\n"
}

success() {
  printf "\033[1m\033[32m${1} \xE2\x9C\x94\033[0m\n"
}

whitebold() { 
  printf "\033[1m\033[37m${1}\033[0m\n"
}

# predefault is setting
# all defaults that do not
# dependent on govm.cfg
predefault() {
  # appliaction
  ALREADY_CREATED_VMS=()
  REQUIRED_PARAMS_CONFIG_VM=$(( ${#VALID_CONFIG_PARAMS_VM[@]} - ${#OPTIONAL_CONFIG_PARAMS_VM[@]} ))
  REQUIRED_PARAMS_CONFIG_APP=$(( ${#VALID_CONFIG_PARAMS_APP[@]} - ${#OPTIONAL_CONFIG_PARAMS_APP[@]} ))
  GOVM=".govm"
  DEFAULT_VM="default.cfg"
  VM_LIST=${VM_LIST:-""}
  VM_NAMES=()
  FORCE_DESTROY=${FORCE_DESTROY:-""}
  REALPATH=$(realpath ${0})
  BASEDIR=$(dirname ${REALPATH})
  DB=${BASEDIR}/${GOVM}/db.txt
  TIMESTAMP=$(date '+%s')
  VAGRANT_CMD=${VAGRANT_CMD:-""}
  PROVISION_DIR_NAME="provision"
  CURRENT_OS=$(uname -r | sed -n 's/.*\( *Microsoft *\).*/\1/ip')

  # govm.cfg
  GOVM_CONFIG="${BASEDIR}/${GOVM}/govm.cfg"
  GOVM_NAME="$(basename ${GOVM_CONFIG})"
  PROVISION_DIR=${PROVISION_DIR:-"${BASEDIR}/${PROVISION_DIR_NAME}"}
  CONFIG_DIR=${CONFIG_DIR:-"${BASEDIR}/config"}
  VAGRANTFILE=${VAGRANTFILE:-${BASEDIR}/${GOVM}/Vagrantfiles/linux}
  VMSTORE=${VMSTORE:-${HOME}/${GOVM}}
  APPLIANCESTORE=${APPLIANCESTORE:-${HOME}/"${GOVM}_appliance"}
  LOG=${LOG:-"/log"}
  SCRIPT=${SCRIPT:-"nil"}
  BRIDGE_OPTIONS=${BRIDGE_OPTIONS:-()}

  # vm.cfg
  HASH_TABLE_STRING=${HASH_TABLE_STRING:-"govm:govm"}
  GROUP=${GROUP:-""}
  VM_CONFIG=${VM_CONFIG:-"${BASEDIR}/${GOVM}/${DEFAULT_VM}"}
  SCRIPT_VAGRANT=${PROVISON_DIR_NAME}/${SCRIPT_NAME}
  PROVISION_VARIABLES=${PROVISION_VARIABLES:-""}
  OS_TYPE=${OS_TYPE:-linux}
  SYNC_USER=${SYNC_USER:-"vagrant"}
  getid 192.168.56.2
  getvmname 192.168.56.2
  HOST_ONLY_IP=${HOST_ONLY_IP:-""}
  SYNC_FOLDER=${SYNC_FOLDER:-""}
  VM_NAME=${VM_NAME:-""}
  DISK_SIZE_SECOND=${DISK_SIZE_SECOND:-""}
  DISK_SIZE_PRIMARY=${DISK_SIZE_PRIMARY:-""}
  MOUNTING_POINT=${MOUNTING_POINT:-"nil"}
  FILE_SYSTEM=${FILE_SYSTEM:-"nil"}
  GIT_USERNAME=${GIT_USERNAME:-""}
  GIT_PASSWORD=${GIT_PASSWORD:-""}
  GIT_EMAIL=${GIT_EMAIL:-""}
  GIT_NAME=${GIT_NAME:-""}
  OS_USERNAME=${OS_USERNAME:-""}
  OS_PASSWORD=${OS_PASSWORD:-""}
}

# postdefault is setting
# all defaults that depend
# on govm.cfg or other
# dependencies that are not 
# yet been set
# postdefault() {}


osdefault() {
  if [[ "${CURRENT_OS}" == "microsoft" ]]; then
    APPLIANCESTORE="$(wslpath -w ${APPLIANCESTORE})"
  fi
}

clearoptionalargs() {
  DISK_SIZE_SECOND=""
  DISK_SIZE_PRIMARY=""
}


rmgovm() {
  if [[ -d "${VMSTORE}/${ID}" ]]; then
    rmdirrf "${VMSTORE}/${ID}";
  fi 
}

# rmlogdir is removing
# the log directory if the
# directory is not the default
rmlogdir() {
  if [[ -d "${LOG_PATH}/${ID}" ]]; then
    rmdirrf "${LOG_PATH}/${ID}"
  fi
}

# clean is called after
# destroyed. it will not 
# handle interrupt
# it is removing the 
clean() {
  infobold "Cleaning up..."
  rmgovm;
  rmip;
  rmlogdir;
  success "Destroyed ${ID}!"
}

leftcut() {
  LEFTSIDE="$(cut -d ':' -f 1 <<< ${1})"
}

rightcut() {
  RIGHTSIDE="$(cut -d ':' -f 2 <<< ${1})"
}

getid() {
  local id
  id="$(grep -w ${1} ${DB} | cut -d ':' -f 1)"
  if [[ ${id} ]]; then
    ID="${id}"
  else 
    ID=${ID:-"nil"}
  fi
}

getvmname() {
  local name
  name="$(grep ${1} -w ${DB} | cut -d ':' -f 2)"
  if [[ ${name} ]]; then
    VM_NAME=${name}
  fi
}

getos() {
  local os
  os="$(grep ${1} -w ${DB} | cut -d ':' -f 3)"
  if [[ ${os} ]]; then
    OS_IMAGE=${OS_IMAGE:-os}
  else
    OS_IMAGE=${OS_IMAGE:-"nil"}
  fi
}

getip() {
  local ip
  ip="$(grep ${1} -w ${DB} | cut -d ':' -f 4)"

  if [[ ${ip} ]]; then
    HOST_ONLY_IP=${HOST_ONLY_IP:-ip}
  else
    HOST_ONLY_IP=${HOST_ONLY_IP:-"nil"}
  fi
}

govmpath() {
  GOVM_PATH="${VMSTORE}/${ID}/${GOVM}"
}

# rmip is removing the
# ip-adress from the file
rmip() {
  if grep -q -w "${HOST_ONLY_IP}" "${DB}"; then
    sed -i "/${HOST_ONLY_IP}/d" "${DB}";
  fi
}

makedir() {
  mkdir -p -- "${1}"
}

# rmdirrf is removing
# a directory recusively 
# by forcing it
rmdirrf() {
  sudo rm -rf "${1}"
}

isvmrunning() {
  vboxmanage.exe list runningvms | grep -q -w "${1}" 
  echo "$?"
}

isvmexisting() {
  vboxmanage.exe list vms | grep -q -w "${1}"
  echo "$?"
}

appliancesemver() {
  APPLIANCE_NAME=${1}
  VERSION=1

  if [[ ! -d ${APPLIANCESTORE}/${APPLIANCE_NAME} ]]; then
    makedir "${APPLIANCESTORE}/${APPLIANCE_NAME}"
  fi

  while [[ -s "${APPLIANCESTORE}/${APPLIANCE_NAME}/${APPLIANCE_NAME}-v${VERSION}.0.ova" ]];
  do
    VERSION=$((VERSION+1))
  done

  APPLIANCE_NAME="${APPLIANCE_NAME}-v${VERSION}.0.ova"
}

trapexitup() {
  vagrant destroy --force &> "${LOG_PATH}/${TIMESTAMP}_destroy.log"
  rmgovm;
  rmip;
  rmlogdir;
  infobold "Cleaned ${1}"
}

trapexit() {
  if [[ "${VAGRANT_CMD}" == "up" ]]; then
    infobold "Graceful exiting. Trying to clean as much as possible...";
    trapexitup "${VM_NAME}"
  elif [[ "${VAGRANT_CMD}" == "gup" ]]; then
    infobold "Graceful exiting. Trying to clean as much as possible...";
    trapexitgroup
  else 
    infobold "Nothing to clean up. Exiting!"
  fi
}

trapexitgroup() {
  for CFG in ${ALREADY_CREATED_VMS[@]}
  do
    leftcut ${CFG}
    rightcut ${CFG}
    VM_CONFIG=${LEFTSIDE}    
    ID=${RIGHTSIDE}
    cd "${GOVM_PATH}"
    sourcefile vm.cfg
    trapexitup "${ID}"
  done
}

successexit() {
  infobold "Finishing touches...";
  echo "${ID}:${VM_NAME}:${OS_IMAGE}:${HOST_ONLY_IP}:${RAM}:${CPU}" >> "${DB}";
  success "VM ${ID} is set and ready to go :)"
  ads;
}

gsuccessexit() {
  infobold "Finishing touches...";
  echo "${ID}:${VM_NAME}:${OS_IMAGE}:${HOST_ONLY_IP}:${RAM}:${CPU}" >> "${DB}";
  success "VM ${ID} is set and ready to go :)"
}

hashtablegen() {
  HASH_TABLE_STRING=${PROVISION_VARIABLES[@]}
  local i=0
  if [[ ${#PROVISION_VARIABLES[@]} -gt 0 ]]; then
    for PAIR in "${PROVISION_VARIABLES[@]}"
    do
      if ! [[ "${PAIR}" =~ ':' ]]; then
        PAIR="${PAIR}:${PAIR}"
      fi

      leftcut "${PAIR}"

      if [[ "${LEFTSIDE}" == "os_user" ]]; then
        rightcut "${PAIR}"
        SYNC_USER=${RIGHTSIDE}
      fi

      if [[ ${i} -eq 0 ]]; then
        HASH_TABLE_STRING="${PAIR}" 
      else
        HASH_TABLE_STRING="${HASH_TABLE_STRING},${PAIR}" 
      fi
      i=$((i+1))
    done
  else
    error "Empty PROVISION_VARIABLES Array: ${PROVISION_VARIABLES}"
    error "If you dotn want to have any comment it out"
    exit 1
  fi
}

bridgeoptiongen() {
  local i=0
  if [[ ${#BRIDGE_OPTIONS[@]} -gt 0 ]]; then
    for VALUE in "${BRIDGE_OPTIONS[@]}"
    do
      if [[ ${i} -eq 0 ]]; then
        BRIDGE_OPTION_STRING="${VALUE}" 
      else
        BRIDGE_OPTION_STRING="${BRIDGE_OPTION_STRING},${VALUE}" 
      fi
      i=$((i+1))
    done
  else
    error "Empty BRIDGE_OPTIONS Array!"
    infobold "Your options are:"
    vmlistbridgedlifs
    exit 1
  fi
}

setvenv() {
  export CPU;
  export RAM;
  export OS_IMAGE;
  export SCRIPT;
  export HOST_ONLY_IP;
  export VM_NAME;
  export DISK_SIZE_PRIMARY
  export DISK_SIZE_SECOND
  export MOUNTING_POINT
  export FILE_SYSTEM
  export HASH_TABLE_STRING
  export BRIDGE_OPTION_STRING
  export VAGRANT_EXPERIMENTAL="disks"
  export SYNC_FOLDER;
  export SYNC_USER
}

resetvenv() {
  export -n CPU;
  export -n RAM;
  export -n OS_IMAGE;
  export -n SCRIPT;
  export -n HOST_ONLY_IP;
  export -n VM_NAME;
  export -n DISK_SIZE_PRIMARY
  export -n DISK_SIZE_SECOND
  export -n MOUNTING_POINT
  export -n FILE_SYSTEM
  export -n HASH_TABLE_STRING
  export -n BRIDGE_OPTION_STRING
  export -n SYNC_FOLDER;
  export -n SYNC_USER

}

setvfile() {
  if [[ "${OS_TYPE}" == "windwos" ]]; then
    VAGRANTFILE=${BASEDIR}/${GOVM}/Vagrantfiles/windows
  fi
}

# createcfg is copying the used
# config file for the creation
# and is appending some extra 
# information to it
createcfg() {
  cd ${BASEDIR} 
  REALPATH_VM_CONFIG=$(realpath ${VM_CONFIG})
  cp ${REALPATH_VM_CONFIG} ${GOVM_PATH}/vm.cfg
cat << EOF >> ${GOVM_PATH}/vm.cfg

# CREATED BY GOVM. DO NOT EDIT DATA! 
SYNC_FOLDER=${SYNC_FOLDER}
ID=${ID}
LOG_PATH=${LOG_PATH}
HASH_TABLE_STRING="${HASH_TABLE_STRING}"
EOF
}

# prepvenv is creating the
# syncFolder for the VM and also
# the log folder to log to
prepvenv() {
  ID="$(openssl rand -hex 5)"
  govmpath
  makedir "${GOVM_PATH}"
  makedir "${VMSTORE}/${ID}/sync_folder"

  if [[ ${LOG} == "/log" ]]; then
    makedir "${GOVM_PATH}/logs"
    LOG_PATH=${GOVM_PATH}/logs
  else 
    LOG_PATH=${LOG}/${ID}
    makedir "${LOG_PATH}"
  fi
  SYNC_FOLDER=${SYNC_FOLDER:-"${VMSTORE}/${ID}/sync_folder"}
  VM_NAME="${VM_NAME:-${HOST_ONLY_IP}_${ID}}"
  SCRIPT_NAME=$(basename ${SCRIPT})
}

# postvenv is creating 
# directories and copying 
# all needed vagrant-files so that
# the vagrant commands can run in the
# newly created directory
postvenv() {
  setvenv;
  setvfile
  cp "${VAGRANTFILE}" "${GOVM_PATH}/Vagrantfile"
  DIR_NAME=$(dirname ${SCRIPT})
  makedir ${GOVM_PATH}/${DIR_NAME}
  cp "${PROVISION_DIR}/${SCRIPT}" "${GOVM_PATH}/${SCRIPT}"
  createcfg;
}

#sourcefile is sourcing the
# given file into the current
# shell-ENV
sourcefile() {
  dos2unix "${1}" &> /dev/null
  . "${1}"
  govmpath
}

# validateAndSourceVMConfig
# is validating the config file
# for the virtual-machine (syntax only)
# meaning duplicated keys or not enough
# keys and if the config file is valid 
# it is getting sourced.
validatevmcfg() {
  local config_name=$(basename "${VM_CONFIG}")
  GIVEN_PARAMS_REQUIRED=()
  GIVEN_PARAMS_OPTIONAL=()
  info "Loading ${config_name}...";
  if [[  -s "${VM_CONFIG}" && "${VM_CONFIG}" == *.cfg ]]; then
    while read LINE
    do
      VALUE="$(echo -e "${LINE}" | tr -d '[:space:]')"
      if ! [[ "${VALUE}" =~ ^([A-Za-z0-9_]+)=([^'#'$%'&''*'^]+$) ]]; then
        [[ "${VALUE}" =~ ^\#.*$ || -z "${VALUE}" ]] && continue
        error "Wrong syntax: ${VALUE}"
        exit 1
      else
        NAME="${BASH_REMATCH[1]}"
        if [[ "${GIVEN_PARAMS_REQUIRED[*]}" =~ "${NAME}" || "${GIVEN_PARAMS_OPTIONAL[*]}" =~ "${NAME}" ]]; then
          error "Key duplicated ${NAME}"
          exit 1
        elif ! [[ "${VALID_CONFIG_PARAMS_VM[*]}" =~ "${NAME}" ]]; then
          error "Unexpected key ${NAME}"
          exit 1
        elif [[ "${OPTIONAL_CONFIG_PARAMS_VM[*]}" =~ "${NAME}" ]]; then
          GIVEN_PARAMS_OPTIONAL+=("${NAME}")
        elif [[ "${VALID_CONFIG_PARAMS_VM[*]}" =~ "${NAME}" ]]; then
          GIVEN_PARAMS_REQUIRED+=("${NAME}")
        fi
      fi
    done < ${VM_CONFIG}
  if [[ ${#GIVEN_PARAMS_REQUIRED[*]} -eq ${REQUIRED_PARAMS_CONFIG_VM} ]]; then
    success "Valid Syntax and Arguments for ${config_name}" 
  else 
    error "Not Enough Arguments"
    error "Valid-Arguments: ${VALID_CONFIG_PARAMS_VM[*]}"
    error "Optional: ${OPTIONAL_CONFIG_PARAMS_VM[*]}"
    exit 1
  fi
  
  else 
    error "*.cfg is not existing or is empty or has the wrong extension (expected: .cfg)"
    exit 1
  fi
}

# validateappcfg
# is validating the config file
# for the application (syntax only)
# and if the config file is valid 
# it is getting sourced.
validateappcfg() {
  GIVEN_PARAMS_OPTIONAL=()
  GIVEN_PARAMS_REQUIRED=()
  info "Loading ${GOVM_NAME}...";
  if [[  -s "${GOVM_CONFIG}" ]]; then
    while read LINE
    do
      VALUE="$(echo -e "${LINE}" | tr -d '[:space:]')"

      if ! [[ "${VALUE}" =~ ^([^'#']+)=([^'#'$%'&''*'^]+$) ]]; then
        [[ "${VALUE}" =~ ^\#.*$ || -z "${VALUE}" ]] && continue
        error "Did not match ${VALUE}"
        exit 1
      else
        NAME="${BASH_REMATCH[1]}"
       if [[ "${GIVEN_PARAMS_REQUIRED[*]}" =~ "${NAME}" || "${GIVEN_PARAMS_OPTIONAL[*]}" =~ "${NAME}" ]]; then
          error "Key duplicated ${NAME}"
          exit 1
        elif ! [[ "${VALID_CONFIG_PARAMS_APP[*]}" =~ "${NAME}" ]]; then
          error "Unexpected key ${NAME}"
          exit 1
        elif [[ "${OPTIONAL_CONFIG_PARAMS_APP[*]}" =~ "${NAME}" ]]; then
          GIVEN_PARAMS_OPTIONAL+=("${NAME}")
        elif [[ "${VALID_CONFIG_PARAMS_APP[*]}" =~ "${NAME}" ]]; then
          GIVEN_PARAMS_REQUIRED+=("${NAME}")
        fi
      fi
    done < ${GOVM_CONFIG}

    if [[ ${#GIVEN_PARAMS_REQUIRED[@]} -eq ${REQUIRED_PARAMS_CONFIG_APP} ]]; then
      success "Valid! Sourcing ${GOVM_NAME}" 
    else 
      error "Not Enough Arguments"
      error "Expected: ${VALID_CONFIG_PARAMS_APP[*]}"
      exit 1
    fi

  else 
    error "govm.cfg is not existing or is empty."
    exit 1
  fi
}


# validaterequiredvmargs is  checking if 
# all given VM-Configs are the type 
# that they has to be like 
# CPU should be an integer not 
# a word and so on
validaterequiredvmargs() {
  local config_name=$(basename "${VM_CONFIG}")
  info "Validating required arguments values of ${config_name}..."
  if ! [[ "${CPU}" =~ ^[0-9]+$ && "${CPU}" -ge 1 && "${CPU}" -le 100 ]]; then
    error "CPU may only contain numbers and shall be bigger than 1";
    exit 1;
  elif ! [[ "${RAM}" =~ ^[0-9]+$ && "${RAM}" -ge 512  && "${RAM}" -le 16000 ]]; then
    error "Memory may only contain numbers and shall be bigger than 4";
    exit 1;
  elif ! [[ -s "${PROVISION_DIR}/${SCRIPT}" ]]; then
    error "Shell-script not found or empty: ${PROVISION_DIR}/${SCRIPT}";
    exit 1;
  elif ! [[ "${HOST_ONLY_IP}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    error "Invalid IP-Adress";
    exit 1;
  elif ! [[ "${SUPPORTED_OS_TYPES[@]}" =~ "${OS_TYPE}" ]]; then
    error "os is not currently supported: ${OS_TYPE}"
    exit 1
  elif ! validateip;then
    exit 1
  elif validateoptionalvmargs; then
    success "Valid values!" 
  fi
}

validateoptionalvmargs() {
  local config_name=$(basename "${VM_CONFIG}")
  infobold "Validating optional arguments values of ${config_name}..."
  if [[ "${DISK_SIZE_SECOND}" ]]; then
    if ! [[ "${DISK_SIZE_SECOND}" =~ ^([0-9]+)GB$ ]]; then
      error "Invalid Disk-size for second disk ${DISK_SIZE_SECOND}. It should be in the format 9999GB"
      exit 1
    elif [[ (! "${MOUNTING_POINT}" =~ ^//[A-Za-z0-9]+$ || "${UNSUPPORTED_MOUNTING_POINTS[*]}" =~ "${MOUNTING_POINT}") && -d "${MOUNTING_POINT}" ]]; then
      error "Invalid mounting point ${MOUNTING_POINT}"
      exit 1
    elif ! [[ "${SUPPORTED_FILE_SYSTEMS[*]}" =~ "${FILE_SYSTEM}" ]]; then
      error "file system is currently not supported ${FILE_SYSTEM}."
      exit 1
    fi
  elif [[ "${DISK_SIZE_PRIMARY}" ]]; then
    if ! [[ ${DISK_SIZE_PRIMARY} =~ ^([0-9]+)GB$ ]]; then
      error "Invalid Disk-size for main disk ${DISK_SIZE_PRIMARY}. It should be in the format 9999GB"
      exit 1
    fi
  elif [[ "${SYNC_FOLDER}" ]]; then
    if [[ -d "${SYNC_FOLDER}" ]]; then
      makedir "${SYNC_FOLDER}"
    else 
      error "${SYNC_FOLDER} is not a directory!"
      exit 1
    fi
  elif [[ "${PROVISION_VARIABLES}" ]]; then
    hashtablegen
  elif [[ "${VM_NAME}" ]]; then
    if ! [[ "${VM_NAME}" =~ ^([A-Za-z0-9_.-]+)$ ]]; then
      error "VM_NAME may only contain letters numbres hypens and underscores: ${VM_NAME}"
      exit 1
    fi
  fi
}

# validateappargs is checking if 
# the given values are valid and is setting 
# defaults if needed
validateappargs() {
  info "Validating App-Configuration arguments values..."
  if ! [[ -d ${VMSTORE} ]]; then
    makedir "${VMSTORE}"
  elif [[ "${LOG}" != "/log" && ! -d "${LOG}" ]]; then
    makedir "${LOG}"
  elif ! [[ -d ${APPLIANCESTORE} ]]; then 
    makedir "${APPLIANCESTORE}"
  elif ! [[ -s ${VAGRANTFILE} ]]; then
    infobold "${VAGRANTFILE} is not existing or is empty. Using default Vagrantfile."
  elif ! [[ -d ${CONFIG_DIR} ]]; then
    makedir "${CONFIG_DIR}"
  elif ! [[ -d ${PROVISION_DIR} ]]; then
    makedir "${PROVISION_DIR}"
  else
    success "Valid GOVM-Values!"
  fi
 
}


# validateip is validating the given ip
# if its already in use or not by following 2 steps:
# First we ping the given IP-Adress. If it is reachable
# then the IP adress is in use in (but it does not have to 
# a virtual-machine but still cant be used for a 
# virtual-machine). Second we check if the IP-Adress
# is existing in our system. If it does we exit. A recreation 
# can be forced with -d flag
validateip() {
  # check if ip is used in any way
  # NOTE: for git bash it is really 
  # complicated. it is a success even though
  # some of the packages are not received
  ping -c 2 -w 3 "${HOST_ONLY_IP}" &> /dev/null

  if [[ "${?}" -eq 0 && -z "${FORCE_DESTROY}" ]]; then
    error "Machine with the IP: ${HOST_ONLY_IP} exists. Choose an other IP-Adress. (Ping successfull)"
    error "It may not be an virtual-machine but a machine with the same ip in the same network is not possible!"
    exit 1
  fi

  # check if ip exist within govm-ecosystem
  getid "${HOST_ONLY_IP}"

  if [[ "${ID}" != "nil" && -z "${FORCE_DESTROY}" ]]; then
    getid "${HOST_ONLY_IP}"
    error "Machine still existing in our system ID: ${ID}. Run Command with -d to force recreation."    
    exit 1
  fi

  if [[ ${FORCE_DESTROY} ]]; then
    destroy
    if [ "${VM_CONFIG}" ]; then
      sourcefile "${VM_CONFIG}"
    fi
  fi 

}

# validateposixgroup is validatin
# all given flags but not the values
# of the given flags. These are validated in
# validateInput. Here we validate the given flags
# and if they can be used together 
# using groups.
validateposixgroup() {
  CHECK_FILE=()
  CHECK_VAGRANT=()
  CHECK_GROUPUP=()
  CHECK_LIST=()

  for ARG in "$@"
  do
    if [[ "${ARG}" =~ ^-.$ ]]; then
      if [[ "${FILE_GROUP[*]}" =~ "${ARG}" && "${ARG}" != "-v" ]]; then
        CHECK_FILE+=("${ARG}")
      elif [[ "${VAGRANT_GROUP[*]}" =~ "${ARG}" && "${ARG}" != "-v" ]]; then
        CHECK_VAGRANT=("${ARG}")
      elif [[ "${GROUPCMD_GROUP[*]}" =~ "${ARG}" && "${ARG}" != "-v" ]]; then
        CHECK_GROUPUP=("${ARG}")
      elif [[ "${LIST_GROUP[*]}" =~ "${ARG}" && "${ARG}" != "-v" ]]; then
        CHECK_LIST+=("${ARG}")
      fi
    fi
  done

  if [[ "${#CHECK_FILE[@]}" -eq $(( ${#FILE_GROUP[@]} -1 )) && "${#CHECK_VAGRANT[@]}" -eq 0 && "${#CHECK_LIST[@]}" -eq 0 && "${#CHECK_GROUPUP[@]}" -eq 0 && ! "${VAGRANT_CMD}" =~  g[a-z]+ ]]; then
    infobold "Running ${VAGRANT_CMD} on ${VM_CONFIG}"
  elif [[ "${#CHECK_FILE[@]}" -eq 0 && "${#CHECK_VAGRANT[@]}" -eq $(( ${#VAGRANT_GROUP[@]} -1 )) && "${#CHECK_LIST[@]}" -eq 0 && "${#CHECK_GROUPUP[@]}" -eq 0 && ! "${VAGRANT_CMD}" =~  g[a-z]+ ]]; then
    infobold "Running \"${VAGRANT_CMD}\" on ${ID}..."
  elif [[ "${#CHECK_FILE[@]}" -eq 0 && "${#CHECK_VAGRANT[@]}" -eq 0 && "${#CHECK_LIST[@]}" -eq ${#LIST_GROUP[@]} && -z "${VAGRANT_CMD}" && "${#CHECK_GROUPUP[@]}" -eq 0 ]]; then
    infobold "Listing all virtual-machines..."
  elif [[ "${#CHECK_FILE[@]}" -eq 0 && "${#CHECK_VAGRANT[@]}" -eq 0 && "${#CHECK_LIST[@]}" -eq 0 && "${#CHECK_GROUPUP[@]}" -eq  $(( ${#GROUPCMD_GROUP[@]} -1 )) && "${VAGRANT_CMD}" =~ g[a-z]+ ]]; then
    infobold "Running \"${VAGRANT_CMD}\" on group: $(basename ${GROUP})"
  elif [[ "${#CHECK_FILE[@]}" -eq 0 && "${#CHECK_VAGRANT[@]}" -eq 0 && "${#CHECK_LIST[@]}" -eq 0 && "${#CHECK_GROUPUP[@]}" -eq 0 && ! "${VAGRANT_CMD}" =~ g[a-z]+ ]]; then
    infobold "Running command \"${VAGRANT_CMD}\" on default-machine..."
  else
    error "Too many or not enough arguments"
    usage;
    exit 1
  fi

}

# createvenv is
# sourcing the config file
# in the ${VMSTORE}/${ID}
# and is running the given command afterwards
# otherwise the Vagrantfile cannot pull
# the ENV-Variables
createvenv() {
  govmpath
  cd ${GOVM_PATH}
  sourcefile vm.cfg;
  setvenv;
}

createvm() {
  infobold "Creating Virtual-Machine ${ID}. This may take a while..."
  # vagrant up &> ${LOG_PATH}/"${TIMESTAMP}_up.log" 
  vagrant up
}

up() {
  validatevmcfg;
  sourcefile "${VM_CONFIG}";
  validaterequiredvmargs && prepvenv;
  postvenv;
  cd ${GOVM_PATH};
  createvm && successexit || error "Something went wrong. Debbuging information can be found at ${LOG_PATH}"
}

# alias to vagrant destroy
destroy() {
  infobold "Destroying ${ID}..."
  createvenv;
  vagrant destroy --force &> "${LOG_PATH}/${TIMESTAMP}_destroy.log"
  cd ${BASEDIR}; 
  clean;
}

# alias to vagrant halt
halt() {
  local FIRST_ARG=${1:-""}
  local isrunning
  info "Stopping ${ID}..."
  createvenv;
  isrunning=$(isvmrunning "${VM_NAME}")

  if [[ "${isrunning}" -eq 0 ]]; then
    vagrant halt &> "${LOG_PATH}/${TIMESTAMP}_halt.log";
    success "Stopped ${ID}!"
  elif [[ ${FIRST_ARG} == "export" ]]; then
    infobold "Machine already powered off. Continueing..."
  else 
    error "Machine is not running!"
    exit 1
  fi

}

# alias to vagrant ssh
vssh() {
  info "SSH into ${ID}"
  createvenv;
  vagrant ssh;
}

# alias to vagrant start
start() {
  info "Starting ${ID}. This may take some time..."
  createvenv;
  vagrant up &> ${LOG_PATH}/"${TIMESTAMP}_start.log"
  success "${ID} up and running!"
}

# create an appliance
# of the given virtual-machine
vexport() {
  sourcefile "${VM_CONFIG}"
  getid "${HOST_ONLY_IP}"
  halt 'export'
  infobold "Exporting ${VM_NAME}. This may take some time..."
  appliancesemver "${VM_NAME}"
  vmexport "${VM_NAME}" "single"
  success "Finished! appliance can be found at ${APPLIANCESTORE}"
}

# groupup is just a helper for 
# starting the virtual machines
# without the any validaton
# before it
groupup() {
  prepvenv;
  postvenv;
  cd ${GOVM_PATH};
  ALREADY_CREATED_VMS+=("${1}:${ID}")
  createvm && gsuccessexit || error "Something went wrong. Debbuging information can be found at ${LOG_PATH}."
}

# group is creating
# as many virtuals machines 
# as configs files given in the 
# given directory
gup() {
  IP_ADRESSES=()
  NAMES=()

  # checking syntax of all configs files
  for CFG in ${GROUP}/*.cfg; 
  do
    VM_CONFIG="${CFG}"
    validatevmcfg
  done

  # checking for duplication of ip or names in the given group
  for CFG in ${GROUP}/*.cfg;
  do
    sourcefile "${CFG}"
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
  # of the given arguments
  # fare valid
  for CFG in ${GROUP}/*.cfg; 
  do
    VM_CONFIG=${CFG}
    cd "${BASEDIR}"
    sourcefile "${CFG}"
    validaterequiredvmargs 
  done

  info "Starting creation process..."

  # starting creation of all
  # virtual machines
  for CFG in ${GROUP}/*.cfg; 
  do
    cd "${BASEDIR}"
    clearoptionalargs
    VM_CONFIG=${CFG}
    sourcefile "${CFG}";
    resetvenv
    info "Creating $(basename ${CFG})..."
    groupup "${CFG}"
  done

}

# gdestroy is an alias
# for vagrant destroy 
# but build for a group
# destruction
gdestroy() {
  for CFG in ${GROUP}/*.cfg; 
  do
    VM_CONFIG=${CFG}
    cd "${BASEDIR}"
    resetvenv
    sourcefile "${CFG}";
    getid "${HOST_ONLY_IP}"
    destroy
  done
}

# gdestroy is an alias
# for vagrant destroy 
# but build for a group
# destruction
ghalt() {
  local FIRST_ARG=${1:-""}
  local isrunning;
  for CFG in ${GROUP}/*.cfg; 
  do
    VM_CONFIG=${CFG}
    cd "${BASEDIR}"
    resetvenv
    sourcefile "${CFG}";

    # VM_NAMES is not necessary for halt 
    # but if halt is getting used in combination with export
    # it is usefull to not do it two times
    if [[ ${FIRST_ARG} == "export" ]]; then
      VM_NAMES+=("${VM_NAME}")
    fi

    isrunning=$(isvmrunning "${VM_NAME}")
    
    if [[ "${isrunning}" -eq 1 ]]; then
      infobold "Machine is not running. Continueing..."
      continue
    fi

    getid "${HOST_ONLY_IP}"
    if [[ "${ID}" ]]; then
      govmpath
      cd ${GOVM_PATH}
      halt
    else
      error "Did not find the machines! Do they even run?"
      exit 2
    fi
  done
}

gstart() {
  local exists
  local isrunning
  for CFG in ${GROUP}/*.cfg; 
  do
    VM_CONFIG=${CFG}
    cd "${BASEDIR}"
    resetvenv
    sourcefile "${CFG}";
    exists=$(isvmexisting ${VM_NAME})
    if [[ ${exists} -ne 0 ]]; then
      error "Machine ${VM_NAME} does not exists"
      exit 1
    fi
    isrunning=$(isvmrunning ${VM_NAME})
    if [[ ${isrunning} -eq 0 ]]; then
      infobold "Machine ${VM_NAME} is already up and running. Continuening with next..."
      continue
    fi
    getid "${HOST_ONLY_IP}"
    start
  done
}

# alias to vboxmanage.exe 
# export <machines>
gexport() {
  local basename
  infobold "Exporting group: ${GROUP}"
  ghalt "export"
  basename=$(basename ${GROUP})
  appliancesemver "${basename}"
  vmexport "${basename}" "group"
}

# list is listing all the 
# virtual-machines created
# by govm
list() {
  if [ -z "$(ls -A ${VMSTORE})" ]; then
    infobold "No Machines have been created yet!"
    exit 1
  fi
  column ${DB} -t -s ":" 
}

vmexport() {
  local dir=${1}
  local type=${2}
  osdefault
  if [[ "${type}" == "single" ]]; then
    infobold "Exporting ${VM_NAME} to ${APPLIANCE_NAME}"
    vboxmanage.exe 'export' "${VM_NAME}" --output "${APPLIANCESTORE}/${dir}/${APPLIANCE_NAME}"
  elif [[ "${type}" == "group" ]]; then
    infobold "Exporting machine group (${VM_NAMES[*]}) to ${APPLIANCE_NAME}" 
    vboxmanage.exe 'export' "${VM_NAMES[@]}" --output "${APPLIANCESTORE}/${dir}/${APPLIANCE_NAME}" && success "Created appliance ${APPLIANCE_NAME}"
  else
    error "currently not supported for ${CURRENT_OS}"
    exit 1
  fi
}

vmlistbridgedlifs() {
  vboxmanage.exe list bridgedifs | grep -w "Name:" | tr -s " " 
}


# main is the entering point
# of the application
main() {
  predefault
  init;
  validateappcfg;
  sourcefile ${GOVM_CONFIG};
  validateappargs;
  validateposixgroup "$@"
  bridgeoptiongen
  if [[ "${VAGRANT_CMD}" == "ssh" && "${ID}" ]]; then
    vssh
  elif [[ "${VAGRANT_CMD}" == "export" && -s ${VM_CONFIG} ]]; then
    vexport
  elif [[ "${VAGRANT_CMD}" == "gup" && -d "${GROUP}" ]]; then
    gup; 
  elif [[ "${VAGRANT_CMD}" == "gstart" && -d "${GROUP}" ]]; then
    gstart
  elif [[ "${VAGRANT_CMD}" == "gdestroy" && -d "${GROUP}" ]]; then
    gdestroy
  elif [[ "${VAGRANT_CMD}" == "ghalt" && -d "${GROUP}" ]]; then
    ghalt
  elif [[ "${VAGRANT_CMD}" == "gexport" && -d "${GROUP}" ]]; then
    gexport
  elif [[ "${VM_LIST}" ]]; then
    list
  elif [[ "${VAGRANT_CMD}" == "destroy" && "${ID}" ]]; then 
    destroy;
  elif [[ "${VAGRANT_CMD}" == "halt" && "${ID}" ]]; then
    halt;
  elif [[ "${VAGRANT_CMD}" == "start" && "${ID}" ]]; then
    start
  elif [[ "${VAGRANT_CMD}" == "up" ]]; then

    up
  else 
    error "Posix-Arguments did not match!"
    usage
  fi
}

main "$@"
