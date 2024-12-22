# RHEL 10 ファミリー用のお知らせ

最終更新日: 2024年12月20日(日本時間)

## ⚠︎ レスキューイメージなしのイメージです

- ディスクの使用容量を削減するために、レスキューイメージを削除しています。
- ただし一部のインフラやユースケースでは、レスキューイメージを利用したい、ということも理解しています。
  - AWSでEC2シリアルコンソールを利用する時など
- その際は、このコマンドを実行してレスキューイメージを復元することを推奨します。
  ```sh
  sudo dnf -y install dracut-config-rescue
  sudo kernel-install add $(uname -r) /lib/modules/$(uname -r)/vmlinuz
  [[ -f /etc/os-release ]] && . /etc/os-release
  sudo grub2-mkconfig -o /boot/efi/EFI/$(echo $ID)/grub.cfg
  ```

## 追加パッケージについて

- 無線通信関連のカーネルモジュールによるエラーを防ぐため、以下のパッケージを追加でインストールしています。
  - `wireless-regdb`
  - `iw` (依存パッケージとして)
- 上記のパッケージがない場合、カーネルモジュール `cfg80211` が `regulatory.db` ファイルをロードできず、以下のようなエラーメッセージが表示されます。
  ```
  platform regulatory.0: Direct firmware load for regulatory.db failed with ｆ -2
  cfg80211: failed to load regulatory.db
  ```
- 仮想環境で使用する場合、このエラーは実際の動作に影響を与えません。そのため、無視することも可能ですが、本プロジェクトではパッケージを追加してエラーを解消しています。