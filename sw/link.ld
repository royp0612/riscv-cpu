/* link.ld - tells the linker where things go in memory.
 *
 * Code starts at address 0, where the PC begins after reset.
 * The CPU has separate instruction and data memories, and loads/stores
 * cannot read instruction memory. So for now this script only allows
 * code: if main.c uses globals or string constants, the build stops
 * with a clear error instead of producing a program that silently fails.
 */
OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    /* Must match imem.sv: DEPTH words x 4 bytes. 1024 words = 4K. */
    IMEM (rx) : ORIGIN = 0x00000000, LENGTH = 4K
}

SECTIONS
{
    .text : {
        *(.text.init)      /* crt0.S first, so _start is at address 0 */
        *(.text*)
    } > IMEM               /* build fails if the program is too big */

    /* Anything that would need data memory. Must be empty for now. */
    .data_check (NOLOAD) : {
        *(.rodata*) *(.srodata*)
        *(.data*)   *(.sdata*)
        *(.bss*)    *(.sbss*)  *(COMMON)
    } > IMEM

    ASSERT(SIZEOF(.data_check) == 0,
           "Globals/strings not supported yet: imem and dmem are separate. Use locals only.")

    /DISCARD/ : { *(.eh_frame*) *(.comment) *(.note*) }
}
