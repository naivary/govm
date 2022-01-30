usage() {
  echo "-c [integer] is setting the count of CPUs"
  echo "-m [integer] is setting the RAM"
  echo "-i [integer] is setting the OS-Image"
  echo "-s [path] is setting the path to the provision-shell-script"
  echo "-h [ipv4] is setting the ip-adress for host-only of the type 192.168.56.0/24"
  echo "-f [path] is specifing the path to a *.config file with the parameters CPU, RAM, OS_IMAGE, IP and SCRIPT"
}

while getopts "c:m:i:f:s:h:" OPT; do
  case "${OPT}" in
    c)
      CPU=${OPTARG}
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
    ?)
      usage
      exit 1
      ;;
  esac
done

setEnvVar() {
  export CPU;
  export RAM;
  export OS_IMAGE;
  export SCRIPT;
  export HOST_ONLY_IP;

  # not set by User
  export SYNC_FOLDER;
  export VM_NAME;
}

reset() {
  echo "Cleaning up...";
  unset CPU;
  unset RAM;
  unset OS_IMAGE;
  unset SCRIPT;
  unset HOST_ONLY_IP;

  #not set by User
  unset SYNC_FOLDER;
  unset VM_NAME;
}

syncFolder() {
  if [ ! -d "~/.machines" ]; then
    mkdir -p "$HOME/.machines"
  fi
  UUID="$(xxd -pu <<< uuidgen)" 
  VM_NAME="${HOST_ONLY_IP}_${UUID}"
  mkdir -p -- "$HOME/.machines/$UUID"
  SYNC_FOLDER="$HOME/.machines/$UUID"
}

sourceConfigFile() {
  echo "Loading $CONFIG_FILE...";
  . "$CONFIG_FILE";
}

initVM() {
  echo "Creating Virtual-Machine with the ID: $UUID"
  vagrant up;
}

validateInput() {
  echo "Validating Paramaters..."
  if [[ -n ${CPU//[0-9]/} || $CPU -lt 1 ]]; then
    echo "CPU may only contain numbers and shall be bigger than 1";
    reset;
    return 1;
  elif [[ -n ${RAM//[0-9]/} || $RAM -lt 4 ]]; then
    echo "Memory may only contain numbers and shall be bigger than 4";
    reset;
    return 1;
  elif ! [[ -s $SCRIPT ]]; then
    echo "Shell-script not found or empty";
    reset;
    return 1;
  elif ! [[ $HOST_ONLY_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "Invalid IP-Adress";
    reset;
    return 1;
  else 
    echo "Everthing fine!" 
    return 0;
  fi
}

main() {
  if [[ ( $CPU && $RAM && $OS_IMAGE && $SCRIPT && $HOST_ONLY_IP ) && ( -z $CONFIG_FILE) ]]; then
    # ineraction 
    syncFolder;
    validateInput && setEnvVar;
    initVM;
    mv "./.vagrant" "$SYNC_FOLDER";
  elif [[ -s $CONFIG_FILE && $CONFIG_FILE == *.config ]]; then
    # file
    sourceConfigFile;
    syncFolder;
    validateInput && setEnvVar;
    initVM;
    mv "./.vagrant" "$SYNC_FOLDER";
  else 
    # error
    echo "Error: Not enough Arguments or *.config file not given."
    usage;
  fi
}

main;