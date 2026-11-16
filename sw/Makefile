CC      = riscv64-unknown-elf-gcc
OBJCOPY = riscv64-unknown-elf-objcopy
OBJDUMP = riscv64-unknown-elf-objdump
CFLAGS  = -march=rv32i -mabi=ilp32 -O1 -ffreestanding -nostdlib -Wl,--no-relax -T link.ld

prog.hex: prog.bin
	python3 bin2hex.py prog.bin > prog.hex

prog.bin: prog.elf
	$(OBJCOPY) -O binary prog.elf prog.bin

prog.elf: crt0.S main.c link.ld
	$(CC) $(CFLAGS) crt0.S main.c -o prog.elf

dump: prog.elf
	$(OBJDUMP) -d prog.elf

clean:
	rm -f prog.elf prog.bin prog.hex