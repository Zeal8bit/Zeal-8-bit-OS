; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0


    ; Search the given partition type in the MBR header. If found, the first oen will
    ; be returned. The LBA start partition will be returned, CHS is ignored.
    ; Parameters:
    ;   E  - Partition type to look for
    ;   HL - Buffer containing the MBR data (512 bytes), can be unaligned
    ; Returns:
    ;   A - ERR_SUCCESS if the partition was found
    ;       ERR_NO_SUCH_ENTRY if there is no such partition
    ;       ERR_INVALID_FILESYSTEM if the buffer is not an MBR
    ;   DEHL - LBA of the first absolute sector in the partition
    ; Alters:
    ;   A, BC, DE, HL
    EXTERN mbr_search_partition
