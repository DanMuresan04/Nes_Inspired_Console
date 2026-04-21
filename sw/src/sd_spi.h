/*
 * sd_spi.h  --  Pure-C SD card driver for MicroBlaze via AXI SPI (XSpi)
 *
 * Extracted and translated from DXSPISDVOL.cpp (Digilent Inc., MIT License)
 * Adapted for MicroBlaze bare-metal, FatFs R0.16 bridge layer.
 *
 * Hardware:
 *   SPI Base Addr  : 0x44A20000  (SD_CARD / AXI_LITE_SPI)
 *   CS  Base Addr  : 0x44A10000  (SD_CARD / AXI_LITE_SDCS)
 */

#ifndef SD_SPI_H
#define SD_SPI_H

#include "xspi.h"
#include "xil_types.h"

/* SD card type flags (returned by sd_spi_ioctl MMC_GET_TYPE) */
#define CT_MMC      0x01    /* MMC ver 3 */
#define CT_SD1      0x02    /* SD ver 1 */
#define CT_SD2      0x04    /* SD ver 2 */
#define CT_SDC      (CT_SD1|CT_SD2) /* SD */
#define CT_BLOCK    0x08    /* Block addressing */

/* FatFs diskio status bits (mirrored from diskio.h) */
#define STA_NOINIT  0x01
#define STA_NODISK  0x02
#define STA_PROTECT 0x04

/* disk_ioctl command codes (mirrored from diskio.h) */
#define CTRL_SYNC         0
#define GET_SECTOR_COUNT  1
#define GET_SECTOR_SIZE   2
#define GET_BLOCK_SIZE    3
#define MMC_GET_TYPE      10
#define MMC_GET_CSD       11
#define MMC_GET_CID       12
#define MMC_GET_OCR       13
#define MMC_GET_SDSTAT    14

/*
 * Initialize the SD card through the AXI SPI peripheral.
 * Must be called before any read/write.
 *
 * @param spi_base   AXI SPI base address (0x44A20000)
 * @param cs_base    AXI GPIO CS  base address (0x44A10000)
 * @return 0 on success, STA_NOINIT if init failed
 */
int sd_spi_init(XSpi *SpiInstancePtr);

/* Returns current status flags (0 = ready, STA_NOINIT = not initialized) */
int sd_spi_status(void);

/*
 * Read 'count' 512-byte sectors starting at 'sector' (LBA) into 'buff'.
 * Returns 0 on success, non-zero on error.
 */
int sd_spi_read_blocks(u8 *buff, u32 sector, u32 count);

/*
 * Write 'count' 512-byte sectors starting at 'sector' (LBA) from 'buff'.
 * Returns 0 on success, non-zero on error.
 */
int sd_spi_write_blocks(const u8 *buff, u32 sector, u32 count);

/*
 * Miscellaneous control.  Supports CTRL_SYNC, GET_SECTOR_COUNT,
 * GET_BLOCK_SIZE, MMC_GET_TYPE, MMC_GET_CSD, MMC_GET_CID, MMC_GET_OCR.
 * Returns 0 on success, non-zero on error / unsupported command.
 */
int sd_spi_ioctl(u8 cmd, void *buff);

#endif /* SD_SPI_H */
