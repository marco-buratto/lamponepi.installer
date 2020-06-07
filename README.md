# Lampone Pi, installing the live ISO

Lampone Pi is a live Debian arm64 port for the Raspberry Pi.

Here are the instructions on how write the live ISO image file onto a SD card so that it's compliant to be booted by a Raspberry Pi.
A Linux host is required (Debian Buster x86_64 has been tested and used for the development).

**\
\
Writing the live image onto a SD card**

Connect the SD-to-USB dongle to the computer/hypervisor.
Open a terminal as root (*su -*) and use *fdisk -l* for locating its device file, for example:

    # fdisk -l
    
    Disk /dev/sda: 50 GiB, 53687091200 bytes, 104857600 sectors
    Disk model: VBOX HARDDISK   
    Units: sectors of 1 * 512 = 512 bytes
    Sector size (logical/physical): 512 bytes / 512 bytes
    I/O size (minimum/optimal): 512 bytes / 512 bytes
    Disklabel type: dos
    Disk identifier: 0xbce97a12

    Device     Boot    Start       End  Sectors Size Id Type
    /dev/sda1  *        2048  98568191 98566144  47G 83 Linux
    /dev/sda2       98570238 104855551  6285314   3G  5 Extended
    /dev/sda5       98570240 104855551  6285312   3G 82 Linux swap / Solaris


    Disk /dev/sdc: 7.4 GiB, 7969177600 bytes, 15564800 sectors
    Disk model: MicroSD/M2      
    Units: sectors of 1 * 512 = 512 bytes
    Sector size (logical/physical): 512 bytes / 512 bytes
    I/O size (minimum/optimal): 512 bytes / 512 bytes
    Disklabel type: dos
    Disk identifier: 0x73dc7c47

*/dev/sdc* is the device file corresponding to the USB dongle.

Now we write the live image to the SD card in a way it is compatible with a Raspberry Pi's booting:

    apt install -y xorriso
    mkdir /sbin/lamponepi-installer; mv pi-boot /sbin/lamponepi-installer/
    
    lamponepi-install.sh --iso /path/to/lampone-pi.iso --device /dev/sdc


**\
\
liveng**

The resulting partitioning scheme is *liveng* compliant (https://liveng.readthedocs.io/en/latest/) - the same used by in Resilient Linux with the minimum possible modifications for the Pi porting. The liveng partitioning scheme allows programs and kernel updates with a readonly system partition (if the live image supports it).
