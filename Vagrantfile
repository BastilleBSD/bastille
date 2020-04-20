# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.define "bastille" do |vm_config|

    vm_config.ssh.shell = "sh"

    vm_config.vm.box = "freebsd/FreeBSD-12.1-RELEASE"
    vm_config.vm.box_version = "2019.11.01"

    vm_config.vm.provider "virtualbox" do |vb|
      vb.name = "bastille"
      vb.cpus = "1"
      vb.memory = "1024"
    end

    vm_config.vm.provision "shell", inline: "cd /vagrant; make install"

  end
end
