# govm
vagrant-wrapper or govm (which is called govm because it will be implemented in go in the future with a proper API) is 
currently a shell-wrapper for vagrant and virtualbox to create automatically:
- one highly configurable virtual machine
- run any action you know from vagrant on these machines
- create a group of virtual machines with multiple config-files each representing a virtual machine
- manage the group with the known commands (destroy/start/halt)
- export a group or one virtual machine as an .ova file
- easy import of [main.ova](#mainova) file with a `.exe` file.
- providing your own `Vagrantfile`

# Requirements
The only requirements are [HashiCorp Vagrant](https://www.vagrantup.com/) and [Oracle VirtualBox](https://www.virtualbox.org/).
Because we don't want to waste your time, there are some pre-written **init-scripts** for [wsl](init/wsl.sh) and [ubuntu](init/linux.sh) which will
install all requirements and make some adjustements needed for `govm` to work properply. If you decide to run one of the init scripts be sure to reboot your local machine and then start using govm. 

IMPORTANT: do not use govm directly after using the init script! There may occur an error which is discussed in [this](#init) section (even though you did not use govm directly afterwards).

## init: wsl
The init script wsl.sh will install `Chocolatey`, `Oracle VirtualBox` and `HashiCorp Vagrant`. 
It will also try to create a `Host-Only Ethernt Adapter` with the `IPv4: 192.168.56.1/24` but it may fail because a reboot is needed before using VirtualBox-API `vboxmanage`. Because of this it may occur an error which can be [solved](#init). This is only the windows part. For HashiCorp Vagrant to run properly using wsl there are some `env-variables`
needed. 
1. `export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"`
2. `export PATH="$PATH:/mnt/c/Program Files/Oracle/VirtualBox"` 

These env-Variables will be appended to your `~/.bashrc` so they will be permanently set.
Because govm is using some `sudo` commands for removing and creating folders you may be
asked to enter a password. This is obviously killing the User-Experience so the init script 
will also create a file at `/etc/sudoers.d/<username>` and will allow the current user to run any
sudo commands without entering the password `<username> ALL = PASSWD:ALL`.

## init: ubuntu
This init script will do the same as [wsl](#wslsh) but for ubuntu/debian. 
This script is created for ubuntu and may be used for other linux-distrubutions 
that use the `apt` package manager.

# Documentation
The following sections will explain in detail how to use `govm`. Before you start reading the documentation here are some conventions:
1. `vm.cfg` is always representing a virtual-machine config file. For the purpose of the documentation it is named uniformerly. But your config files can be named in any way you like.
2. `-someflag [options]` options is always referring to the options explained in the [Usage](#usage) section.
3. `$VARIABLE` is meaning that this variables can be set by you via the config file or it is an intern variable that is generated. For example `$GOVM-ID` is referring to the `hex-id` that is generated by `govm` for the virtual-machine for future unique references. (obviously $HOME, $PATH etc... have still the same linux meaning) 
4. `govm.XXX` means that the value definied in `govm.cfg` will be used.
5. `<config-option>: <default-value> -[opt|req]`. Using this syntax helps to simplify  which defaults the config-options in the different config files have and if they are **required(req)** or **optional(opt)**
6. If you wish to have the default for a value just comment out the parameter in the config file.

## Usage
`-v [up|halt|start|ssh|destroy|export]` is specifing the govm-command that should be run. Prefixing the command with a `g` e.g `gdestroy` will run the command as a `group-command`<br/>
`-f [path]` path to a `vm.cfg`. <br/>
`-g [path]` specifing a directory with one or more `vm.cfg` files each representing a virtual machine. <br/>
`-m [$GOVM-ID]` the virtual machine which should be manipulated by the specified `-v` command<br/>
`-i` if present the group or virtual machine is getting exported as [main.ova](#mainova). <br/>
`-r` if present it will force a `recreation` of the virtual-machine if there is a virtual-machine registered but not reachable. You may also use it to  `reload` a virtual machine or group.  
`-l` listing all virtual-machine created by `govm` <br/>

If you wish to list all virtual-machines with some additional information run `govm -l`. <br/>

Every command should start as following `govm -v [options]`. This way every command is properly structured and human readable. <br/>

If you run the command `govm -v [options]` without specifiying `-f`, `-g` or `-m` govm will run the defined command on the `default.cfg` virtual-machine. <br/>

# Config
Config files are the way that govm can be manipulated and controlled to serve your purpose. There are two types of `.cfg files`.
1. `vm.cfg` which is representing a virtual machine and the [configuration](#vmcfg) it should have.
2. `govm.cfg` . This [file](#govmcfg) is controlling the software as a whole e.g. metadata and storing information.

## vm.cfg 
In the following you will be introduced to all the config options with a detailed explanation what the option will affect.

`CPU: govm.CPU -opt` <br/>
Quantity of proceccors 
for the virtual-machine. 
`min: 1`, `max: 100`

`RAM: govm.RAM -opt` <br/>
Amount of memory for the virtual-machine. 
`min: 512 MB` `max: 16000 MB`.

`OS_IMAGE: govm.OS_IMAGE -opt` <br/>
Base Box that vagrant should use 
for setting the operating-system.
If you use windows be sure that
the `OS_TYPE` is also set to windows.
All possible base-boxes can be found [here](https://app.vagrantup.com/boxes/search?provider=virtualbox).

`OS_TYPE: linux -opt` <br/>
Is informing the application
which type of operating-system you are
using. This is needed because as always windows
needs some special configurations in the vagrantfile.
Valid values are linux and windows.

`SCRIPT: govm.SCRIPT -opt` <br/>
Provision script that will run for the virtual-machine.
If you wish to have the minimum of provision
its recommended to take [provision/default.sh](provision/default.sh)
which is only doing an update and upgrade on the system.
Every path has to be set relative to the `govm.PROVISION_DIR`.

`HOST_ONLY_IP: 192.168.56.2 -req` <br/>
IPv4-Address of the Host-Only-Virtual-Adapter 
for the virtual-machine.
NOTE: 192.168.56.2 is reserved for 
the default virtual-machine so do not use it!

`VM_NAME: $HOST_ONLY_IP+$GOVM-ID -opt` <br/>
Name of the virtual-machine.

`SYNC_DIR: $VMSTORE/$GOVM-ID/SYNC_DIR -opt` <br/> 
The directory that should be mounted 
from host to guest. The default 
is a created directory called
`sync_dir` in the home directory
of the guest-machine which will be mounted to
`govm.VMSTORE/$GOVM-ID/sync_dir`. 


`DISK_SIZE_PRIMARY: 40GB -opt` <br/>
Disk-Size of primary disk of the virtual-machine.  
NOTE: Because this feature is currently
experimental there are some issues with `wsl`.
Because of this it is not recommend to use it with `wsl`.
For more Information read [Disk size](#Disk-Size) <br/>

`DISK_SIZE_SECOND: nil -opt` <br/>
If you would like to have
a second disk attached to your
virtual machine you can 
set a disk-size here
otherwise there is only
one attached <br/>

`MOUNTING_POINT: nil` <br/>
Mounting point of the second disk. By definition all mounting point paths has to be an absolute path so it has to start with a `/`. All mounting paths are supported beside: 
- `/root`
- `/`
- `/boot`
- `/var`

IMPORTANT: always start your path
with a double // if using git-bash. This prevents that the
path is getting converted by `mingw`. 
This variable is required if `DISK_SIZE-SECOND` is set otherwise it is getting ignored <br/>

`FILE_SYSTEM: nil` <br/>
mkfs for the second disk. Valid values are:
- `ext3`
- `ext4`
- `xfs` <br/>

This variable is required if `DISK_SIZE-SECOND` is set otherwise it is getting ignored.
 
`PROVISION_VAR: () -opt` <br/>
Variables that you want to access 
in your provision script.
It is an array seperated with 
whitespace e.g. ("KEY:VALUE" "KEY:VALUE").
If you just declare an string in the array 
then this will be taken as key and value i.e. 
("something") -> ("something:something")

SPECIAL-VARIABLES:
1. `os_user`: if this is set this users home-directory will be used as the `SYNC_DIR`.


## govm.cfg
In the following you will be introduced to all the config options with a detailed explanation what the option will affect.

`VMSTORE: $HOME/.govm -opt` <br/>
Location where the metadata 
of every created virtual-machine 
is getting saved. 
NOTE: if you are using wsl
you have to use a path
pointing to a location in the
windows system i.e. `/mnt/c/<user>/some/dir` <br/>

`APPLIANCSTORE: $HOME/.govm_appliance -opt` <br/>
Location where the .ova files will be created
and saved. <br/> 

`BRIDGE_OPTIONS: nil -req` <br/>
Possible networks virtual-box can use to bridge
to. It is an array seperated by whitespace
e.g. ("first network" "second network") <br/>

`LOG: govm.VMSTORE/$GOVM-ID/logs -opt` <br/>
Location wehere the logging is made. 

`VAGRANTFILE: .govm/vagrantfile/linux -opt` <br/>
Location to the vagrantfile 
that you would like to use. govm 
has some required arguments that will
still be required even if an other 
`VAGRANTFILE` is used. To solve the problem
deliver the options needed (only `HOST_ONLY_IP`). You dont have to 
use them in your vagrantfile but the validation is then satisfied. <br/>

`CONFIG_DIR: vagrant-wrapper/config -opt` <br/>
Directory where you would
like to store your groups and vm.cfg. 
The structure of the directories has a [meaning](#project-structure). <br/>

`PROVISION_DIR: vagrant-wrapper/provision -opt` <br/>
Directory with all your
provisions-scripts. <br/>

In `govm.cfg` are also some globally defined default values for the 
virtual-machine `cfg` files which are required to be present. 
These are `CPU` `RAM` `OS_IMAGE` `SCRIPT`. There are already some defaults 
set for you in the present [govm.cfg](.govm/govm.cfg) but feel free to change them. 

# Creation process
There are two types of creation-processes [single-creation](#single-creation) and [group-creation](#group-creation). Even though a group-creation can be started with one `vm.cfg` it is highly recommended to use the single-creation for two reasons:
1. security 
2. faster creation time

`govm` is running some other validations if [single-creation](#single-creation) is used instead of [group-creation](#group-creation)

## single-creation
Single-creation is the process of creating one virtual-machine with an optional provided
vm.cfg file representing the virtual-machine and the configurations for the virtual-machine.

To start a single-creation you have two options:
1. You can run `govm -v up`. This will create a virtual machine based on the [default.cfg](.govm/default.cfg).
2. You can run `govm -v up -f your/vm/config/path`. This will create a virtual-machine based on the `.cfg` that you provided.

After the virtual machine is created your are able to interact with it by using the `$GOVM-ID` of the virtual-machine created by `govm`.
The syntax for any interaction with the virtual machine is `govm -v [options] -m [$GOVM-ID]`.

## group-creation
Group-creation is the process of creating multiple virtual-machines based on a directory
which contains multiple vm.cfg files, each representing a virtual-machine.

To start a group-creation you have to run `govm -v gup -g path/to/dir`

After the group is created you can interact with the each virtual-machine as it would be a [`single-creation`](#single-creation).
For some **syntax-sugar** there are some *group-commands* as described in [usage](#usage) like `gdestroy` or `ghalt` 
which will run the given command on the whole group so you dont have to run a single command by hand on every virtual-machine in the same group.

## Exporting
Exporting is the possibility to export a group or a single 
virtual-machine as an `.ova` file which then can be used in every
Type-2 virtualization to import the create Environment.

This feature is a great way to create an `Environment`, have it saved as an `.ova` file and thne used it with any Type-2-Provider. 
This is giving you the possibility to keep your `GUI` clean from **dead virtual-machines**. 

### How is the .ova filename generated?

For a single-export `govm -v export -f some/cfg/file` its straightforward: The name of the virtual-machine will be used.
For a group-export `govm -v gexport -g some/dir` the directory name is used for the name of the `.ova` file.

After the first part of the name is calculated a versioning will be calculated. The versioning is based on [semver](https://semver.org/) standard with a small simplification. So the end result will be: `$VM_NAME-v1.0.ova` or `Group-Dir-Name-v1.0.ova`.

### main.ova
`main.ova` is a special kind of `.ova` file. This file is the main ova file which will be used by [import.exe](.govm/pkg/exe/import.exe). `import.exe` will automatically import `main.ova` into `VirtualBox`. This is especially useful if you have multiple computers that all can import with one click the `main.ova` and are ready to go with the prepared virtual-machine `Environemt`.

## Custome Vagrantfile
With `govm` you can also provide your own custome `Vagrantfile` that should be used instead of the [default](.govm/vagrantfile/) vagrantfiles. If you would like to use a custome Vagrantfile there are some rules that you have to follow for a proper integration of your custome `Vagrantfile`.

## Testing
The first valid command that you will run will trigger an `integrationtest` which is assuring that every functionality is working properly. If the testing was successfull an empty file named `tested` will be created, which is informing `govm` that the `integrationtest` was already ran successfully. Don't worry you will see some error messages that are intentionally or known issues that will not influence any functionalities.

# WSL
As always there are some specialities needed for `windows (wsl)`. We tried to cover as much as possible but still there are some limitation
compared to a native linux machine.

## Disk-Size
Becuase the disk-size config in vagrant is currently [experimental](https://www.vagrantup.com/docs/disks/usage) there are still some issues using it with WSL. There is a way around using `Git-Bash` but it is not recommended to use it, if you wish to work with wsl afterwards to manage those virtual-machines.

# Best-practices
Here are some best practices that you may follow. It is just a recommendation because the software was mostly tested with these practices and will promise
a flawless experience.

## Project structure
The project structure can be what ever you want. But it is recommened to use the structure which will be present after you clone the repository.

`.govm` <br/>
This directory contains directories and files that are used by the software to function properly. The only files that should be changed by you are
`govm.cfg` and `default.cfg`.

`config` <br/>
In this directory you can define your virtual-machine `cfg` files. If you want to create a `group` of virtual-machines
create a directory with the name of the group and insert all `cfg` files into that new directory e.g.
```
📦config
 ┣ 📂ansible
 ┃ ┣ 📜controll.cfg
 ┃ ┗ 📜master.cfg
 ┣ 📂redis
 ┃ ┣ 📜master.cfg
 ┃ ┗ 📜replica.cfg
 ┣ 📜test.cfg
 ┗ 📜windows.cfg
```
the directory name will be used as the [filename](#how-is-the-ova-filename-generated) of the `.ova` file. <br/>

`provision` <br/>
Every provision script or other types of provision should be located here. The structure of the directory is up to you. If you are using an other provision directory other than the default one be sure to set it as `PROVISION_DIR` in `govm.cfg`. All `SCRIPT` values in any `vm.cfg` file should be releative to `PROVISION_DIR`

## Naming
Because the names of your directories in the config direcroty and virtual-machine names [matter](#how-is-the-ova-filename-generated) it is a good idea to choose the names that they represent the purpose of the virtual-machine or the group like you can see in the example tree-structure above.

# Errors
Errors are something nobody likes! Thats a fact! But they will always be a part of software. The following sections are describing how to [interpretated](#interpretation) some custome defined errors and some known [issues](#known-issues-and-possible-fixes) and possible fixes.

## Interpretation 
If you see anytime an error message with `nil` then this means
that some option was not set which is required if you are using
one other option for example: if you would like to have
an additional disk with the option `DISK_SIZE_SECOND` but your are not
setting the `FILE_SYSTEM` for it, then you will see that type of error message.

## Init
Running the init script will install all requirements and setup the environment for `govm` to work properly. After a reboot of your local machine you can use govm. In some cases it may occur an error that vagrant is not able to start the virtual-machine. There are two solutions for this error:
1. Use govm after a reboot of the local machine once the init script is finished.
2. Deactive and activate the `VirtualBox Host-Only Ethernet Adapter` and reboot your local machine afterwards.
3. Delete all `VirtualBox Host-Only Ethernet Adapter` and create one without a `dhcp-server` and with the `IPv4 192.168.56.1/24`.



## Known issues and possible fixes

- https://github.com/hashicorp/vagrant/issues/6736  
  - `FIX: chcp.com 1252` 
- https://github.com/moby/moby/issues/24029  
  - `FIX: start every mounting path with a double slash in the config file`
- https://stackoverflow.com/questions/14219092/bash-script-and-bin-bashm-bad-interpreter-no-such-file-or-directory
- https://stackoverflow.com/questions/11616835/r-command-not-found-bashrc-bash-profile
