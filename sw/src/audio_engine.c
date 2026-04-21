/*
 * audio_engine.c  --  Simple looping DMA audio engine
 *
 * One pre-loaded PCM buffer in DDR. DMA streams it to the PWM audio IP.
 * The MM2S fast ISR fires on completion and immediately restarts the transfer
 * for a seamless, gapless loop.
 *
 * --- CRITICAL: Fast Interrupt Mode ---
 * The INTC has IS_FAST=1 (XPAR_MICROBLAZE_0_AXI_INTC_IS_FAST=1).
 * In this mode the hardware jumps directly to the address in the IVAR register.
 * XIntc_Initialize() sets ALL IVARs to 0x10 (the MicroBlaze reset/exception stub).
 * XIntc_Connect()    ONLY updates a software HandlerTable — it does NOT write IVAR.
 * XIntc_Start()      does NOT write IVAR either.
 *
 * The ONLY function that writes the IVAR hardware register is:
 *   XIntc_ConnectFastHandler(IntcPtr, Id, handler)
 *
 * Without this, every DMA interrupt jumps to 0x10, which looks like a clean
 * CPU reboot because 0x10 is the MicroBlaze reset vector stub.
 *
 * Fast handlers must be declared with: __attribute__ ((fast_interrupt))
 * They take no arguments — the DMA instance is accessed via the global AxiDma.
 */

#include "audio_engine.h"
#include "xil_cache.h"
#include "xil_printf.h"

XAxiDma AxiDma;

static u8  *s_audio_buf = NULL;
static u32  s_audio_len = 0;

/* ---------------------------------------------------------------------------
 * MM2S Fast ISR — fires when DMA-to-device (audio playback) completes.
 * Must be no-argument with fast_interrupt attribute so the compiler saves/
 * restores the correct registers for a direct IVAR jump.
 * --------------------------------------------------------------------------- */
void __attribute__ ((fast_interrupt)) dma_mm2s_fast_isr(void)
{
    u32 IrqStatus = XAxiDma_IntrGetIrq(&AxiDma, XAXIDMA_DMA_TO_DEVICE);
    XAxiDma_IntrAckIrq(&AxiDma, IrqStatus, XAXIDMA_DMA_TO_DEVICE);

    if (!(IrqStatus & XAXIDMA_IRQ_ALL_MASK)) return;

    if (IrqStatus & XAXIDMA_IRQ_ERROR_MASK) {
        /* DMA error during playback — soft reset and re-enable interrupts. */
        XAxiDma_Reset(&AxiDma);
        u32 Timeout = 500;
        while (!XAxiDma_ResetIsDone(&AxiDma) && --Timeout) {}
        XAxiDma_IntrEnable(&AxiDma,
                           XAXIDMA_IRQ_IOC_MASK | XAXIDMA_IRQ_ERROR_MASK,
                           XAXIDMA_DMA_TO_DEVICE);
        /* Fall through — attempt restart even after error recovery. */
    }

    if (IrqStatus & XAXIDMA_IRQ_IOC_MASK) {
        /* Seamless loop: restart the same buffer immediately. */
        if (s_audio_buf && s_audio_len > 0) {
            XAxiDma_SimpleTransfer(&AxiDma,
                                   (UINTPTR)s_audio_buf,
                                   s_audio_len,
                                   XAXIDMA_DMA_TO_DEVICE);
        }
    }
}

/* ---------------------------------------------------------------------------
 * S2MM Fast ISR — safety drain handler.
 *
 * udp_receive_dma() enables S2MM IOC interrupts (DMACR bit 12). Even after a
 * DMA reset, a deferred AXI-bus completion can still assert S2MM introut.
 * Without a valid IVAR the CPU jumps to 0x10 and reboots.
 * This handler acknowledges and drops all S2MM flags so nothing leaks through.
 * --------------------------------------------------------------------------- */
void __attribute__ ((fast_interrupt)) dma_s2mm_fast_isr(void)
{
    u32 IrqStatus = XAxiDma_IntrGetIrq(&AxiDma, XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_IntrAckIrq(&AxiDma, IrqStatus, XAXIDMA_DEVICE_TO_DMA);
    /* Disable S2MM hardware interrupts so this never fires again. */
    XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
}

int audio_engine_init(XIntc *IntcPtr, u8 *audio_data, u32 num_bytes)
{
    XAxiDma_Config *Config;
    int Status;

    xil_printf("[DMA] Initialising audio engine (%lu bytes)...\r\n",
               (unsigned long)num_bytes);

    s_audio_buf = audio_data;
    s_audio_len = num_bytes;

    Config = XAxiDma_LookupConfig(XPAR_XAXIDMA_0_BASEADDR);
    if (!Config) {
        xil_printf("[DMA] LookupConfig FAILED\r\n");
        return XST_FAILURE;
    }

    Status = XAxiDma_CfgInitialize(&AxiDma, Config);
    if (Status != XST_SUCCESS) {
        xil_printf("[DMA] CfgInitialize FAILED\r\n");
        return XST_FAILURE;
    }

    if (XAxiDma_HasSg(&AxiDma)) {
        xil_printf("[DMA] ERROR: SG mode detected — expected simple mode\r\n");
        return XST_FAILURE;
    }

    /* -----------------------------------------------------------------------
     * Register fast handlers — these write directly to the IVAR hardware
     * register, which is the ONLY way to override the 0x10 reset stub.
     * XIntc_Connect alone does NOT write IVAR and would leave both lines
     * jumping to 0x10 on every interrupt, rebooting the CPU.
     * --------------------------------------------------------------------- */
    Status = XIntc_ConnectFastHandler(IntcPtr,
                                      DMA_MM2S_INTR_ID,
                                      (XFastInterruptHandler)dma_mm2s_fast_isr);
    if (Status != XST_SUCCESS) {
        xil_printf("[DMA] ConnectFastHandler MM2S FAILED\r\n");
        return XST_FAILURE;
    }

    Status = XIntc_ConnectFastHandler(IntcPtr,
                                      DMA_S2MM_INTR_ID,
                                      (XFastInterruptHandler)dma_s2mm_fast_isr);
    if (Status != XST_SUCCESS) {
        xil_printf("[DMA] ConnectFastHandler S2MM FAILED\r\n");
        return XST_FAILURE;
    }

    /* Disable S2MM hardware interrupt output — belt-and-suspenders.
     * The fast ISR handles any stale assertion, then disables itself. */
    XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);

    /* Enable both lines in the INTC's IER and arm MM2S hardware interrupt. */
    XIntc_Enable(IntcPtr, DMA_S2MM_INTR_ID);
    XIntc_Enable(IntcPtr, DMA_MM2S_INTR_ID);
    XAxiDma_IntrEnable(&AxiDma,
                       XAXIDMA_IRQ_IOC_MASK | XAXIDMA_IRQ_ERROR_MASK,
                       XAXIDMA_DMA_TO_DEVICE);

    /* Flush D-cache so DDR has the final audio data before DMA reads it. */
    Xil_DCacheFlushRange((UINTPTR)s_audio_buf, s_audio_len);

    Status = XAxiDma_SimpleTransfer(&AxiDma,
                                    (UINTPTR)s_audio_buf,
                                    s_audio_len,
                                    XAXIDMA_DMA_TO_DEVICE);
    if (Status != XST_SUCCESS) {
        xil_printf("[DMA] SimpleTransfer FAILED\r\n");
        return XST_FAILURE;
    }

    xil_printf("[DMA] Audio streaming started\r\n");
    return XST_SUCCESS;
}