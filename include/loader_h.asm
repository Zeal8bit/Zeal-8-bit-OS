; SPDX-FileCopyrightText: 2026 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

      IFNDEF LOADER_H
      DEFINE LOADER_H

      INCLUDE "osconfig.asm"

  IF CONFIG_KERNEL_ENABLE_ELF_BINARY
      DEFC BIN_RAW = 0
      DEFC BIN_ELF = 0x7f     ; First byte of the header
      DEFC ELF_HEADER_SIZE = 52
      
      DEFC LOADER_BUF_SIZE = ELF_HEADER_SIZE

      EXTERN zos_elf_read_header
      EXTERN zos_elf_load
  ELSE
      ; Must be enough to store the stat structure
      DEFC LOADER_BUF_SIZE = 32
  ENDIF

      EXTERN zos_load_file_chunks
      EXTERN g_load_filename
      EXTERN g_load_dev

      ENDIF