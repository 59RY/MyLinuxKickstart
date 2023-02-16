# RHEL 9 ファミリー用のお知らせ

最終更新日: 2023年2月16日(日本時間)

## ⚠︎ レスキューイメージなしのイメージです

- ディスクの使用容量を削減するために、レスキューイメージを削除しています。
  - AWS など一部インフラでは利用できないためです。
- ただし一部のインフラやユースケースでは、レスキューイメージを利用したい、ということも理解しています。
- その際は、このコマンドを実行してレスキューイメージを復元することを推奨します。
  ```sh
  sudo dnf -y install dracut-config-rescue
  sudo kernel-install add $(uname -r) /lib/modules/$(uname -r)/vmlinuz
  [[ -f /etc/os-release ]] && . /etc/os-release
  sudo grub2-mkconfig -o /boot/efi/EFI/$(echo $ID)/grub.cfg
  ```
