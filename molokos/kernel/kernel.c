
typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int size_t;

#define VGA_WIDTH  80
#define VGA_HEIGHT 25

static volatile uint16_t* const VGA_MEMORY = (uint16_t*)0xB8000;

static size_t row = 0;
static size_t col = 0;
static uint8_t color = 0x0F; // white on black

static uint16_t vga_entry(char c, uint8_t attr) {
    return (uint16_t)c | ((uint16_t)attr << 8);
}

static void clear_screen(void) {
    for (size_t y = 0; y < VGA_HEIGHT; y++) {
        for (size_t x = 0; x < VGA_WIDTH; x++) {
            VGA_MEMORY[y * VGA_WIDTH + x] = vga_entry(' ', color);
        }
    }

    row = 0;
    col = 0;
}

static void putchar(char c) {
    if (c == '\n') {
        col = 0;
        row++;
    } else {
        VGA_MEMORY[row * VGA_WIDTH + col] = vga_entry(c, color);
        col++;

        if (col >= VGA_WIDTH) {
            col = 0;
            row++;
        }
    }

    if (row >= VGA_HEIGHT) {
        row = 0;
    }
}

void puts(const char* s) {
    while (*s) {
        putchar(*s++);
    }

    putchar('\n');
}

void kmain(void) {
    clear_screen();
    puts("Hello from kernel.c!");
    while(10);
    puts("Now running in 32-bit Protected Mode.");
    puts("Loaded by a tiny MBR bootloader.");

    for (;;) {
        __asm__ volatile ("hlt");
    }
}

__attribute__((section(".text.start"), used))
void _start(void) {
    kmain();

    for (;;) {
        __asm__ volatile ("hlt");
    }
}