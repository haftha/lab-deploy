# lab-deploy

A Vagrant and Ansible-based PXE deployment solution for mass-deploying operating system images to lab computers using multicast technology.

## Overview

lab-deploy provides an automated, infrastructure-as-code approach to setting up a complete lab deployment environment using:
- **Vagrant** for VM orchestration
- **Ansible** for configuration management
- **PXE boot** for network-based client deployment (Legacy BIOS **and** UEFI/EFI)
- **Multicast** for efficient simultaneous deployments

## Features

- **Automated Setup**: Vagrant + Ansible automates the entire server setup
- **PXE Boot Support**: Boot clients over the network using PXELINUX/SYSLINUX (Legacy) and GRUB2 EFI (UEFI)
- **Multicast Deployment**: Deploy images to multiple computers simultaneously using udpcast
- **Debian Live Environment**: Network-bootable Debian Live for imaging operations
- **Infrastructure as Code**: Reproducible, version-controlled configuration
- **Wake-on-LAN**: Remote power-on capabilities for lab machines
- **Flexible Image Management**: Support for partclone-based disk imaging
- **MAC Collection**: Automated discovery and registration of client MAC addresses

## Architecture

The solution consists of:

1. **Deploy Server (Vagrant VM)**:
   - dnsmasq (DHCP + TFTP server)
   - PXE boot infrastructure for Legacy BIOS (PXELINUX/SYSLINUX) and UEFI (GRUB2 via `grubnetx64.efi`)
   - Debian Live kernel/initrd for network boot
   - Image storage and multicast server (udpcast)
   - Wake-on-LAN tools

2. **Golden Client (Physical Machine)**:
   - Reference system for creating master images
   - Boots via PXE into Debian Live to capture disk image
   - Image is saved to the deploy server via `save_image.sh <image-name>`

3. **Lab Clients (Physical/Virtual Machines, up to 20)**:
   - Boot via PXE from network (Legacy BIOS or UEFI)
   - Receive images via multicast (udpcast)
   - Can be powered on remotely via Wake-on-LAN

## Requirements

### Host System
- **VirtualBox** 7.0+
- **Vagrant** 2.3+
- **Ansible** 2.10+ (installed on host)
- At least 4 GB RAM available for the deploy server VM
- 50 GB+ free disk space for images

### Network Requirements
- Bridged network adapter for PXE/DHCP (deploy server must be in the same broadcast domain as clients)
- Clients must support PXE boot (Legacy BIOS or UEFI network boot)
- Network switch with IGMP snooping support (strongly recommended for multicast efficiency)
- **Note on DHCP transition**: When switching from the deploy server's built-in DHCP to a router-based DHCP later, ensure the router forwards DHCP options 66 (TFTP server) and 67 (bootfile name) to maintain PXE boot functionality. This is also called a **DHCP proxy** or **PXE proxy** configuration.

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/haftha/lab-deploy.git
cd lab-deploy
```

### 2. Prepare Debian Live Files

Before starting the VMs, run the preparation script once:

```bash
./prepare-debian-live.sh
```

The script implements a **download-once, reuse-many** strategy:

- The ISO is downloaded **once** and cached in `~/.cache/lab-deploy/`.  
  Subsequent runs (e.g. after `vagrant destroy && vagrant up`) reuse the cached file — no repeated download.
- The SHA256 checksum is verified automatically against the official Debian mirror.
- Boot files (`vmlinuz`, `initrd.img`) are extracted into `./debian-live-files/`  
  without requiring root privileges (`7z` reads the ISO directly — no `mount` needed).
- If the boot files already exist, extraction is skipped as well.

| Run condition | Download | Extract |
|---|---|---|
| First run | ✅ Yes | ✅ Yes |
| ISO cached, files extracted | ⏭ Skip | ⏭ Skip |
| ISO cached, files missing | ⏭ Skip | ✅ Yes |
| ISO corrupt / missing | ✅ Re-download | ✅ Yes |

**To force a re-download or re-extraction:**

```bash
# Force re-extraction only (ISO stays cached):
rm -rf ./debian-live-files/
./prepare-debian-live.sh

# Force full re-download and re-extraction:
rm -rf ~/.cache/lab-deploy/ ./debian-live-files/
./prepare-debian-live.sh
```

> #### Debian 13 (Trixie)
> The ISO is fetched from the official Debian release mirror:
> `https://cdimage.debian.org/cdimage/release/current-live/amd64/iso-hybrid/`  
> Version: **debian-live-13.3.0-amd64-standard.iso**  
> To update to a newer point release, change the version in `prepare-debian-live.sh`.

> #### Prerequisites
> The following tools must be installed on the **host system**:
> ```bash
> sudo apt install wget p7zip-full
> ```


### 3. Start the Deploy Server

```bash
vagrant up lab-deploy-server
```

This will:
- Create a Debian 12 (Bookworm) VM as the deploy server
- Install all required packages (`dnsmasq`, `partclone`, `udpcast`, `syslinux`, `grub-efi-amd64-bin`, `etherwake`, etc.)
- Configure PXE boot infrastructure for both Legacy BIOS and UEFI clients
- Set up DHCP/TFTP services via dnsmasq
- Copy deployment scripts to `/usr/local/bin/`

### 4. Configure Your Network

During `vagrant up`, you will be prompted to select a bridged network interface. Choose the interface connected to your lab network.

### 5. Collect Client MAC Addresses

SSH into the deploy server and run the MAC collection script:

```bash
vagrant ssh lab-deploy-server
sudo /usr/local/bin/collect_mac.sh
```

The script performs an ARP scan of the configured subnet and writes discovered machines into `config/machines.yml`. Review and edit the file as needed (see [Machine Definitions](#machine-definitions)).

### 6. Boot Client Computers

1. Configure client computers to boot via PXE (usually F12 during POST for Legacy, or boot menu for UEFI)
2. Clients will receive an IP address via DHCP from the deploy server
3. The PXE boot menu will appear
4. Select the appropriate boot option (Legacy or EFI)

## Directory Structure

```
lab-deploy/
├── Vagrantfile                  # VM definitions and configuration
├── prepare-debian-live.sh       # Script to download/extract Debian Live
├── ansible/
│   ├── inventory.ini            # Ansible inventory (optional, Vagrant generates)
│   ├── server_playbook.yml      # Deploy server configuration playbook
│   ├── client_playbook.yml      # Golden client configuration playbook
│   └── templates/               # Configuration templates
│       ├── dnsmasq.conf.j2
│       ├── pxelinux.cfg.j2      # Legacy BIOS PXE menu
│       └── grub.cfg.j2          # UEFI GRUB2 PXE menu
├── scripts/                     # Deployment scripts (deployed to /usr/local/bin/)
│   ├── save_image.sh            # Create disk image: save_image.sh <image-name>
│   ├── multicast_deploy.sh      # Deploy via multicast: multicast_deploy.sh <no_of_clients> <image-name>
│   ├── wake_up_machines.sh      # Wake-on-LAN utility
│   ├── collect_mac.sh           # Discover and register client MAC addresses
│   └── lib/                     # Script libraries
│       ├── partclone_functions.sh
│       ├── ntfsclone_functions.sh
│       └── udpcast_functions.sh
├── config/
│   └── machines.yml             # Lab machines configuration (MACs, IPs, names)
├── debian-live-files/           # Pre-extracted Debian Live boot files
│   ├── vmlinuz                  # (created by prepare-debian-live.sh)
│   └── initrd.img               # (created by prepare-debian-live.sh)
└── docs/
    ├── INSTALL.md               # Installation guide
    ├── USAGE.md                 # Usage guide
    └── TROUBLESHOOTING.md       # Troubleshooting tips
```

## Configuration

### Network Settings

Edit `ansible/server_playbook.yml` to customize:

```yaml
vars:
  dhcp_range_start: "192.168.1.101"
  dhcp_range_end:   "192.168.1.120"
  server_ip:        "192.168.1.10"
  tftp_root:        /srv/tftp
  images_dir:       /srv/images
```

> All IP addresses in `config/machines.yml` must be within the same subnet (`192.168.1.0/24` in the example above).

### Machine Definitions

Collect client machine MAC addresses automatically:

```bash
vagrant ssh lab-deploy-server
sudo /usr/local/bin/collect_mac.sh
```

The script writes discovered entries to `config/machines.yml`. You can also edit the file manually:

```yaml
machines:
  - name: client01
    mac: "08:00:27:00:00:01"
    ip: "192.168.1.101"
  - name: client02
    mac: "08:00:27:00:00:02"
    ip: "192.168.1.102"
  # ...
  - name: client20
    mac: "08:00:27:00:00:20"
    ip: "192.168.1.120"
```

> **Note**: The Golden Client should **not** be listed in `machines.yml` to prevent it from being accidentally woken up or overwritten during a mass deployment.

## Usage

### Three-Step Deployment Workflow

The standard deployment process uses three scripts:

```bash
# Step 1 — Save a disk image from the golden client
save_image.sh <image-name>

# Step 2 — Wake up all lab client machines
wake_up_machines.sh

# Step 3 — Deploy image to all clients via multicast
multicast_deploy.sh <no_of_clients> <image-name>
```

### Creating System Images

1. Prepare the reference (golden) computer with the desired OS configuration (Debian 13, EFI-enabled)
2. Boot it via PXE into the Debian Live environment
3. SSH into the deploy server and capture the disk image:

```bash
# Replace 192.168.1.10 with your deploy server IP
ssh vagrant@192.168.1.10
sudo /usr/local/bin/save_image.sh <image-name>
```

The image will be stored under `/srv/images/<image-name>`.

### Deploying Images

The correct sequence is important: clients must be waiting in the PXE boot menu **before** the multicast sender is started, because udpcast waits for a defined number of receivers before beginning transmission.

1. **Wake up client machines** (they will PXE-boot and reach the boot menu):

```bash
ssh vagrant@192.168.1.10
sudo /usr/local/bin/wake_up_machines.sh
```

2. **Wait** until all clients have booted into the PXE menu and selected "Deploy Image" (or have been auto-selected via timeout).

3. **Start multicast deployment** — specify the expected number of clients and the image name:

```bash
sudo /usr/local/bin/multicast_deploy.sh <no_of_clients> <image-name>
```

> Example: `sudo /usr/local/bin/multicast_deploy.sh 20 debian13-lab`

4. Clients receive and write the image; they reboot automatically when done.

### DHCP Transition (Deploy Server → Router)

Initially, the deploy server acts as the DHCP server (via dnsmasq). To hand over DHCP to your router later:

1. Disable the DHCP function in dnsmasq on the deploy server (keep TFTP active)
2. Configure the router's DHCP server to include:
   - **Option 66** (TFTP Server Name): `192.168.1.10` (deploy server IP)
   - **Option 67** (Bootfile Name):
     - For Legacy BIOS: `pxelinux.0`
     - For UEFI: `grubnetx64.efi`
3. Test PXE boot from a client to confirm DHCP and TFTP still work correctly

## Common Commands

```bash
# Start the deploy server
vagrant up lab-deploy-server

# Re-provision (apply configuration changes)
vagrant provision lab-deploy-server

# SSH into the server
vagrant ssh lab-deploy-server

# Stop the server
vagrant halt lab-deploy-server

# Destroy and rebuild
vagrant destroy -f lab-deploy-server
vagrant up lab-deploy-server

# Skip Debian Live provisioning during development
vagrant provision lab-deploy-server --provision-with ansible --ansible-tags="basic,scripts"

# Skip netboot provisioning (faster iteration)
vagrant provision lab-deploy-server --provision-with ansible --ansible-tags="basic"

# View server status
vagrant status
```

## Troubleshooting

### "Debian Live files not found" error

Run the preparation script before starting the VM:

```bash
./prepare-debian-live.sh
```

If the error persists, force a full re-extraction:

```bash
rm -rf ./debian-live-files/
./prepare-debian-live.sh
```

If the download fails or the checksum is rejected, clear the ISO cache and retry:

```bash
rm -rf ~/.cache/lab-deploy/
./prepare-debian-live.sh
```

### UEFI clients do not PXE boot

Ensure that `grubnetx64.efi` is present in `tftp_root` and that dnsmasq (or the router DHCP) is serving the correct bootfile name for EFI clients. Check the Ansible template `grub.cfg.j2` for correct configuration.

### Clients boot but do not receive an image

Verify that `multicast_deploy.sh` was started **after** clients are already waiting in the PXE boot menu. The udpcast sender waits for `<no_of_clients>` receivers before starting. If fewer clients connect, the transfer will not begin.

### Slow provisioning

Skip the netboot tag during development:

```bash
vagrant provision lab-deploy-server --provision-with ansible --ansible-tags="basic"
```

### SSH connection refused

Ensure the VM is fully booted:

```bash
vagrant ssh lab-deploy-server -c "echo 'SSH ready'"
```

### PXE stops working after DHCP handover to router

Ensure the router's DHCP server is configured with DHCP options 66 and 67 pointing to the deploy server. See [DHCP Transition](#dhcp-transition-deploy-server--router).

## Documentation

- [Installation Guide](docs/INSTALL.md) — Detailed setup instructions
- [Usage Guide](docs/USAGE.md) — Comprehensive usage documentation
- [Troubleshooting](docs/TROUBLESHOOTING.md) — Common issues and solutions

## Support

For issues and questions:
- Open an issue on GitHub
- Check the [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
- Review the [Usage Documentation](docs/USAGE.md)
