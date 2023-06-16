; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    ; Header defining the pages size and virtual addresses. To keep the maximum compatibility
    ; of user programs, this file shall be used in both MMU and MMU-less kernel builds.

    IFNDEF KERN_MMU_H
    DEFINE KERN_MMU_H

    ; Virtual page size is 16KB (so we have 4 pages)
    DEFC KERN_MMU_VIRT_PAGES_SIZE = 0x4000


    ; Virtual pages addresses
    DEFC KERN_MMU_PAGE0_VIRT_ADDR = 0x0000
    DEFC KERN_MMU_PAGE1_VIRT_ADDR = 0x4000
    DEFC KERN_MMU_PAGE2_VIRT_ADDR = 0x8000
    DEFC KERN_MMU_PAGE3_VIRT_ADDR = 0xC000


    ; Macro returning the virtual page index (0-3) of a given 16-bit address.
    ; Only the highest byte is required to calculate the page index.
    ; For example:
    ;   0x0000-0x3fff returns 0 (page 0)
    ;   0x4000-0x7fff returns 1 (page 1)
    ;   0x8000-0xbfff returns 2 (page 2)
    ;   0xc000-0xffff returns 3 (page 3)
    ; Parameters:
    ;   msb (register)- Highest byte of the 16-bit virtual address
    ; Returns:
    ;   A - Page index
    ;   Z flag - Set if A contains 0
    ; Alters:
    ;   A
    MACRO KERNEL_MMU_PAGE_OF_VIRT_ADDR msb
        ld a, msb
        rlca
        rlca
        and 3
    ENDM


    ENDIF ; KERN_MMU_H