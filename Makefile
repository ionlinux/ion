# Ion OS - Top-Level Build

.PHONY: all clean boot busybox initramfs rootfs disk run

BUILD_DIR = build
KERNEL   ?= /home/mattmoore/source/torvalds/linux/arch/x86/boot/bzImage

all: disk

boot:
	$(MAKE) -C boot

busybox:
	./scripts/build-busybox.sh

initramfs: busybox
	./scripts/mk-initramfs.sh

rootfs: busybox
	./scripts/mk-rootfs.sh

disk: boot initramfs rootfs
	sudo ./scripts/mkdisk.sh \
		--kernel $(KERNEL) \
		--initrd $(BUILD_DIR)/initramfs.img \
		--rootfs $(BUILD_DIR)/rootfs

run: disk
	./scripts/run-qemu.sh

clean:
	$(MAKE) -C boot clean
	sudo rm -rf $(BUILD_DIR) || rm -rf $(BUILD_DIR)
	rm -f ion-os.img
