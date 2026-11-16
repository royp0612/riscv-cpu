#define LEDS     (*(volatile unsigned int *)0x1000000C)
#define SWITCHES (*(volatile unsigned int *)0x10000010)

int main(void) {
    while (1) {
        LEDS = ~SWITCHES;
    }
}