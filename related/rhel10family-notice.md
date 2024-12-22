# Notice for RHEL 10 Family

Last Update: Dec. 20, 2024, JST.

## Caution: This image isn't installed the rescue image

- Rescue images are deleted to reduce disk space usage.
- However, I also understand that you want to use the it on infrastructures where it's available.
  - Such as when using the EC2 serial console in AWS.
- In this case, I recommend running these commands to restore the rescue image.
  ```sh
  sudo dnf -y install dracut-config-rescue
  sudo kernel-install add $(uname -r) /lib/modules/$(uname -r)/vmlinuz
  [[ -f /etc/os-release ]] && . /etc/os-release
  sudo grub2-mkconfig -o /boot/efi/EFI/$(echo $ID)/grub.cfg
  ```

## About Additional Packages

- To prevent errors related to wireless communication kernel modules, the following packages are installed:
  - `wireless-regdb`
  - `iw` (as a dependency)
- Without these packages, the kernel module `cfg80211` fails to load the `regulatory.db` file, resulting in the following error messages:
  ```
  platform regulatory.0: Direct firmware load for regulatory.db failed with ｆ -2
  cfg80211: failed to load regulatory.db
  ```
- When using a virtual environment, this error does not affect actual operation. Therefore, it can be ignored. However, in this project, the packages are installed to resolve the error.