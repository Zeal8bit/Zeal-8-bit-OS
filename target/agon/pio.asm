; SPDX-FileCopyrightText: 2023 Shawn Sijnstra <shawn@sijnstra.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "errors_h.asm"
        INCLUDE "drivers_h.asm"
        INCLUDE "interrupt_h.asm"
        INCLUDE "time_h.asm"

        EXTERN video_vblank_isr
        EXTERN keyboard_interrupt_handler

        SECTION KERNEL_DRV_TEXT
        PUBLIC pio_init


; NOTE: for interrupts to work
; MADL needs to be 0 (RSMIX) for interrupts vector I to use MBASE
pio_init:

        ld bc, video_msleep
        ld hl, int_set_vblank
        ld de, int_get_vblank

        call    zos_time_init

        ld a, interrupt_vector_table >> 8
        ld i, a

        ld a, ERR_SUCCESS

        ret

        ; Interrupt handler, called when an interrupt occurs
        ; They shall not be the same but for the moment,
        ; let's say it is the case as only the PIO is the only driver
        ; implemented that uses the interrupts
        PUBLIC interrupt_default_handler
        PUBLIC interrupt_pio_handler
interrupt_default_handler:
        di
        ei
        reti



        ; No exit action at this point. Consider undoing the interrupt changes from boot?
pio_deinit:
        ld a, ERR_SUCCESS
        ret

        ; Perform an I/O requested by the user application.
        ; Parameters:
        ;       B - Dev number the I/O request is performed on.
        ;       C - Command number. Driver-dependent.
        ;       DE - 16-bit parameter, also driver-dependent.
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       A, BC, DE, HL
pio_ioctl:
        ld a, ERR_NOT_IMPLEMENTED
        ret

        ; The following functions don't make sense for the PIO
pio_read:
pio_write:
pio_open:
pio_close:
pio_seek:
        ld a, ERR_NOT_SUPPORTED
        ret

        PUBLIC video_vblank_isr
interrupt_pio_handler:
video_vblank_isr:
        ; Add 16(ms) to the counter
        di
        push    hl
        push    de
        push    af
        SET_GPIO        PB_DR, 2                ; Need to set this to 2 for the interrupt to work correctly

        ld hl, (vblank_count)
        ld de, 16                               ;16 ms is approx 1/60th of a second.
        add hl, de
        ld (vblank_count), hl
        pop     af
        pop     de
        pop     hl
        ei
        reti

        ;======================================================================;
        ;================= P R I V A T E   R O U T I N E S ====================;
        ;======================================================================;
        ; Do not use vblank counter for msleep at the moment, it is less accurate than
        ; the default OS function which counts cycles.
        ; Routine to sleep at least DE milliseconds
        ; Parameters:
        ;       DE - 16-bit duration
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       Can alter any
video_msleep:
        ; Make sure the parameter is no 0
        ld a, d
        or e
        ret z
        ld a,d
        inc a
        jr z,_video_msleep_max
        ld a,e
        and 0xf         ;check if it needs to round up?
        jr z,_video_msleep_start
        ld hl,16        ;timer increment resolution as the round up value
        add hl,de       ;adding a +1 for number of interrupt cycles to round up
        jr nc,_video_msleep_no_carry
_video_msleep_max:
        ld hl,65536-256     ;we maxed out the timer = 65536 - resolution
_video_msleep_no_carry:
        ex de,hl        ;de has the updated timer now
_video_msleep_start:
        ; TODO: Make sure the VBlank interrupt are still enabled?
        ; Each VBlank ticks counts as 16ms, except the first one, so make sure we ignore it
        ; wait for a change on the tick count.
        ld hl, vblank_count
        ; No need to check the most-significant byte
        ld a, (hl)
_video_msleep_ignore:
        halt
        cp (hl)
        ; We can take our time here, use jr
        jr z, _video_msleep_ignore
        ; A change occurred, clean the count and wait for DE ticks
        ld hl, 0
        ld (vblank_count), hl
_video_msleep_wait:
        xor a
        ld hl, (vblank_count)
        sbc hl, de
        jp c, _video_msleep_wait
        ; Success, A is already 0.
        ret


        ; Routines to get the vblank count (can be used as a timer)
        ; Parameters:
        ;       None
        ; Returns:
        ;       DE - time_millis_t data type
        ;       A - ERR_SUCCESS
        ; Alters:
        ;       None
int_get_vblank:
        ld de, (vblank_count)
        xor a
        ret

        ; Routines to set the vblank count (can be used as a timer)
        ; Parameters:
        ;       DE - time_millis_t data type
        ; Returns:
        ;       A - ERR_SUCCESS
        ; Alters:
        ;       None
int_set_vblank:
        ld (vblank_count), de
        xor a
        ret

        SECTION DRIVER_BSS
vblank_count:  DEFS 2

        SECTION KERNEL_DRV_VECTORS
NEW_DRIVER_STRUCT("GPIO", \
                  pio_init, \
                  pio_read, pio_write, \
                  pio_open, pio_close, \
                  pio_seek, pio_ioctl, \
                  pio_deinit)