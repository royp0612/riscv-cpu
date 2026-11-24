#include "uart.h"
#define LEDS     (*(volatile unsigned int *)0x1000000C)
#define SWITCHES (*(volatile unsigned int *)0x10000010)
volatile unsigned int boot_value = 42;
volatile unsigned int counter;
int main(void) {
    if (boot_value != 42 || counter != 0) {
        uart_puts("STARTUP FAIL\r\n");
        for (;;) {}
    }

    boot_value = 99;
    counter = 17;
    while (1) {
        uart_puts("Hi\r\n");
        LEDS = ~SWITCHES;
    }
}
