# Ion OS Bootloader - UEFI Build Rules

# Toolchain
CC       = gcc
LD       = ld
OBJCOPY  = objcopy

# Architecture
ARCH     = x86_64

# gnu-efi paths (system installation)
EFI_INC      = /usr/include/efi
EFI_INC_ARCH = /usr/include/efi/$(ARCH)
EFI_LIB      = /usr/lib
EFI_CRT      = $(EFI_LIB)/crt0-efi-$(ARCH).o
EFI_LDS      = $(EFI_LIB)/elf_$(ARCH)_efi.lds

# Compiler flags
CFLAGS = -ffreestanding \
         -fno-stack-protector \
         -fno-stack-check \
         -fpic \
         -fshort-wchar \
         -mno-red-zone \
         -maccumulate-outgoing-args \
         -Wall -Wextra \
         -DGNU_EFI_USE_MS_ABI \
         -I$(EFI_INC) \
         -I$(EFI_INC_ARCH) \
         -I. \
         -std=gnu11 \
         -O2

# Linker flags
LDFLAGS = -nostdlib \
          -shared \
          -Bsymbolic \
          -T $(EFI_LDS) \
          -L $(EFI_LIB) \
          $(EFI_CRT)

# Libraries (order matters)
LIBS = -lefi -lgnuefi

# objcopy sections to keep
OBJCOPY_SECTIONS = -j .text \
                   -j .sdata \
                   -j .data \
                   -j .dynamic \
                   -j .rodata \
                   -j .dynsym \
                   -j .rel \
                   -j .rela \
                   -j .rel.* \
                   -j .rela.* \
                   -j .reloc \
                   -j .eh_frame

# Source files
SRCS = main.c console.c loader.c linux.c memory.c
OBJS = $(SRCS:.c=.o)

# Output
TARGET     = bootx64
ELF_TARGET = $(TARGET).so
EFI_TARGET = $(TARGET).efi

.PHONY: all clean

all: $(EFI_TARGET)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

$(ELF_TARGET): $(OBJS)
	$(LD) $(LDFLAGS) $(OBJS) -o $@ $(LIBS)

$(EFI_TARGET): $(ELF_TARGET)
	$(OBJCOPY) $(OBJCOPY_SECTIONS) --input-target=elf64-x86-64 --output-target=pei-x86-64 --subsystem=10 $< $@

clean:
	rm -f $(OBJS) $(ELF_TARGET) $(EFI_TARGET)
