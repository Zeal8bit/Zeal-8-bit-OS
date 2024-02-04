; SPDX-FileCopyrightText: 2024 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    IFNDEF COMPACTFLASH_H
    DEFINE COMPACTFLASH_H

    INCLUDE "osconfig.asm"

    ; Address of the CompactFlash on the I/O bus
    DEFC CF_IO_ADDR     = CONFIG_TARGET_COMPACTFLASH_ADDRESS
    DEFC CF_SECTOR_SIZE = 512

    DEFC CF_REG_DATA    = CF_IO_ADDR + 0
    ; Error and feature registers are the same
    DEFC CF_REG_ERROR   = CF_IO_ADDR + 1    ; RO
    DEFC CF_REG_FEATURE = CF_IO_ADDR + 1    ; WO
    DEFC CF_REG_SEC_CNT = CF_IO_ADDR + 2
    DEFC CF_REG_LBA_0   = CF_IO_ADDR + 3
    DEFC CF_REG_LBA_8   = CF_IO_ADDR + 4
    DEFC CF_REG_LBA_16  = CF_IO_ADDR + 5
    DEFC CF_REG_LBA_24  = CF_IO_ADDR + 6

    ; For the command register, define the ones we are interested in
    DEFC CF_REG_COMMAND = CF_IO_ADDR + 7    ; WO
    DEFC COMMAND_READ_SECTORS  = 0x20
    DEFC COMMAND_READ_BUFFER   = 0xE4
    DEFC COMMAND_WRITE_SECTORS = 0x30
    DEFC COMMAND_FLUSH_CACHE   = 0xE7
    DEFC COMMAND_WRITE_BUFFER  = 0xE8
    DEFC COMMAND_IDENTIFY_DRV  = 0xEC
    DEFC COMMAND_SET_FEATURES  = 0xEF

    ; For the status register, define the different bit
    DEFC CF_REG_STATUS  = CF_IO_ADDR + 7    ; RO
    DEFC STATUS_BUSY_BIT = 7
    DEFC STATUS_RDY_BIT  = 6
    DEFC STATUS_DWF_BIT  = 5
    DEFC STATUS_DSC_BIT  = 4
    DEFC STATUS_DRQ_BIT  = 3
    DEFC STATUS_CORR_BIT = 2
    DEFC STATUS_ERR_BIT  = 0

    ; For the feature register, the different possibilities
    DEFC FEATURE_ENABLE_8_BIT  = 0x1
    DEFC FEATURE_DISABLE_8_BIT = 0x81

    ENDIF