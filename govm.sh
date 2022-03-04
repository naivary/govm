#!/bin/bash

# Copyright etomer GmbH 
# Author Sayed Mustafa Hussaini 
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


trap func_trapexit INT;

func_usage() {
  # govm-cmd
  echo "-v [up/halt/start/ssh/destroy] is setting the vagrant command you want to run (has to be present with every command.)"
  echo "You can also prefix any command with g for exampe func_gdestroy to destroy a whole group (ssh is not possible)"

  # path/machine
  echo "-f [path] is specifing the path to a *.config file with the parameters CPU, RAM, OS_IMAGE, IP and SCRIPT"
  echo "-g [path] is setting the path to a directory with one or more *.cfg files to create a group of virtual-machines at once"
  echo "-m [integer] is setting the Machine"
  
  # behavior changes
  echo "-i if this is present the group/virtual-machine that is getting exported is set as the main.ova"
  echo "which is getting used by import.ps1/exe for automatically setting up importing the .ova file"
  echo "-r if this is present it will force a recreation of the vm if there is a virtual machine registered but not reachable"
  echo "-l is listing all virtual-machines that have been created by govm and should be used as govm -l"
  echo "For a detailed documentation visit: https://github.com/No1Lik3U/vagrant-wrapper#documentation"
}

while getopts "f:g:v:m:lrid" OPT; do
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
      LIST_DATA="true"
      ;;
    r)
      FORCE_REPLACE="true"
      ;;
    d)
      DETACH_MODE="true"
      ;;
    g)
      GROUP=${OPTARG}
      ;;
    i)
      MAIN_OVA="true"
      ;;
    ?)
      func_usage
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
    "SYNC_DIR"
    "HOST_ONLY_IP"
    "VM_NAME"
    "CUSTOME_VARIABLES"
    "DISK_SIZE_PRIMARY"
    "DISK_SIZE_SECOND"
    "MOUNTING_POINT"
    "FILE_SYSTEM"
    "VAGRANTFILE"
)

OPTIONAL_CONFIG_PARAMS_VM=(
  "CPU"
  "RAM"
  "OS_IMAGE"
  "OS_TYPE"
  "SCRIPT"
  "SYNC_DIR"
  "CUSTOME_VARIABLES"
  "DISK_SIZE_PRIMARY"
  "DISK_SIZE_SECOND"
  "MOUNTING_POINT"
  "FILE_SYSTEM"
)

VALID_CONFIG_PARAMS_APP=(
  "VMSTORE"
  "FILE_DIR"
  "PROVISION_DIR"
  "CONFIG_DIR"
  "APPLIANCESTORE"
  "BRIDGE_OPTIONS"
  "LOG_DIR"
  "CPU"
  "RAM"
  "OS_IMAGE"
  "SCRIPT"
  "OS_TYPE"
  "CUSTOME_VARIABLES"
  "VAGRANTFILE"
)

OPTIONAL_CONFIG_PARAMS_APP=(
  "VMSTORE"
  "FILE_DIR"
  "PROVISION_DIR"
  "CONFIG_DIR"
  "APPLIANCESTORE"
  "LOG_DIR"
  "VAGRANTFILE"
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

# func_predefault is setting
# all defaults that do not
# dependent on govm.cfg.
# All other defaults that have
# a dependencie can be set int postdefault
func_predefault() {
  # appliaction
  ALREADY_CREATED_VMS=()
  REQUIRED_PARAMS_CONFIG_VM=$(( ${#VALID_CONFIG_PARAMS_VM[@]} - ${#OPTIONAL_CONFIG_PARAMS_VM[@]} ))
  REQUIRED_PARAMS_CONFIG_APP=$(( ${#VALID_CONFIG_PARAMS_APP[@]} - ${#OPTIONAL_CONFIG_PARAMS_APP[@]} ))
  GOVM=".govm"
  DEFAULT_VM="default.cfg"
  LIST_DATA=${LIST_DATA:-""}
  VM_NAMES=()
  FORCE_REPLACE=${FORCE_REPLACE:-""}
  REALPATH=$(realpath ${0})
  BASEDIR=$(dirname ${REALPATH})
  DB=${BASEDIR}/${GOVM}/db.txt
  TIMESTAMP=$(date '+%s')
  VAGRANT_CMD=${VAGRANT_CMD:-""}
  PROVISION_DIR_NAME="provision"
  CURRENT_OS=$(uname -r | sed -n 's/.*\( *Microsoft *\).*/\1/ip')
  MAIN_OVA=${MAIN_OVA:-"false"}
  VAGRANTFILE_TYPE="default"

  # govm.cfg
  GOVM_CONFIG="${BASEDIR}/${GOVM}/govm.cfg"
  GOVM_NAME="$(basename ${GOVM_CONFIG})"
  PROVISION_DIR=${PROVISION_DIR:-"${BASEDIR}/${PROVISION_DIR_NAME}"}
  CONFIG_DIR=${CONFIG_DIR:-"${BASEDIR}/configs"}
  FILE_DIR=${FILE_DIR:-${BASEDIR}/${GOVM}/vagrantfiles}
  VAGRANTFILE=${VAGRANTFILE:-linux}
  VMSTORE=${VMSTORE:-${HOME}/${GOVM}}
  APPLIANCESTORE=${APPLIANCESTORE:-${HOME}/"${GOVM}_appliance"}
  LOG_DIR=${LOG_DIR:-""}
  SCRIPT=${SCRIPT:-"nil"}
  BRIDGE_OPTIONS=()

  # vm.cfg
  GROUP=${GROUP:-""}
  VM_CONFIG=${VM_CONFIG:-"${BASEDIR}/${GOVM}/${DEFAULT_VM}"}
  VM_NAME=${VM_NAME:-"govm"}
  SCRIPT_VAGRANT=${PROVISON_DIR_NAME}/${SCRIPT_NAME}
  OS_TYPE=${OS_TYPE:-linux}
  SYNC_USER=${SYNC_USER:-"vagrant"}
  func_getid "${VM_NAME}"
  func_getvmname "${VM_NAME}"
  HOST_ONLY_IP=${HOST_ONLY_IP:-""}
  SYNC_DIR=${SYNC_DIR:-""}
  DISK_SIZE_SECOND=${DISK_SIZE_SECOND:-""}
  DISK_SIZE_PRIMARY=${DISK_SIZE_PRIMARY:-""}
  MOUNTING_POINT=${MOUNTING_POINT:-"nil"}
  FILE_SYSTEM=${FILE_SYSTEM:-"nil"}
  CUSTOME_VARIABLES=("govm:govm")
}

# func_postdefault is setting all
# defaults that have a dependencie 
# on govm.cfg values
func_postdefault() {
  DEFAULT_CPU=${CPU}
  DEFAULT_RAM=${RAM}
  DEFAULT_OS_IMAGE=${OS_IMAGE}
  DEFAULT_SCRIPT=${SCRIPT}
  DEFAULT_OS_TYPE=${OS_TYPE}
  DEFAULT_CUSTOME_VARIABLES=${CUSTOME_VARIABLES}
  DEFAULT_VAGRANTFILE=${VAGRANTFILE}
}

# func_osdefault is checking ig the current
# used system is an wsl system or native linux
# distrubution and if it is an wsl system it converts 
# some paths to a windows path for the virtualbox api
# so it will work properly
func_osdefault() {
  if [[ "${CURRENT_OS}" == "microsoft" ]]; then
    APPLIANCESTORE="$(wslpath -w ${APPLIANCESTORE})"
  fi
}

# func_vagrantfilevm is checking
# if the vagrantfile that is getting
# used is a default or a custome
# vagrantfile and will make some
# required options optional.
func_vagrantfilevm() {
  if [[ "${VAGRANTFILE_TYPE}" == "custome" ]]; then
    OPTIONAL_CONFIG_PARAMS_VM+=("HOST_ONLY_IP")
    OPTIONAL_CONFIG_PARAMS_VM+=("VAGRANTFILE")
    REQUIRED_PARAMS_CONFIG_VM=$(( ${#VALID_CONFIG_PARAMS_VM[@]} - ${#OPTIONAL_CONFIG_PARAMS_VM[@]} ))
  else 
    OPTIONAL_CONFIG_PARAMS_VM+=("VAGRANTFILE")
    REQUIRED_PARAMS_CONFIG_VM=$(( ${#VALID_CONFIG_PARAMS_VM[@]} - ${#OPTIONAL_CONFIG_PARAMS_VM[@]} ))
    func_bridgeoptiongen
  fi
}

# we need to check before if the vagrantfile is custome
# or one of the defaults because the bridge_options will be 
# optional which will lead to an error if its handled after the govm.cfg
# is getting sourced.
func_vagrantfileapp() {
  local dir=$(grep -w "FILE_DIR=" .govm/govm.cfg | cut -d "=" -f 2)
  local iscommented=$(grep -w "FILE_DIR=" .govm/govm.cfg | grep -o "^#")

  if [[ "${iscommented}" == "#" ]]; then
    return
  fi

  if ! [[ -d "${dir}" ]]; then
    error "FILE_DIR is not directory: ${dir}"
    exit 1
  fi

  if ! [[ "${dir}" == "${BASEDIR}/${GOVM}/vagrantfiles" ]]; then
    OPTIONAL_CONFIG_PARAMS_APP+=("BRIDGE_OPTIONS")
    REQUIRED_PARAMS_CONFIG_APP=$(( ${#VALID_CONFIG_PARAMS_APP[@]} - ${#OPTIONAL_CONFIG_PARAMS_APP[@]} ))
    VAGRANTFILE_TYPE="custome"
  fi
}

# func_resetvariables is setting
# some optional arguments
# to empty strings
func_resetvariables() {
  DISK_SIZE_SECOND=""
  DISK_SIZE_PRIMARY=""
  SYNC_DIR=""
  VM_NAME=""
  CPU=${DEFAULT_CPU}
  RAM=${DEFAULT_RAM}
  OS_IMAGE=${DEFAULT_OS_IMAGE}
  SCRIPT=${DEFAULT_SCRIPT}
  OS_TYPE=${DEFAULT_OS_TYPE}
  CUSTOME_VARIABLES=${DEFAULT_CUSTOME_VARIABLES}

}

# func_rmgovm is removing
# the meta-data if a already
# created virtual-machine
func_rmgovm() {
  if [[ -d "${VMSTORE}/${ID}" ]]; then
    func_rmdirrf "${VMSTORE}/${ID}";
  fi 
}

# func_rmlogdir is removing
# the log directory if the
# directory is not the default
func_rmlogdir() {
  if [[ -d "${LOG_PATH}/${ID}" ]]; then
    func_rmdirrf "${LOG_PATH}/${ID}"
  fi
}

# func_clean is called after
# destroyed. it will not 
# handle interrupt
# it is removing the 
func_clean() {
  infobold "Cleaning up..."
  func_rmgovm;
  func_delete;
  func_rmlogdir;
  success "Destroyed ${ID}!"
}


# func_leftcut is cutting out the
# value on the leftside 
# of a colon seperated string
func_leftcut() {
  LEFTSIDE="$(cut -d ':' -f 1 <<< ${1})"
}

# func_rightcut is cutting out the
# value on the rightside 
# of a colon seperated string
func_rightcut() {
  RIGHTSIDE="$(cut -d ':' -f 2 <<< ${1})"
}

# func_getid 
func_getid() {
  local id
  id="$(grep -w ${1} ${DB} | cut -d ':' -f 1)"

  if [[ ${id} ]]; then
    ID="${id}"
  else 
    ID=${ID:-"nil"}
  fi
}

func_getvmname() {
  local name
  name="$(grep ${1} -w ${DB} | cut -d ':' -f 2)"
  if [[ ${name} ]]; then
    VM_NAME=${name}
  fi
}

func_getos() {
  local os
  os="$(grep ${1} -w ${DB} | cut -d ':' -f 3)"
  if [[ ${os} ]]; then
    OS_IMAGE=${OS_IMAGE:-os}
  else
    OS_IMAGE="nil"
  fi
}

func_getip() {
  local ip
  ip="$(grep ${1} -w ${DB} | cut -d ':' -f 4)"

  if [[ ${ip} ]]; then
    HOST_ONLY_IP=${HOST_ONLY_IP:-ip}
  else
    HOST_ONLY_IP="nil"
  fi
}

# func_verifyarr is checking if the syntax of the 
# given arr and returning it 
func_verifyarrcustomearr() {
  local arr
  arr=$(echo "${1}" | cut -d "=" -f 2 | tr -d '()' | tr -d '[:space:]')

  if ! [[ "${arr}" =~ ^(\"[A-Za-z0-9_-]+:[A-Za-z0-9_-]+\")+$ ]]; then
    echo 1
  else 
    echo 0
  fi
}

# func_govmpath is setting the path
# to the current virtual-machine
# and his metadata in the $VMSTORE
func_govmpath() {
  GOVM_PATH="${VMSTORE}/${ID}/${GOVM}"
}

# func_makedir is creating
# all nonexisting directories
# of a given path
func_makedir() {
  mkdir -p -- "${1}"
}

# func_rmdirrf is removing
# a directory recusively 
# by forcing it
func_rmdirrf() {
  sudo rm -rf "${1}"
}

# func_isvmrunning is checking if the virtual-machine
# is already up and running
func_isvmrunning() {

  if [[ "${CURRENT_OS}" == "microsoft" ]]; then
    vboxmanage.exe list runningvms | grep -q -w "${1}" 
  else
    vboxmanage list runningvms | grep -q -w "${1}" 
  fi

  echo "$?"
}

# isvmexting check if the virtual-machine
# exists in virtualbox
func_isvmexisting() {

  if [[ "${CURRENT_OS}" == "microsoft" ]]; then
    vboxmanage.exe list vms | grep -q -w "${1}"
  else
    vboxmanage list vms | grep -q -w "${1}"
  fi
  
  echo "$?"
}

# func_appliancesemver is generating an filename
# for the .ova file based on the rules described in the documentation: 
# https://github.com/No1Lik3U/vagrant-wrapper#how-is-the-ova-filename-generated
func_appliancesemver() {
  APPLIANCE_NAME=${1}
  VERSION=1

  if [[ ! -d ${APPLIANCESTORE}/${APPLIANCE_NAME} && ${MAIN_OVA} == "false" ]]; then
    func_makedir "${APPLIANCESTORE}/${APPLIANCE_NAME}"
  fi

  if [[ ${MAIN_OVA} == "false" ]]; then
    while [[ -s "${APPLIANCESTORE}/${APPLIANCE_NAME}/${APPLIANCE_NAME}-v${VERSION}.0.ova" ]];
    do
      VERSION=$((VERSION+1))
    done
    APPLIANCE_NAME="${APPLIANCE_NAME}-v${VERSION}.0.ova"
  else
    sudo rm ${APPLIANCESTORE}/main.ova || true 2> /dev/null
    APPLIANCE_NAME="main.ova"
  fi
  
}

# trapexutup is cleaning a single-creation
# of a virtual-machine by destroying it
func_trapexitup() {
  vagrant destroy --force &> "${LOG_PATH}/${TIMESTAMP}_destroy.log"
  func_rmgovm;
  func_delete;
  func_rmlogdir;
  infobold "Cleaned ${1}"
}

# func_trapexit will be triggered if the user
# is using CRTL+C. It will only run an
# action if it is an up or func_gup operation
# otherwise its just ignoring the call
func_trapexit() {
  if [[ "${VAGRANT_CMD}" == "up" ]]; then
    infobold "Graceful exiting. Trying to clean as much as possible...";
    func_trapexitup "${VM_NAME}"
  elif [[ "${VAGRANT_CMD}" == "func_gup" ]]; then
    infobold "Graceful exiting. Trying to clean as much as possible...";
    func_trapexitgroup
  else 
    infobold "Nothing to clean up. Exiting!"
  fi
}

# func_trapexitgroup is cleaning
# all created virtual-machines by
# destroying them and deleting the 
# directory in $VMSTORE.
func_trapexitgroup() {
  for CFG in ${ALREADY_CREATED_VMS[@]}
  do
    # get config-file
    func_leftcut ${CFG}
    # get of the config-file
    func_rightcut ${CFG}
    VM_CONFIG=${LEFTSIDE}    
    ID=${RIGHTSIDE}
    func_govmpath
    cd "${GOVM_PATH}"
    func_sourcefile vm.cfg
    func_trapexitup "${ID}"
  done
}

# func_successexit is inserting the
# newly created virtual-machine
# to the db.txt for future interactions
# and listing purposes. BEfore inserting the
# new data it will also insert an empty line
# if one is needed because otherwise the appending 
# will not work properly
func_successexit() {
  infobold "Finishing touches...";
  func_insert
  success "VM ${ID} is set and ready to go :)"
}

func_newline() {
  sed -i -e '$a\' "${1}"
}

func_insert() {
  func_newline "${DB}"
  if [[ -z "${HOST_ONLY_IP}" ]]; then
    HOST_ONLY_IP="nil"
  fi

  echo "${ID}:${VM_NAME}:${OS_IMAGE}:${HOST_ONLY_IP}:${RAM}:${CPU}" >> "${DB}";
}

func_delete() {
  sed -i "/${VM_NAME}/d" "${DB}";
}

# func_hashtablegen is creating an comma 
# seperated string with the given 
# key:value pairs which will be used by
# the vagrantfile to create an actual
# ruby hash
func_hashtablegen() {
  CUSTOME_VARIABLES_STRING=""
  local i=0

  if [[ ${#CUSTOME_VARIABLES[@]} -gt 0 ]]; then
    for PAIR in "${CUSTOME_VARIABLES[@]}"
    do
      if ! [[ "${PAIR}" =~ ':' ]]; then
        PAIR="${PAIR}:${PAIR}"
      fi

      func_leftcut "${PAIR}"

      if [[ "${LEFTSIDE}" == "os_user" ]]; then
        func_rightcut "${PAIR}"
        SYNC_USER=${RIGHTSIDE}
      fi

      if [[ ${i} -eq 0 ]]; then
        CUSTOME_VARIABLES_STRING="${PAIR}" 
      else
        CUSTOME_VARIABLES_STRING="${CUSTOME_VARIABLES_STRING},${PAIR}" 
      fi
      i=$((i+1))
    done
  else
    error "Empty CUSTOME_VARIABLES Array: ${CUSTOME_VARIABLES}"
    error "If you dont want to have any comment it out"
    exit 1
  fi
}

# func_bridgeoptiongen is creating a string which is seperated 
# by commas which will then be used by the vagrantfile to create 
# an actual ruby arr for the bridge options
func_bridgeoptiongen() {
  local i=0
  if [[ "${VAGRANTFILE_TYPE}" == "custome" ]]; then
    return 0
  fi
  BRIDGE_OPTIONS_STRING=""
  if [[ ${#BRIDGE_OPTIONS[@]} -gt 0 ]]; then
    for VALUE in "${BRIDGE_OPTIONS[@]}"
    do
      if [[ ${i} -eq 0 ]]; then
        BRIDGE_OPTIONS_STRING="${VALUE}" 
      else
        BRIDGE_OPTIONS_STRING="${BRIDGE_OPTIONS_STRING},${VALUE}" 
      fi
      i=$((i+1))
    done
  else
    error "Empty BRIDGE_OPTIONS Array!"
    infobold "Your options are:"
    func_vmlistbridgedlifs
    exit 1
  fi
}

# func_setvenv is exporting 
# all neded env-variables
# for the current shell-session
func_setvenv() {
  export CPU;
  export RAM;
  export OS_IMAGE;
  export SCRIPT;
  export HOST_ONLY_IP;
  export VM_NAME;
  export DISK_SIZE_PRIMARY;
  export DISK_SIZE_SECOND;
  export MOUNTING_POINT;
  export FILE_SYSTEM;
  export CUSTOME_VARIABLES_STRING;
  export BRIDGE_OPTIONS_STRING;
  export VAGRANT_EXPERIMENTAL="disks"
  export SYNC_DIR;
  export SYNC_USER;
}

# func_resetvenv is deleting all
# exported env-variables of
# the current shell-session
func_resetvenv() {
  export -n CPU;
  export -n RAM;
  export -n OS_IMAGE;
  export -n SCRIPT;
  export -n HOST_ONLY_IP;
  export -n VM_NAME;
  export -n DISK_SIZE_PRIMARY;
  export -n DISK_SIZE_SECOND;
  export -n MOUNTING_POINT;
  export -n FILE_SYSTEM;
  export -n CUSTOME_VARIABLES_STRING;
  export -n BRIDGE_OPTIONS_STRING;
  export -n BRIDGE_OPTIONS;
  export -n SYNC_DIR;
  export -n SYNC_USER;

}

# func_setvfile is setting the
# vagrantfile that should 
# be used for the 
func_setvfile() {
  if [[ "${OS_TYPE}" == "windows" && "${VAGRANTFILE_TYPE}" == "default" ]]; then
    VAGRANTFILE=${FILE_DIR}/windows
  fi
}

# func_createcfg is copying the used
# config file for the creation
# and is appending some extra 
# information to it
func_createcfg() {
  cd ${BASEDIR} 
  REALPATH_VM_CONFIG=$(realpath ${VM_CONFIG})
  cp ${REALPATH_VM_CONFIG} ${GOVM_PATH}/vm.cfg

cat << EOF >> ${GOVM_PATH}/vm.cfg
# CREATED BY GOVM. DO NOT EDIT DATA! 
SYNC_DIR=${SYNC_DIR}
ID=${ID}
LOG_PATH=${LOG_PATH}
CUSTOME_VARIABLES_STRING="${CUSTOME_VARIABLES_STRING}"
EOF
}

# func_prepvenv is creating the
# syncFolder for the VM and also
# the log folder to log to
func_prepvenv() {
  ID="$(openssl rand -hex 5)"
  func_govmpath
  func_makedir "${GOVM_PATH}"

  if [[ -z ${LOG_DIR} ]]; then
    func_makedir "${GOVM_PATH}/logs"
    LOG_PATH=${GOVM_PATH}/logs
  else 
    LOG_PATH=${LOG_DIR}/${ID}
    func_makedir "${LOG_PATH}"
  fi

  if [[ ${SYNC_DIR} == "" ]]; then
    func_makedir "${VMSTORE}/${ID}/sync_dir"
    SYNC_DIR="${VMSTORE}/${ID}/sync_dir"
  fi

  SCRIPT_NAME=$(basename ${SCRIPT})
}

# func_postvenv is creating 
# directories and copying 
# all needed vagrant-files so that
# the vagrant commands can run in the
# newly created directory
func_postvenv() {
  func_setvenv;
  func_setvfile
  cp "${FILE_DIR}/${VAGRANTFILE}" "${GOVM_PATH}/Vagrantfile"
  DIR_NAME=$(dirname ${SCRIPT})
  func_makedir ${GOVM_PATH}/${DIR_NAME}
  cp "${PROVISION_DIR}/${SCRIPT}" "${GOVM_PATH}/${SCRIPT}"
  func_createcfg;
}

#func_sourcefile is sourcing the
# given file into the current
# shell-ENV
func_sourcefile() {
  . "${1}"
  func_govmpath
}

# validateAndSourceVMConfig
# is validating the config file
# for the virtual-machine (syntax only)
# meaning duplicated keys or not enough
# keys and if the config file is valid 
# it is getting sourced.
func_validatevmcfg() {
  local config_name=$(basename "${VM_CONFIG}")
  local iscorrect
  GIVEN_PARAMS_REQUIRED=()
  GIVEN_PARAMS_OPTIONAL=()
  info "Loading ${config_name}...";

  if [[  -s "${VM_CONFIG}" && "${VM_CONFIG}" == *.cfg ]]; then
    while read LINE
    do
      VALUE_LINE="$(echo -e "${LINE}" | tr -d '[:space:]')"
      if ! [[ "${VALUE_LINE}" =~ ^([A-Za-z0-9_]+)=([^'#'$%'&''*'^]+$) ]]; then
        [[ "${VALUE_LINE}" =~ ^\#.*$ || -z "${VALUE_LINE}" ]] && continue
        error "Wrong syntax: ${VALUE_LINE}"
        exit 1
      else
        NAME="${BASH_REMATCH[1]}"
        if [[ "${GIVEN_PARAMS_REQUIRED[*]}" =~ "${NAME}" || "${GIVEN_PARAMS_OPTIONAL[*]}" =~ "${NAME}" ]]; then
          error "Key duplicated ${NAME}"
          exit 1
        elif ! [[ "${VALID_CONFIG_PARAMS_VM[*]}" =~ "${NAME}" ]]; then
          error "Unexpected key ${NAME}"
          exit 1
        elif [[ "${NAME}" == "CUSTOME_VARIABLES" ]]; then
          iscorrect=$(func_verifyarrcustomearr "${LINE}")

          if [[ ${iscorrect} -eq 1 ]]; then
            error "Array is in the wrong syntax: ${LINE}"
            exit 1
          fi

          VALUE=$(echo "${LINE}" | cut -d "=" -f 2 | tr -d '()' | tr -d '"' )
          ARR=(${VALUE})
          CUSTOME_VARIABLES+=("${ARR[@]}")
        elif [[ "${OPTIONAL_CONFIG_PARAMS_VM[*]}" =~ "${NAME}" ]]; then
          GIVEN_PARAMS_OPTIONAL+=("${NAME}")
        elif [[ "${VALID_CONFIG_PARAMS_VM[*]}" =~ "${NAME}" ]]; then
          GIVEN_PARAMS_REQUIRED+=("${NAME}")
        fi
      fi
    done < ${VM_CONFIG}

  if [[ ${#GIVEN_PARAMS_REQUIRED[*]} -eq ${REQUIRED_PARAMS_CONFIG_VM} ]]; then
    # why we call func_hashtablegen here is because
    # if the custome_variables option is set then it will get
    # appended to the govm.custome_variable and the formatted string will be created
    func_hashtablegen
    success "Valid Syntax and Arguments for ${config_name}" 
  else 
    error "Not Enough Arguments: $(basename ${VM_CONFIG})"
    error "Valid-Arguments: ${VALID_CONFIG_PARAMS_VM[*]}"
    error "Given: ${GIVEN_PARAMS_REQUIRED[@]}"
    exit 1
  fi
  
  else 
    error "*.cfg is not existing or is empty or has the wrong extension (expected: .cfg)"
    exit 1
  fi
}

# func_validateappcfg
# is validating the config file
# for the application (syntax only)
# and if the config file is valid 
# it is getting sourced.
func_validateappcfg() {
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
      infobold "Be sure that if you are using the default FILE_DIR"
      infobold "that the BRIDGE_OPTIONS has to be set. Here are the possible options:"
      func_vmlistbridgedlifs
      exit 1
    fi

  else 
    error "govm.cfg is not existing or is empty."
    exit 1
  fi
}


# func_validaterequiredvmargs is  checking if 
# all given VM-Configs are the type 
# that they has to be like 
# CPU should be an integer not 
# a word and so on
func_validaterequiredvmargs() {
  local config_name=$(basename "${VM_CONFIG}")
  local isexisting=$(func_isvmexisting ${VM_NAME})
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
  fi

  if ! [[ "${VM_NAME}" =~ ^([A-Za-z0-9_-]+)$ ]]; then
    error "VM_NAME may only contain letters numbres hypens and underscores: ${VM_NAME}"
    exit 1
  elif [[ ${isexisting} -eq 0 ]]; then
    error "VM_NAME is duplicated: ${VM_NAME}"
    exit 1
  fi 

  if ! [[ "${SUPPORTED_OS_TYPES[@]}" =~ "${OS_TYPE}" ]]; then
    error "os is not currently supported: ${OS_TYPE}"
    exit 1
  elif ! func_validateip; then
    exit 1
  elif func_validateoptionalvmargs; then
    success "Valid values!" 
  fi
}

# func_validateoptionalvmargs is validating 
# the optional parameters of the config-file
func_validateoptionalvmargs() {
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
  elif [[ "${SYNC_DIR}" ]]; then
    if ! [[ -d "${SYNC_DIR}" ]]; then
      func_makedir "${SYNC_DIR}"
    fi
  fi

  if ! [[ -f "${FILE_DIR}/${VAGRANTFILE}" && -s "${FILE_DIR}/${VAGRANTFILE}" ]]; then
    error "VAGRANTFILE is empty or not found: ${VAGRANTFILE}"
    exit 1
  elif ! [[ "${VAGRANTFILE}" =~ ^([A-Za-z0-9_-]+)$ ]]; then
    error "VAGRANTFILE may only have letters numbers _ and -"
    exit 1
  fi

}

# func_validateappargs is checking if 
# the given values are valid and is setting 
# defaults if needed
func_validateappargs() {
  info "Validating App-Configuration arguments values..."
  if ! [[ -d ${VMSTORE} ]]; then
    func_makedir "${VMSTORE}"
  elif [[ "${LOG_DIR}" && ! -d "${LOG_DIR}" ]]; then
    func_makedir "${LOG_DIR}"
  elif ! [[ -d ${APPLIANCESTORE} ]]; then 
    func_makedir "${APPLIANCESTORE}"
  elif ! [[ -d ${CONFIG_DIR} ]]; then
    func_makedir "${CONFIG_DIR}"
  elif ! [[ -d ${PROVISION_DIR} ]]; then
    func_makedir "${PROVISION_DIR}"
  elif ! [[ -d ${FILE_DIR} ]]; then
    error "FILE_DIR does not exist: ${FILE_DIR}"
    exit 1
  elif ! [[ "${VAGRANTFILE}" =~ ^([A-Za-z0-9_-]+)$ ]]; then
    error "VAGRANTFILE may only have letters numbers _ and -"
    exit 1
  else
    success "Valid GOVM-Values!"
  fi
 
}

# func_validateip is validating the given ip
# if its already in use or not by following 2 steps:
# First we ping the given IP-Adress. If it is reachable
# then the IP adress is in use in (but it does not have to 
# a virtual-machine but still cant be used for a 
# virtual-machine). Second we check if the IP-Adress
# is existing in our system. If it does we exit. A recreation 
# can be forced with -d flag
func_validateip() {
  # check if ip is used in any way
  if [[ "${VAGRANTFILE_TYPE}" == "custome" ]]; then
    return 0
  fi 

  if ! [[ "${HOST_ONLY_IP}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    error "Invalid IP-Adress";
    exit 1;
  fi

  # NOTE: for git bash it is really 
  # complicated. it is a success even though
  # some of the packages are not received
  ping -c 2 -w 3 "${HOST_ONLY_IP}" &> /dev/null

  if [[ "${?}" -eq 0 && -z "${FORCE_REPLACE}" ]]; then
    error "Machine with the IP: ${HOST_ONLY_IP} exists. Choose an other IP-Adress. (Ping successfull)"
    error "It may not be an virtual-machine but a machine with the same ip in the same network is not possible!"
    exit 1
  fi

  # check if ip exist within govm-ecosystem
  func_getid "${VM_NAME}"

  if [[ "${ID}" != "nil" && -z "${FORCE_REPLACE}" ]]; then
    func_getid "${VM_NAME}"
    error "Machine still existing in our system ID: ${ID}. Run command with -r to force recreation."    
    exit 1
  fi

  if [[ ${FORCE_REPLACE} && "${ID}" != "nil" ]]; then
    func_destroy
    if [ "${VM_CONFIG}" ]; then
      func_sourcefile "${VM_CONFIG}"
    fi
  fi 

}


# func_createvenv is
# sourcing the config file
# in the ${VMSTORE}/${ID}
# and is running the given command afterwards
# otherwise the Vagrantfile cannot pull
# the ENV-Variables
func_createvenv() {
  func_govmpath
  cd ${GOVM_PATH}
  func_sourcefile vm.cfg;
  func_setvenv;
}

# func_createvm is creating the
# virtual machine using vagrant up 
func_createvm() {
  infobold "Creating Virtual-Machine ${ID}. This may take a while..."
  # vagrant up &> ${LOG_PATH}/"${TIMESTAMP}_up.log" 
  vagrant up
}

# func_up is creating a virtual-machine with vagrant up. 
# Before creating the virtual-machine it will also 
# validate the the used config file for the creation 
# and create the needed environment for vagrant to run properly.
func_up() {
  func_validatevmcfg;
  func_sourcefile "${VM_CONFIG}";
  func_validaterequiredvmargs && func_prepvenv;
  func_postvenv;
  cd ${GOVM_PATH};
  func_createvm && func_successexit || error "Something went wrong. Debbuging information can be found at ${LOG_PATH}"
}

# alias to vagrant func_destroy
func_destroy() {
  infobold "Destroying ${ID}..."
  func_createvenv;
  vagrant destroy --force &> "${LOG_PATH}/${TIMESTAMP}_destroy.log"
  cd ${BASEDIR}; 
  func_clean;
}

# alias to vagrant func_halt
func_halt() {
  local FIRST_ARG=${1:-""}
  local isrunning
  info "Stopping ${ID}..."
  func_createvenv;
  isrunning=$(func_isvmrunning "${VM_NAME}")

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
func_ssh() {
  info "SSH into ${ID}"
  func_createvenv;
  vagrant ssh;
}

# alias to vagrant func_start
func_start() {
  info "Starting ${ID}. This may take some time..."
  func_createvenv;
  vagrant up &> ${LOG_PATH}/"${TIMESTAMP}_start.log"
  success "${ID} up and running!"
}

# create an appliance
# of the given virtual-machine
func_export() {
  infobold "Exporting ${VM_NAME}. This may take some time..."
  func_getvmname "${ID}"
  func_halt 'export';
  func_appliancesemver "${VM_NAME}"
  func_vmexport "${VM_NAME}" "single"
  success "Finished! appliance can be found at ${APPLIANCESTORE}"
}

# func_groupup is just a helper for 
# starting the virtual machines
# without the any validaton
# before it
func_groupup() {
  func_prepvenv;
  func_postvenv;
  cd ${GOVM_PATH};
  ALREADY_CREATED_VMS+=("${1}:${ID}")
  func_createvm && func_successexit || error "Something went wrong. Debbuging information can be found at ${LOG_PATH}."
}

# group is creating
# as many virtuals machines 
# as configs files given in the 
# given directory
func_gup() {
  IP_ADRESSES=()
  NAMES=()

  # checking syntax of all configs files
  for CFG in ${GROUP}/*.cfg; 
  do
    VM_CONFIG="${CFG}"
    func_newline "${VM_CONFIG}"
    func_validatevmcfg
  done

  # checking for duplication of ip or names in the given group
  for CFG in ${GROUP}/*.cfg;
  do
    func_resetvariables
    func_sourcefile "${CFG}"

    if [[ "${IP_ADRESSES[*]}" =~ "${HOST_ONLY_IP}" ]]; then
      error "Duplicated IP-Adress ${HOST_ONLY_IP}"
      exit 1
    elif [[ "${NAMES[*]}" =~ "${VM_NAME}" && "${VM_NAME}" ]]; then
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
    func_resetvariables
    cd "${BASEDIR}"
    func_sourcefile "${CFG}"
    func_validaterequiredvmargs 
  done

  info "Starting creation process..."

  # starting creation of all
  # virtual machines
  for CFG in ${GROUP}/*.cfg; 
  do
    cd "${BASEDIR}"
    func_resetvariables
    VM_CONFIG=${CFG}
    func_sourcefile "${CFG}";
    func_resetvenv;
    info "Creating $(basename ${CFG})...";
    func_groupup "${CFG}";
  done
}

# func_gdestroy is an alias
# for vagrant destroy 
# but build for a group
# destruction
func_gdestroy() {
  for CFG in ${GROUP}/*.cfg; 
  do
    VM_CONFIG=${CFG}
    cd "${BASEDIR}"
    func_resetvenv
    func_sourcefile "${CFG}";
    func_getid "${VM_NAME}"
    func_destroy
  done
}

# func_gdestroy is an alias
# for vagrant destroy 
# but build for a group
# destruction
func_ghalt() {
  local FIRST_ARG=${1:-""}
  local isrunning;
  for CFG in ${GROUP}/*.cfg; 
  do
    VM_CONFIG=${CFG}
    cd "${BASEDIR}"
    func_resetvenv
    func_sourcefile "${CFG}";

    # VM_NAMES is not necessary for func_halt 
    # but if func_halt is getting used in combination with export
    # it is usefull to not do it two times
    if [[ ${FIRST_ARG} == "export" ]]; then
      VM_NAMES+=("${VM_NAME}")
    fi

    isrunning=$(func_isvmrunning "${VM_NAME}")
    
    if [[ "${isrunning}" -eq 1 ]]; then
      infobold "Machine is not running. Continueing..."
      continue
    fi

    func_getid "${VM_NAME}"
    if [[ "${ID}" ]]; then
      func_govmpath
      cd ${GOVM_PATH}
      func_halt
    else
      error "Did not find the machines! Do they even run?"
      exit 2
    fi
  done
}

func_gstart() {
  local exists
  local isrunning
  for CFG in ${GROUP}/*.cfg; 
  do
    VM_CONFIG=${CFG}
    cd "${BASEDIR}"
    func_resetvenv
    func_sourcefile "${CFG}";
    exists=$(func_isvmexisting ${VM_NAME})
    if [[ ${exists} -ne 0 ]]; then
      error "Machine ${VM_NAME} does not exists"
      exit 1
    fi
    isrunning=$(func_isvmrunning ${VM_NAME})
    if [[ ${isrunning} -eq 0 ]]; then
      infobold "Machine ${VM_NAME} is already up and running. Continuening with next..."
      continue
    fi
    func_getid "${VM_NAME}"
    func_start
  done
}

# alias to vboxmanage.exe export <machines>
func_gexport() {
  local basename
  infobold "Exporting group: $(basename ${GROUP})"
  func_ghalt "export"
  basename=$(basename ${GROUP})
  func_appliancesemver "${basename}"
  func_vmexport "${basename}" "group"
}

# func_list is listing all the 
# virtual-machines created
# by govm
func_list() {
  if [ -z "$(ls -A ${VMSTORE})" ]; then
    infobold "No Machines have been created yet!"
    exit 1
  fi
  
  column ${DB} -t -s ":" 
}

# func_vmexport is exporting a single virtual-machine
# or a group of virtual-machines as an .ova file to
# the $APPLIANCESTORE. It is also checking if a wsl
# system is used and is converting the path to a 
# windowspath for a proper function
func_vmexport() {
  local dir=${1}
  local type=${2}

  if [[ ${MAIN_OVA} == "true" ]]; then
    dir=""
  else
    dir="/${dir}"
  fi

  func_osdefault
  if [[ "${type}" == "single" ]]; then
    infobold "Exporting ${VM_NAME} as ${APPLIANCE_NAME}"
    if [[ "${CURRENT_OS}" == "microsoft" ]]; then
      vboxmanage.exe 'export' "${VM_NAME}" --output "${APPLIANCESTORE}${dir}/${APPLIANCE_NAME}"
    else 
      vboxmanage 'export' "${VM_NAME}" --output "${APPLIANCESTORE}${dir}/${APPLIANCE_NAME}"
    fi

  elif [[ "${type}" == "group" ]]; then

    if [[ "${CURRENT_OS}" == "microsoft" ]]; then
      vboxmanage.exe 'export' "${VM_NAMES[@]}" --output "${APPLIANCESTORE}/${dir}/${APPLIANCE_NAME}" && success "Created appliance ${APPLIANCE_NAME}"
    else 
      vboxmanage 'export' "${VM_NAMES[@]}" --output "${APPLIANCESTORE}/${dir}/${APPLIANCE_NAME}" && success "Created appliance ${APPLIANCE_NAME}"
    fi
    infobold "Exporting machine group (${VM_NAMES[*]}) as ${APPLIANCE_NAME}" 
  else
    error "currently not supported for ${CURRENT_OS}"
    exit 1
  fi
}

# func_vmlistbridgedlifs is listing all
# posbbile bridge-options that the user
# can use for the bridge-network in virtualbox
func_vmlistbridgedlifs() {
  if [[ "${CURRENT_OS}" == "microsoft" ]]; then
    vboxmanage.exe list bridgedifs | grep -w "Name:" | tr -s " " 
  else 
    vboxmanage list bridgedifs | grep -w "Name:" | tr -s " "
  fi
}

# integreationtest will test all functionalities in the app
# by simulating an example func_usage of an end-user
# for this the default.cfg and
# an example group located at .govm/configs
func_integrationtest() {
  if ! [[ -f ${BASEDIR}/${GOVM}/tested ]]; then
    PROVISION_DIR="${BASEDIR}/${GOVM}/provision"
    FILE_DIR="${BASEDIR}/${GOVM}/vagrantfiles"
    GROUP="${BASEDIR}/${GOVM}/configs/ubuntu"
    APPSTORE=${APPLIANCESTORE}
    infobold "Running some tests to asure that everything works as planned."
    infobold "This will take some time. Get a coffee... :)"
    func_up
    func_halt
    func_start
    func_export
    APPLIANCESTORE=${APPSTORE}
    func_export
    APPLIANCESTORE=${APPSTORE}
    MAIN_OVA="true"
    func_export 
    APPLIANCESTORE=${APPSTORE}
    func_destroy
    success "Single-functions are working!"
    infobold "Testing group functions..."
    sleep 10
    ID=""
    MAIN_OVA="false"
    func_gup
    func_ghalt
    func_gstart
    func_gexport
    APPLIANCESTORE=${APPSTORE}
    MAIN_OVA="true"
    func_gexport
    APPLIANCESTORE=${APPSTORE}
    func_gdestroy
    success "Group-functions are working!"
    infobold "Testing edge cases..."
    VM_CONFIG="${BASEDIR}/${GOVM}/default.cfg"
    ID=""
    func_up
    FORCE_REPLACE="true" 
    func_up
    func_destroy
    func_rmdirrf "${APPLIANCESTORE}"
    func_rmdirrf "${VMSTORE}"
    func_rmdirrf "${GOVM}/configs"
    touch "${BASEDIR}/${GOVM}/tested"
    success "Finished testing! Everthing working!"
    exit 0
  fi
}

# func_validateposixgroup is validatin
# all given flags but not the values
# of the given flags. These are validated in
# validateInput. Here we validate the given flags
# and if they can be used together 
# using groups.
func_validateposixgroup() {
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

  if [[ "${#CHECK_FILE[@]}" -eq $(( ${#FILE_GROUP[@]} -1 )) && "${#CHECK_VAGRANT[@]}" -eq 0 && "${#CHECK_LIST[@]}" -eq 0 && "${#CHECK_GROUPUP[@]}" -eq 0 && "${VAGRANT_CMD}" == "up" ]]; then
    infobold "Running ${VAGRANT_CMD} on ${VM_CONFIG}"
    VM_CONFIG=${CONFIG_DIR}/${VM_CONFIG}
    SINGLE_CFG_NAME=$(basename ${VM_CONFIG})
    func_newline "${VM_CONFIG}"
  elif [[ "${#CHECK_FILE[@]}" -eq 0 && "${#CHECK_VAGRANT[@]}" -eq $(( ${#VAGRANT_GROUP[@]} -1 )) && "${#CHECK_LIST[@]}" -eq 0 && "${#CHECK_GROUPUP[@]}" -eq 0 && ! "${VAGRANT_CMD}" =~  g[a-z]+ ]]; then
    infobold "Running \"${VAGRANT_CMD}\" on ${ID}..."
  elif [[ "${#CHECK_FILE[@]}" -eq 0 && "${#CHECK_VAGRANT[@]}" -eq 0 && "${#CHECK_LIST[@]}" -eq ${#LIST_GROUP[@]} && -z "${VAGRANT_CMD}" && "${#CHECK_GROUPUP[@]}" -eq 0 ]]; then
    infobold "Listing all virtual-machines..."
  elif [[ "${#CHECK_FILE[@]}" -eq 0 && "${#CHECK_VAGRANT[@]}" -eq 0 && "${#CHECK_LIST[@]}" -eq 0 && "${#CHECK_GROUPUP[@]}" -eq  $(( ${#GROUPCMD_GROUP[@]} -1 )) && "${VAGRANT_CMD}" =~ g[a-z]+ ]]; then
    infobold "Running \"${VAGRANT_CMD}\" on group: $(basename ${GROUP})"
    GROUP=${CONFIG_DIR}/${GROUP}
  elif [[ "${#CHECK_FILE[@]}" -eq 0 && "${#CHECK_VAGRANT[@]}" -eq 0 && "${#CHECK_LIST[@]}" -eq 0 && "${#CHECK_GROUPUP[@]}" -eq 0 && "${VAGRANT_CMD}" =~ [a-z]+ ]]; then
    infobold "Running command \"${VAGRANT_CMD}\" on default-machine..."
  else
    error "Too many or not enough arguments."
    error "It may also be that you used a wrong combination like govm -v start -f some/vm.cfg."
    func_usage;
    exit 1
  fi

}

# main is the entering point
# of the application
main() {
  func_predefault
  func_init;
  func_vagrantfileapp;
  func_validateappcfg;
  func_sourcefile ${GOVM_CONFIG};
  func_validateappargs;
  func_postdefault;
  func_vagrantfilevm;
  func_validateposixgroup "$@"
  func_integrationtest

  if [[ "${VAGRANT_CMD}" == "ssh" && "${ID}" ]]; then
    func_ssh
  elif [[ "${VAGRANT_CMD}" == "export" && ${ID} ]]; then
    func_export
  elif [[ "${VAGRANT_CMD}" == "gup" && -d "${GROUP}" ]]; then
    func_gup; 
  elif [[ "${VAGRANT_CMD}" == "gstart" && -d "${GROUP}" ]]; then
    func_gstart
  elif [[ "${VAGRANT_CMD}" == "gdestroy" && -d "${GROUP}" ]]; then
    func_gdestroy
  elif [[ "${VAGRANT_CMD}" == "ghalt" && -d "${GROUP}" ]]; then
    func_ghalt
  elif [[ "${VAGRANT_CMD}" == "gexport" && -d "${GROUP}" ]]; then
    func_gexport
  elif [[ "${LIST_DATA}" ]]; then
    func_list
  elif [[ "${VAGRANT_CMD}" == "destroy" && "${ID}" ]]; then 
    func_destroy;
  elif [[ "${VAGRANT_CMD}" == "halt" && "${ID}" ]]; then
    func_halt;
  elif [[ "${VAGRANT_CMD}" == "start" && "${ID}" ]]; then
    func_start
  elif [[ "${VAGRANT_CMD}" == "up" ]]; then
    func_up
  else 
    error "Posix-Arguments did not match!"
    func_usage
  fi
}

main "$@"
