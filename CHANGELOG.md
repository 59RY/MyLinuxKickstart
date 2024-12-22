# Changelog

## 0.4 (2023/12/22)

Pre-Release: 2024-12-22

- Add Another Configurations
  - for:
    - AlmaLinux 10 Beta (UEFI)
    - AlmaLinux Kitten 10 (UEFI)
	- CentOS 10 Stream (UEFI)
  - These files also review the list of packages to be installed.
- Add:
  - Added instructions on how to distribute RHEL9 family
  - Notice for RHEL 10 Family
- TBD (TODO):
  - Include instructions on how to distribute RHEL10 family

## 0.3 (2023/08/01)

Pre-Release: 2023-07-19

- Add Another Configurations
  - for:
    - AlmaLinux 9 (UEFI)
	- EuroLinux 9 (UEFI)
	- RHEL 9 (UEFI, netinst)
    - Rocky Linux 9 (UEFI)
  - Modify from others:
    - Specify install packages
    - Adjust delete packages at the post script
- Add:
  - Pre-script (UEFI Only)
- Modify:
  - Adjust services (UEFI Only)
  - How to detect using the disk (UEFI Only)
  - Review of files to trancate, and how to implement it
- Delete:
  - MIRACLE LINUX 9 (UEFI) Configuration file
    - Because MIRACLE LINUX is unlikely to release an ARM version
  - Regenerating initramfs (UEFI Only)
- Refactoring:
  - dracut config option
  - Delete DNF cache command

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
