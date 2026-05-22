BUILD_DIR := build

CC      ?= gcc -m32
LD      ?= ld -32
OBJCOPY ?= objcopy
NASM    ?= nasm
QEMU    ?= qemu-system-i386

CFLAGS := \
	-std=gnu11 \
	-ffreestanding \
	-Wall \
	-Wextra \
	-m32 \
	-fno-pic \
	-fno-pie \
	-fno-stack-protector \
	-fno-builtin \
	-fno-unwind-tables \
	-fno-asynchronous-unwind-tables \
	-nostdlib \
	-nostartfiles \
	-nodefaultlibs

.PHONY: all run clean

all: $(BUILD_DIR)/os-image.bin

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/kernel.o: kernel.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -g3 -ggdb3 -c $< -o $@

$(BUILD_DIR)/kernel.elf: $(BUILD_DIR)/kernel.o linker.ld
	$(LD) -m elf_i386 -T linker.ld -o $@ $(BUILD_DIR)/kernel.o

$(BUILD_DIR)/kernel.bin: $(BUILD_DIR)/kernel.elf
	$(OBJCOPY) -O binary $< $@

$(BUILD_DIR)/boot.bin: boot.asm $(BUILD_DIR)/kernel.bin
	@sectors=$$(( ( $$(wc -c < $(BUILD_DIR)/kernel.bin) + 511 ) / 512 )); \
	echo "Kernel sectors: $$sectors"; \
	$(NASM) -f bin -D"KERNEL_SECTORS=$$sectors" $< -o $@

$(BUILD_DIR)/kernel.padded.bin: $(BUILD_DIR)/kernel.bin
	cp $< $@
	truncate -s $$(( ( $$(wc -c < $<) + 511 ) / 512 * 512 )) $@

$(BUILD_DIR)/os-image.bin: $(BUILD_DIR)/boot.bin $(BUILD_DIR)/kernel.padded.bin
	cat $(BUILD_DIR)/boot.bin $(BUILD_DIR)/kernel.padded.bin > $@

run: $(BUILD_DIR)/os-image.bin
	$(QEMU) -drive format=raw,file=$<

clean:
	rm -rf $(BUILD_DIR)/
