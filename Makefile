# Ion OS - Top-Level Build

.PHONY: all clean boot boot-iso initramfs rootfs squashfs disk iso run run-iso

BUILD_DIR = build
KERNEL   ?= /home/mattmoore/source/torvalds/linux/arch/x86/boot/bzImage

all: disk

boot:
	$(MAKE) -C boot

boot-iso:
	$(MAKE) -C boot iso

initramfs:
	KERNEL=$(KERNEL) ./scripts/mk-initramfs.sh

rootfs:
	KERNEL=$(KERNEL) ./scripts/mk-rootfs.sh

squashfs: rootfs
	./scripts/mk-squashfs.sh

disk: boot initramfs rootfs
	sudo ./scripts/mkdisk.sh \
		--kernel $(KERNEL) \
		--initrd $(BUILD_DIR)/initramfs.img \
		--rootfs $(BUILD_DIR)/rootfs

iso: boot-iso initramfs squashfs
	./scripts/mkiso.sh \
		--efi boot/bootx64-iso.efi \
		--kernel $(KERNEL) \
		--initrd $(BUILD_DIR)/initramfs.img \
		--squashfs $(BUILD_DIR)/rootfs.squashfs

run: disk
	./scripts/run-qemu.sh

run-iso: iso
	./scripts/run-qemu-iso.sh

clean:
	$(MAKE) -C boot clean
	sudo rm -rf $(BUILD_DIR) || rm -rf $(BUILD_DIR)
	rm -f ion-os.img ion-os.iso
