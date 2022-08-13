        INCLUDE "errors_h.asm"
        INCLUDE "osconfig.asm"
        INCLUDE "log_h.asm"
        INCLUDE "vfs_h.asm"
        INCLUDE "drivers_h.asm"

        EXTERN strlen
        EXTERN zos_vfs_write
        EXTERN zos_boilerplate

        SECTION KERNEL_TEXT

        ; The log component will let any other module output texts on the standard output.
        ; If the standard output has not been set up yet, the messages will be copied
        ; to an internal buffer (if configured to do so).
        ; As soon as the standard output is set, the buffer will be flushed to the driver,
        ; and the buffer won't be used anymore.

        PUBLIC zos_log_init
zos_log_init:
        ; Initialize the prefix buffer with '( ) ' 
        ld de, _log_esc
        ld hl, _log_dummy_prefix
        ld bc, _log_dummy_prefix_end - _log_dummy_prefix
        ldir
        ; Set the logging to buffer first
        ld a, LOG_IN_BUFFER
        ld (_log_property), a
        ret

_log_dummy_prefix: DEFM 0x1b, "[30m( ) "
_log_dummy_prefix_end:

        ; Routine called as soon as stdout is set in the VFS
        ; In our case, we will print the system boilerplate
        ; if this is the first time the stdout is set.
        ; In other words, print the boielrplate if we are booting.
        ; Parameters:
        ;       HL - STDOUT driver 
        PUBLIC zos_log_stdout_ready
zos_log_stdout_ready:
        ; We are going to optimize this a bit. Instead of calling vfs function
        ; to write to the stdout, we will directly comunicate with the driver.
        push hl
        push de
        ex de, hl
        GET_DRIVER_WRITE()
        ld (_log_write_fun), hl
        pop de
        pop hl
        ld a, (_log_plate_printed)
        or a
        ret nz
        ; If this is the first time we come here, print the boilerplate
        inc a
        ld (_log_plate_printed), a
        ; Set the property to log on stdout now instead of buffer
        ; TODO: Flush the buffer
        ld a, LOG_ON_STDOUT
        ld (_log_property), a
        push hl
        xor a   ; No prefix to print
        ld hl, zos_boilerplate
        call zos_log_message
        pop hl
        ret

        PUBLIC zos_log_error
zos_log_error:
        IF CONFIG_KERNEL_LOG_SUPPORT_ANSI_COLOR
        ; Set the color to red (31) in the escape sequence
        ld a, '1'
        ld (_log_esc + 3), a
        ENDIF

        ld a, 'E'
        jr zos_log_message

        PUBLIC zos_log_warning
zos_log_warning:
        IF CONFIG_KERNEL_LOG_SUPPORT_ANSI_COLOR
        ; Set the color to yellow (33) in the escape sequence
        ld a, '3'
        ld (_log_esc + 3), a
        ENDIF

        ld a, 'W'
        jr zos_log_message

        PUBLIC zos_log_info
zos_log_info:
        IF CONFIG_KERNEL_LOG_SUPPORT_ANSI_COLOR
        ; Set the color to green (32) in the escape sequence
        ld a, '2'
        ld (_log_esc + 3), a
        ENDIF

        ld a, 'I'
        ; Fallthrough

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
        push bc
        ld b, a
        ld a, (_log_property)
        cp LOG_DISABLED
        jr z, _zos_log_popbc_ret
        cp LOG_IN_BUFFER
        jr z, _zos_log_buffer
        ; Do not alter parameters
        push hl
        push de
        ; Check if we need to print the prefix
        ld a, b
        or a
 IF CONFIG_KERNEL_LOG_SUPPORT_ANSI_COLOR
        push af
 ENDIF
        jp z, _zos_log_no_prefix
        ; Set the letter to put in the ( )
        ld (_log_prefix + 1), a
 IF CONFIG_KERNEL_LOG_SUPPORT_ANSI_COLOR
        ld de, _log_esc
        ld bc, _log_esc_end - _log_esc
 ELSE
        ld de, _log_prefix
        ld bc, _log_esc_end - _log_prefix        
 ENDIF
        push hl
        call _zos_log_call_write
        pop hl
_zos_log_no_prefix:
        ; Calculate the length of the string in HL
        call strlen
        ex de, hl
        call _zos_log_call_write
 IF CONFIG_KERNEL_LOG_SUPPORT_ANSI_COLOR
        ; If Z flag is NOT set, we had a prefix, we have to write
        ; the end of the escape sequence
        pop af
        call nz, _zos_log_write_end_seq
 ENDIF
        pop de
        pop hl
_zos_log_popbc_ret:
        pop bc
        ret
_zos_log_buffer:
        ; TODO: implement with a ringbuffer?
        pop bc
        ret
        
        IF CONFIG_KERNEL_LOG_SUPPORT_ANSI_COLOR
_zos_log_write_end_seq:
        ld de, _log_postfix
        ld bc, _log_postfix_end - _log_postfix
        jp _zos_log_call_write
        ENDIF

        ; Private routine to call the driver's write function
        ; Parameters:
        ;       DE - Buffer to print
        ;       BC - Size
        ; Alters:
        ;       A, BC, DE, HL
_zos_log_call_write:
        ; Driver's write function needs 32-bit on the stack.
        ; No need to push the return address as we are not returning
        ; from it.
        ld hl, 0
        push hl
        push hl
        ; Load the function address
        ld hl, (_log_write_fun)
        ; Check if the funciton is 0!
        ld a, h
        or l
        ret z
        jp (hl)

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

_log_postfix: DEFB 0x1b, '[', '0', 'm' ; Escape sequence
_log_postfix_end:

        SECTION KERNEL_BSS
_log_plate_printed: DEFS 1
_log_write_fun:     DEFS 2
_log_property:      DEFS 1
_log_esc:           DEFS 5 ; RAM for '\x1b[XYm'
_log_prefix:        DEFS 4 ; RAM for '(W) ' where XY is escape sequence code (4 chars)
_log_esc_end:

        ASSERT(_log_dummy_prefix_end - _log_dummy_prefix == _log_esc_end - _log_esc)


        IF CONFIG_LOG_BUFFER_SIZE > 0
_log_index:  DEFS 2
_log_buffer: DEFS CONFIG_LOG_BUFFER_SIZE
        ENDIF