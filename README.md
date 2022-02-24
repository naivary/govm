# Purpose
vagrant-wrapper or govm (which is called govm because it will be implemented in go in the future with a proper API) is 
currently a shell-wrapper for vagrant and virtualbox to create automatically:
* one highly configurable virtual machine
* run any action you know from vagrant on this machine
  * ssh
  * destroy
  * start
  * halt
* create a group of virtual machines with multiple config-files reperesent each virtual machine
* manage the group with the known commands (destroy/start/halt)
* export a group or one virtual machine as an .ova file

# Requirements
The only requirements are [HashiCorp Vagrant](https://www.vagrantup.com/) and [Oracle VirtualBox](https://www.virtualbox.org/).
Because we don't want to waste your time there are some pre-written **init-scripts** for [windows(wsl)](init/wsl.sh) and [ubuntu](init/linux.sh) which will
install all requirement and make some adjustement needed for `govm` to work properply.

## wsl.sh
The init script wsl.sh will install **Chocolatey, Oracle VirtualBox, HashiCorp Vagrant**. 
It will also try to create a `Host-Only Ethernt Adapter` with the `IPv4: 192.168.56.1/24`. This is only
the windows part. For HashiCorp Vagrant to run properly using wsl there are some **env-variables**
needed. 
1. `export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"`
2. `export PATH="$PATH:/mnt/c/Program Files/Oracle/VirtualBox"` 

These env-Variables will be appended to your `~/.bashrc` so they will be permanently set.
Becuase govm.sh is using some `sudo` commands for removing and creating folders you may be
asked to enter a password. This is obviulsy killing the User-Experience so the init script 
will also create a file at `/etc/sudoers.d/<username>` and will allow the current user to run any
sudo commands without entering the password (`<username> ALL = PASSWD:ALL`).

# Documentation

## Usage
`-v [up|halt|start|ssh|destroy]` is setting the vagrant command you want to run. You can also prefix any command with `g[up|halt|start|ssh|destroy]` e.g `gdestroy` to run a command like `destroy` on the whole group. <br/>

`-f [path]` is specifing the path to a `*.config` file with the *possible arguments*. <br/>
`-g [path]` is setting the path to a directory with one or more `*.cfg` files each representing a `virtual machine` creating multiple virtual machines at once <br/>
`-m [ID]` is setting the `virtual machine` which should be manipulated by the `-v` command. <br/>
`-i` if this is present the group or virtual machine  that is getting `exported` as an `.ova` is set as the `main.ova`. <br/>
`-r` if this is present it will force a `recreation` of the vm if there is a virtual machine registered but not reachable. You may also use it to `reload` a virtual machine or group. <br/>

Every command should but does not have to start with: `govm -v [options]`. Afterwards you can specifiy antyhing like `-f`.
This way every command is properly structured and human readable.

If you rungthe command `govm -v [options]` without specifiying `-f`, `-g` or `-m` govm will run the defined command on the **default** virtual-machine.

# Config
> Config (cfg) files are the way that govm can be manipulated and controlled 
> to serve your purpose.
There are two types of `.cfg files`.
1. `*.cfg` which is representing a virtual machine and the [options](#config-options) is should have after it has been created.
2. [govm.cfg](#govmcfg). This file is controlling the software as a whole for example setting default values or where the virtual machine metadata should be saved.

## vm.cfg 
> *.cfg files are setting the options with which the virtual-machine
> should be created. The name of file does not have to be vm.cfg it can be anthing
> but has to have the extension .cfg.

There are lots of options to that can be defined to create a virtual-machine based on yout needs. In this section you will learn about all possible options. <br/>
`CPU` <br/>
Quantity of proceccors 
for the virtual-machine. Has to be 1
or bigger but less than 100

`RAM` <br/>
Amaount of memory for the virtual-machine. 
min: 512 MB; max: 16000 MB.

`OS_IMAGE` <br/>
base box that vagrant should use 
for setting the operating system.
If you use windows be sure that
the `OS_TYPE` is also set to windows.
All possible base-boxes can be found [here](https://app.vagrantup.com/boxes/search?provider=virtualbox)

`OS_TYPE` <br/>
OS_TYPE is informing the application
which type of operating-system you are
using. This is needed because as always windows
needs some special configurations in the vagrantfile.
Valid values are "linux" and "windows"
default: linux

`SCRIPT` <br/>
Defining the provision script that shall run 
in the virtual-machine. If you wish to
have the minimum of provision
its recommended to take provision/default.sh
which is only doing an update and upgrade in ubuntu.
Every path has to be set relative to the `PROVISION_DIR`.

`HOST_ONLY_IP` <br/>
Defining the ip of the host-only-virtual-adapter 
of the virtual-machine.
NOTE: 192.168.56.2 is reserved for 
the default virtual-machine. 
Its recommended to never use it.
default: 192.168.56.2

`VM_NAME` <br/>
The name of the virtual-machine.
Take a describtive name that is representing 
the purpose of the virtual-machine
`default: <HOST_ONLY_IP>_<ID>`

`SYNC_FOLDER` <br/> 
The directory that shall be mounted 
from host to guest. The default 
is a created directory called
`sync_folder` in the home directory
of the guest-machine mounted to
`VMSTORE/GOVM-ID/sync_folder`.
If you wish the default behavior
comment out the option.

`DISK_SIZE_PRIMARY` <br/>
here you can set the main 
disk size in the virtual-machine  
its recommended to have a 
disk size of 32GB or more 
NOTE: Because this feature is currently
experimental there are some issues with `wsl`.
Because of this it is not recommend to use it with `wsl`.
For more Information read [Disk size](#Disk-Size)
`default: 40GB`

`DISK_SIZE_SECOND` <br/>
If you would like to have
a second disk attached to your
virtual machine you can 
set a disk-size here
otherwise there is only
one attached 
`default: nil`

`MOUNTING_POINT` <br/>
Where shall the second disk be mounted?
note the path has to be always an absolut
path. Tt is not allowed to mount to:
- /root
- /
- /boot
- /var
IMPORTANT: always start your path
with a double // if using git-bash. This prevents that the
path is getting converted by mingw.
`default: nil`

`FILE_SYSTEM` <br/>
FILE_SYSTEM is setting the
mkfs that is getting used 
on the second disk. Valid values are:
`ext3`
`ext4`
`xfs`
`default: nil`
 
`PROVISION_VAR` <br/>
PROVISION_VAR are variables
that you want to access 
in your provision script.
It is an array seperated with 
whitespace. For example ("GIT_PASSWORD:hardpassword" "GIT_USERNAME=No1Lik3U").
If you dont need it just comment out the parameter.
If you just declare an string in the array like ("something")
then this will be taken as key and value like this 
("something") -> {something => something}
SPECIAL-VARIABLES:
1. os_user: if this is set this users home-directory will be used as the mounting point in the virtual-machine
`default: ()`



## govm.cfg

# Creating single or groups

## Single-creation
> Single-creation is the process of creating one virtual-machine with an optional provided
> .cfg file representing the virtual-machine.

To start a single-creation you have two options:
1. You can run `govm -v up`. This will create a virtual machine based on the [default.cfg](.govm/default.cfg).
2. You can run `govm -v up -f your/vm/config/path`. This will create a virtual-machine based on the `.cfg` that you provided.

After the virtual machine is created you may interact with it by using the `ID` of the virtual-machine created by `govm`.
You can get any `metadata-information` of the running virtual-machines by running `govm -l`. After you got the ID you can ran any command
that you know from **Vagrant** and [more!](#Exporting) <br/>

The syntax for any interaction with the virtual machine is `govm -v [options] -m [ID]`.

## Group-creation
> Group-creation is the process of creating multiple virtual-machines based on a directory
> which contains multiple .cfg files, each representin a virtual-machine with his own
> configuration.

To start a group-creation you have to run `govm -v gup -g path/to/dir/with/cfg/files`

After the group is created you can interact with the each virtual-machine as it would be a single-creation.
For some **syntax-sugar** there are some *group-commands* as described in [usage](#usage) like `gdestroy` or `ghalt` which will run the given command on the whole group so you dont have to run a single command by hand on every virtual-machine in the same group.

## Exporting
> Exporting is the possibility to export a group or a single 
> virtual-machine as an .ova file which then can be used in every
> Type-2 virtualization provider because it is an standard.

This feature is a great way to create a cluster-system have it saved as an `.ova` file and used it anywhere you like. This is giving you the possibility
to keep your `GUI` clean from **dead virtual-machines**. 

### How is the .ova filename generated?

For a single-export `govm -v export -f some/cfg/file` its straightforward: The name of the virtual-machine will be used.
For a group-export `govm -v gexport -g some/dir` the directory name is used for the name of the `.ova` file.

After the first part of the name is calculated based on the rules described above the versioning will be calculated. The versioning is based on [semver](https://semver.org/) standard.

# WSL
As always there are some specialities needed for windows (wsl). We tried to cover as much as possible but still there are some limitation
compared to a native linux machine.

## Disk-Size


# Best-practices
Here are some best practices that you may follow. It is just a recommendation because the software was mostly tested this way and will promise
a flawless experience.

## Project structure


# Errors

## Interpretation 
If you see anytime an error message with "nil" then this means
that some option was not set which is required if you are using
one other option for example: if you would like to have
an additional disk with the option DISK_SIZE_SECOND but your are not
setting the FILE_SYSTEM for it, then you will see that type of error message.


## Known issues and possible fixes

https://github.com/hashicorp/vagrant/issues/6736  
FIX: chcp.com 1252  
https://github.com/moby/moby/issues/24029  
FIX: start every mounting path with a double slash in the config file
https://stackoverflow.com/questions/14219092/bash-script-and-bin-bashm-bad-interpreter-no-such-file-or-directory
https://stackoverflow.com/questions/11616835/r-command-not-found-bashrc-bash-profile
