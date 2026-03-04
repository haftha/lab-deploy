# Installation Guide

## Prerequisites

Install the following tools on your **host system**:

- [VirtualBox](https://www.virtualbox.org/) 7.0+
- [Vagrant](https://www.vagrantup.com/) 2.3+
- [Ansible](https://docs.ansible.com/) 2.10+
- `wget` and `p7zip-full` (for the Debian Live preparation script)

```bash
sudo apt install virtualbox vagrant ansible wget p7zip-full
```

## Step-by-Step Setup

### 1. Clone the repository

```bash
git clone https://github.com/haftha/lab-deploy.git
cd lab-deploy
```

### 2. Prepare Debian Live boot files

Run once before starting the VM:

```bash
./prepare-debian-live.sh
```

The script downloads Debian Live 13 (Trixie) — about 1 GB — and extracts the
kernel (`vmlinuz`) and initrd (`initrd.img`) into `./debian-live-files/`.
The ISO is cached in `~/.cache/lab-deploy/` so subsequent runs are instant.

### 3. Start the deploy server

```bash
vagrant up lab-deploy-server
```

During the first boot you will be prompted to select the bridged network
interface — choose the NIC connected to your lab network.

Vagrant will:
1. Create a Debian 12 (Bookworm) VM
2. Set a static IP (`192.168.1.10`) on the bridged interface
3. Run the Ansible playbook to install and configure all services

### 4. Verify the server

```bash
vagrant ssh lab-deploy-server
systemctl status dnsmasq
ls /srv/tftp/
```

You should see `pxelinux.0`, `grubnetx64.efi`, and the `debian-live/`
directory in `/srv/tftp/`.

## Upgrading

To rebuild the deploy server from scratch:

```bash
vagrant destroy -f lab-deploy-server
./prepare-debian-live.sh   # re-run only if Debian Live version changed
vagrant up lab-deploy-server
```

## Network Requirements

- The bridged NIC on the host must be in the **same broadcast domain** as the
  lab clients (same switch, no VLAN isolation).
- Clients must have PXE boot enabled in their BIOS/UEFI firmware.
- A managed switch with **IGMP snooping** is recommended for multicast
  efficiency (prevents flooding).
