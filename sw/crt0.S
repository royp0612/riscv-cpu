    .section .text.init
    .globl _start
_start:
    li   sp, 0x1000      # stack at the top of data memory (1024 words = 4 KB)
    call main
1:  j    1b              # if main ever returns, loop here forever