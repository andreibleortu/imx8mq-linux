# Check if CROSS_COMPILE is defined, if not, define it and export it
ifndef CROSS_COMPILE
	# Add cross-compiler here, if not already present
	CROSS_COMPILE := 
	export CROSS_COMPILE
endif

# Determine the number of available processors for parallel builds
CONCURRENCY = $(shell nproc --all)
# Get the current working directory
PWD = $(shell pwd)

# Platform-specific parameters
ATF_MODEL = imx8mq
NXP_FW_FILES = firmware/ddr/synopsys/lpddr4_pmu_train_{1,2}d_{d,i}mem.bin firmware/hdmi/cadence/signed_hdmi_imx8m.bin
# U-Boot model, device tree, and USB gadget manufacturer
UBOOT_MODEL = pico-imx8mq
UBOOT_DTB = imx8mq-pico-pi.dtb
UBOOT_GADG_MFR = 2024ASS
# NXP mkimage model
NXP_MKIMG_MODEL = iMX8M
# Linux kernel model and device tree
LINUX_MFR = freescale
LINUX_DTB = imx8mq-pico-pi.dtb
# Buildroot model and root password
BUILDROOT_MODEL = imx8mqevk
BUILDROOT_ROOT_PASSWD = imx8m
# TechNexion UUU model
TN_UUU_TYPE = pico
TN_UUU_MODEL = imx8mq

# Load addresses for various components
# assumed FDT is at most 256 KB
FDT_LOAD_ADDR = 0x40000000
# assumed initrd is at most 256 MB
INITRD_LOAD_ADDR = 0x40040000
KERNEL_LOAD_ADDR = 0x50040000

# Directories for different components
CONFIGS_DIR = 0-config
ATF_DIR = 1-atf
NXP_FW_DIR = 2-nxp-fw
UBOOT_DIR = 3-uboot
NXP_MKIMG_DIR = 4-nxp-mkimg
NXP_UUU_DIR = 5-nxp-uuu
LINUX_DIR = 6-linux
BUILDROOT_DIR = 7-buildroot
FIT_DIR = 8-fit
DISKIMG_DIR = 9-diskimg
CONFIGS_PATH = $(PWD)/$(CONFIGS_DIR)

# Stamps to track the build status of each component
ATF_STAMP = $(ATF_DIR)/.stamp
NXP_FW_STAMP = $(NXP_FW_DIR)/.stamp
UBOOT_PREPARE_STAMP = $(UBOOT_DIR)/.prepare_stamp
UBOOT_COMPILE_STAMP = $(UBOOT_DIR)/.compile_stamp
NXP_MKIMG_STAMP = $(NXP_MKIMG_DIR)/.stamp
NXP_UUU_STAMP = $(NXP_UUU_DIR)/.stamp
LINUX_PREPARE_STAMP = $(LINUX_DIR)/.prepare_stamp
LINUX_COMPILE_STAMP = $(LINUX_DIR)/.compile_stamp
BUILDROOT_PREPARE_STAMP = $(BUILDROOT_DIR)/.prepare_stamp
BUILDROOT_COMPILE_STAMP = $(BUILDROOT_DIR)/.compile_stamp
FIT_STAMP = $(FIT_DIR)/.stamp
DISKIMG_STAMP = $(DISKIMG_DIR)/.stamp
	
# Install necessary dependencies
$(CONFIGS_DIR):
	@packages="build-essential libusb-1.0-0-dev libbz2-dev libzstd-dev pkg-config cmake libssl-dev g++ zlib1g-dev libtinyxml2-dev libzip-dev unzip bison flex"; \
	for pkg in $$packages; do \
		if ! dpkg -s $$pkg >/dev/null 2>&1; then \
			missing_packages="$$missing_packages $$pkg"; \
		fi; \
	done; \
	if [ -n "$$missing_packages" ]; then \
		echo "Installing missing packages:$$missing_packages"; \
		sudo apt install -y $$missing_packages; \
	else \
		echo "All packages are already installed. Continuing."; \
	fi

# Build Trusted Firmware-A (BL31)
$(ATF_DIR): $(ATF_STAMP)
$(ATF_STAMP):
	# Clone the ATF repository if the directory does not exist
	if [ ! -d $(ATF_DIR) ]; then \
		git clone https://github.com/nxp-imx/imx-atf --branch lf_v2.6 --single-branch --depth 1 && \
		mv imx-atf $(ATF_DIR); \
	fi
	# Build the ATF
	cd "$(ATF_DIR)" && \
	$(MAKE) SPD=none PLAT=$(ATF_MODEL) -j $(CONCURRENCY)
	# Create a stamp file to indicate that the ATF has been built
	touch $(ATF_STAMP)

# Download and extract NXP i.MX Firmware (BL2)
# firmware version 8.9
NXP_FW_VER = firmware-imx-8.9
$(NXP_FW_DIR): $(NXP_FW_STAMP)
$(NXP_FW_STAMP):
	# Download and extract the firmware if the directory does not exist
	if [ ! -d $(NXP_FW_DIR) ]; then \
		wget -O $(NXP_FW_VER).bin http://sources.buildroot.net/firmware-imx/$(NXP_FW_VER).bin && \
		chmod +x ./$(NXP_FW_VER).bin && \
		./$(NXP_FW_VER).bin --auto-accept && \
		rm $(NXP_FW_VER).bin && \
		mv $(NXP_FW_VER) $(NXP_FW_DIR); \
	fi
	# Create a stamp file to indicate that the firmware has been downloaded and extracted
	touch $(NXP_FW_STAMP)

# Prepare the TechNexion customized U-Boot for compilation
$(UBOOT_DIR)-prepare: $(UBOOT_PREPARE_STAMP)
$(UBOOT_PREPARE_STAMP):
	# Clone the U-Boot repository if the directory does not exist
	if [ ! -d $(UBOOT_DIR) ]; then \
		git clone https://github.com/TechNexion/u-boot-tn-imx --branch tn-imx_v2023.04_6.1.55_2.2.0-stable --single-branch --depth 1 && \
		mv u-boot-tn-imx $(UBOOT_DIR); \
	fi
	# Prepare U-Boot for compilation
	cd $(UBOOT_DIR) && \
	rm -f /spl/u-boot-spl.bin u-boot-nodtb.bin && \
	$(MAKE) $(UBOOT_MODEL)_defconfig -j $(CONCURRENCY) && \
	cp -f $(CONFIGS_PATH)/uboot-extra.config $(CONFIGS_PATH)/uboot-default.env . && \
	sed -i 's/UBOOT_GADG_MFR/$(UBOOT_GADG_MFR)/' uboot-extra.config && \
	scripts/kconfig/merge_config.sh ".config" "uboot-extra.config"
	# Create a stamp file to indicate that U-Boot has been prepared
	touch $(UBOOT_PREPARE_STAMP)

# Compile U-Boot
$(UBOOT_DIR)-compile: $(UBOOT_COMPILE_STAMP)
$(UBOOT_COMPILE_STAMP):
	# Compile U-Boot
	cd $(UBOOT_DIR) && \
	$(MAKE) -j $(CONCURRENCY)
	# Create a stamp file to indicate that U-Boot has been compiled
	touch $(UBOOT_COMPILE_STAMP)

# Package U-Boot and the firmware
NXP_EXPANDED_FW_FILES = $(shell echo $(NXP_FW_FILES))
$(NXP_MKIMG_DIR): $(NXP_MKIMG_STAMP)
$(NXP_MKIMG_STAMP):
	# Clone the imx-mkimage repository if the directory does not exist
	if [ ! -d $(NXP_MKIMG_DIR) ]; then \
		git clone https://github.com/nxp-imx/imx-mkimage/ --branch lf-5.15.32_2.0.0 --single-branch --depth 1 && \
		mv imx-mkimage $(NXP_MKIMG_DIR); \
	fi
	# Copy firmware files to the mkimage directory
	cd $(NXP_FW_DIR) && \
	bash -c 'cp -f $(NXP_FW_FILES) $(PWD)/$(NXP_MKIMG_DIR)/$(NXP_MKIMG_MODEL)/'
	# Package U-Boot and the firmware
	cd $(NXP_MKIMG_DIR)/$(NXP_MKIMG_MODEL) && \
	rm -f flash.bin && \
	cp -f \
		../../$(ATF_DIR)/build/$(ATF_MODEL)/release/bl31.bin \
		../../$(UBOOT_DIR)/spl/u-boot-spl.bin \
		../../$(UBOOT_DIR)/u-boot-nodtb.bin \
		../../$(UBOOT_DIR)/arch/arm/dts/$(UBOOT_DTB) \
		../../$(UBOOT_DIR)/tools/mkimage \
		. && \
	mv -f mkimage mkimage_uboot && \
	cd .. && \
	$(MAKE) flash_evk SOC=$(NXP_MKIMG_MODEL) dtbs=$(UBOOT_DTB) -j $(CONCURRENCY)
	# Create a stamp file to indicate that the mkimage has been created
	touch $(NXP_MKIMG_STAMP)

# Build NXP UUU (Universal Update Utility)
$(NXP_UUU_DIR): $(NXP_UUU_STAMP)
$(NXP_UUU_STAMP):
	# Clone the mfgtools repository if the directory does not exist
	if [ ! -d $(NXP_UUU_DIR) ]; then \
		git clone https://github.com/nxp-imx/mfgtools && \
		mv mfgtools $(NXP_UUU_DIR); \
	fi
	# Build the UUU
	cd $(NXP_UUU_DIR) && \
	mkdir -p build && \
	cd build && \
	cmake .. && \
	$(MAKE) -j $(CONCURRENCY)
	# Create a stamp file to indicate that the UUU has been built
	touch $(NXP_UUU_STAMP)

# Boot only U-Boot
BOOT_U = boot-u
$(BOOT_U):
	# Boot U-Boot using UUU
	cd $(NXP_UUU_DIR) && \
	sudo build/uuu/uuu -b spl ../$(NXP_MKIMG_DIR)/$(NXP_MKIMG_MODEL)/flash.bin

# Prepare Linux kernel for compilation
ARCH = arm64
export ARCH

LINUX_POWER_PATCH = $(CONFIGS_PATH)/linux-imx8mq-power.patch
$(LINUX_DIR)-prepare: $(LINUX_PREPARE_STAMP)
$(LINUX_PREPARE_STAMP):
	# Clone the Linux kernel repository if the directory does not exist
	if [ ! -d $(LINUX_DIR) ]; then \
		git clone https://github.com/torvalds/linux/ --branch v6.6 --single-branch --depth 1 && \
		mv linux $(LINUX_DIR); \
	fi
	# Prepare the Linux kernel for compilation
	cd $(LINUX_DIR) && \
	$(MAKE) defconfig -j $(CONCURRENCY) && \
	cp -f $(CONFIGS_PATH)/linux-extra.config . && \
	scripts/kconfig/merge_config.sh ".config" "linux-extra.config" && \
	if ! patch -R -p1 -s -f --dry-run < "$(LINUX_POWER_PATCH)"; then \
		patch -p1 < "$(LINUX_POWER_PATCH)"; \
	fi
	# Create a stamp file to indicate that the Linux kernel has been prepared
	touch $(LINUX_PREPARE_STAMP)

# Compile Linux kernel
$(LINUX_DIR)-compile: $(LINUX_COMPILE_STAMP)
$(LINUX_COMPILE_STAMP):
	# Compile the Linux kernel
	cd $(LINUX_DIR) && \
	$(MAKE) -j $(CONCURRENCY)
	# Create a stamp file to indicate that the Linux kernel has been compiled
	touch $(LINUX_COMPILE_STAMP)

# Prepare Buildroot for compilation
BUILDROOT_ROOT_PASSWD_ESCAPED=$(shell printf '%s\n' "$(BUILDROOT_ROOT_PASSWD)" | sed -e 's/[\/&]/\\&/g')
$(BUILDROOT_DIR)-prepare: $(BUILDROOT_PREPARE_STAMP)
$(BUILDROOT_PREPARE_STAMP):
	# Clone the Buildroot repository if the directory does not exist
	if [ ! -d $(BUILDROOT_DIR) ]; then \
		git clone https://github.com/buildroot/buildroot/ --branch 2024.05.1 --single-branch --depth 1 && \
		mv buildroot $(BUILDROOT_DIR); \
	fi
	# Prepare Buildroot for compilation
	cd $(BUILDROOT_DIR) && \
	$(MAKE) $(BUILDROOT_MODEL)_defconfig -j $(CONCURRENCY) && \
	cp -f $(CONFIGS_PATH)/buildroot-extra.config . && \
	sed -i -E 's/BR2_TARGET_GENERIC_ROOT_PASSWD="placeholder"/BR2_TARGET_GENERIC_ROOT_PASSWD="$(BUILDROOT_ROOT_PASSWD_ESCAPED)"/' buildroot-extra.config && \
	support/kconfig/merge_config.sh ".config" "buildroot-extra.config"
	# Create a stamp file to indicate that Buildroot has been prepared
	touch $(BUILDROOT_PREPARE_STAMP)

# Compile Buildroot
$(BUILDROOT_DIR)-compile: $(BUILDROOT_COMPILE_STAMP)
$(BUILDROOT_COMPILE_STAMP):
	# Compile Buildroot
	cd $(BUILDROOT_DIR) && \
	$(MAKE) -j $(CONCURRENCY)
	# Create a stamp file to indicate that Buildroot has been compiled
	touch $(BUILDROOT_COMPILE_STAMP)

# Create the Flattened Image Tree (FIT) image
LINUX_DTB_PATH = $(LINUX_MFR)/$(LINUX_DTB)
$(FIT_DIR): $(FIT_STAMP)
$(FIT_STAMP):
	# Create the FIT directory if it does not exist
	if [ ! -d $(FIT_DIR) ]; then \
		mkdir $(FIT_DIR); \
	fi
	# Create the FIT image
	cd $(FIT_DIR) && \
	rm -f linux.itb && \
	cp -f \
		$(CONFIGS_PATH)/linux.its \
		../$(LINUX_DIR)/arch/arm64/boot/Image \
		../$(LINUX_DIR)/arch/arm64/boot/dts/$(LINUX_DTB_PATH) \
		../$(BUILDROOT_DIR)/output/images/rootfs.cpio \
		. && \
	sed -i 's/LINUX_DTB/$(LINUX_DTB)/' linux.its && \
	sed -i 's/FDT_LOAD_ADDR/$(FDT_LOAD_ADDR)/' linux.its && \
	sed -i 's/INITRD_LOAD_ADDR/$(INITRD_LOAD_ADDR)/' linux.its && \
	sed -i 's/KERNEL_LOAD_ADDR/$(KERNEL_LOAD_ADDR)/' linux.its && \
	mkimage -f linux.its linux.itb
	# Create a stamp file to indicate that the FIT image has been created
	touch $(FIT_STAMP)

# Create the disk image
$(DISKIMG_DIR): $(DISKIMG_STAMP)
$(DISKIMG_STAMP):
	# Create the disk image directory if it does not exist
	if [ ! -d $(DISKIMG_DIR) ]; then \
		mkdir $(DISKIMG_DIR); \
	fi
	# Create the disk image
	cd "$(DISKIMG_DIR)" && \
	rm -f disk.img && \
	truncate --size 200M disk.img && \
	(echo o; echo n; echo p; echo 1; echo ""; echo ""; echo w) | fdisk disk.img && \
	DEVICE=$$(sudo partx -a -v disk.img | tail -1 | awk -F':' '{print $$1}') && \
	sudo mkfs.fat -F 32 $${DEVICE}p1 && \
	sudo mkdir /mnt/arm-diskimg && \
	sudo mount $${DEVICE}p1 /mnt/arm-diskimg && \
	sudo cp -f "../$(FIT_DIR)/linux.itb" /mnt/arm-diskimg && \
	sudo umount /mnt/arm-diskimg && \
	sudo rm -r /mnt/arm-diskimg && \
	sudo partx -d $$DEVICE && \
	sudo losetup -D $$DEVICE
	# Create a stamp file to indicate that the disk image has been created
	touch $(DISKIMG_STAMP)

# Boot Linux
BOOT_LINUX = boot-linux
SERIAL_DEVICE = /dev/ttyUSB0
$(BOOT_LINUX):
	# Boot U-Boot using UUU
	@$(MAKE) boot-u
	sleep 10
	# Send a break signal to the serial device
	@sudo bash -c 'echo -e "\x03" > $(SERIAL_DEVICE)'
	# Send commands to the serial device to boot Linux
	@sudo bash -c 'printf "\nums mmc 0\n\n" > $(SERIAL_DEVICE)'
	sleep 10
	# Find the UMS disk and write the disk image to it
	fdisk_output=$$(sudo fdisk -l) && \
	device_line=$$(echo "$$fdisk_output" | grep -B1 "UMS disk 0" | grep "^Disk /dev") && \
	DISK=$$(echo "$$device_line" | sed -n 's/^Disk \(\S*\):.*/\1/p') && \
	sleep 2 && \
	umount $${DISK}1 && \
	sudo dd if=$(DISKIMG_DIR)/disk.img of=$$DISK bs=4k
	# Send a break signal to the serial device
	@sudo bash -c 'echo -e "\x03" > $(SERIAL_DEVICE)'
	# Send commands to the serial device to run Linux
	@sudo bash -c 'printf "\nrun linux\n\n" > $(SERIAL_DEVICE)'
	@echo "Linux startup sequence has finished."
	# Prompt the user to launch picocom
	@read -r -p "Want to launch sudo picocom -b 115200 $(SERIAL_DEVICE)? [y/N] " response; \
	if [ "$${response}" = "y" ] || [ "$${response}" = "Y" ] || [ "$${response}" = "yes" ] || [ "$${response}" = "YES" ]; then \
		sudo picocom -b 115200 $(SERIAL_DEVICE); \
	fi

# List all targets
list:
	@echo $(TARGETS)

# Define all targets
TARGETS := $(CONFIGS_DIR) $(ATF_STAMP) $(NXP_FW_STAMP) $(UBOOT_PREPARE_STAMP) $(UBOOT_COMPILE_STAMP) $(NXP_MKIMG_STAMP) $(NXP_UUU_STAMP) $(LINUX_PREPARE_STAMP) $(LINUX_COMPILE_STAMP) $(BUILDROOT_PREPARE_STAMP) $(BUILDROOT_COMPILE_STAMP) $(FIT_STAMP) $(DISKIMG_STAMP)

# Build all targets
all: $(TARGETS)

# Clean all generated directories
clean-all:
	rm -rf $(ATF_DIR) $(NXP_FW_DIR) $(UBOOT_DIR) $(NXP_MKIMG_DIR) $(NXP_UUU_DIR) $(LINUX_DIR) $(BUILDROOT_DIR) $(FIT_DIR) $(DISKIMG_DIR)

# Declare phony targets
.PHONY: all clean-all $(CONFIGS_DIR) $(ATF_STAMP) $(NXP_FW_STAMP) $(UBOOT_PREPARE_STAMP) $(UBOOT_COMPILE_STAMP) $(NXP_MKIMG_STAMP) $(NXP_UUU_STAMP) $(LINUX_PREPARE_STAMP) $(LINUX_COMPILE_STAMP) $(BUILDROOT_PREPARE_STAMP) $(BUILDROOT_COMPILE_STAMP) $(FIT_STAMP) $(DISKIMG_STAMP) $(BOOT_U) $(BOOT_LINUX) list
