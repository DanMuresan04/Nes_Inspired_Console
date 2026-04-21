/*
 * sd_spi.c  --  Pure-C SD card driver for MicroBlaze via AXI XSpi
 *
 * Translated from DXSPISDVOL.cpp (Digilent Inc., BSD-3-Clause)
 * by Keith Vogel / Thomas Kappenman; adapted for FatFs R0.16 bridge.
 *
 * Uses Xilinx XSpi polled-mode. CS line is an AXI GPIO output mapped
 * at SD_CS_BASE.  Bit 0 = CS (0=asserted), Bit 0 of +4 = direction (0=out).
 */
#include <string.h> /* For memset */
#include "sd_spi.h"
#include "xil_io.h"
#include "sleep.h"
#include <string.h>
#include "xil_printf.h"
#include "sleep.h"
#include <string.h>
#include "xil_printf.h"

/* -------------------------------------------------------------------------- */
/*  Module-private state                                                       */
/* -------------------------------------------------------------------------- */
            
static XSpi *GlobalSpiPtr = NULL;
static u8    _card_type;     /* CT_xxx flags */
static volatile u8 _stat = STA_NOINIT;

/* -------------------------------------------------------------------------- */
/*  MMC / SD SPI command set                                                  */
/* -------------------------------------------------------------------------- */
#define CMD0    (0)
#define CMD1    (1)
#define ACMD41  (41|0x80)
#define CMD8    (8)
#define CMD9    (9)
#define CMD10   (10)
#define CMD12   (12)
#define ACMD13  (13|0x80)
#define CMD16   (16)
#define CMD17   (17)
#define CMD18   (18)
#define CMD23   (23)
#define ACMD23  (23|0x80)
#define CMD24   (24)
#define CMD25   (25)
#define CMD41   (41)
#define CMD55   (55)
#define CMD58   (58)

/* -------------------------------------------------------------------------- */
/*  Low-level helpers                                                          */
/* -------------------------------------------------------------------------- */

/* Exchanges a single byte via AXI Quad SPI */
static u8 xchg_byte(u8 tx)
{
    u8 rx = 0xFF;
    if (GlobalSpiPtr != NULL) {
        /* XSpi_Transfer handles the FIFO polling and status checks automatically */
        XSpi_Transfer(GlobalSpiPtr, &tx, &rx, 1);
    }
    return rx;
}

static u8 dummy_tx_buf[512];
static int dummy_initialized = 0;

/* Transmits a block of bytes */
static void xmit_mmc(u8 *buff, u32 bc)
{
    if (GlobalSpiPtr != NULL) {
        /* Pass the entire buffer to the Xilinx driver at once! */
        XSpi_Transfer(GlobalSpiPtr, buff, NULL, bc);
    }
}

/* Receives a block of bytes */
static void rcvr_mmc(u8 *buff, u32 bc)
{
    if (!dummy_initialized) {
        memset(dummy_tx_buf, 0xFF, 512);
        dummy_initialized = 1;
    }

    if (GlobalSpiPtr != NULL) {
        u32 remaining = bc;
        u8 *rx_ptr = buff;
        
        while (remaining > 0) {
            /* Process in chunks up to our dummy buffer size */
            u32 chunk = (remaining > 512) ? 512 : remaining;
            
            /* Blast the chunk using the hardware FIFOs */
            XSpi_Transfer(GlobalSpiPtr, dummy_tx_buf, rx_ptr, chunk);
            
            rx_ptr += chunk;
            remaining -= chunk;
        }
    }
}

/* Waits for the SD card to be ready */
static int wait_ready(void)
{
    u8 d;
    u32 tmr;
    for (tmr = 500; tmr; tmr--) {
        rcvr_mmc(&d, 1);
        if (d == 0xFF) break;
        usleep(1000);
    }
    return tmr ? 1 : 0;
}

/* De-asserts the Chip Select line (Drives it HIGH) */
static void deselect(void)
{
    u8 d = 0xFF;
    if (GlobalSpiPtr != NULL) {
        /* 0x00 means assert no slaves (CS goes HIGH) */
        XSpi_SetSlaveSelect(GlobalSpiPtr, 0x00);
    }
    rcvr_mmc(&d, 1); /* Dummy clock to let card release MISO */
}

/* Asserts the Chip Select line (Drives it LOW) and waits for ready */
static int select_card(void)
{
    u8 d;
    if (GlobalSpiPtr != NULL) {
        /* 0x01 means assert Slave 0 (CS goes LOW) */
        XSpi_SetSlaveSelect(GlobalSpiPtr, 0x01);
    }
    rcvr_mmc(&d, 1); /* Dummy clock */
    
    if (wait_ready()) return 1;
    
    deselect();
    return 0;
}

static int rcvr_datablock(u8 *buff, u32 btr)
{
    u8 d[2];
    u32 tmr;
    for (tmr = 100; tmr; tmr--) {
        rcvr_mmc(d, 1);
        if (d[0] != 0xFF) break;
        usleep(1000);
    }
    if (d[0] != 0xFE) return 0;
    rcvr_mmc(buff, btr);
    rcvr_mmc(d, 2);   /* discard CRC */
    return 1;
}

static u8 send_cmd(u8 cmd, u32 arg)
{
    u8 n, d, buf[6];

    if (cmd & 0x80) {           /* ACMD<n> = CMD55 + CMD<n> */
        cmd &= 0x7F;
        n = send_cmd(CMD55, 0);
        if (n > 1) return n;
    }

    if (cmd != CMD12) {
        deselect();
        if (!select_card()) return 0xFF;
    }

    buf[0] = 0x40 | cmd;
    buf[1] = (u8)(arg >> 24);
    buf[2] = (u8)(arg >> 16);
    buf[3] = (u8)(arg >>  8);
    buf[4] = (u8)(arg);
    n = 0x01;
    if (cmd == CMD0) n = 0x95;
    if (cmd == CMD8) n = 0x87;
    buf[5] = n;
    xmit_mmc(buf, 6);

    if (cmd == CMD12) rcvr_mmc(&d, 1);   /* skip stuff byte */
    n = 10;
    do { rcvr_mmc(&d, 1); } while ((d & 0x80) && --n);
    return d;
}

/* -------------------------------------------------------------------------- */
/*  Public API                                                                 */
/* -------------------------------------------------------------------------- */

/* -------------------------------------------------------------------------- */
/* Public API                                                                */
/* -------------------------------------------------------------------------- */

int sd_spi_init(XSpi *SpiInstancePtr)
{
    /* 1. Save the hardware instance pointer for all future operations */
    GlobalSpiPtr = SpiInstancePtr;

    u8  ty = 0;
    u8  buf[4];
    u32 tmr;

    /* --- Card identification sequence --- */
    if (send_cmd(CMD0, 0) == 1) {               /* Enter Idle */
        xil_printf("  [SD_SPI] CMD0 OK\r\n");
        
        if (send_cmd(CMD8, 0x1AA) == 1) {       /* SDv2? */
            rcvr_mmc(buf, 4);
            xil_printf("  [SD_SPI] CMD8 OK: %02X %02X\r\n", buf[2], buf[3]);
            
            if (buf[2] == 0x01 && buf[3] == 0xAA) {
                for (tmr = 1000; tmr; tmr--) {
                    if (send_cmd(ACMD41, 0x40000000) == 0) break;
                    usleep(1000);
                }
                xil_printf("  [SD_SPI] ACMD41 loop finished (tmr=%lu)\r\n", (unsigned long)tmr);
                
                if (tmr && send_cmd(CMD58, 0) == 0) {
                    rcvr_mmc(buf, 4);
                    ty = (buf[0] & 0x40) ? CT_SD2 | CT_BLOCK : CT_SD2;
                    xil_printf("  [SD_SPI] CMD58 OK, type=%02X\r\n", ty);
                }
            }
        } else {                                /* SDv1 or MMCv3 */
            u8 cmd;
            if (send_cmd(ACMD41, 0) <= 1) {
                ty = CT_SD1; cmd = ACMD41;
            } else {
                ty = CT_MMC; cmd = CMD1;
            }
            for (tmr = 1000; tmr; tmr--) {
                if (!send_cmd(cmd, 0)) break;
                usleep(1000);
            }
            if (!tmr || send_cmd(CMD16, 512) != 0) {
                xil_printf("  [SD_SPI] Timeout or CMD16 FAILED\r\n");
                ty = 0;
            }
        }
    } else {
        xil_printf("  [SD_SPI] CMD0 FAILED\r\n");
    }

    _card_type = ty;
    deselect();

    if (ty) {
        _stat &= ~STA_NOINIT;
        xil_printf("  [SD_SPI] SUCCESS (Type=%d)\r\n", ty);
        return 0;
    } else {
        xil_printf("  [SD_SPI] FAILED (Card Type 0)\r\n");
        return STA_NOINIT;
    }
}

int sd_spi_status(void)
{
    return _stat;
}

int sd_spi_read_blocks(u8 *buff, u32 sector, u32 count)
{
    u8 cmd;
    if (!count) return 1;
    if (_stat & STA_NOINIT) return 1;

    if (!(_card_type & CT_BLOCK)) sector *= 512;   /* byte address for v1 */

    cmd = (count > 1) ? CMD18 : CMD17;
    if (send_cmd(cmd, sector) == 0) {
        do {
            if (!rcvr_datablock(buff, 512)) break;
            buff += 512;
        } while (--count);
        if (cmd == CMD18) send_cmd(CMD12, 0);
    }
    deselect();
    return count ? 1 : 0;
}

int sd_spi_write_blocks(const u8 *buff, u32 sector, u32 count)
{
    /* Write is not required for read-only FatFs, provided for completeness */
    (void)buff; (void)sector; (void)count;
    return 1;
}

int sd_spi_ioctl(u8 cmd, void *buff)
{
    u8 csd[16];
    u32 cs;
    u8 *ptr = (u8 *)buff;

    if (_stat & STA_NOINIT) return 1;

    switch (cmd) {
    case CTRL_SYNC:
        if (select_card()) { deselect(); return 0; }
        return 1;

    case GET_SECTOR_COUNT:
        if ((send_cmd(CMD9, 0) == 0) && rcvr_datablock(csd, 16)) {
            if ((csd[0] >> 6) == 1) {               /* SDv2 */
                cs = csd[9] + ((u32)csd[8] << 8) +
                     ((u32)(csd[7] & 63) << 16) + 1;
                *(u32 *)buff = cs << 10;
            } else {                                 /* SDv1 / MMC */
                u8 n = (csd[5] & 15) + ((csd[10] & 128) >> 7) +
                       ((csd[9] & 3) << 1) + 2;
                cs = (csd[8] >> 6) + ((u32)csd[7] << 2) +
                     ((u32)(csd[6] & 3) << 10) + 1;
                *(u32 *)buff = cs << (n - 9);
            }
            deselect();
            return 0;
        }
        deselect();
        return 1;

    case GET_BLOCK_SIZE:
        if (_card_type & CT_SD2) {
            if (send_cmd(ACMD13, 0) == 0) {
                xchg_byte(0xFF);
                if (rcvr_datablock(csd, 16)) {
                    for (u32 i = 64 - 16; i; i--) xchg_byte(0xFF);
                    *(u32 *)buff = 16UL << (csd[10] >> 4);
                    deselect();
                    return 0;
                }
            }
        } else {
            if ((send_cmd(CMD9, 0) == 0) && rcvr_datablock(csd, 16)) {
                if (_card_type & CT_SD1)
                    *(u32 *)buff = (((csd[10] & 63) << 1) +
                                   ((u32)(csd[11] & 128) >> 7) + 1) <<
                                   ((csd[13] >> 6) - 1);
                else
                    *(u32 *)buff = ((u32)((csd[10] & 124) >> 2) + 1) *
                                   (((csd[11] & 3) << 3) +
                                    ((csd[11] & 224) >> 5) + 1);
                deselect();
                return 0;
            }
        }
        deselect();
        return 1;

    case MMC_GET_TYPE:
        *ptr = _card_type;
        return 0;

    case MMC_GET_CSD:
        if ((send_cmd(CMD9, 0) == 0) && rcvr_datablock((u8 *)buff, 16)) {
            deselect(); return 0;
        }
        deselect();
        return 1;

    case MMC_GET_CID:
        if ((send_cmd(CMD10, 0) == 0) && rcvr_datablock((u8 *)buff, 16)) {
            deselect(); return 0;
        }
        deselect();
        return 1;

    case MMC_GET_OCR:
        if (send_cmd(CMD58, 0) == 0) {
            for (u32 i = 0; i < 4; i++) *((u8 *)buff + i) = xchg_byte(0xFF);
            deselect();
            return 0;
        }
        deselect();
        return 1;

    default:
        return 1;
    }
}
