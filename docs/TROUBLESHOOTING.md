# Troubleshooting Guide

## "Debian Live files not found" during `vagrant up`

Run the preparation script before starting the VM:

```bash
./prepare-debian-live.sh
```

If the error persists, force a full re-extraction:

```bash
rm -rf ./debian-live-files/
./prepare-debian-live.sh
```

If the download fails or the checksum is rejected, clear the ISO cache:

```bash
rm -rf ~/.cache/lab-deploy/
./prepare-debian-live.sh
```

## UEFI clients do not PXE boot

1. Verify `grubnetx64.efi` exists in `/srv/tftp/` on the deploy server.
2. Confirm dnsmasq (or your router) sends the correct bootfile for EFI clients
   (DHCP option 93 = 7 → `grubnetx64.efi`).
3. Check `/var/log/syslog` on the deploy server for DHCP and TFTP errors.

## Clients boot but do not receive an image

- Ensure `multicast_deploy.sh` is started **after** all clients are already
  waiting in the PXE boot menu. udpcast waits for `<no_of_clients>` receivers
  before transmitting; if fewer connect, the transfer never starts.
- Check that the number passed to `multicast_deploy.sh` matches the actual
  number of waiting clients.

## Slow provisioning

Skip the netboot provisioning step during development:

```bash
vagrant provision lab-deploy-server --provision-with ansible --ansible-tags="basic"
```

## SSH connection refused

Ensure the VM is fully booted:

```bash
vagrant ssh lab-deploy-server -c "echo 'SSH ready'"
```

If this fails, restart the VM:

```bash
vagrant halt lab-deploy-server && vagrant up lab-deploy-server
```

## PXE stops working after DHCP handover to router

Ensure the router's DHCP scope includes:

- **Option 66** (TFTP Server Name): deploy server IP (`192.168.1.10`)
- **Option 67** (Bootfile Name): `pxelinux.0` (Legacy) or `grubnetx64.efi` (UEFI)

See [USAGE.md — DHCP Transition](USAGE.md#dhcp-transition-to-router) for details.

## Image transfer fails mid-way

- Check disk space on the deploy server: `df -h /srv/images`.
- Check for network interruptions (managed switch with IGMP snooping is
  recommended).
- Retry with a smaller number of clients to isolate the problem.

## `collect_mac.sh` finds no hosts

- Ensure the deploy server's bridged interface is active:
  `ip addr show eth1`
- Confirm clients are powered on and connected to the same network segment.
- Try a manual arp-scan: `sudo arp-scan 192.168.1.0/24`
