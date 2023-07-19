# Changelog

## 0.3.testing (----/--/--)

Pre-Release: 2023-07-19

- Add Another Configurations
  - for:
    - AlmaLinux 9 (UEFI)
    - Rocky Linux 9 (UEFI)
  - Modify from others:
    - Specify install packages
    - Adjust delete packages at the post script

## 0.2 (2023-07-19)

- Modify:
  - Bootloader
  - Re-enable locale-related environment variables on SSH
  - After installation, turn off the instance (safe for VMWare)
- Refactoring:
  - Not to use variables
  - 50-languages.conf
  - Zerofill free spaces
  - Make explicit:
    - Enforce SELinux
    - Enable cloud-init services
- Remove files:
  - `/etc/machine-id` (Trancate)
  - `/etc/sysconfig/network-scripts/ifcfg-ens3`
  - `/var/lib/systemd/random-seed`
  - `/var/lib/rpm/__db*`
- ...and refactoring some more comments.

## 0.1 (2023-02-21)

- Initial Release
