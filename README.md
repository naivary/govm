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
`-v [up|halt|start|ssh|destroy]` is setting the vagrant command you want to run (has to be present with every command.) You can also prefix any command with `g[up|halt|start|ssh|destroy]` e.g `gdestroy` to destroy a whole `group`. <br/>

`-f [path]` is specifing the path to a `*.config` file with the *possible arguments*. <br/>
`-g [path]` is setting the path to a directory with one or more `*.cfg` files each representing a `virtual machine` creating multiple virtual machines at once <br/>
`-m [ID]` is setting the `virtual machine` which should be manipulated by the `-v` command. <br/>
`-i` if this is present the group or virtual machine  that is getting `exported` as an `.ova` is set as the `main.ova`. <br/>
`-r` if this is present it will force a `recreation` of the vm if there is a virtual machine registered but not reachable. You may also use it to `reload` a virtual machine or group. <br/>

# Config
Config files are the way that govm can be manipulated and controlled to serve your purpose. There are two types of `.cfg-files`
1. `vm.cfg` which is representing a virtual machine and the [options](#default.cfg) create.
2. [govm.cfg](#govmcfg). This file is controlling the software as a whole for example setting default values or where the virtual machine `metadata` should be saved.

## default.cfg

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

The syntax for any interaction with the virtual machine is <br/>
`govm -v [options] -m [ID]`


## Group-creation

## Exporting


## Error-Interpretation ##
If you see anytime an error message with "nil" then this means
that some option was not set which is required if you are using
one other option for example: if you would like to have
an additional disk with the option DISK_SIZE_SECOND but your are not
setting the FILE_SYSTEM for it, then you will see that type of error message.


## Known Issues ## 

https://github.com/hashicorp/vagrant/issues/6736  
FIX: chcp.com 1252  
https://github.com/moby/moby/issues/24029  
FIX: start every mounting path with a double slash in the config file
https://stackoverflow.com/questions/14219092/bash-script-and-bin-bashm-bad-interpreter-no-such-file-or-directory
https://stackoverflow.com/questions/11616835/r-command-not-found-bashrc-bash-profile

## Error Codes ##

1: General error
2: Machine not found in system (grep in used_ip.txt)