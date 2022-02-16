#!/bin/bash

trap trapexit INT;

usage() {
  echo "-c [integer] is setting the count of CPUs"
  echo "-m [integer] is setting the RAM"
  echo "-o [integer] is setting the OS-Image"
  echo "-s [path] is setting the path to the provision-shell-script"
  echo "-i [ipv4] is setting the ip-adress for host-only of the type 192.168.56.0/24"
  echo "-f [path] is specifing the path to a *.config file with the parameters CPU, RAM, OS_IMAGE, IP and SCRIPT"
  echo "-v [up/halt/start/ssh/destroy] is setting the vagrant command you want to run (has to be present with every command.)"
  echo "You can also prefix any command with g for exampe gdestroy to destroy a whole group (ssh is not possible)"
  echo "-d if this is present it will force a recreation of the vm if there is a virtual machine registered but not reachable"
  echo "-g [path] is setting the path to a directory with one or more *.cfg files to create a group of virtual-machines at once"
}

while getopts "c:r:o:s:i:f:g:v:n:m:ld" OPT; do
  case "${OPT}" in
    c)
      CPU="${OPTARG}"
      ;;
    r)
      RAM=${OPTARG}
      ;;
    o)
      OS_IMAGE=${OPTARG}
      ;;
    f)
      VM_CONFIG=${OPTARG}
      ;;
    s)
      SCRIPT=${OPTARG}
      ;;
    i)
      HOST_ONLY_IP=${OPTARG}
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
GROUPCMD_GROUP=("-g" "-v")
VAGRANT_GROUP=("-v" "-m")
LIST_GROUP=("-l")
VALID_CONFIG_PARAMS_VM=(
    "CPU"
    "RAM"
    "OS_IMAGE"
    "SCRIPT"
    "HOST_ONLY_IP"
    "VM_NAME"
    "DISK_SIZE_PRIMARY"
    "DISK_SIZE_SECOND"
    "MOUNTING_POINT"
    "FILE_SYSTEM"
    "GIT_USERNAME"
    "GIT_PASSWORD"
    "GIT_EMAIL"
    "GIT_NAME"
    "OS_USERNAME"
    "OS_PASSWORD"
)

OPTIONAL_CONFIG_PARAMS_VM=(
  "DISK_SIZE_PRIMARY"
  "DISK_SIZE_SECOND"
  "MOUNTING_POINT"
  "FILE_SYSTEM"
  "CPU"
  "RAM"
  "SCRIPT"
  "OS_IMAGE"
)

VALID_CONFIG_PARAMS_APP=(
  "VMSTORE"
  "APPLIANCESTORE"
  "LOG"
  "CPU"
  "RAM"
  "OS_IMAGE"
  "SCRIPT"
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
ALREADY_CREATED_VMS=()
IS_MANUAL="false"
IS_FILE="false"
REQUIRED_PARAMS_CONFIG_VM=$(( ${#VALID_CONFIG_PARAMS_VM[@]} - ${#OPTIONAL_CONFIG_PARAMS_VM[@]} ))
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


tips() {
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

setDefaultValues() {
  BASE_DIR=".govm"
  VM_LIST=${VM_LIST:-""}
  VM_NAMES=()
  FORCE_DESTROY=${FORCE_DESTROY:-""}
  REALPATH=$(realpath ${0})
  BASEDIR=$(dirname ${REALPATH})
  VM_CONFIG=${VM_CONFIG:-""}
  ID=${ID:-0}
  VM_NAME=${VM_NAME:-""}
  GOV_CONFIG=${BASEDIR}/${BASE_DIR}/gov.cfg
  IP_FILE=${BASEDIR}/${BASE_DIR}/used_ip.txt
  GROUP=${GROUP:-""}
  DISK_SIZE_SECOND=${DISK_SIZE_SECOND:-""}
  DISK_SIZE_PRIMARY=${DISK_SIZE_PRIMARY:-""}
  MOUNTING_POINT=${MOUNTING_POINT:-"nil"}
  FILE_SYSTEM=${FILE_SYSTEM:-"nil"}
  TIMESTAMP=$(date '+%s')
}

emptyOptionalArguments() {
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

iptoid() {
  ID="$(grep ${1} ${IP_FILE} | cut -d '=' -f 1)"
}

idtoip() {
  HOST_ONLY_IP="$(grep ${1} ${IP_FILE} | cut -d '=' -f 2)"
}

leftcut() {
  LEFTSIDE="$(cut -d ':' -f 1 <<< ${1})"
}

rightcut() {
  RIGHTSIDE="$(cut -d ':' -f 2 <<< ${1})"
}

# rmip is removing the
# ip-adress from the file
rmip() {
  if grep -q -w "${HOST_ONLY_IP}" "${IP_FILE}"; then
    sed -i "/${HOST_ONLY_IP}/d" "${IP_FILE}";
  fi
}

makedir() {
  mkdir -p -- "${1}"
}

rmdirrf() {
  rm -rf "${1}"
}

isvmrunning() {
  vboxmanage list runningvms | grep -q -w "${1}" 
}


trapexitup() {
  vagrant destroy --force &> /dev/null
  rmgovm;
  rmip;
  rmlogdir;
  infobold "Cleaned ${1}"
}

trapexit() {
  infobold "Graceful exiting. Trying to clean as much as possible...";
  if [[ "${VAGRANT_CMD}" == "up" ]]; then
    trapexitup
  elif [[ "${VAGRANT_CMD}" == "gup" ]]; then
    trapexitgroup
  fi
}

trapexitgroup() {
  for CFG in ${ALREADY_CREATED_VMS[@]}
  do
    leftcut ${CFG}
    rightcut ${CFG}
    VM_CONFIG=${LEFTSIDE}    
    ID=${RIGHTSIDE}
    cd "${VMSTORE}/${ID}/${BASE_DIR}"
    sourcefile vm.cfg
    trapexitup "${ID}"
  done
}

trapexitdestroy() {
  echo "destroy"
}

successexit() {
  infobold "Finishing touches...";
  # createcfg
  echo "${ID}=${HOST_ONLY_IP}" >> "${IP_FILE}";
  success "VM ${ID} is set and ready to go :)"
  tips;
}

gsuccessexit() {
  infobold "Finishing touches...";
  createcfg;
  echo "${ID}=${HOST_ONLY_IP}" >> "${IP_FILE}";
  success "VM ${ID} is set and ready to go :)"
}

setvenv() {
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
  export DISK_SIZE_PRIMARY
  export DISK_SIZE_SECOND
  export MOUNTING_POINT
  export FILE_SYSTEM
  export VAGRANT_EXPERIMENTAL="disks"
  # not set by User
  export SYNC_FOLDER;
}

resetvenv() {
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
  export -n DISK_SIZE_PRIMARY
  export -n DISK_SIZE_SECOND
  export -n MOUNTING_POINT
  export -n FILE_SYSTEM
  # not set by User
  export -n SYNC_FOLDER;

}


# createcfg is copying the used
# config file for the creation
# and is appending some extra 
# information to it
createcfg() {
  cd ${BASEDIR} 
  REALPATH_VM_CONFIG=$(realpath ${VM_CONFIG})
  cp ${REALPATH_VM_CONFIG} ${VMSTORE}/${ID}/${BASE_DIR}/vm.cfg
cat << EOF >> ${VMSTORE}/${ID}/${BASE_DIR}/vm.cfg
SYNC_FOLDER=${SYNC_FOLDER}
ID=${ID}
LOG_PATH=${LOG_PATH}
EOF
}

# prepvenv is creating the
# syncFolder for the VM and also
# the log folder to log to
prepvenv() {
  ID="$(openssl rand -hex 5)"
  makedir "${VMSTORE}/${ID}/${BASE_DIR}"
  makedir "${VMSTORE}/${ID}/sync_folder"

  if [[ ${LOG} == "/log" ]]; then
    makedir "${VMSTORE}/${ID}/${BASE_DIR}/logs"
    LOG_PATH=${VMSTORE}/${ID}/${BASE_DIR}/logs
  else 
    LOG_PATH=${LOG}/${ID}
    makedir "${LOG_PATH}"
  fi
  SYNC_FOLDER="${VMSTORE}/${ID}/sync_folder"
  SCRIPT_NAME=$(basename ${SCRIPT})


}

# postvenv is creating 
# directories and copying 
# all needed vagrant-files so that
# the vagrant commands can run in the
# newly created directory
postvenv() {
  setvenv;
  cp "${BASEDIR}/${BASE_DIR}/Vagrantfile" "${VMSTORE}/${ID}/${BASE_DIR}/Vagrantfile"
  makedir "${VMSTORE}/${ID}/${BASE_DIR}/provision"
  cp "${SCRIPT}" "${VMSTORE}/${ID}/${BASE_DIR}/provision/${SCRIPT_NAME}"
  createcfg;
}

#sourcefile is sourcing the
# given file into the current
# shell-ENV
sourcefile() {
  . "${1}"
}

# validateAndSourceVMConfig
# is validating the config file
# for the virtual-machine (syntax only)
# meaning duplicated keys or not enough
# keys and if the config file is valid 
# it is getting sourced.
validatevmcfg() {
  GIVEN_PARAMS_REQUIRED=()
  GIVEN_PARAMS_OPTIONAL=()
  info "Loading ${VM_CONFIG}...";
  if [[  -s "${VM_CONFIG}" && "${VM_CONFIG}" == *.cfg ]]; then
    while read LINE
    do
      VALUE="$(echo -e "${LINE}" | tr -d '[:space:]')"
      if ! [[ "${VALUE}" =~ ^([A-Za-z0-9_]+)=([^'#'$%'&''*'^]+$) ]]; then
        [[ "${LINE}" =~ ^\#.*$ || -z "${LINE}" ]] && continue
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
    success "Valid Syntax and Arguments for ${VM_CONFIG}" 
  else 
    error "Not Enough Arguments"
    error "Expected: ${VALID_CONFIG_PARAMS_VM[*]}"
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
  GIVEN_PARAMS=()
  info "Loading ${GOV_CONFIG}...";
  if [[  -s "${GOV_CONFIG}" ]]; then
    while read LINE
    do
      VALUE="$(echo -e "${LINE}" | tr -d '[:space:]')"

      if ! [[ "${VALUE}" =~ ^([^'#']+)=([^'#'$%'&''*'^]+$) ]]; then
        [[ "${VALUE}" =~ ^\#.*$ || -z "${VALUE}" ]] && continue
        error "Did not match ${VALUE}"
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
    else 
      error "Not Enough Arguments"
      error "Expected: ${VALID_CONFIG_PARAMS_APP[*]}"
      exit 1
    fi

  else 
    error "gov.cfg is not existing or is empty or has the wrong extension (expected: .cfg)"
    exit 1
  fi
}


# validatevmargs is  checking if 
# all given VM-Configs are the type 
# that they has to be like 
# CPU should be an integer not 
# a word and so on
validatevmargs() {
  info "Validating ${VM_CONFIG} argument values..."
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
  elif ! validateip;then
    exit 1
  elif ! [[ "${GIT_PASSWORD}" =~ ^(ghp_)([A-Za-z0-9]{36})$ ]];then
    error "Invalid Git-Password"
    exit 1
  elif [[ "${DISK_SIZE_SECOND}" ]]; then
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
  else 
    success "Valid VM-Values!" 
    return 0
  fi
}

# validateappargs is checking if 
# the given values are valid and is setting 
# defaults if needed
validateappargs() {
  info "Validating App-Configuration arguments values..."
  if ! [[ -d ${VMSTORE} ]]; then
    makedir "${VMSTORE}"
  elif ! [[ ${LOG} == "/log" && -d "${LOG}" ]]; then
    makedir "${LOG}"
  elif ! [[ -d ${APPLIANCESTORE} ]]; then 
    makedir "${APPLIANCESTORE}"
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
  ping -c 2 "${HOST_ONLY_IP}" &> /dev/null;

  if [[ "$?" -eq 0  && -z "${FORCE_DESTROY}" ]]; then
    error "Machine with the IP: ${HOST_ONLY_IP} exists. Choose an other IP-Adress. (Ping successfull)"
    exit 1
  fi

  # check if ip exist within govm-ecosystem
  grep -q -w "${HOST_ONLY_IP}" ${IP_FILE}  

  if [[ "$?" -eq 0 && -z "${FORCE_DESTROY}" ]]; then
    iptoid ${HOST_ONLY_IP}
    error "Machine still existing in our system ID: ${ID}. Run Command with -d to force recreation."    
    exit 1
  fi

  grep -q -w ${HOST_ONLY_IP} ${IP_FILE}

  IS_SUCCESS=${?}

  if [[ ${FORCE_DESTROY}  && "${IS_SUCCESS}" -eq 0 ]]; then
    iptoid ${HOST_ONLY_IP}
    destroy
    if [ "${VM_CONFIG}" ]; then
      sourcefile
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
      elif [[ "${GROUPCMD_GROUP[*]}" =~ "${ARG}" && "${ARG}" != "-v" ]]; then
        CHECK_GROUPUP=("${ARG}")
      elif [[ "${ARG}" == "-v" ]]; then
        VAGRANT_COMMAND_GIVEN="true"
      elif [[ "${LIST_GROUP[*]}" =~ "${ARG}" && "${ARG}" != "-v" ]]; then
        CHECK_LIST+=("${ARG}")
      fi
    fi
  done

  if [[ "${#CHECK_MANUAL[@]}" -eq $(( ${#MANUAL_GROUP[@]} -1 )) && "${#CHECK_FILE[@]}" -eq 0 && "${#CHECK_VAGRANT[@]}" -eq 0 && "${#CHECK_LIST[@]}" -eq 0 && "${VAGRANT_COMMAND_GIVEN}" == "true" ]]; then
    infobold "Starting creation process..."
    IS_MANUAL="true"
  elif [[ "${#CHECK_MANUAL[@]}" -eq 0 && "${#CHECK_FILE[@]}" -eq $(( ${#FILE_GROUP[@]} -1 )) && "${#CHECK_VAGRANT[@]}" -eq 0 && "${#CHECK_LIST[@]}" -eq 0 && "${VAGRANT_COMMAND_GIVEN}" == "true" && "${#CHECK_GROUPUP[@]}" -eq 0 ]]; then
    infobold "Starting creation process"
    IS_FILE="true"
  elif [[ "${#CHECK_MANUAL[@]}" -eq 0 && "${#CHECK_FILE[@]}" -eq 0 && "${#CHECK_VAGRANT[@]}" -eq $(( ${#VAGRANT_GROUP[@]} -1 )) && "${#CHECK_LIST[@]}" -eq 0 && "${VAGRANT_COMMAND_GIVEN}" == "true" && "${#CHECK_GROUPUP[@]}" -eq 0 ]]; then
    infobold "Running command..."
  elif [[ "${#CHECK_MANUAL[@]}" -eq 0 && "${#CHECK_FILE[@]}" -eq 0 && "${#CHECK_VAGRANT[@]}" -eq 0 && "${#CHECK_LIST[@]}" -eq ${#LIST_GROUP[@]} && "${VAGRANT_COMMAND_GIVEN}" == "false" && "${#CHECK_GROUPUP[@]}" -eq 0 ]]; then
    infobold "Listing all virtual-machines..."
  elif [[ "${#CHECK_MANUAL[@]}" -eq 0 && "${#CHECK_FILE[@]}" -eq 0 && "${#CHECK_VAGRANT[@]}" -eq 0 && "${#CHECK_LIST[@]}" -eq 0 && "${VAGRANT_COMMAND_GIVEN}" == "true" && "${#CHECK_GROUPUP[@]}" -eq  $(( ${#GROUPCMD_GROUP[@]} -1 )) ]]; then
    infobold "Running group command on all virtual-machines..."
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
  grep -q -w "${ID}" ${IP_FILE}  

  if [[ "${?}" -ne 0 ]]; then
    error "${ID} does not exist!"
    infobold "run gov -l for a listing of all virtual-machines"
    exit 1
  fi

  init;
  cd ${VMSTORE}/${ID}/${BASE_DIR}
  sourcefile vm.cfg;
  setvenv;
}

createvm() {
  infobold "Creating Virtual-Machine ${ID}. This may take a while..."
  vagrant up &> ${LOG_PATH}/"${TIMESTAMP}_up.log" 
}

# fileup is creating
# a virtual-machine based
# on a given config file
# and the values 
fileup() {  
  init;
  validatevmcfg;
  sourcefile ${VM_CONFIG}
  validatevmargs && prepvenv;
  postvenv;
  cd ${VMSTORE}/${ID}/${BASE_DIR};
  createvm && successexit || error "Something went wrong. Debbuging information can be found at ${LOG_PATH}"

}

# manualup is creating
# a virtual-machine based
# on the arguments given
# in the command-line
# NOTE: this is not recommended 
# because the commands will get 
# really big. fileup is the recommend 
# way
manualup() {
  init;
  validatevmargs && prepvenv;
  postvenv;
  cd ${VMSTORE}/${ID}/${BASE_DIR};
  createvm && successexit || error "Something went wrong. Debbuging information can be found at ${LOG_PATH}"
}


up() {
  if [[ ${IS_MANUAL} == "true" ]]; then
    manualup
  elif [[ ${IS_FILE} == "true" ]]; then
    fileup;
  else 
    echo "Error."
    usage;
  fi
}

# alias to vagrant destroy
destroy() {
  infobold "Destroying ${ID}..."
  createvenv;
  vagrant destroy --force &> /dev/null;
  cd ${BASEDIR}; 
  clean;
}


halt() {
  info "Stopping ${ID}..."
  createvenv;
  isvmrunning "${VM_NAME}"
  if [[ "$?" -eq 0 ]]; then
    vagrant halt &> "${LOG_PATH}/${TIMESTAMP}_halt.log";
    success "Stopped ${ID}!"
  else 
    error "Machine is not running!"
  fi

}

vssh() {
  info "SSH into ${ID}"
  createvenv;
  vagrant ssh;
}

start() {
  info "Starting ${ID}. This may take some time..."
  createvenv;
  vagrant up &> ${LOG_PATH}/"${TIMESTAMP}_start.log"
  success "${ID} up and running!"
}


vexport() {
  sourcefile ${VM_CONFIG}
  halt
  infobold "Exporting ${VM_NAME}..."
  vboxmanage 'export' "${VM_NAME}" --output "${APPLIANCESTORE}/${VM_NAME}.ova"
  success "Finished! appliance can be found at ${APPLIANCESTORE}"
}


# groupup is just a helper for 
# starting the virtual machines
# without the any validaton
# before it
groupup() {
  prepvenv;
  postvenv;
  cd ${VMSTORE}/${ID}/${BASE_DIR};
  ALREADY_CREATED_VMS+=("${1}:${ID}")
  createvm && gsuccessexit || error "Something went wrong. Debbuging information can be found at ${LOG_PATH}."
}

# group is creating
# as many virtuals machines 
# as configs files given in the 
# given directory
gup() {
  init
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
    validatevmargs 
  done

  info "Starting creation process..."

  # starting creation of all
  # virtual machines
  for CFG in ${GROUP}/*.cfg; 
  do
    emptyOptionalArguments
    VM_CONFIG=${CFG}
    sourcefile "${CFG}";
    resetvenv
    info "Creating $(basename ${CFG})..."
    cd "${BASEDIR}"
    groupup "${CFG}"
  done

}

# gdestroy is an alias
# for vagrant destroy 
# but build for a group
# destruction
gdestroy() {
  init
  for CFG in ${GROUP}/*.cfg; 
  do
    VM_CONFIG=${CFG}
    cd "${BASEDIR}"
    resetvenv
    sourcefile "${CFG}";
    iptoid "${HOST_ONLY_IP}"
    destroy
  done
}

# gdestroy is an alias
# for vagrant destroy 
# but build for a group
# destruction
ghalt() {
  init
  for CFG in ${GROUP}/*.cfg; 
  do
    VM_CONFIG=${CFG}
    cd "${BASEDIR}"
    resetvenv
    sourcefile "${CFG}";
    VM_NAMES+=("${VM_NAME}")
    isvmrunning "${VM_NAME}" && echo "$?"
    
    if [[ "${?}" -eq 1 ]]; then
      infobold "Machine is not running. Continueing..."
      continue
    fi
    iptoid "${HOST_ONLY_IP}"
    if [[ "${ID}" ]]; then
      cd ${VMSTORE}/${ID}/${BASE_DIR}
      halt
    else
      error "Did not find the machines! Do they even run?"
      exit 2
    fi
  done
}

gstart() {
  init
  for CFG in ${GROUP}/*.cfg; 
  do
    VM_CONFIG=${CFG}
    cd "${BASEDIR}"
    resetvenv
    sourcefile "${CFG}";
    iptoid "${HOST_ONLY_IP}"
    start
  done
}

# alias to vboxmanage 
# export <machines>
gexport() {
  i=1
  infobold "Exporting group: ${GROUP}"
  ghalt
  BASENAME=$(basename ${GROUP})
  FILENAME="${BASENAME}.v${i}.ova"

  while true 
  do
    if [[ -s ${APPLIANCESTORE}/${FILENAME} ]]; then
      i=$((i +1))
      NEW_FILENAME="${BASENAME}.v${i}.ova"
      infobold "${FILENAME} exists! Renaming appliance to ${NEW_FILENAME}"
      FILENAME=${NEW_FILENAME}
    else 
      break
    fi  
  done
  
  vboxmanage 'export' "${VM_NAMES[@]}" --output "${APPLIANCESTORE}/${FILENAME}" && success "Created appliance ${FILENAME}"
}

# list is listing all the 
# virtual-machines created
# by govm
list() {
  init; 
  if [ -z "$(ls -A ${VMSTORE})" ]; then
    infobold "No Machines have been created yet!"
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
    sourcefile vm.cfg && echo "" || continue
    printf "$format" \
    "${ID}" "${VM_NAME}" "${HOST_ONLY_IP}" "${OS_IMAGE}" "${CPU}" "${RAM}" 
  done

}



# main is the entering point
# of the application
main() {
  setDefaultValues
  validateposixgroup "$@"
  validateappcfg;
  sourcefile ${GOV_CONFIG};
  validateappargs;
  if [[ "${VAGRANT_CMD}" == "destroy" && "${ID}" ]]; then 
    destroy;
  elif [[ "${VAGRANT_CMD}" == "halt" && "${ID}" ]]; then
    halt;
  elif [[ "${VAGRANT_CMD}" == "start" && "${ID}" ]]; then
    start
  elif [[ "${VAGRANT_CMD}" == "up" ]]; then
    up
  elif [[ "${VAGRANT_CMD}" == "ssh" && "${ID}" ]]; then
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
  else 
    error "Wrong arguments or not enough arguments"
    usage
  fi
}

main "$@"
