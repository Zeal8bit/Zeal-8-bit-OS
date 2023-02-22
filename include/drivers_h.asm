; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        IFNDEF DRIVERS_H
        DEFINE DRIVERS_H

        ; Flags to mark whether the driver's write/read functions contains a 32-bit
        ; offset at the top of the stack or not.
        ; The offset is used by filesystem, whereas the absence of offset marks an access
        ; made by a user program directly to the driver (as a block device).
        DEFC DRIVER_OP_HAS_OFFSET = 0
        DEFC DRIVER_OP_NO_OFFSET  = 1

        ; The drivers structure is like this:
        DEFVARS 0 {
                driver_name_t   DS.B 4
                driver_init_t   DS.W 1
                driver_read_t   DS.W 1
                driver_write_t  DS.W 1
                driver_open_t   DS.W 1
                driver_close_t  DS.W 1
                driver_seek_t   DS.W 1
                driver_ioctl_t  DS.W 1
                driver_deinit_t DS.W 1
                driver_end      DS.B 1
        }

        ; Provide a macro for defining a driver structure
        MACRO NEW_DRIVER_STRUCT name, init, read, write, open, close, seek, ioctl, deinit
            DEFS 4, name
            DEFW init
            DEFW read
            DEFW write
            DEFW open
            DEFW close
            DEFW seek
            DEFW ioctl
            DEFW deinit
        ENDM

        ; Macro used to point to the function address at index in the driver (in DE)
        MACRO GET_DRIVER_FUN index
            ld a, index
            add e
            ld e, a
            adc d
            sub e
            ld d, a
            ; Dereference DE to get the function address
            ld a, (de)
            ld l, a
            inc de
            ld a, (de)
            ld h, a
        ENDM

        ; Macro used to reference `open` function from the driver in DE
        MACRO GET_DRIVER_OPEN _
            GET_DRIVER_FUN(driver_open_t)
        ENDM

        ; Macro used to reference `read` function from the driver in DE
        MACRO GET_DRIVER_READ _
            GET_DRIVER_FUN(driver_read_t)
        ENDM

        ; Macro used to reference `write` function from the driver in DE
        MACRO GET_DRIVER_WRITE _
            GET_DRIVER_FUN(driver_write_t)
        ENDM

        ; Macro used to reference `close` function from the driver in DE
        MACRO GET_DRIVER_CLOSE _
            GET_DRIVER_FUN(driver_close_t)
        ENDM

        ; Macro used to reference `ioctl` function from the driver in DE
        MACRO GET_DRIVER_IOCTL _
            GET_DRIVER_FUN(driver_ioctl_t)
        ENDM

        ; Macro used to reference `close` function from the driver in DE
        MACRO GET_DRIVER_SEEK _
            GET_DRIVER_FUN(driver_seek_t)
        ENDM

        ; Maximum length of a driver name
        DEFC DRIVER_NAME_LENGTH = 4

        ; Number of functions in the driver structure
        DEFC DRIVER_STRUCT_FUNCTIONS = 8

        ; Size of the driver structure in bytes
        DEFC DRIVER_STRUCT_SIZE = (DRIVER_NAME_LENGTH + DRIVER_STRUCT_FUNCTIONS * 2)

        ENDIF