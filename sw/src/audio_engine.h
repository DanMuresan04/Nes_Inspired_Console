/**
 * @file audio_engine.h
 * @brief PCM Audio Streamer for the Custom FPGA Arcade Console.
 * 
 * AUDIO FORMAT:
 * - Direct PCM stream (8-bit unsigned).
 * - Must be pre-loaded into DDR memory via UDP or SD card.
 * - Hardware handles automatic looping via Interrupts.
 */

#ifndef AUDIO_ENGINE_H
#define AUDIO_ENGINE_H

#include "xparameters.h"
#include "xaxidma.h"
#include "xintc.h"

// --- Constants ---
#define DMA_MM2S_INTR_ID    XPAR_FABRIC_AXI_DMA_0_INTR    /* 2 */
#define DMA_S2MM_INTR_ID    XPAR_FABRIC_AXI_DMA_0_INTR_1  /* 3 */

/**
 * @brief Initialises the AXI DMA and registers the looping interrupt handlers.
 * 
 * ALIGNMENT WARNING:
 * The DMA engine requires your audio buffer to be 4-byte aligned and its size
 * to be a multiple of 4. Failing to do this will trigger a FATAL DMA ERROR.
 * 
 * BGM LOOPING:
 * Once initialized, the hardware will automatically loop the buffer forever
 * using an Interrupt Service Routine (ISR). You do NOT need to poll the audio
 * status in your main loop.
 *
 * @param IntcPtr    Pointer to your initialized Interrupt Controller.
 * @param audio_data Pointer to your raw PCM data in DDR.
 * @param num_bytes  Total size of the audio track (MUST be multiple of 4).
 * @return XST_SUCCESS on success, XST_FAILURE otherwise.
 */
int audio_engine_init(XIntc *IntcPtr, u8 *audio_data, u32 num_bytes);

/* Internal hardware handlers - don't call these directly. */
void dma_mm2s_fast_isr(void);   
void dma_s2mm_fast_isr(void);   

extern XAxiDma AxiDma;

#endif /* AUDIO_ENGINE_H */