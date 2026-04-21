/**
 * @file main.c
 * @brief Top-level system controller and Game Entry Point.
 * 
 * This module coordinates the boot sequence, asset loading across network/SD,
 * and maintains the 60FPS main game loop.
 */

#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include "xil_cache.h"  
#include "gpu_engine.h"
#include "audio_engine.h"

#include "xil_printf.h"
#include "xparameters.h"
#include "xintc.h"
#include "xil_exception.h"
#include "xil_io.h"         

/* ---- FatFs R0.16 ---- */
#include "ff16/source/ff.h"
#include "ff16/source/diskio.h"

/* =========================================================================
 * MULTIPLEXER SWITCH
 * ========================================================================= */
#define DEV_MODE 1  /* 1 = Load via UDP/DMA, 0 = Load via SD Card */

/* In Dev Mode, the PC sends a Config packet (type 0x11) announcing the exact
 * file size before streaming audio.  No hardcoded audio size needed.
 * Graphics still loaded from SD card for now. */
#define UDP_EXPECTED_GRAPHICS_BYTES 65536    // Adjust to your actual atlas size

static FATFS FatFs; 

#define AUDIO_BUF_SIZE  (8U * 1024U * 1024U)   /* 8 Megabytes */
#define GRAPHICS_BUF_SIZE (64 * 1024)          /* 64KB max for NES-style tiles */

static u8 *audio_buf __attribute__ ((aligned (32))) = (u8 *)0x8A000000;
static u8 *graphics_buf __attribute__ ((aligned (32))) = (u8 *)0x89000000;
XIntc GlobalIntc;

/* Game layout constants */
#define LOGICAL_WIDTH       320
#define LOGICAL_HEIGHT      240
#define LOGICAL_TILE_SIZE   16
#define FLOOR_ROW           14
#define FLOOR_Y_START       (FLOOR_ROW * LOGICAL_TILE_SIZE)
#define MARIO_STAND_Y       (FLOOR_Y_START - 16)

/* Sprite Atlas Definitions */
#define TILE_BRICK          1
#define MARIO_ATLAS_BASE    2 
#define ENEMY_ATLAS_BASE    16 

/* AXI DMA MM2S (Transmit) Register Addresses */
#define MM2S_DMACR   (XPAR_AXI_DMA_0_BASEADDR + 0x00)
#define MM2S_DMASR   (XPAR_AXI_DMA_0_BASEADDR + 0x04)
#define MM2S_SA      (XPAR_AXI_DMA_0_BASEADDR + 0x18)
#define MM2S_LENGTH  (XPAR_AXI_DMA_0_BASEADDR + 0x28)
typedef enum {
    MARIO_IDLE = 0, MARIO_RUN_1, MARIO_RUN_2, MARIO_RUN_3, MARIO_SKID,
    MARIO_JUMP, MARIO_DEAD, MARIO_SWIM_1, MARIO_SWIM_2, MARIO_SWIM_3,
    MARIO_SWIM_4, MARIO_SWIM_5, MARIO_CLIMB_1, MARIO_CLIMB_2
} MarioFrameId;

/* =========================================================================
 * HELPER: Blast Graphics to GPU (Used by both SD and UDP)
 * ========================================================================= */
static void blast_graphics_to_gpu(u32 bytes_read) {
    xil_printf("[GPU] Blasting %u bytes to FPGA Sprite BRAM... ", (unsigned int)bytes_read);
    Xil_Out32(GPU_CTRL_REG, 1);
    for (u32 i = 0; i < bytes_read; i += 4) {
        u32 packed_word = (graphics_buf[i+3] << 24) |
                          (graphics_buf[i+2] << 16) |
                          (graphics_buf[i+1] <<  8) |
                          (graphics_buf[i]);
        Xil_Out32(GPU_DATA_REG, packed_word);
    }
    Xil_Out32(GPU_CTRL_REG, 0);
    xil_printf("OK!\r\n");
}

/* =========================================================================
 * DEV MODE: UDP Loading Functions
 *
 * Two-phase protocol:
 *   Phase 1 — Config packet (seq 0): [Type=0x11][StreamType][4-byte FileSize]
 *             DMA'd into a small staging buffer (just once) to read the size.
 *   Phase 2 — Audio stream (seq 1..N): [raw audio payload]
 *             DMA'd DIRECTLY into audio_buf using the proven S2MM_LENGTH =
 *             remaining pattern.  No type byte, no staging, no memcpy.
 * ========================================================================= */
#if DEV_MODE

#define S2MM_DMACR   (XPAR_AXI_DMA_0_BASEADDR + 0x30)
#define S2MM_DMASR   (XPAR_AXI_DMA_0_BASEADDR + 0x34)
#define S2MM_DA      (XPAR_AXI_DMA_0_BASEADDR + 0x48)
#define S2MM_LENGTH  (XPAR_AXI_DMA_0_BASEADDR + 0x58)

/* Config staging — pinned to DDR because DMA can't reach LMB BRAM.
 * Only used once per transfer, not in the audio hot path. */
static u8 *dma_cfg_staging __attribute__((aligned (32))) = (u8 *)0x88800000;

/* --- Packet Type IDs (must match Python sender) --- */
#define PKT_TYPE_AUDIO   0x00
#define PKT_TYPE_VIDEO   0x01
#define PKT_TYPE_CONFIG  0x11

/* Helper: do a single S2MM DMA transfer, poll for completion.
 * Returns actual bytes transferred, or 0 on error/ghost.
 * ALWAYS leaves the DMA channel in a clean (Idle/Reset) state on exit
 * so the caller can retry or start a new transfer immediately. */
static u32 dma_s2mm_once(u8 *dest, u32 max_len) {
    /* Clear old interrupt/error status bits, then start */
    Xil_Out32(S2MM_DMASR, 0x7000);
    Xil_Out32(S2MM_DMACR, 0x1001);
    Xil_Out32(S2MM_DA,    (u32)(UINTPTR)dest);
    Xil_Out32(S2MM_LENGTH, max_len);

    u32 sr;
    do {
        sr = Xil_In32(S2MM_DMASR);

        if (sr & 0x60) {   /* DMASlvErr | DMADecErr — true hardware bus error */
            xil_printf("\r\n[UDP] FATAL BUS ERROR! SR=0x%08x (SlvErr=%d, DecErr=%d)\r\n", 
                       sr, (sr>>6)&1, (sr>>5)&1);
            Xil_Out32(S2MM_DMACR, 0x4);
            while (Xil_In32(S2MM_DMACR) & 0x4) {}
            return 0;
        }

        if (sr & 0x10) {   /* DMAIntErr — Internal/Overflow error, retryable */
            /* Quietly reset and return 0 so Stage 1 retries */
            Xil_Out32(S2MM_DMACR, 0x4);
            while (Xil_In32(S2MM_DMACR) & 0x4) {}
            return 0;
        }

    } while (!(sr & 0x2) && !(sr & 0x1));  /* Wait for Idle or Halted */

    u32 actual = Xil_In32(S2MM_LENGTH);
    if (actual == 0) {
        /* Ghost TLAST — reset and signal caller to retry */
        Xil_Out32(S2MM_DMACR, 0x4);
        while (Xil_In32(S2MM_DMACR) & 0x4) {}
    }
    return actual;
}

static u32 udp_receive_dma(u8 *dst_buf, const char* name) {

    xil_printf("[UDP] Waiting for config packet...\r\n");


    /* NOTE: No soft reset here! udp_receive_graphics() completed cleanly,
     * leaving the DMA in Idle state. The audio config packet (and possibly
     * the first audio data packet) is already in the AXI Stream FIFO.
     * A soft reset (DMACR bit 2) also flushes that FIFO, destroying the
     * config packet before Phase 1 can read it. */

    /* ---------------------------------------------------------------
     * PHASE 1: Receive config packet (staging buffer, just once)
     * Wire from VHDL (seq stripped): [Type(1)] [StreamType(1)] [Size(4)]
     * --------------------------------------------------------------- */
    u32 expected_bytes = 0;
    while (expected_bytes == 0) {
        u32 actual = dma_s2mm_once(dma_cfg_staging, 2048);
        if (actual == 0) continue;

        Xil_DCacheInvalidateRange((UINTPTR)dma_cfg_staging, actual);

        if (actual >= 6 && dma_cfg_staging[0] == PKT_TYPE_CONFIG) {
            u8  stream_type = dma_cfg_staging[1];
            expected_bytes  = ((u32)dma_cfg_staging[2] << 24) |
                              ((u32)dma_cfg_staging[3] << 16) |
                              ((u32)dma_cfg_staging[4] <<  8) |
                              ((u32)dma_cfg_staging[5]);
            xil_printf("[UDP] CONFIG: stream=0x%02x, size=%lu bytes\r\n",
                       stream_type, expected_bytes);
        } else {
            xil_printf("[UDP] Ignoring non-config packet (len=%lu). First 8 bytes: ", actual);
            for(int i=0; i<8 && i<(int)actual; i++) {
                xil_printf("%02x ", dma_cfg_staging[i]);
            }
            xil_printf("\r\n");
        }
    }

    /* ---------------------------------------------------------------
     * PHASE 2: Receive audio stream — PROVEN WORKING PATTERN
     * Direct DMA into dst_buf, S2MM_LENGTH = remaining, no staging.
     * --------------------------------------------------------------- */
    xil_printf("[UDP] Streaming %s (%lu bytes)...\r\n", name, expected_bytes);

    u8  *write_ptr = dst_buf;
    u32  received  = 0;
    u32  packets   = 0;

    while (received < expected_bytes) {
        u32 max_chunk = expected_bytes - received;

        u32 actual = dma_s2mm_once(write_ptr, max_chunk);
        if (actual == 0) continue;

        write_ptr += actual;
        received  += actual;
        packets++;

        if (packets % 100 == 0) {
            xil_printf("\r[UDP] Stitched %lu packets... (%lu / %lu bytes)    ",
                       packets, received, expected_bytes);
        }
    }

    Xil_DCacheInvalidateRange((UINTPTR)dst_buf, expected_bytes);

    xil_printf("\r\n[UDP] %s received perfectly! (%lu bytes across %lu packets)\r\n",
               name, received, packets);
    return received;
}
static u32 udp_receive_graphics(u8 *dst_buf, const char* name) {

    xil_printf("[UDP] Waiting for graphics config packet...\r\n");

    /* Phase 1: Config packet — extract file size */
    u32 expected_bytes = 0;
    while (expected_bytes == 0) {
        u32 actual = dma_s2mm_once(dma_cfg_staging, 2048);
        if (actual == 0) continue;

        Xil_DCacheInvalidateRange((UINTPTR)dma_cfg_staging, actual);

        if (actual >= 6 && dma_cfg_staging[0] == PKT_TYPE_CONFIG) {
            expected_bytes = ((u32)dma_cfg_staging[2] << 24) |
                             ((u32)dma_cfg_staging[3] << 16) |
                             ((u32)dma_cfg_staging[4] <<  8) |
                             ((u32)dma_cfg_staging[5]);
            xil_printf("[UDP] GRAPHICS CONFIG: size=%lu bytes\r\n", expected_bytes);
        } else {
            xil_printf("[UDP] Ignoring non-config packet (len=%lu). First 8 bytes: ", actual);
            for(int i=0; i<8 && i<(int)actual; i++) {
                xil_printf("%02x ", dma_cfg_staging[i]);
            }
            xil_printf("\r\n");
        }
    }

    /* Phase 2: Direct DMA into graphics_buf — same proven pattern */
    u8  *write_ptr = dst_buf;
    u32  received  = 0;
    u32  packets   = 0;

    while (received < expected_bytes) {
        u32 max_chunk = expected_bytes - received;
        u32 actual = dma_s2mm_once(write_ptr, max_chunk);
        if (actual == 0) continue;

        write_ptr += actual;
        received  += actual;
        packets++;
    }

    Xil_DCacheInvalidateRange((UINTPTR)dst_buf, expected_bytes);

    xil_printf("[UDP] %s received! (%lu bytes across %lu packets)\r\n",
               name, received, packets);
    return received;
}
#endif

/* =========================================================================
 * STANDARD MODE: SD Card Loading Functions
 * ========================================================================= */
static u32 sd_load_graphics(void)
{
    FIL fil;
    FRESULT fr;
    u32 bytes_read = 0;

    xil_printf("[SD] Opening 0:IMG/ATLAS.BIN... ");
    fr = f_open(&fil, "0:IMG/ATLAS.BIN", FA_READ | FA_OPEN_EXISTING);
    if (fr != FR_OK) {
        xil_printf("FAILED (FR=%d)\r\n", (int)fr);
        return 0;
    }

    u32 file_size = (u32)f_size(&fil);
    if (file_size > GRAPHICS_BUF_SIZE) {
        xil_printf("FAILED: File too large (%lu bytes)\r\n", (unsigned long)file_size);
        f_close(&fil);
        return 0;
    }

    xil_printf("OK (%lu bytes)\r\n", (unsigned long)file_size);

    fr = f_read(&fil, graphics_buf, file_size, (UINT*)&bytes_read);
    if (fr != FR_OK || bytes_read == 0) {
        xil_printf("[SD] Failed to read graphics data\r\n");
        f_close(&fil);
        return 0;
    }

    f_close(&fil);
    blast_graphics_to_gpu(bytes_read);
    return bytes_read;
}

static u32 sd_load_audio(void)
{
    FIL fil;
    FRESULT fr;
    u32 bytes_read = 0;

    xil_printf("[SD] Opening 0:AUDIO/BGM_01.BIN... ");
    fr = f_open(&fil, "0:AUDIO/BGM_01.BIN", FA_READ | FA_OPEN_EXISTING);
    if (fr != FR_OK) {
        xil_printf("FAILED (FR=%d)\r\n", (int)fr);
        return 0;
    }

    u32 file_size = (u32)f_size(&fil);
    u32 load_size = (file_size < AUDIO_BUF_SIZE) ? file_size : AUDIO_BUF_SIZE;
    xil_printf("OK (%lu bytes)\r\n", (unsigned long)file_size);
    if (file_size == 0) {
        f_close(&fil);
        return 0;
    }

    u8  *dst       = audio_buf;
    u32  remaining = load_size;
    UINT br;

    xil_printf("[SD] Loading audio (dots = 64KB each):");
    while (remaining > 0) {
        UINT chunk = (remaining > 65536U) ? 65536U : (UINT)remaining; 
        fr = f_read(&fil, dst, chunk, &br);
        if (fr != FR_OK || br == 0) {
            f_close(&fil);
            return 0;
        }
        dst        += br;
        bytes_read += br;
        remaining  -= br;
        if ((bytes_read & 0x0FFFF) == 0) xil_printf("."); 
    }

    xil_printf("\r\n[SD] Loaded %lu bytes OK\r\n", (unsigned long)bytes_read);
    f_close(&fil);
    return bytes_read;
}

/* =========================================================================
 * main()
 * ========================================================================= */
int main(void)
{
    int Status;
    Xil_ICacheEnable();  
    Xil_DCacheEnable();  

    xil_printf("--- SoC Booted with Caches Enabled ---\r\n");

    /* --- 1. INTERRUPT CONTROLLER --- */
    xil_printf("[INTC] Initialising... ");
    Status = XIntc_Initialize(&GlobalIntc, 0);
    if (Status != XST_SUCCESS) return XST_FAILURE;
    xil_printf("OK\r\n");

    /* --- 2. GPU / DISPLAY INIT --- */
    clear_screen(0);
    clear_all_sprites();
    clear_hud();
    hud_init();

    /* --- 3. LOAD ASSETS --- */
    u32 audio_bytes = 0;
    u32 graphics_bytes = 0;

#if DEV_MODE
    /* ASSET LOADING: DEV MODE (Streaming via Ethernet)
     * The console waits for the Python main.py script to send data. 
     */
    xil_printf("\r\n[DEV MODE] Loading assets...\r\n");

    // 1. Load graphics over the network (ATLAS.BIN via UDP)
    graphics_bytes = udp_receive_graphics(graphics_buf, "ATLAS.BIN");
    if (graphics_bytes > 0) {
        blast_graphics_to_gpu(graphics_bytes);
    }

    // 2. Load audio over the network
    audio_bytes = udp_receive_dma(audio_buf, "BGM_01.BIN");

#else
    xil_printf("\r\n[RELEASE MODE] Loading assets from SD Card...\r\n");
    xil_printf("[SD] Mounting FAT32 volume... ");
    if (f_mount(&FatFs, "0:", 1) == FR_OK) {
        xil_printf("OK\r\n");
        audio_bytes = sd_load_audio();
        graphics_bytes = sd_load_graphics(); 
    } else {
        xil_printf("FAILED! Cannot mount SD card.\r\n");
    }
#endif

    if (graphics_bytes == 0) {
        xil_printf("WARNING: No graphics loaded, screen might be corrupted!\r\n");
    }

    /* --- 4. START INTERRUPTS --- */
    Status = XIntc_Start(&GlobalIntc, XIN_REAL_MODE);
    if (Status != XST_SUCCESS) return XST_FAILURE;
    Xil_ExceptionInit();
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
                                 (Xil_ExceptionHandler)XIntc_InterruptHandler,
                                 &GlobalIntc);
    Xil_ExceptionEnable();

    /* --- 5. AUDIO ENGINE / DMA --- */
    /* Truncate to a 4-byte boundary. The AXI DMA MM2S channel (32-bit bus,
     * no DRE) requires LENGTH to be a multiple of 4. Writing an unaligned
     * value causes a DMAIntErr that permanently halts the engine.
     * 1,950,407 % 4 == 3  =>  safe = 1,950,404.  The 3 missing bytes are
     * inaudible at the very end of the track. */
    u32 safe_audio_bytes = audio_bytes & ~0x3U; /* round DOWN to nearest 4 */

    if (audio_bytes > 0) {
        /* Log the truncation so we can confirm it in the terminal */
        if (safe_audio_bytes != audio_bytes) {
            xil_printf("[AUDIO] Truncating %lu -> %lu bytes (4-byte alignment, no DRE)\r\n",
                       audio_bytes, safe_audio_bytes);
        }
        // audio_engine_init re-initializes the DMA for playback (MM2S),
        // cleanly ending the UDP S2MM phase.
        Status = audio_engine_init(&GlobalIntc, audio_buf, safe_audio_bytes);
    }
    
    for (int col = 0; col < 64; col++)
        set_bg_tile(col, FLOOR_ROW, TILE_BRICK);

    int  mario_x     = 20;
    int  mario_y     = MARIO_STAND_Y;
    int  vel_x       = 2;
    int  anim_timer  = 0;
    int  game_tick   = 0; 
    int  run_step    = 0;  

    int current_score = 0;
    int current_time  = 398;

    /* --- 6. MAIN GAME LOOP --- */
    while (1) {
        /* A. INPUT: Read the state of the controller bits. */
        mario_x += vel_x;
        if (mario_x <= 0 || mario_x >= (LOGICAL_WIDTH - 16)) vel_x = -vel_x;

        /* --- B. ANIMATION & TIMERS --- */
        anim_timer++;
        game_tick++;

        if (anim_timer >= 4) {
            run_step = (run_step + 1) % 3; 
            anim_timer  = 0;
        }

        if (game_tick >= 8) {
            current_score += 10;
            current_time--;
            hud_print_int(2,  2, current_score, 6);
            hud_print_int(26, 2, current_time,  3);
            game_tick = 0;
        }

        /* --- C. RESOLVE CURRENT FRAME --- */
        MarioFrameId current_frame;
        if (vel_x == 0) {
            current_frame = MARIO_IDLE;
        } else {
            if (run_step == 0) current_frame = MARIO_RUN_1;
            else if (run_step == 1) current_frame = MARIO_RUN_2;
            else current_frame = MARIO_RUN_3;
        }

        /* --- D. COLLISION --- */
        uint64_t collision_mask    = get_hardware_collisions();
        bool     is_touching_enemy = (collision_mask & (1ULL << 1));
        uint8_t  enemy_tile        = ENEMY_ATLAS_BASE + (is_touching_enemy ? 1 : 0);

        /* --- E. RENDER --- */
        set_sprite(0, true, mario_x, mario_y,
                   (vel_x < 0),
                   MARIO_ATLAS_BASE + current_frame);
                   
        set_sprite(1, true, 160, MARIO_STAND_Y, false, enemy_tile);

        /* E. SYNC: Wait for the monitor to finish drawing before we change state.
         * This locks the game loop to exactly 60 Hz.
         */
        wait_for_vsync();

        /* --- F. AUDIO LOOP ---
         * No polling needed here. The dma_audio_isr() in audio_engine.c
         * handles seamless looping entirely in hardware interrupt context:
         * when the MM2S channel fires its IOC interrupt, the ISR immediately
         * calls XAxiDma_SimpleTransfer() to restart the same buffer.
         * Polling the DMASR registers here would race with the ISR, corrupt
         * an already-restarted transfer, and crash the CPU.
         * Do NOT add raw Xil_Out32(MM2S_*) calls in this loop. */
    }
}