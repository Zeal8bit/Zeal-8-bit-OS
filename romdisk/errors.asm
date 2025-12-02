; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    INCLUDE "zos_sys.asm"

    SECTION TEXT

    DEFC LAST_VALID_ERROR = ERR_DIR_NOT_EMPTY

    ; Print a given message and the string of an error.
    ; This is handy for example after a failed syscall.
    ; Parameters:
    ;   DE - Message to print before the error message. If NULL, a default message
    ;        will be printed.
    ;   BC - Size of the message to print
    ;    A - Error code to print the value of
    ; Returns:
    ;   A - ERR_SUCCESS on success, error code else
    ; Alters:
    ;   A, BC, DE, HL
    PUBLIC error_print
error_print:
    push af
    ; Check if DE is NULL. If that's the case, use a default error message.
    ld a, d
    or e
    jp nz, _error_print_no_default
    ; Default error message
    ld de, error_default_message
    ld bc, error_default_message_end - error_default_message
_error_print_no_default:
    S_WRITE1(DEV_STDOUT)
    pop af
    ; Save the error code in B
    ld b, a
    call error_to_string
    ; Check return value
    or a
    ret nz
    ; Put the message to print in DE
    ex de, hl
    ; Get the length of the string
    ld hl, error_table_len
    ; BC = [HL + B]
    ld a, b
    add l
    ld l, a
    adc h
    sub l
    ld h, a
    ; Set the size
    ld b, 0
    ld c, (hl)
    ; Before calling WRITE syscall, replace the last char (NULL-byte) by \n
    ld h, d
    ld l, e
    add hl, bc
    ; Increment the size to include the \n
    inc c
    push hl
    ld (hl), '\n'
    ; Ready for the syscall. (DE = message, BC = length)
    S_WRITE1(DEV_STDOUT)
    ; Restore the NULL-byte
    pop hl
    ld (hl), 0
    ret

        PUBLIC open_error
open_error:
        neg
        ld de, str_open_err
        ld bc, str_open_err_end - str_open_err
        call error_print
        ld a, 1
        ret
str_open_err: DEFM "open error: "
str_open_err_end:

    ; Get the string associated to the given error code
    ; The returned address must NOT be altered.
    ; Parameters:
    ;   A - Error code
    ; Returns:
    ;   HL - Address of the string containing the error string
    ;   A - ERR_SUCCESS on success, ERR_FAILURE if error code was invalid
    ; Alters:
    ;   A, HL
    PUBLIC error_to_string
error_to_string:
    ; Currently, the last
    cp LAST_VALID_ERROR + 1
    jp nc, _error_to_string_invalid
    ; Error code is valid, get the pointer from the table
    ld hl, error_table
    ; HL += A * 2
    ASSERT(LAST_VALID_ERROR < 128)
    rlca    ; A is < 128
    add l
    ld l, a
    adc h
    sub l
    ld h, a
    ; Dereference HL
    ld a, (hl)
    inc hl
    ld h, (hl)
    ld l, a
    ; Return success
    xor a
    ret
_error_to_string_invalid:
    ld a, ERR_FAILURE
    ret


    ; Default error message to be prepended
error_default_message:
    DEFM "error: "
error_default_message_end:

    ; Table that regroups the address of the error strings
    ; Entry i contains the address of the error string for error i
error_table:
    DEFW err_success_str
    DEFW err_failure_str
    DEFW err_not_implemented_str
    DEFW err_not_supported_str
    DEFW err_no_such_entry_str
    DEFW err_invalid_syscall_str
    DEFW err_invalid_parameter_str
    DEFW err_invalid_virt_page_str
    DEFW err_invalid_phys_address_str
    DEFW err_invalid_offset_str
    DEFW err_invalid_name_str
    DEFW err_invalid_path_str
    DEFW err_invalid_filesystem_str
    DEFW err_invalid_filedev_str
    DEFW err_path_too_long_str
    DEFW err_already_exist_str
    DEFW err_already_opened_str
    DEFW err_already_mounted_str
    DEFW err_read_only_str
    DEFW err_bad_mode_str
    DEFW err_cannot_register_more_str
    DEFW err_no_more_entries_str
    DEFW err_no_more_memory_str
    DEFW err_not_a_dir
    DEFW err_not_a_file
    DEFW err_entry_corrupted
    DEFW err_dir_not_empty

    ; Table that regroups the length of the strings listed above
error_table_len:
    DEFB err_failure_str - err_success_str - 1
    DEFB err_not_implemented_str - err_failure_str - 1
    DEFB err_not_supported_str - err_not_implemented_str - 1
    DEFB err_no_such_entry_str - err_not_supported_str - 1
    DEFB err_invalid_syscall_str - err_no_such_entry_str - 1
    DEFB err_invalid_parameter_str - err_invalid_syscall_str - 1
    DEFB err_invalid_virt_page_str - err_invalid_parameter_str - 1
    DEFB err_invalid_phys_address_str - err_invalid_virt_page_str - 1
    DEFB err_invalid_offset_str - err_invalid_phys_address_str - 1
    DEFB err_invalid_name_str - err_invalid_offset_str - 1
    DEFB err_invalid_path_str - err_invalid_name_str - 1
    DEFB err_invalid_filesystem_str - err_invalid_path_str - 1
    DEFB err_invalid_filedev_str - err_invalid_filesystem_str - 1
    DEFB err_path_too_long_str - err_invalid_filedev_str - 1
    DEFB err_already_exist_str - err_path_too_long_str - 1
    DEFB err_already_opened_str - err_already_exist_str - 1
    DEFB err_already_mounted_str - err_already_opened_str - 1
    DEFB err_read_only_str - err_already_mounted_str - 1
    DEFB err_bad_mode_str - err_read_only_str - 1
    DEFB err_cannot_register_more_str - err_bad_mode_str - 1
    DEFB err_no_more_entries_str - err_cannot_register_more_str - 1
    DEFB err_no_more_memory_str - err_no_more_entries_str - 1
    DEFB err_not_a_dir - err_no_more_memory_str - 1
    DEFB err_not_a_file - err_not_a_dir - 1
    DEFB err_entry_corrupted - err_not_a_file - 1
    DEFB err_dir_not_empty - err_entry_corrupted - 1
    DEFB err_dir_not_empty_end - err_dir_not_empty - 1


    ; The strings themselves
err_success_str: DEFM "Success", 0
err_failure_str: DEFM "Failure", 0
err_not_implemented_str: DEFM "Not implemented", 0
err_not_supported_str: DEFM "Not supported", 0
err_no_such_entry_str: DEFM "No such entry", 0
err_invalid_syscall_str: DEFM "Invalid syscall", 0
err_invalid_parameter_str: DEFM "Invalid parameter", 0
err_invalid_virt_page_str: DEFM "Invalid virtual page", 0
err_invalid_phys_address_str: DEFM "Invalid physical address", 0
err_invalid_offset_str: DEFM "Invalid offset", 0
err_invalid_name_str: DEFM "Invalid name", 0
err_invalid_path_str: DEFM "Invalid path", 0
err_invalid_filesystem_str: DEFM "Invalid filesystem", 0
err_invalid_filedev_str: DEFM "Invalid file dev", 0
err_path_too_long_str: DEFM "Path is too long", 0
err_already_exist_str: DEFM "Already exists", 0
err_already_opened_str: DEFM "Already opened", 0
err_already_mounted_str: DEFM "Already mounted", 0
err_read_only_str: DEFM "Read-only device", 0
err_bad_mode_str: DEFM "Bad open mode", 0
err_cannot_register_more_str: DEFM "Cannot register more", 0
err_no_more_entries_str: DEFM "No more entries", 0
err_no_more_memory_str: DEFM "No more memory", 0
err_not_a_dir: DEFM "Not a directory", 0
err_not_a_file: DEFM "Not a file", 0
err_entry_corrupted: DEFM "Entry corrupted", 0
err_dir_not_empty: DEFM "Directory not empty", 0
err_dir_not_empty_end:
