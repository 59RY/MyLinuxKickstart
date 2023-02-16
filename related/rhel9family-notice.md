# Notice for RHEL 9 Family

Last Update: Fed. 16, 2023, JST.

## Caution: This image isn't installed the rescue image

- Rescue images are deleted to reduce disk space usage.
  - Because some infrastructures (such as AWS) can't use it.
- However, I also understand that you want to use the it on infrastructures where it's available.
- In this case, I recommend running these commands to restore the rescue image.
  ```sh
  sudo dnf -y install dracut-config-rescue
  sudo kernel-install add $(uname -r) /lib/modules/$(uname -r)/vmlinuz
  [[ -f /etc/os-release ]] && . /etc/os-release
  sudo grub2-mkconfig -o /boot/efi/EFI/$(echo $ID)/grub.cfg
  ```
