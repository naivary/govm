# vagrant-wrapper
Vagrant-Wrapper is a shell script for creating dynamic VM automatically.

# Documentation

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
