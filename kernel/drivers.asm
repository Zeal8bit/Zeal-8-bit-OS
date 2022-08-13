; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "osconfig.asm"
        INCLUDE "drivers_h.asm"
        INCLUDE "errors_h.asm"
        INCLUDE "utils_h.asm"
        INCLUDE "vfs_h.asm"
        INCLUDE "log_h.asm"

        ; Forward declaraction of symbols used below
        EXTERN zos_drivers_init
        EXTERN _vfs_work_buffer
        EXTERN byte_to_ascii
        EXTERN __KERNEL_DRV_VECTORS_head
        EXTERN __KERNEL_DRV_VECTORS_size

        SECTION KERNEL_TEXT

        PUBLIC zos_drivers_init
zos_drivers_init:
        ; Initialize the messages, use the global usable buffer
        ld hl, _driver_log_success
        ld de, _vfs_work_buffer
        ld bc, _driver_log_end - _driver_log_success
        ldir

        ; Browse the driver vectors and try to initialize them all
        ld hl, __KERNEL_DRV_VECTORS_head
        ; Load the size of the vectors in B
        ; Unfortunately, we can't assert on a linker symbol
        ld b, __KERNEL_DRV_VECTORS_size / driver_end

_zos_driver_init_next_driver:
        ; HL points to the name of the driver
        call zos_driver_name_valid     ; Check if the name is valid
        jp nc, _zos_valid_name
        ; Invalid name
        ld a, ERR_INVALID_NAME
        call _zos_driver_log_error
        ; Log that this driver has an invalid name
        jp _zos_next_driver
_zos_valid_name:
        call zos_driver_find_by_name     ; Check if the name already exists
        jp nz, _zos_register_driver
        ; Driver name already exists
        ld a, ERR_ALREADY_EXIST
        call _zos_driver_log_error
        jp _zos_next_driver        
_zos_register_driver:
        ; Register the driver in the list
        call zos_driver_register
        or a
        ; Log success will not alter the flags, so if Z is set when entering
        ; the routine, it will be set when exiting the routine.
        call z, _zos_driver_log_success
        call nz, _zos_driver_log_error
_zos_next_driver:
        ; Skip to the next driver in the list
        ld a, driver_end
        ADD_HL_A()
        djnz _zos_driver_init_next_driver
        ; Log finished registering drivers
        ret

_driver_log_success: DEFM "Driver: .... init success\n", 0
_driver_log_failed: DEFM "Driver: .... init failed, error $..\n", 0
_driver_log_end:

        DEFC SUCCESS_MESSAGE_LEN = _driver_log_failed - _driver_log_success
        DEFC FAILED_MESSAGE_LEN = _driver_log_end - _driver_log_failed
        DEFC LOG_MESSAGES_LEN = FAILED_MESSAGE_LEN + SUCCESS_MESSAGE_LEN
        ASSERT(VFS_WORK_BUFFER_SIZE >= SUCCESS_MESSAGE_LEN + FAILED_MESSAGE_LEN)

        ; Copies the driver name and the error to the log buffer.
        ; Then calls the error log function.
        ; Parameters:
        ;       HL - Driver name (4 characters)
        ;       A - Error code
        ; Alters:
        ;       A, C, DE
_zos_driver_log_error:
        ; Setting C to DRIVER_NAME_LENGTH will prevent any modification
        ; on B when performing ldir
        ld c, DRIVER_NAME_LENGTH
        push hl
        ; Point to the log failed message
        ld de, _vfs_work_buffer + SUCCESS_MESSAGE_LEN + 8
        REPT DRIVER_NAME_LENGTH
        ldi
        ENDR
        ; Point to failed log message's error code 
        ld hl, _vfs_work_buffer + LOG_MESSAGES_LEN - 4
        call byte_to_ascii
        ld (hl), d
        inc hl
        ld (hl), e
        ld hl, _vfs_work_buffer + SUCCESS_MESSAGE_LEN
        call zos_log_error
        pop hl
        ret
        ; Same as above but with a success
_zos_driver_log_success:
        ; Setting C to DRIVER_NAME_LENGTH will prevent any modification
        ; on B when performing ldir
        ld c, DRIVER_NAME_LENGTH
        push hl
        ; Point to the log failed message
        ld de, _vfs_work_buffer + 8
        REPT DRIVER_NAME_LENGTH
        ldi
        ENDR
        ld hl, _vfs_work_buffer
        call zos_log_info
        pop hl
        ; Do not alter former flags 
        or a
        ret

        ; Checks whether the name has already been registered
        ; Parameters:
        ;       HL - Address of the string
        ; Returns:
        ;       A  - 0 if exists, non-zero else
        ;       DE - Address of the existing drivers (if any)
        ; Alters:
        ;       A, DE
        PUBLIC zos_driver_find_by_name
zos_driver_find_by_name:
        ; If we have no drivers, returns 1 directly
        ld a, (_loaded_drivers_count)
        or a
        jp nz, _zos_driver_find_by_name_start
        inc a
        ret
_zos_driver_find_by_name_start:
        push bc
        ; Save HL as it must not be destroyed 
        push hl
        ; Calculate the offset in the loaded drivers array
        ld hl, _loaded_drivers
_zos_driver_find_by_name_loop:
        ; Dereference the value in the array
        ; DE = *(HL)
        ld e, (hl)
        inc hl
        ld d, (hl)
        inc hl
        ; DE is the string address from the array, HL is its address
        ; But the string to compare it with is on the top of the stack
        ex (sp), hl
        ; Load the maximum length
        ld bc, DRIVER_NAME_LENGTH
        call strncmp
        or a
        ; If they are identical, A will be equal to 0
        jp z, _zos_driver_find_by_name_already_exists
        ; Not the same, try the next one which is on the stack
        ex (sp), hl
        inc hl
        inc hl
        ld a, _loaded_drivers_end & 0xff
        cp l
        jp nz, _zos_driver_find_by_name_loop
        ld a, _loaded_drivers_end >> 8
        sub h
        jp nz, _zos_driver_find_by_name_loop
        ; End of the array, entry doesn't exist!
        inc a   ; return A strictly positive
_zos_driver_find_by_name_already_exists:
        pop hl
        pop bc
        ret

        ;======================================================================;
        ;================= P R I V A T E   R O U T I N E S ====================;
        ;======================================================================;

        ; Checks whether the string passed as a parameter is a valid driver
        ; name. In other words, it tests if all the characters are alpha-numerical 
        ; Parameters:
        ;       HL - Address of the string
        ; Returns:
        ;       A - 0 if invalid, non-zero else
        ; Alters:
        ;       A, DE
zos_driver_name_valid:
        ld d, h
        ld e, l
        ld a, (de)
        call is_alpha_numeric
        ret c
        REPT (DRIVER_NAME_LENGTH - 1)
        inc de
        ld a, (de)
        call is_alpha_numeric
        ret c
        ENDR
        ret

        ; Registers the driver pointed by HL in the array of loaded drivers 
        ; Parameters:
        ;       HL - Address of the driver to register
        ; Returns:
        ;       A - 0 on success, error code else
        ; Alters:
        ;       A, DE
zos_driver_register:
        ; Check if we can still register a driver
        ld a, (_loaded_drivers_count)
        cp CONFIG_KERNEL_MAX_LOADED_DRIVERS
        jr z, _zos_driver_register_full
        ; Call the driver's init function first
        ; Save HL and BC as we need them in the caller
        push bc
        push hl
        ; Optimize a bit
        ASSERT(driver_init_t == 4)
        inc hl
        inc hl
        inc hl
        inc hl
        ; Dereference HL into DE, then exchange
        ld e, (hl)
        inc hl
        ld d, (hl)
        ex de, hl
        ; Perform a call to a register address (HL)
        CALL_HL()
        pop hl
        pop bc
        ; If it succeeded but is hidden, return (but as a success)
        ASSERT(ERR_DRIVER_HIDDEN == 255)
        inc a
        ret z
        ; Was not ERR_DRIVER_HIDDEN, restore A
        dec a
        ; If the driver's init didn't return ERR_SUCCESS, don't try to save it
        ret nz
        ; Save HL in DE
        ex de, hl
        ; Look for an empty spot in the array
        ; We are sure that drivers cannot be in the first 256 bytes of the
        ; virtual memory, thus we can simply check the upper 8-bit of address
        xor a
        ld hl, _loaded_drivers + 1
_zos_driver_register_loop:
        cp (hl)
        jp z, _zos_driver_register_found
        inc hl
        inc hl
        jp _zos_driver_register_loop
_zos_driver_register_found:
        ; As HL is pointing to the upper 8-bit, save these first
        ld (hl), d
        dec hl
        ld (hl), e
        ; Increment _loaded_drivers_count before restoring HL
        ld hl, _loaded_drivers_count
        inc (hl)
        ex de, hl
        ; Return success, optimize a bit
        xor a
        ret
_zos_driver_register_full:
        ld a, ERR_CANNOT_REGISTER_MORE
        ret

        IF 0
        ; Calculate string's hash value
        ; Parameters:
        ;       HL - String to calculate the hash of
        ; Returns:
        ;       A - Hash value between 0 and DRIVER_NAME_LENGTH - 1
        ; Alters:
        ;       A, C, DE
zos_hash_name:
        ld d, h
        ld e, l
        ld a, 5
        REPT DRIVER_NAME_LENGTH
        ld c, a
        ; A = A << 5 (on 8-bit)
        rrca
        rrca
        rrca
        and 0b11100000
        ; A += C
        add c
        ; A += *str++
        add (hl)
        inc hl
        ENDR
        ex de, hl
        ; Return A % DRIVER_NAME_LENGTH
        and DRIVER_NAME_LENGTH - 1
        ret
        ENDIF

        SECTION KERNEL_BSS
; Allocate 8-bit for the current number of drivers
_loaded_drivers_count: DEFS 1 
; Allocate 2 bytes per cell, each cell contains a pointer to the driver structure.
_loaded_drivers: DEFS CONFIG_KERNEL_MAX_LOADED_DRIVERS * 2 
_loaded_drivers_end:
; Log message
_driver_log_msg: DEFS 16