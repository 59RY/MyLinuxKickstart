# RHEL 9 ファミリーの配布用イメージ作成の流れ

## 目次

- ローカル環境
  - Kickstartを用いてインストール
  - ディスクイメージを作成
- AWS
  - 作業用インスタンスの作成
  - 作業用ディスクの作成・アタッチ
  - ディスクイメージを作業用インスタンスにコピー
  - ディスクイメージを、作業用ディスクに書き込む
  - 作業用ディスクに変更を加える
  - 作業用ディスクからディスクイメージに書き出す
  - 作業用ディスクのデタッチ
  - スナップショット作成
  - AMI作成、および公開

## ローカル環境

### Kickstartを用いてインストール

- インストーラーISO(netinst版)をダウンロードする。
- 仮想マシン・ソフトウェアを用意する。
  - 例: x86_64の場合は「VMWare」、aarch64の場合は「UTM」など
- Kickstartを用いてOSをインストールする。

## AWS環境

### 作業用インスタンスの作成

- 作成しようとしているOS、バージョン、アーキテクチャに適したものを作業用インスタンスのAMIとして選定する。
  - 例: Rocky Linux 9 (aarch64版)のイメージを作ろうとしている場合は、「[Rocky Linux 9 (Official) - aarch64](https://aws.amazon.com/marketplace/pp/prodview-6ihwigagrts66)」を利用する。
- ディスクイメージは6GiB以上あるのが望ましい。
  - ただし選定するAMIによっては、既に8GiB または 10GiBになっている場合もある。
- ユーザーデータを指定する。
  ```yaml
  #cloud-config
  
  packages:
    - qemu-img
  ```
- 残りは任意の指定をし、インスタンスを作成する。

### 作業用ディスクの作成・アタッチ

- 作業用のディスクを作成する。
  - これは、後々ディスクイメージを書き込んだりスナップショットを作成したりする。
  - ディスクサイズ: 基本的に2GiB
  - アベイラビリティーゾーンは、作業用インスタンスと合わせる。

### ディスクイメージを作業用インスタンスにコピー

SFTPまたはS3を用いて作業用インスタンスへ転送する。SFTPが簡単だと思われる。

### ディスクイメージを、作業用ディスクに書き込む

作業用インスタンスにSSHでログインした上で実施する。

```bash
qemu-img convert -f <DISK_FORMAT> -O raw <DISK_IMAGE_FILENAME> disk.img
sudo dd if=disk.img of=/dev/nvme1n1 bs=1M
```

- `<DISK_FORMAT>`: ローカル環境で作成したディスクイメージの形式。qcow2やvmdkなど
- `<DISK_IMAGE_FILENAME>`: ローカル環境で作成したディスクイメージ名

### 作業用ディスクに変更を加える

#### 1. マウント作業

```bash
mkdir ./tmp
sudo mount /dev/nvme1n1p<PARTITION> ./tmp
sudo mount -o rbind /sys ./tmp/sys && sudo mount -o rbind /dev ./tmp/dev && sudo mount -t proc none ./tmp/proc
sudo chroot ./tmp
```

- `<PARTITION>`: パーティション番号
  - UEFI環境の場合、通常`2`となる
  - BIOS環境の場合、通常`1`となる

#### 2. dracutの再作成

作業用ディスクのrootユーザとして実行する。

```bash
dracut -f --regenerate-all
exit
```

#### 3. 不要ファイルの削除(Part1)

作業用インスタンスの標準ユーザに戻る。

```bash
cd ./tmp
sudo find ./var/log/ -type f -name \* -not -name 'README' -exec cp -f /dev/null {} \;
sudo su
```

#### 4. 不要ファイルの削除(Part2)

作業用インスタンスのrootユーザとして実行する。

```bash
cd root
rm --force .bash_history
rm --force .bash_logout
rm --force anaconda-ks.cfg
mkdir -p ../usr/share/kickstart-dist
mv --force original-ks.cfg ../usr/share/kickstart-dist/CONFIG
chmod 644 ../usr/share/kickstart-dist/CONFIG
cd ../
dd if=/dev/zero of=./zerofill bs=4K || :
rm ./zerofill
```

> **NOTE**
> - ddコマンド部分で「out-of-space」エラーがでることがあるが、これは意図的である。
> - RHELの場合は、original-ks.cfgは削除する。`kickstart-dist` ディレクトリの作成もしない。

UEFI環境の場合は追加で以下を実行する。

```bash
mkdir ../tmp2
mount /dev/nvme1n1p1 ../tmp2
dd if=/dev/zero of=../tmp2/zerofill bs=512 || :
rm ../tmp2/zerofill
```

作業完了後は再起動する。

```bash
reboot
```

▲上記コマンド実行後、作業用インスタンスから切断され、作業用インスタンスが再起動される。

### 作業用ディスクからディスクイメージに書き出す

作業用インスタンスに再度SSHにログインする。

```bash
sudo dd if=/dev/nvme1n1 of=disk_new.img bs=1M count=<DISKSIZE>
qemu-img convert -c -f raw -O qcow2 disk_new.img disk_new.qcow2
```

- `<DISKSIZE>`: 元々作成していたディスクイメージの容量(MiB単位)

▲上記コマンド実行後に、SFTPなどを用いてディスクイメージをローカルやS3などに転送する。

### ディスクイメージの容量(MiB)が1024の倍数では無かった場合

1024の倍数になるように(1GiB単位でちょうどになるように)ディスクを拡張する。

```bash
sudo growpart /dev/nvme1n1 <PARTITION>
sudo mount /dev/nvme1n1p<PARTITION> ./tmp
sudo mount -o rbind /sys ./tmp/sys && sudo mount -o rbind /dev ./tmp/dev && sudo mount -t proc none ./tmp/proc
sudo chroot ./tmp

# root ユーザーになる
xfs_growfs /dev/nvme1n1p<PARTITION>
exit

# 不要ファイルを削除する(標準ユーザー)
cd ./tmp
sudo find ./var/log/ -type f -name \* -not -name 'README' -exec cp -f /dev/null {} \;
sudo su

# 不要ファイルを削除する(ルートユーザー)
cd root
rm --force .bash_history
rm --force .bash_logout
cd ../
dd if=/dev/zero of=./zerofill bs=4K || :
rm ./zerofill

# 再起動する
reboot
```

- `<PARTITION>`: パーティション番号
  - UEFI環境の場合、通常`2`となる
  - BIOS環境の場合、通常`1`となる

### 作業用ディスクのデタッチ

作業用ディスクをデタッチする。

### スナップショット作成

作業用ディスクからスナップショットを作成する。

- ※AMI配布時は、スナップショット名を `<OS名> <バージョン> - <アーキテクチャ> (<YYYY-MM-DD>)` という規則にしている

### AMI作成、および公開

作成したスナップショットをもとに、AMIを作成・公開する。

- イメージ名は、スナップショットと同じ `<OS名> <バージョン> - <アーキテクチャ> (<YYYY-MM-DD>)` という規則にしている
- 適切な説明
- 適切なアーキテクチャの選択
- ルートデバイス名は `/dev/xvda`
- ブートモードは明示的に選択する
- ボリュームは、今ドキは「汎用SSD (gp3)」が良いように思う
