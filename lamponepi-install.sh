#!/bin/bash

set -e

function System()
{
    base=$FUNCNAME
    this=$1

    # Declare methods.
    for method in $(compgen -A function)
    do
        export ${method/#$base\_/$this\_}="${method} ${this}"
    done

    # Properties list.
    DEVICE="$DEVICE"
    FULL_ISO_FILE="$FULL_ISO_FILE"
}

# ##################################################################################################################################################
# Public
# ##################################################################################################################################################

#
# Void System_run().
# This script writes a standard live ISO onto a SD card so that it's compliant to be booted by a Raspberry Pi.
# Partitioning scheme is liveng compliant (https://liveng.readthedocs.io/en/latest/) - the same used by in Resilient Linux
# with the minimum possible modifications for the Pi porting.
# liveng specifications by Marco Buratto and Michele Sartori.
#
function System_run()
{
    if [ -n "$FULL_ISO_FILE" ] && [ -n "$DEVICE" ]; then
        printf "\n* Installing the system, please have a cup of coffee...\n"
        System_install "$FULL_ISO_FILE" "$DEVICE"

        echo "Installation accomplished."
    else
        exit 1
    fi
}

# ##################################################################################################################################################
# Private static
# ##################################################################################################################################################

function System_install()
{
    image="$1"
    device="$2"

    isoFile="/tmp/lamponepi-kif.iso"
    if [ -f $isoFile ]; then
        rm $isoFile
    fi

    if [ -d /tmp/lamponepi.tmp ]; then
        rm -R /tmp/lamponepi.tmp
    fi
    mkdir /tmp/lamponepi.tmp

    # Extract the live folder from the hybrid iso, we are only interested in the kernel, initrd, filesystem.squashfs files.
    mount $1 /mnt
    cp -R /mnt/live /tmp/lamponepi.tmp/
    umount /mnt

    rm /tmp/lamponepi.tmp/live/initrd.img-4.19* || true
    rm /tmp/lamponepi.tmp/live/vmlinuz-4.19* || true

    mv /tmp/lamponepi.tmp/live/initrd* /tmp/lamponepi.tmp/live/initrd.img
    mv /tmp/lamponepi.tmp/live/vmlinuz* /tmp/lamponepi.tmp/live/vmlinuz

    # Create the working ISO file from the files.
    cd /tmp/lamponepi.tmp
    xorrisofs -v -J -r -V LAMPONE_PI -o $isoFile .

    # Unmount.
    for i in $(mount | grep $device | awk '{print $1}'); do umount $i; done

    isoFileSize=$(du -sm "$isoFile" | awk '{print $1}') # MiB.

    # Initially wipe the $device with wipefs.
    wipefs -af $device && sleep 2

    # Create a blank MBR.
    printf "o\nw\n" | fdisk $device && sync && sleep 6

    # Create the boot FAT partition of 256MiB.
    printf "n\np\n\n\n+256M\nw\n" | fdisk $device && sync && sleep 2
    printf "t\nc\nw\n" | fdisk $device && sync && sleep 2
    mkfs.vfat -n "UEFI Boot" ${device}1 && sleep 2
    printf "a\nw\n" | fdisk $device && sync && sleep 2

    # Create the first system partition for writing kernel+initrd+filesystem.squashfs files into.
    printf "n\np\n\n\n+${isoFileSize}M\nw\n" | fdisk $device && sync && sleep 2

    # Write content from the working ISO with xorriso into the host partition.
    xorriso -abort_on FAILURE -return_with SORRY 0 -indev "$isoFile" -boot_image any discard -overwrite on -volid 'SK-SYSTEM1' -rm_r live/filesystem.packages live/filesystem.packages-remove live/filesystem.size -- -outdev stdio:${device}2 -blank as_needed

    # Create the second system partition (256MiB) and write the kernel+initrd files into.
    printf "n\np\n\n\n+256M\nw\n" | fdisk $device && sync && sleep 2
    xorriso -abort_on FAILURE -return_with SORRY 0 -indev "$isoFile" -boot_image any discard -overwrite on -volid 'SK-SYSTEM2' -rm_r live/filesystem.packages live/filesystem.packages-remove live/filesystem.size live/filesystem.squashfs -- -outdev stdio:${device}3 -blank as_needed

    # Find out ISO partitions' UUIDs.
    isoUuidSystemPartition=$(blkid -s UUID ${device}2 | grep -oP '(?<=UUID=").*(?=")')
    isoUuidSecondSystemPartition=$(blkid -s UUID ${device}3 | grep -oP '(?<=UUID=").*(?=")')

    # Create UEFI structures; pass isoUuid* to grub.cfg:
    # GRUB will load kernel and initrd from the second system partition (which will be rewritten via xorrisofs after the kernel update by the system itself),
    # and will instruct the live-build-patched initrd to load the filesystem.squashfs from the first (complete) system partition.
    # A fallback boot is also available, with ye olde settings (i.e.: kernel/initrd loader from first system partition);
    # this boot option will also pass a special boot parameter, so the system can re-build the second system partition (xorrisofs).

    mount ${device}1 /mnt
    cp -R /sbin/lamponepi-installer/pi-boot/* /mnt
    sed -i -e "s/SYSTEM_ISO_UUID1/$isoUuidSystemPartition/g" /mnt/efi/boot/grub.cfg
    sed -i -e "s/SYSTEM_ISO_UUID2/$isoUuidSecondSystemPartition/g" /mnt/efi/boot/grub.cfg
    umount /mnt

    # Create the persistence partition as the last partition (with all the remaining space left) with the persistence.conf file inside.  
    printf "n\np\n\n\n\nw\n" | fdisk $device && sync && sleep 2

    mkfs.ext4 -F ${device}4 && sleep 2
    e2label ${device}4 "persistence"

    mount ${device}4 /mnt
    echo "/ union" > /mnt/persistence.conf
    umount /mnt 
}

# ##################################################################################################################################################
# Main
# ##################################################################################################################################################

DEVICE=""
FULL_ISO_FILE=""

# Must be run as root (sudo).
ID=$(id -u)
if [ $ID -ne 0 ]; then
    echo "This script needs super cow powers."
    exit 1
fi

# Parse user input.
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        --iso)
            FULL_ISO_FILE="$2"
            shift
            shift
            ;;

        --device)
            DEVICE="$2"
            shift
            shift
            ;;

        *)
            shift
            ;;
    esac
done

if [ -z "$DEVICE" ] || [ -z "$FULL_ISO_FILE" ]; then
    echo "Missing parameters. Use --iso <iso-image-file> --device <device>, for example --iso /path/to/live-image-arm64.hybrid.iso --device /dev/sda."
else
    System "system"
    $system_run
fi

exit 0