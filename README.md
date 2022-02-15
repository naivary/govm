# vagrant-wrapper
Vagrant-Wrapper is a shell script for creating dynamic VM automatically.

# Documentation

## Usage ##
-c [integer] is setting the count of CPUs  
-m [integer] is setting the RAM  
-i [integer] is setting the OS-Image  
-s [path] is setting the path to the provision-shell-script  
-h [ipv4] is setting the ip-adress for host-only of the type 192.168.56.0/24  
-f [path] is specifing the path to a *.config file with the parameters CPU, RAM, OS_IMAGE, IP and SCRIPT  
-v [up/halt/start/ssh/destroy] is setting the vagrant command you want to run (has to be present with every command.)  
-d if this is present it will force a recreation of the vm if there is a virtual machine registered but not reachable  
-g [path] is setting the path to a directory with one or more *.cfg files to create a group of virtual-machines at once  


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

## Known Issues ## 

https://github.com/hashicorp/vagrant/issues/6736  
FIX: chcp.com 1252  
https://github.com/moby/moby/issues/24029  
FIX: start every mounting path with a double slash in the config file
