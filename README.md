# Purpose
vagrant-wrapper or govm (which is called govm because it will be implemented in go in the future with a proper API) is 
currently a shell-wrapper for vagrant to create automatically:
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
The only requirement that is needed is **HashiCorp Vagrant** and **Oracle VirtualBox**.
Because of these requirements there are also some *init scripts* for **windows (wsl)** and **ubuntu**;

**wsl.sh**
The init script wsl.sh will install *Chocolatey, Oracle VirtualBox, HashiCorp Vagrant*. 
It will also try to create a Host-Only adapter with the IPv4: 192.168.56.1/24. This is only
the windows part. For HashiCorp Vagrant to run properly using wsl there are some ENV-Variables
needed. 
1. `export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"`
2. `export PATH="$PATH:/mnt/c/Program Files/Oracle/VirtualBox"`
These ENV-Variables will be appended to your `~/.bashrc` so the will be permanently set.
Becuase govm.sh is using some `sudo` commands for removing and creating folders you may be
asked to enter a password. Because this is killing the User-Experience it will also
create an file `/etc/sudoers.d/<username>` and will allow the current user to run any
sudo commands without entering the password.
# Documentation

## Usage ##
-f [path] is specifing the path to a *.config file with the parameters CPU, RAM, OS_IMAGE, IP and SCRIPT  
-v [up/halt/start/ssh/destroy] is setting the vagrant command you want to run (has to be present with every command.)  
-d if this is present it will force a recreation of the vm if there is a virtual machine registered but not reachable  
-g [path] is setting the path to a directory with one or more *.cfg files to create a group of virtual-machines at once  
-i [integer] is setting the OS-Image  


The usage is pretty straight forward. You can create a virtual machine manually using the flags.
This practice is not recommended because it is not really effective but if your are just interest in
getting started fast with one Virtual-Machine it is more than enough.

The recommended way is to use Config files (*.cfg).

Using this method its pretty easy to create from one config file
one virtual machine and have it persist some where to reuse it again
and again.

If you would like to create multiple virtual-machines at once you can do that too. Just
create a sub-directory under config and create multiple config files each reperesenting 
a virtual machine. 

For every command you run you have to provide the -v flag, whtich stands for -vagrant
and is representing the vagrant command you would like to run e.g. up, halt, start, destroy.
Prefixing the commands with a "g" for example -v gup will start the creation process in group
creation meaning you can start, destroy, halt and create multiple machines at once.

## Rules ##
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