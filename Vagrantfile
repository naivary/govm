# -*- mode: ruby -*-
# vi: set ft=ruby :


Vagrant.configure("2") do |config|
  config.vm.box = ENV["OS_IMAGE"] 
  config.vm.provision "shell", path: ENV["SCRIPT"]
  config.vm.synced_folder ENV["SYNC_FOLDER"], "/vagrant", disabled:true
  config.vm.network "private_network", ip: ENV["HOST_ONLY_IP"]
  config.vm.network "public_network"
  config.vm.provider "virtualbox" do |vb|
    vb.memory = ENV["RAM"]
    vb.cpus = ENV["CPU"]
  end
end
