# Procedure for creating distribution images for RHEL 9 Family

## Table of Contents

- Local Environment
  - Installation using Kickstart
  - Creating a disk image
- AWS
  - Creating a working instance
  - Creating and attaching a working disk
  - Copying the disk image to the working instance
  - Writing the disk image to the working disk
  - Modifying the working disk
  - Writing changes from the working disk to the disk image
  - Detaching the working disk
  - Creating a snapshot
  - Creating and publishing an AMI

## Local Environment

### Installation using Kickstart

- Download the installer ISO (netinst version).
- Prepare a virtual machine or software.
  - Example: Use “VMWare” for x86_64, or “UTM” for aarch64, etc.
- Install the OS using Kickstart.

## AWS Environment

### Creating a working instance

- Select an appropriate AMI for the OS, version, and architecture you are trying to create.
  - Example: If you are trying to create an image of Rocky Linux 9 (aarch64), use “[Rocky Linux 9 (Official) - aarch64](https://aws.amazon.com/marketplace/pp/prodview-6ihwigagrts66)”.
- The disk image should be at least 6 GiB in size.
  - However, some AMIs may already be 8 GiB or 10 GiB in size.
- Specify user data.
  ```yaml
  #cloud-config
  
  packages:
    - qemu-img
  ```
- Make any other desired specifications and create the instance.

### Creating and attaching a working disk

- Create a working disk.
  - This will be used later to write the disk image or create snapshots.
  - Disk size: Typically 2GiB
  - Use the same availability zone as the working instance.

### Copying the disk image to the working instance

Transfer the disk image to the working instance using SFTP or S3. SFTP is recommended for simplicity.

### Writing the disk image to the working disk

Log in to the working instance via SSH and execute the following commands:

```bash
qemu-img convert -f <DISK_FORMAT> -O raw <DISK_IMAGE_FILENAME> disk.img
sudo dd if=disk.img of=/dev/nvme1n1 bs=1M
```

- `<DISK_FORMAT>`: The format of the disk image created in the local environment, such as qcow2 or vmdk.
- `<DISK_IMAGE_FILENAME>`: The filename of the disk image created in the local environment.

### Modifying the working disk

```bash
mkdir ./tmp
sudo mount /dev/nvme1n1p<PARTITION> ./tmp
sudo mount -o rbind /sys ./tmp/sys && sudo mount -o rbind /dev ./tmp/dev && sudo mount -t proc none ./tmp/proc
sudo chroot ./tmp
```

- `<PARTITION>`: Partition number
  - For UEFI environments, it's usually `2`.
  - For BIOS environments, it's usually `1`.

▲ After executing the above commands, you'll become the root user of the working disk.

```bash
dracut -f --kver $(ls /boot/vmlinuz-* | cut -c 15-)
exit
```

▲ After executing the above commands, you'll return to the standard user of the working instance.

```bash
cd ./tmp
sudo find ./var/log/ -type f -name \* -not -name 'README' -exec cp -f /dev/null {} \;
sudo su
```

▲ After executing the above commands, you'll become the root user of the working instance.

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
reboot
```

> **NOTE**
> - An “out-of-space” error may occur during the dd command, but this is intentional.
> - For RHEL, delete the original-ks.cfg and do not create the kickstart-dist directory.

▲ After executing the above commands, you'll be disconnected from the working instance, and the instance will restart.

### Writing changes from the working disk to the disk image

Re-login to the working instance via SSH.

```bash
sudo dd if=/dev/nvme1n1 of=disk_new.img bs=1M count=<DISKSIZE>
qemu-img convert -c -f raw -O qcow2 disk_new.img disk_new.qcow2
```

- `<DISKSIZE>`: The capacity of the originally created disk image (in MiB).

▲ After executing the above commands, transfer the disk image using SFTP or other methods to a local machine or S3.

### Detaching the working disk

Detach the working disk.

### Creating a snapshot

Create a snapshot from the working disk.

- ※ For AMI distribution, use the naming convention `<OS Name> <Version> - <Architecture> (<YYYY-MM-DD>)` .

### Creating and publishing an AMI

Create and publish an AMI based on the created snapshot.

- The image name should follow the same convention as the snapshot: `<OS Name> <Version> - <Architecture> (<YYYY-MM-DD>)` .
- Provide an appropriate description.
- Select the appropriate architecture.
- The root device name should be `/dev/xvda`.
- Explicitly select the boot mode.
- The volume should ideally be “General Purpose SSD (gp3)”.
