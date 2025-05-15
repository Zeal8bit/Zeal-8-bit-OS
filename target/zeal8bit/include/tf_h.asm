; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    IFNDEF TFCARD_H
    DEFINE TFCARD_H

    DEFC IO_MAPPER_BANK     = 0x8E ; I/O device bank, accessible in 0xA0
    DEFC SPI_CONTROLLER_IDX = 1

    DEFC TFCARD_ERR_NOT_SUPPORTED   = 0xFD
    DEFC TFCARD_ERR_FAILURE         = 0xFE
    DEFC TFCARD_ERR_TIMEOUT         = 0xFF

    DEFC TF_CMD_MASK  = 0x40
    DEFC TF_CMD0_CRC  = 0x95
    DEFC TF_CMD1_CRC  = 0xF9
    DEFC TF_CMD55_CRC = 0x65
    DEFC TF_CMD58_CRC = 0x95

    DEFC TF_ILL_CMD   = 0x05

    ; SPI controller-related contants
    DEFC SPI_REG_BASE = 0xa0
    DEFC SPI_REG_VERSION = (SPI_REG_BASE + 0)
    DEFC SPI_REG_CTRL    = (SPI_REG_BASE + 1)
        DEFC SPI_REG_CTRL_START    = 1 << 7   ; Start SPI transaction
        DEFC SPI_REG_CTRL_RESET    = 1 << 6   ; Reset the SPI controller
        DEFC SPI_REG_CTRL_CS_START = 1 << 5   ; Assert chip select (low)
        DEFC SPI_REG_CTRL_CS_END   = 1 << 4   ; De-assert chip select signal (high)
        DEFC SPI_REG_CTRL_CS_SEL   = 1 << 3   ; Select among two chip selects (0 for TF card, 1 is reserved)
        DEFC SPI_REG_CTRL_RSV2     = 1 << 2
        DEFC SPI_REG_CTRL_RSV1     = 1 << 1
        DEFC SPI_REG_CTRL_STATE    = 1 << 0   ; SPI controller in BUSY state if 1, IDLE if 0
    DEFC SPI_REG_CLK_DIV  = (SPI_REG_BASE + 2)
    DEFC SPI_REG_RAM_LEN  = (SPI_REG_BASE + 3)
    DEFC SPI_REG_CHECKSUM = (SPI_REG_BASE + 4)
    ; ... ;
    DEFC SPI_REG_RAM_FIFO = (SPI_REG_BASE + 7)
    DEFC SPI_REG_RAM_FROM = (SPI_REG_BASE + 8)
    DEFC SPI_REG_RAM_TO   = (SPI_REG_BASE + 15)

    ENDIF ; TFCARD_H