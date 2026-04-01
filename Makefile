# Ion OS - Top-Level Build

.PHONY: all clean boot disk run

all: boot

boot:
	$(MAKE) -C boot

disk: boot
	./scripts/mkdisk.sh

run: disk
	./scripts/run-qemu.sh

clean:
	$(MAKE) -C boot clean
	rm -f ion-os.img
