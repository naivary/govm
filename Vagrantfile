# -*- mode: ruby -*-
# vi: set ft=ruby :


Vagrant.configure("2") do |config|
  config.vm.box = ENV["OS_IMAGE"] 
  config.vm.provision "shell", path: ENV["SCRIPT"], env: {"OS_USERNAME" => "musti", "OS_PASSWORD" => ENV["OS_PASSWORD"], "GIT_USERNAME" => ENV["GIT_USERNAME"], "GIT_PASSWORD" => ENV["GIT_PASSWORD"]}
  config.vm.synced_folder ENV["SYNC_FOLDER"], "/home/gov/sync_folder", disabled:false
  config.vm.synced_folder ".", "/vagrant", disabled:true
  config.vm.network "private_network", ip: ENV["HOST_ONLY_IP"]
  config.vm.network "public_network", bridge: "Realtek PCIe GbE Family Controller"
  config.vm.provider "virtualbox" do |vb|
    vb.name = ENV["VM_NAME"]
    vb.memory = ENV["RAM"]
    vb.cpus = ENV["CPU"]
  end
end
