# Makefile & configs for building U-Boot and Linux for TechNexion's PICO-PI-IMX8M

These configuration files are a result of the [2024 ARM Summer School](https://ocw.cs.pub.ro/courses/ass), held in the Faculty of Automatic Control and Computer Science of the POLITEHNICA University of Bucharest and sponsored by Google.

**Warning:** This Makefile is intended to be run on a Debian-based Linux system. It might wipe unintended disks. Inspect the code for the `9-diskimg` and `boot-linux` stages and make sure you don't have disks matching those modified by the script. Running these stages may require root privileges.

## Dependencies

Before running the Makefile, ensure that you have the necessary dependencies installed. The `0-config` stage attempts to install them automatically. The packages required are: `build-essential`, `libusb-1.0-0-dev`, `libbz2-dev`, `libzstd-dev`, `pkg-config`, `cmake`, `libssl-dev`, `g++`, `zlib1g-dev`, `libtinyxml2-dev`, `libzip-dev`, `unzip`, `bison`, `flex`, `device-tree-compiler`.

The Makefile uses `apt` to install these packages, so it is intended for Debian-based systems.

## Makefile Stages

The Makefile is separated into stages, each building on the dependencies needed to boot Linux on the board.

- **0-config**: Prepares the dependencies required for building the image. It installs necessary packages if they are not already installed.
- **1-atf**: Downloads the Trusted Firmware-A (BL31) from [NXP's GitHub repository](https://github.com/nxp-imx/imx-atf) (branch `lf_v2.6`) and compiles it.
- **2-nxp-fw**: Downloads NXP's i.MX Firmware (BL2) version `8.9` from [the Buildroot sources](http://sources.buildroot.net/firmware-imx/). Please note this auto-accepts an EULA while extracting the files.
- **3-uboot**: Downloads and compiles a TechNexion-customized variant of U-Boot from [their GitHub repository](https://github.com/TechNexion/u-boot-tn-imx) (branch `tn-imx_v2023.04_6.1.55_2.2.0-stable`).
  - **3-uboot-prepare**
  - **3-uboot-compile**
- **4-nxp-mkimg**: Packages U-Boot and the firmware in a firmware package using NXP's `imx-mkimage` tool from [their repository](https://github.com/nxp-imx/imx-mkimage/) (branch `lf-5.15.32_2.0.0`).
- **5-nxp-uuu**: Downloads and compiles the Universal Update Utility (UUU) customized by NXP from [their repository](https://github.com/nxp-imx/mfgtools).
- **boot-u**: Used for only booting U-Boot.
- **6-linux**: Downloads (from [Torvalds' Linux repository](https://github.com/torvalds/linux/), branch `v6.6`), configures, and compiles the Linux kernel.
  - **6-linux-prepare**
  - **6-linux-compile**
- **7-buildroot**: Downloads (from [Buildroot repository](https://github.com/buildroot/buildroot/), version `2024.05.1`), configures, and builds a Linux root filesystem using Buildroot.
  - **7-buildroot-prepare**
  - **7-buildroot-compile**
- **8-fit**: Creates the Flattened Image Tree (FIT) image.
- **9-diskimg**: Creates the disk image.
- **boot-linux**: Boots U-Boot and then Linux, entirely without user interaction.

## Important Note:
 **Disk Modification Risk**: The `9-diskimg` and `boot-linux` stages involve disk operations that could potentially overwrite your disk data. Before running these stages, ensure that you have disconnected all unnecessary storage devices to prevent data loss.

## Usage

To build all stages, run:

```bash
make all
```

You can also build individual stages by specifying the target. For example:

```bash
make 1-atf
```

To clean all generated directories, run:

```bash
make clean-all
```

To list all available targets, run:

```bash
make list
```

## Notes
- **Root Privileges**: Some stages may require root privileges due to operations like installing packages, mounting file systems, and writing to disks.

- **Serial Device Configuration**: By default, the serial device is set to `/dev/ttyUSB0`. If your serial device differs, modify the `SERIAL_DEVICE` variable in the Makefile accordingly.

- **User Interaction**: The `boot-linux` target attempts to automate the booting process. It waits for U-Boot to boot, sends commands over the serial connection, and writes the disk image to the device. Monitor the process carefully.

## License Agreement

Please be aware that by downloading and extracting NXP's i.MX Firmware in stage `2-nxp-fw`, you agree to their EULA, which is auto-accepted during extraction.

## Troubleshooting

- **Missing Packages**: If the automatic installation of packages fails, manually install the required packages listed in the Dependencies section.

- **Disk Not Found**: If the script cannot find the appropriate disk to write the image, verify your connected devices and adjust the script if necessary.

- **Compilation Errors**: Ensure that all dependencies are installed and that you're using compatible versions of the tools and compilers.

## Contributions

Contributions are welcome. Please inspect the code and ensure safety before running any stages that modify disks.