/* =============================================================================
 * File: game_main.c
 * Project: RetroPlay VGA Gaming SoC
 * Description: Bare-metal C Game Engine & Hardware Subsystem Driver
 * ============================================================================= */

#include <stdint.h>

// Memory Mapped I/O Registers
#define SRAM_BASE        0x10000000
#define VRAM_BASE        0x20000000
#define SPRITE_BASE      0x30000000
#define AUDIO_BASE       0x40000000
#define GAMEPAD_BASE     0x50000000
#define UART_BASE        0x60000000

#define REG32(addr)      (*((volatile uint32_t *)(addr)))
#define REG8(addr)       (*((volatile uint8_t *)(addr)))

// UART Registers
#define UART_TX          REG32(UART_BASE + 0x00)
#define UART_STATUS      REG32(UART_BASE + 0x04)

// Gamepad Registers
#define GAMEPAD_BTNS     REG32(GAMEPAD_BASE + 0x00)

// Audio Registers
#define AUDIO_CH1_FREQ   REG32(AUDIO_BASE + 0x00)
#define AUDIO_CH2_FREQ   REG32(AUDIO_BASE + 0x04)

// Sprite Registers (Each sprite has 4 words: [0] X, [1] Y, [2] Color, [3] Enable)
#define SPRITE_X(n)      REG32(SPRITE_BASE + ((n) * 16) + 0x00)
#define SPRITE_Y(n)      REG32(SPRITE_BASE + ((n) * 16) + 0x04)
#define SPRITE_COLOR(n)  REG32(SPRITE_BASE + ((n) * 16) + 0x08)
#define SPRITE_ENABLE(n) REG32(SPRITE_BASE + ((n) * 16) + 0x0C)

void uart_putc(char c) {
    while (UART_STATUS & 0x01); // Wait while TX busy
    UART_TX = (uint32_t)c;
}

void uart_puts(const char *s) {
    while (*s) {
        uart_putc(*s++);
    }
}

void init_vram(void) {
    // Fill 80x60 screen with border tiles
    for (int y = 0; y < 60; y++) {
        for (int x = 0; x < 80; x++) {
            uint32_t offset = y * 80 + x;
            if (y == 0 || y == 59 || x == 0 || x == 79) {
                REG8(VRAM_BASE + offset) = 0x01; // Border tile
            } else {
                REG8(VRAM_BASE + offset) = 0x00; // Background tile
            }
        }
    }
}

void init_audio(void) {
    // Setup 440 Hz square wave on Channel 1
    AUDIO_CH1_FREQ = 1136; // 100MHz / (2 * 440) / 100
    // Setup harmony tone on Channel 2 (554 Hz C#5)
    AUDIO_CH2_FREQ = 902;
}

int main(void) {
    uart_puts("\r\n[RetroPlay SoC] Boot Sequence Initialized...\r\n");

    // Step 1: Initialize VRAM
    init_vram();
    uart_puts("[RetroPlay SoC] VRAM Tilemap Formatted (80x60).\r\n");

    // Step 2: Initialize Sprites
    // Sprite 0: Player spaceship (Red, 16x16) at (100, 100)
    SPRITE_X(0) = 100;
    SPRITE_Y(0) = 100;
    SPRITE_COLOR(0) = 0xE0; // Red (R3:G3:B2)
    SPRITE_ENABLE(0) = 1;

    // Sprite 1: Alien target (Green, 16x16) at (108, 100) -> Overlap for collision test
    SPRITE_X(1) = 108;
    SPRITE_Y(1) = 100;
    SPRITE_COLOR(1) = 0x1C; // Green
    SPRITE_ENABLE(1) = 1;

    uart_puts("[RetroPlay SoC] Sprites 0 & 1 Spawned with Hardware Collision Detection.\r\n");

    // Step 3: Initialize Chiptune Synthesizer
    init_audio();
    uart_puts("[RetroPlay SoC] Chiptune Audio Engine Playing Dual-Tone Fanfare.\r\n");

    // Step 4: Game Loop Read Gamepad
    uint32_t btns = GAMEPAD_BTNS;
    uart_puts("[RetroPlay SoC] System Online. Ready for Player Input.\r\n");

    while (1) {
        // Run main loop
        for (volatile int d = 0; d < 1000; d++);
    }

    return 0;
}
