# govm
vagrant-wrapper or govm (which is called govm because it will be implemented in go in the future with a proper API) is 
currently a shell-wrapper for vagrant and virtualbox to create automatically:
- one highly configurable virtual machine
- run any action you know from vagrant on these machines
- create a group of virtual machines with multiple config-files each representing a virtual machine
- manage the group with the known commands (destroy/start/halt)
- export a group or one virtual machine as an .ova file

# Requirements
The only requirements are [HashiCorp Vagrant](https://www.vagrantup.com/) and [Oracle VirtualBox](https://www.virtualbox.org/).
Because we don't want to waste your time there are some pre-written **init-scripts** for [wsl](init/wsl.sh) and [ubuntu](init/linux.sh) which will
install all requirement and make some adjustement needed for `govm` to work properply. If you decide to run one of the init scripts be sure to reboot your local machine and then start using govm. DO NOT USE govm directly after using the init script! There may occur an error which is discussed in [this](#init) section (even though you did not use govm directly afterwards).

## init: wsl
The init script wsl.sh will install `Chocolatey`, `Oracle VirtualBox`, `HashiCorp Vagrant`. 
It will also try to create a `Host-Only Ethernt Adapter` with the `IPv4: 192.168.56.1/24` but it may fail because actually a reboot is needed before using VirtualBox. Because of this it may occur an error which can be [solved](#init). This is only the windows part. For HashiCorp Vagrant to run properly using wsl there are some `env-variables`
needed. 
1. `export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"`
2. `export PATH="$PATH:/mnt/c/Program Files/Oracle/VirtualBox"` 

These env-Variables will be appended to your `~/.bashrc` so they will be permanently set.
Because govm is using some `sudo` commands for removing and creating folders you may be
asked to enter a password. This is obviulsy killing the User-Experience so the init script 
will also create a file at `/etc/sudoers.d/<username>` and will allow the current user to run any
sudo commands without entering the password `<username> ALL = PASSWD:ALL`.

## init: ubuntu
This init script will do the same as [wsl.sh](#wslsh) but for linux-sytems. 
This script is created for ubuntu and may be used for other linux-distrubutions 
that use the `apt` package manager.

# Documentation
The following sections will explain in detail how to use `govm`. Before you start reading the documentation some general rules should be known to you:
1. `vm.cfg` is always representing a virtual-machine config file. For the purpose of the documentation it is named uniformerly. But your config files can be named in any way you like.
2. `-someflag [options]` is always referring to the options that are declared in the [Usage](#usage) section.
3. `$VARIABLE` is meaning that this variables can be set by you or is an intern variable that is getting used (apart from the obvious $HOME, $PATH etc...)
4. `govm.XXX` means that the value of the `govm.cfg` is used.
5. `GOVM-ID` is referring to the `hex-id` that is generated by `govm` for the virtual-machine for future unique references.
6. `<config-option>: <default-value> -[opt|req]`. Using this syntax you can see in a one liner which defaults the config-options in the `.cfg` have and if they are **required(req)** or **optional(opt)**

## Usage
`-v [up|halt|start|ssh|destroy]` is setting the vagrant command you want to run. You can also prefix any command with `g[up|halt|start|ssh|destroy]` e.g `gdestroy` to run a command like `destroy` on the whole group. <br/>
`-f [path]` is specifing the path to a `vm.cfg` file with the *possible arguments*. <br/>
`-g [path]` is setting the path to a directory with one or more `vm.cfg` files each representing a virtual machine creating multiple virtual machines at once <br/>
`-m [GOVM-ID]` is setting the virtual machine which should be manipulated by the `-v` command. <br/>
`-i` if this is present the group or virtual machine  that is getting `exported` as an `.ova` is set as the `main.ova`. <br/>
`-r` if this is present it will force a `recreation` of the vm if there is a virtual machine registered but not reachable. You may also use it to `reload` a virtual machine or group. 
`-l` this flag can be used without `-v`. It will list all virtual-machine created by `govm` <br/>

Every command should but does not have to start with: `govm -v [options]`. Afterwards you can specifiy any other flag.
This way every command is properly structured and human readable.

If you run the command `govm -v [options]` without specifiying `-f`, `-g` or `-m` govm will run the defined command on the **default** virtual-machine.

# Config
> Config (cfg) files are the way that govm can be manipulated and controlled 
> to serve your purpose.

There are two types of `.cfg files`.
1. `vm.cfg` which is representing a virtual machine and the [configuration](#vmcfg) it should have.
2. `govm.cfg` . This [file](#govmcfg) is controlling the software as a whole e.g. metadata and storing information.

## vm.cfg 
> vm.cfg are representing the configuration of the given virtual-machine.

There are lots of options that can be defined to create a virtual-machine based on your needs. In this section you will learn about all possible options. <br/>

`CPU: govm.CPU -opt` <br/>
Quantity of proceccors 
for the virtual-machine. 
`min: 1`, `max: 100`

`RAM: govm.RAM -opt` <br/>
Amount of memory for the virtual-machine. 
`min: 512 MB` `max: 16000 MB`.

`OS_IMAGE: govm.OS_IMAGE -opt` <br/>
base box that vagrant should use 
for setting the operating system.
If you use windows be sure that
the `OS_TYPE` is also set to windows.
All possible base-boxes can be found [here](https://app.vagrantup.com/boxes/search?provider=virtualbox)

`OS_TYPE: linux -opt` <br/>
OS_TYPE is informing the application
which type of operating-system you are
using. This is needed because as always windows
needs some special configurations in the vagrantfile.
Valid values are "linux" and "windows"

`SCRIPT: govm.SCRIPT -opt` <br/>
Defining the provision script that shall run 
in the virtual-machine. If you wish to
have the minimum of provision
its recommended to take provision/default.sh
which is only doing an update and upgrade in ubuntu.
Every path has to be set relative to the `PROVISION_DIR`.

`HOST_ONLY_IP: 192.168.56.2 -req` <br/>
Defining the ip of the host-only-virtual-adapter 
of the virtual-machine.
NOTE: 192.168.56.2 is reserved for 
the default virtual-machine. 
Its recommended to never use it.

`VM_NAME: $HOST_ONLY_IP+ID -opt` <br/>
The name of the virtual-machine.
Take a describtive name that is representing 
the purpose of the virtual-machine

`SYNC_FOLDER: $VMSTORE/ID/sync_folder -opt` <br/> 
The directory that shall be mounted 
from host to guest. The default 
is a created directory called
`sync_folder` in the home directory
of the guest-machine mounted to
`VMSTORE/GOVM-ID/sync_folder`.
If you wish the default behavior
comment out the option.

`DISK_SIZE_PRIMARY: 40GB -opt` <br/>
here you can set the main 
disk size in the virtual-machine  
its recommended to have a 
disk size of 32GB or more 
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
Where shall the second disk be mounted?
Note the path has to be always an absolut
path. It is not allowed to mount to:
- `/root`
- `/`
- `/boot`
- `/var`

IMPORTANT: always start your path
with a double // if using git-bash. This prevents that the
path is getting converted by `mingw`. This variable is required if `DISK_SIZE-SECOND` is set, otherwise it is getting ignored <br/>

`FILE_SYSTEM: nil` <br/>
FILE_SYSTEM is setting the
mkfs that is getting used 
on the second disk. Valid values are:
- `ext3`
- `ext4`
- `xfs` <br/>

This variable is required if `DISK_SIZE-SECOND` is set otherwise it is getting ignored.
 
`PROVISION_VAR: () -opt` <br/>
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


## govm.cfg
> govm.cfg is setting metadata information
> that are needed for the software to function.

`VMSTORE: $HOME/.govm -opt` <br/>
The location where the metadata 
of every created virtual-machine is getting 
saved. 
NOTE: if you are using wsl
you have to use a path
pointing to a location in the
windows system i.e. `/mnt/c/<user>/some/dir` <br/>

`APPLIANCSTORE: $HOME/.govm_appliance -opt` <br/>
The path where the .ova files will be created
and saved. <br/> 

`BRIDGE_OPTIONS: nil -req` <br/>
Defining the possible networks virtual-box can use to bridge
to it is an array seperated by whitespace
e.g. (<first-network> <second-network>) <br/>

`LOG: govm.VMSTORE/$GOVM-ID/logs -opt` <br/>
The path wehere the debugging 
logging is made the default behavior 
is the logging to the newly created
virtual-machine directore in VMSTORE.
If you wished that kind of behavior 
comment LOG. Otherwise set a
`log-path` you would like to have.

`VAGRANTFILE: .govm/vagrantfile/linux -opt` <br/>
Rhe path to the vagrantfile 
that you would like to use. govm 
has some required arguments that will
still be required even if an other 
`VAGRANTFILE` is used. To solve the problem
deliver the options needed. You dont have to 
use them but the validation is then satisfied. <br/>

`CONFIG_DIR: vagrant-wrapper/config -opt` <br/>
The directory where you would
like to store your vm-configs. 
The default is recommended. Also the
structure of the directories has a [meaning](#project-structure). <br/>

`PROVISION_DIR: vagrant-wrapper/provision -opt` <br/>
The directory with all your
provisions-scripts. The default
is recommended. <br/>

In `govm.cfg` are also some globally defined default values for the 
virtual-machine `cfg` files which are required to be present. These are `CPU` `RAM` `OS_IMAGE` `SCRIPT`.
There are already some defaults set for you in the present [govm.cfg](.govm/govm.cfg)
but feel free to change them. 

# Creation process
There are two types of creation-processes [single-creation](#single-creation) and [group-creation](#group-creation). Even though a group-creation can be started with one `vm.cfg` it is highly recommended to use the single-creation for two reasons:
1. security 
2. faster creation time

`govm` is running some other validations if [`single-creation`](#single-creation) is used instead of [`group-creation`](#group-creation)

## single-creation
> Single-creation is the process of creating one virtual-machine with an optional provided
> .cfg file representing the virtual-machine.

To start a single-creation you have two options:
1. You can run `govm -v up`. This will create a virtual machine based on the [default.cfg](.govm/default.cfg).
2. You can run `govm -v up -f your/vm/config/path`. This will create a virtual-machine based on the `.cfg` that you provided.

After the virtual machine is created your are able to interact with it by using the `GOVM-ID` of the virtual-machine created by `govm`.
You can get any `metadata-information` of the created virtual-machines by running `govm -l`. After you got the `GOVM-ID` you can run any command
that you is specified with `-v [options]` and [more!](#Exporting) <br/>

The syntax for any interaction with the virtual machine is `govm -v [options] -m [GOVM-ID]`.

## group-creation
> Group-creation is the process of creating multiple virtual-machines based on a directory
> which contains multiple vm.cfg files, each representin a virtual-machine with his own
> configuration.

To start a group-creation you have to run `govm -v gup -g path/to/dir/with/cfg/files`

After the group is created you can interact with the each virtual-machine as it would be a [`single-creation`](#single-creation).
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

## Testing
The first valid command that you will run will trigger an `integrationtest` which is assuring that every functionality is working properly. If the testing was successfull an empty file named `tested` will be created, which is telling govm that the integrationtest was already ran successfully.

# WSL
As always there are some specialities needed for windows (wsl). We tried to cover as much as possible but still there are some limitation
compared to a native linux machine.

## Disk-Size
Becuase the disk-size config in vagrant is currently [experimental](https://www.vagrantup.com/docs/disks/usage) there are still some issues using it with WSL. There is a way around using Git-Bash but it is not recommended to use it if you wish to work with wsl afterwards with `govm` to manage those virtual-machines.

# Best-practices
Here are some best practices that you may follow. It is just a recommendation because the software was mostly tested this way and will promise
a flawless experience.

## Project structure
The project structure can be what ever you want. But it is recommened to use the structure which will be present after you clone the repository.

`.govm` <br/>
This directory contains directories and files that are used by the software to function properly. The only files that can be changed by you are
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

https://github.com/hashicorp/vagrant/issues/6736  
FIX: chcp.com 1252  
https://github.com/moby/moby/issues/24029  
FIX: start every mounting path with a double slash in the config file
https://stackoverflow.com/questions/14219092/bash-script-and-bin-bashm-bad-interpreter-no-such-file-or-directory
https://stackoverflow.com/questions/11616835/r-command-not-found-bashrc-bash-profile
