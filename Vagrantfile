# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  # Base box — Debian 12 (stable); wechsle zu debian/trixie64 sobald Debian 13 stable
  config.vm.box               = "debian/bookworm64"
  config.vm.box_check_update  = false

  # ============================================================
  # Deploy Server — PXE/TFTP/DHCP Server for lab deployment
  # ============================================================
  config.vm.define "lab-deploy-server" do |server|

    server.vm.hostname = "lab-deploy-server"

    # Disable automatic VirtualBox Guest Additions update
    if Vagrant.has_plugin?("vagrant-vbguest")
      server.vbguest.auto_update = false
    end

    # NAT: SSH-Forwarding (Port 2210 auf Host → 22 in VM)
    server.vm.network "forwarded_port", guest: 22, host: 2210, id: "ssh"

    # Bridged: PXE/DHCP im Lab-Netz (Interface ggf. anpassen)
    server.vm.network "public_network",
      bridge: "enp7s0f0"

    # Statische IP auf dem Bridged Interface setzen (läuft bei jedem Boot)
    server.vm.provision "shell", run: "always", inline: <<-SHELL
      ip addr flush dev eth1 2>/dev/null || true
      ip addr add 192.168.1.10/24 dev eth1
      ip link set eth1 up
    SHELL

    # Debian Live boot files aus dem Host in die VM übertragen
    server.vm.synced_folder "./debian-live-files", "/tmp/debian-live-files",
      type: "virtualbox"

    # VirtualBox Provider
    server.vm.provider "virtualbox" do |vb|
      vb.name   = "lab-deploy-server"
      vb.memory = "2048"
      vb.cpus   = 2
    end

    # Ansible Provisioning
    server.vm.provision "ansible" do |ansible|
      ansible.playbook   = "ansible/server_playbook.yml"
      ansible.verbose    = "v"
      ansible.groups     = {
        "deploy_server" => ["lab-deploy-server"]
      }
      ansible.extra_vars = {
        server_ip:        "192.168.1.10",
        dhcp_range_start: "192.168.1.101",
        dhcp_range_end:   "192.168.1.120",
        tftp_root:        "/srv/tftp",
        images_dir:       "/srv/images"
      }
      # ansible.tags     = "basic,scripts"  # Einkommentieren zum Überspringen von netboot
    end

  end

end
