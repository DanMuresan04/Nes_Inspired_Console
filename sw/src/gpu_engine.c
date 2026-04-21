#include "gpu_engine.h"
#include "xil_io.h"

// Internal ASCII to Font ROM Index decoder
static uint8_t ascii_to_hud_index(char c) {
    if (c >= '0' && c <= '9') return (c - '0') + 1;
    if (c >= 'A' && c <= 'Z') return (c - 'A') + 11;
    if (c >= 'a' && c <= 'z') return (c - 'a') + 11;
    if (c == '-') return 41; 
    return 0; 
}

void hud_init() {
    clear_hud();
    
    // Headers on Row 1 (Safe from top overscan)
    print_hud(2,  1, "SCORE");
    print_hud(10, 1, "COINS");
    print_hud(18, 1, "WORLD");
    print_hud(26, 1, "TIME");
    print_hud(33, 1, "LIVES");

    // Initial Values on Row 2
    hud_print_int(2,  2, 0, 6);    // Score: 000000
    hud_print_int(11, 2, 0, 2);    // Coins: 00
    print_hud(19, 2, "1-1");       // World
    hud_print_int(26, 2, 398, 3);  // Time
    hud_print_int(34, 2, 3, 2);    // Lives: 03
}

void clear_hud() {
    for (int i = 0; i < 256; i++) {
        Xil_Out32(HUD_BASE_ADDR + (i * 4), 0);
    }
}

void print_hud(int x_col, int y_row, const char* str) {
    int i = 0;
    while (str[i] != '\0' && (x_col + i) < 64) {
        uint32_t ram_index = (y_row * HUD_STRIDE) + (x_col + i);
        Xil_Out32(HUD_BASE_ADDR + (ram_index * 4), ascii_to_hud_index(str[i]));
        i++;
    }
}

void hud_print_int(int x_col, int y_row, int value, int digits) {
    char buf[12];
    buf[digits] = '\0';
    for (int i = digits - 1; i >= 0; i--) {
        buf[i] = (value % 10) + '0';
        value /= 10;
    }
    print_hud(x_col, y_row, buf);
}

void wait_for_vsync() {
    while ((Xil_In32(REG_PPU_STATUS) & 0x01) == 0);
    while ((Xil_In32(REG_PPU_STATUS) & 0x01) == 1);
}

void clear_screen(uint8_t background_tile_id) {
    for (int i = 0; i < 2048; i++) Xil_Out8(VRAM_BASE_ADDR + i, background_tile_id);
}

void clear_all_sprites() {
    for (int i = 0; i < 64; i++) Xil_Out32(OAM_BASE_ADDR + (i * 4), 0);
}

void set_bg_tile(int grid_x, int grid_y, uint8_t tile_id) {
    if (grid_x < 0 || grid_x > 63 || grid_y < 0 || grid_y > 31) return;
    Xil_Out8(VRAM_BASE_ADDR + (grid_y * 64) + grid_x, tile_id);
}

void set_sprite(uint8_t slot, bool enabled, int screen_x, int screen_y, bool flip_x, uint8_t tile_id) {
    if (slot > 63) return;
    uint32_t packed_data = (enabled ? (1U << 31) : 0) | ((screen_x & 0x3FF) << 19) | 
                           ((screen_y & 0x3FF) << 9) | (flip_x ? (1U << 8) : 0) | (tile_id & 0xFF);
    Xil_Out32(OAM_BASE_ADDR + (slot * 4), packed_data);
}

void set_camera_scroll(uint16_t scroll_x, uint16_t scroll_y) {
    Xil_Out32(REG_CAMERA_SCROLL, ((uint32_t)scroll_y << 16) | scroll_x);
}

uint64_t get_hardware_collisions() {
    return ((uint64_t)Xil_In32(REG_COLLISION_HI) << 32) | Xil_In32(REG_COLLISION_LO);
}

uint8_t get_input_state() {
    return (uint8_t)(Xil_In32(REG_INPUT_KEYS) & 0xFF);
}