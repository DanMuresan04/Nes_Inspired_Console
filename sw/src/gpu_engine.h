/**
 * @file gpu_engine.h
 * @brief Game Programmer's Interface for the Custom FPGA GPU.
 * 
 * COORDINATE SYSTEM: 320x240 (Logical)
 * - X: 0 (Left) to 319 (Right)
 * - Y: 0 (Top) to 239 (Bottom)
 */

#ifndef GPU_ENGINE_H
#define GPU_ENGINE_H

#include <stdint.h>
#include <stdbool.h>
#include "xparameters.h"

// Hardware Base Address
#define GPU_BASE_ADDR      XPAR_AXI_LITE_SLAVE_0_BASEADDR

// --- Memory Map Offsets ---
#define REG_COLLISION_LO   (GPU_BASE_ADDR + 0x00) // Collision state for slots 0-31
#define REG_COLLISION_HI   (GPU_BASE_ADDR + 0x04) // Collision state for slots 32-63
#define REG_CAMERA_SCROLL  (GPU_BASE_ADDR + 0x08) // Viewport Offset X/Y
#define REG_INPUT_KEYS     (GPU_BASE_ADDR + 0x0C) // 8-bit Controller Mask
#define REG_PPU_STATUS     (GPU_BASE_ADDR + 0x10) // Bit 0 = VSYNC active

// --- Hardware Internal (Used by the engine implementation) ---
#define GPU_DATA_REG       (GPU_BASE_ADDR + 0x14) // Pixel Data unpacker
#define GPU_CTRL_REG       (GPU_BASE_ADDR + 0x18) // CPU/GPU Memory MUX
#define OAM_BASE_ADDR      (GPU_BASE_ADDR + 0x100)// Sprite Attribute Memory
#define HUD_BASE_ADDR      (GPU_BASE_ADDR + 0x200)// Heads-up Display RAM
#define VRAM_BASE_ADDR     (GPU_BASE_ADDR + 0x800)// Tilemap RAM
#define HUD_STRIDE         64

// --- HUD / OSD Functions ---
/** @brief Resets the HUD memory to an empty state. */
void hud_init(); 
/** @brief Clears all characters from the HUD overlay. */
void clear_hud();
/** @brief Prints a string to a specific row/column on the HUD. max 64 characters wide. */
void print_hud(int x_col, int y_row, const char* str);
/** @brief Prints a formatted integer to the HUD with leading zeros if specified. */
void hud_print_int(int x_col, int y_row, int value, int digits);

// --- System & Frame Timing ---

/**
 * @brief Halts CPU execution until the VGA beam enters the V-Blank period.
 * IMPORTANT: Call this exactly once at the end of every frame to maintain 60FPS
 * and prevent "tearing" or flickering in your graphics.
 */
void wait_for_vsync();

/**
 * @brief Fills the 64x32 background grid with a single tile ID.
 * @param background_tile_id The tile to use (0 is usually empty/sky).
 */
void clear_screen(uint8_t background_tile_id);

/**
 * @brief Hides all 64 sprites. Best used at game startup or level transitions.
 */
void clear_all_sprites();


// --- Graphics Functions ---

/**
 * @brief Places a background tile in the world grid.
 * Grid size is 64x32 (double-width for scrolling).
 * @param grid_x Column index (0 to 63)
 * @param grid_y Row index (0 to 31)
 * @param tile_id Graphic ID from the Atlas
 */
void set_bg_tile(int grid_x, int grid_y, uint8_t tile_id);

/**
 * @brief Confugures one of the 64 hardware sprites.
 * @param slot The sprite slot (0 to 63). 
 *        NOTE: Slot 0 has the highest priority and is drawn ON TOP of all others.
 *        Slot 0 is also the "reference" for the hardware collision detection system.
 * @param enabled Set to true to show, false to hide.
 * @param screen_x X coordinate (0-319).
 * @param screen_y Y coordinate (0-239).
 * @param flip_x  Set to true to mirrored the graphic horizontally.
 * @param tile_id Graphic ID from the Atlas.
 */
void set_sprite(uint8_t slot, bool enabled, int screen_x, int screen_y, bool flip_x, uint8_t tile_id);

/**
 * @brief Scrolls the background viewport.
 * @param scroll_x X-offset in pixels.
 * @param scroll_y Y-offset in pixels.
 */
void set_camera_scroll(uint16_t scroll_x, uint16_t scroll_y);


// --- Game Logic Helpers ---

/**
 * @brief Checks if any sprite is touching Slot 0.
 * Uses hardware-accelerated bounding box checks performed during rendering.
 * @return A 64-bit mask where bit N is 1 if Slot N is touching Slot 0.
 */
uint64_t get_hardware_collisions();

/**
 * @brief Reads the status of the controller buttons.
 * Bit mapping: [Start, Select, A, B, Up, Down, Left, Right]
 * @return An 8-bit mask of active buttons.
 */
uint8_t get_input_state();

#endif // GPU_ENGINE_H

