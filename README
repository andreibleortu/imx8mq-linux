# Files for building U-Boot and Linux for TechNexion's PICO-PI-IMX8M

These configuration files are a result of the [2024 ARM Summer School](https://ocw.cs.pub.ro/courses/ass), held in the Faculty of Automatic Control and Computer Science of the POLITEHNICA University of Bucharest and sponsored by Google.

Warning: this might wipe unintended disks. Inspect the code for the `9-diskimg` and `boot-linux` stages and make sure you don't have disks matching those modified by the script.

The Makefile is separated into stages, each building on the dependencies needed to boot Linux on the board.
- 0-config - prepares the dependencies required for building the image
- 1-atf - downloads the Trusted Firmware-A (BL31) from [NXP's GitHub repository](https://github.com/nxp-imx/imx-atf) and compiles it.
- 2-nxp-fw - downloads NXP's i.MX Firmware (BL2) from [the Buildroot sources](http://sources.buildroot.net). Please note this auto-accepts an EULA while extracting the files.
- 3-uboot - downloads and compiles a TechNexion-customized variant of U-Boot from [their GitHub repository](https://github.com/TechNexion/u-boot-tn-imx)
	- 3-uboot-prepare
	- 3-uboot-compile
- 4-nxp-mkimg - packages U-Boot and the firmware in a firmware package
- 5-nxp-uuu - downloads a variant of Universal Update Utility customized by NXP [off their repository](https://github.com/nxp-imx/mfgtools) and compiles it.
- boot-u - used for only booting U-Boot
- 6-linux - downloads, configures and compiles the Linux kernel
	- 6-linux-prepare
	- 6-linux-compile
- 7-buildroot - downloads, configures and makes a Linux root filesystem using Buildroot
	- 7-buildroot-prepare
	- 7-buildroot-compile
- 8-fit - creates the Flattened Image Tree image
- 9-diskimg - creates the disk image
- boot-linux - boots U-Boot and then Linux, entirely without user interaction