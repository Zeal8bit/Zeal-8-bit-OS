        INCLUDE "errors_h.asm"
        INCLUDE "osconfig.asm"
        INCLUDE "log_h.asm"
        INCLUDE "vfs_h.asm"

        EXTERN strlen
        EXTERN zos_vfs_write

        SECTION KERNEL_TEXT

        ; The log component will let any other module output texts on the standard output.
        ; If the standard output has not been set up yet, the messages will be copied
        ; to an internal buffer (if configured to do so).
        ; As soon as the standard output is set, the buffer will be flushed to the driver,
        ; and the buffer won't be used anymore.

        PUBLIC zos_log_init
zos_log_init:
        ; Initialize the prefix buffer with '( ) ' 
        ld hl, _log_prefix
        ld (hl), '('
        inc hl
        inc hl
        ld (hl), ')'
        inc hl
        ld (hl), ' '
        ; Set the logging to buffer first
        ld a, LOG_IN_BUFFER
        ld (_log_property), a
        ret

        PUBLIC zos_log_error
zos_log_error:
        ld a, 'E'
        jr zos_log_message

        PUBLIC zos_log_warning
zos_log_warning:
        ld a, 'W'
        jr zos_log_message

        PUBLIC zos_log_info
zos_log_info:
        ld a, 'I'

        ; Log a message in the log buffer or STDOUT
        ; Parameters:
        ;       A - Letter to put in between the () prefix
        ;       HL - Message to print
        ; Returns:
        ;       None
        ; Alters:
        ;       A
        PUBLIC zos_log_message
zos_log_message:
        or a    ; If A is 0, do not add prefix
        jp z, _zos_log_no_prefix
        ; If we have to stop logging for a while, don't go further
        ld (_log_prefix + 1), a
        ld a, (_log_property)
        cp LOG_DISABLED
        ret nz
        cp LOG_IN_BUFFER
        jr z, _zos_log_buffer
        ; Do not alter BC
        push bc
        ; zos_vfs_write doen't save HL
        push de
        ; Check if we need to print the prefix
        ld a, (_log_prefix + 1)
        or a
        jp z, _zos_log_no_prefix
        push hl
        ; Log on stdout thanks to the VFS
        ld h, STANDARD_OUTPUT
        ld de, _log_prefix
        ld bc, 4
        call zos_vfs_write
_zos_log_no_prefix:
        ; HL is popped by VFS routines
        call strlen
        push hl
        ex de, hl
        ld h, STANDARD_OUTPUT
        call zos_vfs_write
        pop de
        pop bc
        ret

_zos_log_buffer:
        ret


        ; Modify logging properties. For example, this lets logging only append in the
        ; log buffer and not on the actual hardware.
        ; Parameters:
        ;       A - Flags for the logging module
        ; Returns:
        ;       None
        ; Alters:
        ;       None 
zos_log_set_property:
        ld (_log_property), a
        ret

_zos_log_invalid_parameters:
        ld a, ERR_INVALID_PARAMETER
        ret

        SECTION KERNEL_BSS
_log_property: DEFS 1
_log_prefix: DEFS 4 ; RAM for '(W) ' (4 chars)
        IF CONFIG_LOG_BUFFER_SIZE > 0
_log_index: DEFS 2
_log_buffer: DEFS CONFIG_LOG_BUFFER_SIZE
        ENDIF