# Procedure for creating distribution images for RHEL 9 Family

## Table of Contents

- **Local Environment**
  - Installation using Kickstart
  - Creating a disk image
- **AWS**
  - Creating a working instance
  - Creating and attaching a working disk (1st)
  - Copying the disk image to the working instance
  - Writing the disk image to the working disk
  - Modifying the working disk
    - 1. Mounting Operation
    - 2. Regenerate dracut
    - 3. Delete unnecessary files (Part1)
    - 4. Delete unnecessary files (Part2)
  - Check the disk number again with lsblk
  - Writing changes from the working disk to the disk image
  - If the disk image capacity (MiB) was not a multiple of 1024
  - Creating and attaching a working disk (2nd)
  - Writing to the working disk
  - Detaching the working disk (2nd)
  - Creating a Snapshot from the Second Working Disk
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

### Creating and attaching a working disk (1st)

- Create a working disk.
  - This will be used later to write the disk image.
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

#### 1. Mounting Operation

```bash
mkdir ./tmp
sudo mount /dev/nvme1n1p<PARTITION> ./tmp
sudo mount -o rbind /sys ./tmp/sys && sudo mount -o rbind /dev ./tmp/dev && sudo mount -t proc none ./tmp/proc
sudo chroot ./tmp
```

- `<PARTITION>`: Partition number
  - For aarch64 environments, typically `2`.
  - For x86_64 environments, typically `3` when both a biosboot partition and an EFI partition are created.
    - If only one partition is created, the partition number may vary.

#### 2. Regenerate dracut

Run as root user on the working disk.

```bash
dracut -f --regenerate-all
exit
```

#### 3. Delete unnecessary files (Part1)

Return to the standard user of the working instance.

```bash
cd ./tmp
sudo find ./var/log/ -type f -name \* -not -name 'README' -exec cp -f /dev/null {} \;
sudo su
```

#### 4. Delete unnecessary files (Part2)

Execute as the root user of the working instance.

```bash
cd root
rm --force .bash_history
rm --force .bash_logout
rm --force anaconda-ks.cfg
mkdir -p ../usr/share/kickstart-dist
mv --force original-ks.cfg ../usr/share/kickstart-dist/CONFIG
chmod 644 ../usr/share/kickstart-dist/CONFIG
cd ../
xfs_fsr -v /dev/nvme1n1p1
xfs_io -c "falloc -k -l $(($(df --output=avail /home/<initial instance user>/tmp | tail -n1) * 1024)) /home/<initial instance user>/tmp/dummyfile"
rm /home/<initial instance user>/tmp/dummyfile
dd if=/dev/zero of=./zerofill bs=4K || :
rm ./zerofill
```

> **NOTE**
> - Replace `<initial instance user>` with the name of the initial user on the instance.
> - An “out-of-space” error may occur during the dd command, but this is intentional.
> - For RHEL, delete the original-ks.cfg and do not create the kickstart-dist directory.

For UEFI environment, execute the following additional commands:

```bash
mkdir ../tmp2
mount /dev/nvme1n1p1 ../tmp2
dd if=/dev/zero of=../tmp2/zerofill bs=512 || :
rm ../tmp2/zerofill
```

Reboot after these works are completed.

```bash
reboot
```

▲ After executing the above commands, you'll be disconnected from the working instance, and the instance will restart.

### Check the disk number again with lsblk.

In some cases, the working disk may be nvme0n1.
The following procedures still assume nvme1n1, but if it is nvme0n1, replace it with nvme0n1.

### Writing changes from the working disk to the disk image

Re-login to the working instance via SSH.

```bash
sudo dd if=/dev/nvme1n1 of=disk_new.img bs=1M count=<DISKSIZE>
qemu-img convert -c -f raw -O qcow2 disk_new.img disk_new.qcow2
```

- `<DISKSIZE>`: The capacity of the originally created disk image (in MiB).

▲ After executing the above commands, transfer the disk image using SFTP or other methods to a local machine or S3.

### If the disk image capacity (MiB) was not a multiple of 1024

Expand the disk so that it's a multiple of 1024 (exactly in 1 GiB increments).

```bash
sudo growpart /dev/nvme1n1 <PARTITION>
sudo mount /dev/nvme1n1p<PARTITION> ./tmp
sudo mount -o rbind /sys ./tmp/sys && sudo mount -o rbind /dev ./tmp/dev && sudo mount -t proc none ./tmp/proc
sudo chroot ./tmp

# Become root user
xfs_growfs /dev/nvme1n1p<PARTITION>
exit

# Delete unnecessary files (standard user)
cd ./tmp
sudo find ./var/log/ -type f -name \* -not -name 'README' -exec cp -f /dev/null {} \;
sudo su

# Delete unnecessary files (root user)
cd root
rm --force .bash_history
rm --force .bash_logout
cd ../
dd if=/dev/zero of=./zerofill bs=4K || :
rm ./zerofill

# reboot
reboot
```

- `<PARTITION>`: Partition number
  - For aarch64 environments, typically `2`.
  - For x86_64 environments, typically `3` when both a biosboot partition and an EFI partition are created.
    - If only one partition is created, the partition number may vary.

### Creating and attaching a working disk (2nd)

If you create a snapshot using only the first working disk, you will incur EBS costs for the entire disk capacity.\
To reduce costs, create an additional working disk and use that disk exclusively for snapshot creation.

- In the AWS Console, create a working disk.
  - Disk size: Typically 2 GiB (match the capacity of the first disk).
  - Use the same availability zone as the working instance.

### Writing to the working disk

Use [disk-write-batch.sh](./disk-write-batch.sh) to write to the working disk. Since the script runs interactively, execute it as follows:

- Input source: `/dev/nvme1n1` (or specify the path to the disk_new.img file)
- Output destination: `/dev/nvme2n1`
- Number of blocks to copy: Enter the number of 512 KiB blocks (for example, for 2 GiB, enter `4096`)

### Detaching the working disk (2nd)

Detach the second working disk.

### Creating a Snapshot from the Second Working Disk

Create a snapshot from the working disk.

- ※ For AMI distribution, use the naming convention `<OS Name> <Version> - <Architecture> (<YYYY/MM/DD>)` .

### Creating and publishing an AMI

Create and publish an AMI based on the created snapshot.

- The image name should follow the same convention as the snapshot: `<OS Name> <Version> - <Architecture> (<YYYY/MM/DD>)` .
- Provide an appropriate description.
- Select the appropriate architecture.
- The root device name should be `/dev/xvda`.
- Explicitly select the boot mode.
- The volume should ideally be “General Purpose SSD (gp3)”.
