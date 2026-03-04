# Usage Guide

## Three-Step Deployment Workflow

### Step 1 — Capture a reference image from the golden client

1. Configure the golden client to PXE boot (Legacy BIOS or UEFI).
2. It will boot into Debian Live.
3. On the deploy server, capture the disk image:

```bash
vagrant ssh lab-deploy-server
sudo /usr/local/bin/save_image.sh <image-name>
```

The image is stored under `/srv/images/<image-name>/`.

### Step 2 — Wake up lab client machines

```bash
sudo /usr/local/bin/wake_up_machines.sh
```

Clients will boot via PXE and reach the boot menu.

### Step 3 — Deploy the image

Wait until all clients are in the PXE boot menu and have selected (or
auto-selected) "Deploy Image". Then start the multicast sender:

```bash
sudo /usr/local/bin/multicast_deploy.sh <no_of_clients> <image-name>
```

Example — deploy to 20 clients:

```bash
sudo /usr/local/bin/multicast_deploy.sh 20 debian13-lab
```

## Managing Machine Definitions

### Automatic discovery

```bash
vagrant ssh lab-deploy-server
sudo /usr/local/bin/collect_mac.sh
```

The script ARP-scans `192.168.1.0/24` and writes discovered machines to
`/vagrant/config/machines.yml`.

### Manual editing

Edit `config/machines.yml` on the host:

```yaml
machines:
  - name: client01
    mac: "08:00:27:00:00:01"
    ip: "192.168.1.101"
```

After editing, re-provision dnsmasq:

```bash
vagrant provision lab-deploy-server --provision-with ansible --ansible-tags="basic"
```

## Customising Network Settings

Edit `ansible/server_playbook.yml`:

```yaml
vars:
  dhcp_range_start: "192.168.1.101"
  dhcp_range_end:   "192.168.1.120"
  server_ip:        "192.168.1.10"
  tftp_root:        /srv/tftp
  images_dir:       /srv/images
```

Then re-provision:

```bash
vagrant provision lab-deploy-server
```

## DHCP Transition to Router

When handing DHCP over to your campus router:

1. Disable DHCP in dnsmasq (`/etc/dnsmasq.d/lab-deploy.conf`) — remove or
   comment out the `dhcp-range` line and restart dnsmasq.
2. Configure the router's DHCP server:
   - **Option 66** (TFTP server): `192.168.1.10`
   - **Option 67** (bootfile):
     - Legacy: `pxelinux.0`
     - UEFI: `grubnetx64.efi`
3. Test by PXE-booting a client.
