#ifndef UART_H
#define UART_H

#define UART_TX   (*(volatile unsigned int *)0x10000014)
#define UART_BUSY (*(volatile unsigned int *)0x10000018)

static inline void uart_putc(char c) {
    while (UART_BUSY & 1u) {
    }
    UART_TX = (unsigned char)c;
}

static inline void uart_puts(const char *text) {
    while (*text != '\0') {
        uart_putc(*text);
        ++text;
    }
}

#endif
