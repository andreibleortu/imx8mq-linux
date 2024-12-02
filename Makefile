ifndef CROSS_COMPILE
	# add cross-compiler here, if not already present
    CROSS_COMPILE := 
    export CROSS_COMPILE
endif

CONCURRENCY = $(shell nproc --all)
PWD = $(shell pwd)

# Platform-specific parameters
ATF_MODEL = imx8mq

NXP_FW_FILES = firmware/ddr/synopsys/lpddr4_pmu_train_{1,2}d_{d,i}mem.bin firmware/hdmi/cadence/signed_hdmi_imx8m.bin

UBOOT_MODEL = pico-imx8mq
UBOOT_DTB = imx8mq-pico-pi.dtb
# Alter to your wishes
UBOOT_GADG_MFR = 2024ASS

NXP_MKIMG_MODEL = iMX8M

LINUX_MFR = freescale
LINUX_DTB = imx8mq-pico-pi.dtb

BUILDROOT_MODEL = imx8mqevk
BUILDROOT_ROOT_PASSWD = imx8m

TN_UUU_TYPE = pico
TN_UUU_MODEL = imx8mq

# assumed FDT is at most 256 KB
FDT_LOAD_ADDR = 0x40000000
# assumed initrd is at most 256 MB
INITRD_LOAD_ADDR = 0x40040000
KERNEL_LOAD_ADDR = 0x50040000

# Prepare dependencies
CONFIGS_DIR = 0-config
CONFIGS_PATH = $(shell realpath $(CONFIGS_DIR))
$(CONFIGS_DIR):
	sudo apt install build-essential libusb-1.0-0-dev libbz2-dev \
	libzstd-dev pkg-config cmake libssl-dev g++ zlib1g-dev \
	libtinyxml2-dev libzip-dev unzip bison flex


# Trusted Firmware-A (BL31)
ATF_DIR = 1-atf
ATF_MAKE_FLAGS = SPD=none PLAT=$(ATF_MODEL)

# Add stamp files for each stage
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

$(ATF_DIR): $(ATF_STAMP)
$(ATF_STAMP):
	if [ ! -d $(ATF_DIR) ]; then \
		git clone https://github.com/nxp-imx/imx-atf --branch lf_v2.6 && \
		mv imx-atf $(ATF_DIR); \
	fi
	cd "$(ATF_DIR)" && \
	make $(ATF_MAKE_FLAGS) -j $(CONCURRENCY)
	touch $(ATF_STAMP)
	
# NXP i.MX Firmware (BL2)
NXP_FW_DIR = 2-nxp-fw
NXP_FW_VER = firmware-imx-8.9
# Firmware version to download

$(NXP_FW_DIR): $(NXP_FW_STAMP)
$(NXP_FW_STAMP):
	if [ ! -d $(NXP_FW_DIR) ]; then \
		wget -O $(NXP_FW_VER).bin http://sources.buildroot.net/firmware-imx/$(NXP_FW_VER).bin && \
		chmod +x ./$(NXP_FW_VER).bin && \
		./$(NXP_FW_VER).bin --auto-accept && \
		rm $(NXP_FW_VER).bin && \
		mv $(NXP_FW_VER) $(NXP_FW_DIR); \
	fi
	touch $(NXP_FW_STAMP)
	# auto-accept EULA

# TechNexion Customized U-Boot
UBOOT_DIR = 3-uboot
# UBOOT_DEFAULT_ENV_FILE = uboot-default.env
$(UBOOT_DIR)-prepare: $(UBOOT_PREPARE_STAMP)
$(UBOOT_PREPARE_STAMP):
	if [ ! -d $(UBOOT_DIR) ]; then \
		git clone https://github.com/TechNexion/u-boot-tn-imx --branch tn-imx_v2023.04_6.1.55_2.2.0-stable && \
		mv u-boot-tn-imx $(UBOOT_DIR); \
	fi

	cd $(UBOOT_DIR) && \
	rm -f /spl/u-boot-spl.bin u-boot-nodtb.bin && \
	make $(UBOOT_MODEL)_defconfig -j $(CONCURRENCY) && \
	cp -f $(CONFIGS_PATH)/uboot-extra.config $(CONFIGS_PATH)/uboot-default.env . && \
	sed -i 's/UBOOT_GADG_MFR/$(UBOOT_GADG_MFR)/' uboot-extra.config && \
	scripts/kconfig/merge_config.sh ".config" "uboot-extra.config"
	touch $(UBOOT_PREPARE_STAMP)

$(UBOOT_DIR)-compile: $(UBOOT_COMPILE_STAMP)
$(UBOOT_COMPILE_STAMP):
	cd $(UBOOT_DIR) && \
	make -j $(CONCURRENCY)
	touch $(UBOOT_COMPILE_STAMP)

# Package U-Boot and the firmware
NXP_MKIMG_DIR = 4-nxp-mkimg
NXP_EXPANDED_FW_FILES = $(shell echo $(NXP_FW_FILES))
$(NXP_MKIMG_DIR): $(NXP_MKIMG_STAMP)
$(NXP_MKIMG_STAMP):
	if [ ! -d $(NXP_MKIMG_DIR) ]; then \
		git clone https://github.com/nxp-imx/imx-mkimage/ --branch lf-5.15.32_2.0.0 && \
		mv imx-mkimage $(NXP_MKIMG_DIR); \
	fi

	# Copy NXP firmware blobs
	cd $(NXP_FW_DIR) && \
	bash -c 'cp -f $(NXP_FW_FILES) $(PWD)/$(NXP_MKIMG_DIR)/$(NXP_MKIMG_MODEL)/'

	# copy BL31, BL2, BL33, the DTB and uboot's mkimage
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
	make flash_evk SOC=$(NXP_MKIMG_MODEL) dtbs=$(UBOOT_DTB) -j $(CONCURRENCY)
	touch $(NXP_MKIMG_STAMP)

# Boot only U-Boot
NXP_UUU_DIR = 5-nxp-uuu

$(NXP_UUU_DIR): $(NXP_UUU_STAMP)
$(NXP_UUU_STAMP):
	if [ ! -d $(NXP_UUU_DIR) ]; then \
		git clone https://github.com/nxp-imx/mfgtools && \
		mv mfgtools $(NXP_UUU_DIR); \
	fi

	# Compile NXP's UUU
	cd $(NXP_UUU_DIR) && \
	mkdir build && \
	cd build && \
	cmake .. && \
	make -j $(CONCURRENCY)
	touch $(NXP_UUU_STAMP)

BOOT_U = boot-u
$(BOOT_U):
	cd $(NXP_UUU_DIR) && \
	sudo build/uuu/uuu -b spl ../$(NXP_MKIMG_DIR)/$(NXP_MKIMG_MODEL)/flash.bin

# Compile, configure and build Linux
LINUX_DIR = 6-linux
LINUX_POWER_PATCH = $(CONFIGS_PATH)/linux-imx8mq-power.patch
ARCH = arm64
export ARCH

$(LINUX_DIR)-prepare: $(LINUX_PREPARE_STAMP)
$(LINUX_PREPARE_STAMP):
	if [ ! -d $(LINUX_DIR) ]; then \
		git clone https://github.com/torvalds/linux/ --branch v6.6 --single-branch && \
		mv linux $(LINUX_DIR); \
	fi
	
	cd $(LINUX_DIR) && \
	make defconfig -j $(CONCURRENCY) && \
	cp -f $(CONFIGS_PATH)/linux-extra.config . && \
	scripts/kconfig/merge_config.sh ".config" "linux-extra.config" && \
	if ! patch -R -p1 -s -f --dry-run < "$(LINUX_POWER_PATCH)"; then \
			patch -p1 < "$(LINUX_POWER_PATCH)" ; \
	fi
	touch $(LINUX_PREPARE_STAMP)

$(LINUX_DIR)-compile: $(LINUX_COMPILE_STAMP)
$(LINUX_COMPILE_STAMP):
	cd $(LINUX_DIR) && \
	make -j $(CONCURRENCY)
	touch $(LINUX_COMPILE_STAMP)


# Compile, configure and build Buildroot
BUILDROOT_DIR = 7-buildroot
BUILDROOT_ROOT_PASSWD_ESCAPED=$(shell printf '%s\n' "$(BUILDROOT_ROOT_PASSWD)" | sed -e 's/[\/&]/\\&/g')

$(BUILDROOT_DIR)-prepare: $(BUILDROOT_PREPARE_STAMP)
$(BUILDROOT_PREPARE_STAMP):
	if [ ! -d $(BUILDROOT_DIR) ]; then \
		git clone https://github.com/buildroot/buildroot/ --branch 2024.05.1 && \
		mv buildroot $(BUILDROOT_DIR); \
	fi

	cd $(BUILDROOT_DIR) && \
	make $(BUILDROOT_MODEL)_defconfig -j $(CONCURRENCY) && \
	cp -f $(CONFIGS_PATH)/buildroot-extra.config . && \
	sed -i -E 's/BR2_TARGET_GENERIC_ROOT_PASSWD="placeholder"/BR2_TARGET_GENERIC_ROOT_PASSWD="$(BUILDROOT_ROOT_PASSWD_ESCAPED)"/' buildroot-extra.config && \
	support/kconfig/merge_config.sh ".config" "buildroot-extra.config"
	# Praying that works
	touch $(BUILDROOT_PREPARE_STAMP)

$(BUILDROOT_DIR)-compile: $(BUILDROOT_COMPILE_STAMP)
$(BUILDROOT_COMPILE_STAMP):
	cd $(BUILDROOT_DIR) && \
	make -j $(CONCURRENCY)
	touch $(BUILDROOT_COMPILE_STAMP)

# Create the Flattened Image Tree image
FIT_DIR = 8-fit
LINUX_DTB_PATH = $(LINUX_MFR)/$(LINUX_DTB)

$(FIT_DIR): $(FIT_STAMP)
$(FIT_STAMP):
	if [ ! -d $(FIT_DIR) ]; then \
			mkdir $(FIT_DIR); \
	fi
	
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
	touch $(FIT_STAMP)

# Create the diskimage
DISKIMG_DIR = 9-diskimg
$(DISKIMG_DIR): $(DISKIMG_STAMP)
$(DISKIMG_STAMP):
	if [ ! -d $(DISKIMG_DIR) ]; then \
			mkdir $(DISKIMG_DIR); \
	fi

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
	touch $(DISKIMG_STAMP)

BOOT_LINUX = boot-linux
SERIAL_DEVICE = /dev/ttyUSB0
$(BOOT_LINUX):
	@make boot-u
	sleep 10
	@sudo bash -c 'echo -e "\x03" > $(SERIAL_DEVICE)'
	@sudo bash -c 'printf "\nums mmc 0\n\n" > $(SERIAL_DEVICE)'
	sleep 10
	fdisk_output=$$(sudo fdisk -l) && \
	device_line=$$(echo "$$fdisk_output" | grep -B1 "UMS disk 0" | grep "^Disk /dev") && \
	DISK=$$(echo "$$device_line" | sed -n 's/^Disk \(\S*\):.*/\1/p') && \
	sleep 2 && \
	umount $${DISK}1 && \
	sudo dd if=$(DISKIMG_DIR)/disk.img of=$$DISK bs=4k
	@sudo bash -c 'echo -e "\x03" > $(SERIAL_DEVICE)'
	@sudo bash -c 'printf "\nrun linux\n\n" > $(SERIAL_DEVICE)'
	@echo "Linux startup sequence has finished."
	@read -r -p "Want to launch sudo picocom -b 115200 $(SERIAL_DEVICE)? [y/N] " response; \
	if [ "$${response}" = "y" ] || [ "$${response}" = "Y" ] || [ "$${response}" = "yes" ] || [ "$${response}" = "YES" ]; then \
		sudo picocom -b 115200 $(SERIAL_DEVICE); \
	fi


	
list:
	@echo $(TARGETS)

TARGETS := $(CONFIGS_DIR) $(ATF_STAMP) $(NXP_FW_STAMP) $(UBOOT_PREPARE_STAMP) $(UBOOT_COMPILE_STAMP) $(NXP_MKIMG_STAMP) $(NXP_UUU_STAMP) $(LINUX_PREPARE_STAMP) $(LINUX_COMPILE_STAMP) $(BUILDROOT_PREPARE_STAMP) $(BUILDROOT_COMPILE_STAMP) $(FIT_STAMP) $(DISKIMG_STAMP)

all: $(TARGETS)

.PHONY: all $(CONFIGS_DIR) $(ATF_STAMP) $(NXP_FW_STAMP) $(UBOOT_PREPARE_STAMP) $(UBOOT_COMPILE_STAMP) $(NXP_MKIMG_STAMP) $(NXP_UUU_STAMP) $(LINUX_PREPARE_STAMP) $(LINUX_COMPILE_STAMP) $(BUILDROOT_PREPARE_STAMP) $(BUILDROOT_COMPILE_STAMP) $(FIT_STAMP) $(DISKIMG_STAMP) $(BOOT_U) $(BOOT_LINUX) list
