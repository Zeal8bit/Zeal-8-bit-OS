; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        ; File regrouping all the time-related routines, it includes
        ; timers, clocks, dates and sleep
        INCLUDE "errors_h.asm"
        INCLUDE "time_h.asm"
        INCLUDE "utils_h.asm"
        INCLUDE "osconfig.asm"

        EXTERN zos_sys_remap_de_page_2

        SECTION KERNEL_TEXT

        ; Initialize the time interface. This routine is meant to
        ; be called by a driver. Indeed, it must pass three pointers
        ; which are the addresses to the msleep, settime, gettime routines
        ; respectively.
        ; Parameters:
        ;       BC - Address of msleep (if NULL, a default one will be used)
        ;       HL - Address of settime (can be NULL)
        ;       DE - Address of gettime (can be NULL)
        ;       Note: The given functions can alter any register.
        ; Returns:
        ;       A - ERR_SUCCESS on success, other error code else
        ; Alters:
        ;       A
        PUBLIC zos_time_init
zos_time_init:
        ld (_zos_time_driver_msleep), bc
        ld (_zos_time_driver_settime), hl
        ld (_zos_time_driver_gettime), de
        xor a
        ret


        ; Check whether a time and a date drivers are available
        ; Parameters:
        ;       None
        ; Returns:
        ;       A - Bit 0: Timer available if 1, else 0
        ;           Bit 1: Date available if 1, else 0
        ; Alters:
        ;       A, B, HL
        PUBLIC zos_time_is_available
zos_time_is_available:
        ld b, 3
        ld hl, (_zos_time_driver_gettime)
        ld a, h
        or l
        jr nz, _zos_time_is_date_available
        dec b ; Remove bit 0
_zos_time_is_date_available:
        ld hl, (_zos_date_driver_getdate)
        ld a, h
        or l
        ld a, b
        ret nz
        ; Reset bit 1, keep only bit 0
        and 1
        ret

        ; Sleep for a given amount of time, in milliseconds.
        ; Parameters:
        ;       DE - 16-bit duration (maximum 65 seconds)
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       A, HL
        PUBLIC zos_time_msleep
zos_time_msleep:
        ; Check if we have a custom implementation for this routine
        ld hl, (_zos_time_driver_msleep)
        ld a, h
        or l
        jp z, _zos_time_msleep_default
        ; BC and DE must not be altered
        push bc
        push de
        CALL_HL()
        pop de
        pop bc
        ret
_zos_time_msleep_default:
        ; If DE is 0, we can return directly.
        ld a, d
        or e
        ret z
        ; We could use gettime and settime, but let's just count
        ; the CPU instructions for now.
        push de
        push bc
_zos_waste_time_again:
        ; Divide by 1000 to get the number of T-states per milliseconds
        ; 24 is the number of T-states below
        ld bc, CONFIG_CPU_FREQ / 1000 / 24
_zos_waste_time:
        ; 24 T-states for the following, until 'jp nz, _zos_waste_time'
        dec bc
        ld a, b
        or c
        jp nz, _zos_waste_time
        ; If we are here, a milliseconds has elapsed
        dec de
        ld a, d
        or e
        jp nz, _zos_waste_time_again
        pop bc
        pop de
        xor a
        ret


        ; Routine to manually set/reset the time counter, in milliseconds.
        ; Parameters:
        ;       H - Id of the clock (for future use, unused for now)
        ;       DE - time_millis_t data type. At the moment, DE contains
        ;            the value directly. In the future, it is possible that
        ;            this value becomes a pointer to a bigger structure.
        ; Returns:
        ;       A - ERR_SUCCESS on success,
        ;           ERR_NOT_IMPLEMENTED if target doesn't implement this feature
        ;           error code else
        ; Alters:
        ;       A, HL
        PUBLIC zos_time_settime
zos_time_settime:
        ld hl, (_zos_time_driver_settime)
        ld a, h
        or l
        ld a, ERR_NOT_IMPLEMENTED
        ret z
        ; Save the registers that shall not be modified
        push bc
        push de
        CALL_HL()
        pop de
        pop bc
        ret


        ; Routine to get the time counter, in milliseconds.
        ; The granularity is dependent on the implementation, it could be 1ms
        ; 16ms, or more. The user should be aware of this when calling this
        ; routine. 
        ; Parameters:
        ;       H - Id of the clock (for future use, unused for now)
        ; Returns:
        ;       A - ERR_SUCCESS on success,
        ;           ERR_NOT_IMPLEMENTED if target doesn't implement this feature
        ;           error code else
        ;       DE - time_millis_t data type. At the moment, DE contains
        ;            the value directly. (not a pointer)
        ; Alters:
        ;       A, HL
        PUBLIC zos_time_gettime
zos_time_gettime:
        ld hl, (_zos_time_driver_gettime)
        ld a, h
        or l
        ld a, ERR_NOT_IMPLEMENTED
        ret z
        ; Only BC needs to be saved as DE contains the return value
        push bc
        CALL_HL()
        pop bc
        ret

        ; ------------------------ DATE RELATED ------------------------;

        ; Initialize the date interface implementation. This routine is meant
        ; to be called by a driver. Indeed, it must pass two pointers
        ; which are the addresses to the setdate and getdate routines
        ; respectively.
        ; Parameters:
        ;       HL - Address of setdate (can be NULL)
        ;       DE - Address of getdate (can be NULL)
        ;       Note: The given functions can alter any register.
        ; Returns:
        ;       A - ERR_SUCCESS on success, other error code else
        ; Alters:
        ;       A
        PUBLIC zos_date_init
zos_date_init:
        ld (_zos_date_driver_setdate), hl
        ld (_zos_date_driver_getdate), de
        xor a
        ret


        ; Routine to set system date (usually used when an RTC is available)
        ; Parameters:
        ;       DE - Address to a date structure, as defined in the time_h.asm header file.
        ;            Must not be NULL
        ; Returns:
        ;       A - ERR_SUCCESS on success,
        ;           ERR_NOT_IMPLEMENTED if target doesn't implement this feature
        ;           error code else
        ; Alters:
        ;       A 
        PUBLIC zos_date_setdate
zos_date_setdate:
        ld hl, (_zos_date_driver_setdate)
_zos_date_check_bc_call_hl:
        ld a, h
        or l
        ld a, ERR_NOT_IMPLEMENTED
        ret z
        ld a, d
        or e
        ld a, ERR_INVALID_PARAMETER
        ret z
        ; DE should be remapped if pointing to user's stack area
        push de
        call zos_sys_remap_de_page_2
        ; Save the registers that shall not be modified
        push bc
        CALL_HL()
        pop bc
        pop de
        ret


        ; Routine to get system date (usually used when an RTC is available)
        ; Parameters:
        ;       BC - Address to a date structure to fill, as defined in the
        ;            time_h.asm header file. Must not be NULL.
        ; Returns:
        ;       A - ERR_SUCCESS on success,
        ;           ERR_NOT_IMPLEMENTED if target doesn't implement this feature
        ;           error code else
        ; Alters:
        ;       A 
        PUBLIC zos_date_getdate
zos_date_getdate:
        ld hl, (_zos_date_driver_getdate)
        jp _zos_date_check_bc_call_hl

        SECTION KERNEL_BSS
        ; Time routines
_zos_time_driver_msleep: DEFW 1
_zos_time_driver_settime: DEFW 1
_zos_time_driver_gettime: DEFW 1
        ; Date routines
_zos_date_driver_setdate: DEFW 1
_zos_date_driver_getdate: DEFW 1
