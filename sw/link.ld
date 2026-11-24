/* link.ld - tells the linker where things go in memory.
 *
 * Code starts at address 0, where the PC begins after reset. Read-only
 * data follows the code in the ROM image. The SoC exposes those same
 * ROM offsets to data loads through a read-only window at 0x2000.
 */
OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    /* Must match imem.sv: DEPTH words x 4 bytes. 1024 words = 4K. */
    IMEM (rx) : ORIGIN = 0x00000000, LENGTH = 4K
    ROM_DATA (r) : ORIGIN = 0x00002000, LENGTH = 4K
    RAM (rw) : ORIGIN = 0x00001000, LENGTH = 4k
}

SECTIONS
{
    .text : {
        *(.text.init)      /* crt0.S first, so _start is at address 0 */
        *(.text*)
    } > IMEM               /* build fails if the program is too big */

    __rodata_rom_offset = ALIGN(LOADADDR(.text) + SIZEOF(.text), 4);
    .rodata (ORIGIN(ROM_DATA) + __rodata_rom_offset) : AT(__rodata_rom_offset) {
        *(.rodata*) *(.srodata*)
    } > ROM_DATA

    __data_rom_offset = ALIGN(__rodata_rom_offset + SIZEOF(.rodata), 4);

    .data : AT(__data_rom_offset) {
        __data_start = .;
        *(.data .data.* .sdata .sdata.*)
        . = ALIGN(4);
        __data_end = .;
    } > RAM

    __data_load = ORIGIN(ROM_DATA) + __data_rom_offset;

    .bss (NOLOAD) : {
        . = ALIGN(4);
        __bss_start = .;
        *(.bss .bss.* .sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM

    __stack_top = ORIGIN(RAM) + LENGTH(RAM);

    ASSERT(__data_rom_offset + SIZEOF(.data) <= ORIGIN(IMEM) + LENGTH(IMEM),
        "Code, constants, and data initializers must fit in ROM")

    /DISCARD/ : { *(.eh_frame*) *(.comment) *(.note*) }
}
