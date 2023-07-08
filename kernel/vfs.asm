; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "osconfig.asm"
        INCLUDE "mmu_h.asm"
        INCLUDE "vfs_h.asm"
        INCLUDE "errors_h.asm"
        INCLUDE "disks_h.asm"
        INCLUDE "drivers_h.asm"
        INCLUDE "utils_h.asm"
        INCLUDE "strutils_h.asm"

        EXTERN zos_sys_remap_bc_page_2
        EXTERN zos_sys_remap_de_page_2
        EXTERN zos_sys_remap_user_pages
        EXTERN zos_driver_find_by_name
        EXTERN zos_log_stdout_ready

        SECTION KERNEL_TEXT

        DEFC VFS_DRIVER_INDICATOR = '#'

        PUBLIC zos_vfs_init
zos_vfs_init:
        ; The CPU will write the lowest byte first, so first char in L
        ld hl, ':' << 8 | DISK_DEFAULT_LETTER
        ld (_vfs_current_dir), hl
        ; MSB is 0
        ld hl, '/'
        ld (_vfs_current_dir + 2), hl
        ret


        ; Routine called after a program exited, all the opened devs need to be closed
        ; The default stdout and stdin need to be restored in the array.
        ; Parameters:
        ;       None
        ; Returns:
        ;       None
        ; Alters:
        ;       A, BC, DE, HL
        PUBLIC zos_vfs_clean
zos_vfs_clean:
        ; Set the current dir to the default location
        call zos_vfs_init
        ; Close all the opened devs, even stdout and stdin
        ld b, CONFIG_KERNEL_MAX_OPENED_DEVICES
_zos_vfs_clean_close:
        ld h, b
        dec h
        ; Ignore return value of zos_vfs_close as some may be invalid
        call zos_vfs_close
        djnz _zos_vfs_clean_close
        ; Fall-through

        ; Populate the stdin and stdout in the opened dev table.
        ; Call their respective open function again.
        ; Parameters:
        ;       None
        ; Returns:
        ;       None
        ; Alters:
        ;       HL
        PUBLIC zos_vfs_restore_std
zos_vfs_restore_std:
        ; Populate the stdout and stdin entries
        ld hl, (_dev_default_stdout)
        ld (_dev_table), hl
        ld hl, (_dev_default_stdin)
        ld (_dev_table + 2), hl
        ret

        ; Routine to set the default stdout of the system.
        ; This is where the logs will go by defaults.
        ; Parameters:
        ;       HL - Pointer to the driver. Must be in Kernel BSS or TEXT.
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       A
        PUBLIC zos_vfs_set_stdout
zos_vfs_set_stdout:
        ; Test for a NULL pointer
        ld a, h
        or l
        jp z, _zos_vfs_invalid_parameter
        ld (_dev_default_stdout), hl
        ; Should it call driver's open function?
        ; If entry STANDARD_OUTPUT is null, fill it now
        push hl
        ld hl, (_dev_table + STANDARD_OUTPUT * 2)
        ld a, h
        or l
        pop hl
        jr nz, _zos_vfs_set_stdout_no_set
        ld (_dev_table + STANDARD_OUTPUT * 2), hl
_zos_vfs_set_stdout_no_set:
        call zos_log_stdout_ready
        xor a   ; Optimization for A = ERR_SUCCESS
        ret

        ; Routine to set the default stdin of the system.
        ; Parameters:
        ;       HL - Pointer to the driver. Must be in Kernel BSS or TEXT.
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       A
        PUBLIC zos_vfs_set_stdin
zos_vfs_set_stdin:
        ; Test for a NULL pointer
        ld a, h
        or l
        jp z, _zos_vfs_invalid_parameter
        ld (_dev_default_stdin), hl
        ; If entry STANDARD_INPUT is null, fill it now
        push hl
        ld hl, (_dev_table + STANDARD_INPUT * 2)
        ld a, h
        or l
        pop hl
        ld a, ERR_SUCCESS
        ret nz
        ld (_dev_table + STANDARD_INPUT * 2), hl
        ; Should it call driver's open function?
        ret

_zos_vfs_invalid_parameter_popdehl:
        pop de
_zos_vfs_invalid_parameter_pophl:
        pop hl
_zos_vfs_invalid_parameter:
        ld a, ERR_INVALID_PARAMETER
        ret


        ; Routines used to interact with the drivers

        ; Open the given file or driver
        ; Drivers name shall not exceed 4 characters and must be preceded by VFS_DRIVER_INDICATOR (#)
        ; (5 characters in total)
        ; Names not starting with # will be considered as files.
        ; Parameters:
        ;       BC - Name: driver or file
        ;       H - Flags, can be O_RDWR, O_RDONLY, O_WRONLY, O_NONBLOCK, O_CREAT, O_APPEND, etc...
        ;           It is possible to OR them.
        ; Returns:
        ;       A - Number for the newly opened dev on success, negated error value else.
        ; Alters:
        ;       A
        PUBLIC zos_vfs_open
        ; Internal one doesn't perform a buffer address check
        PUBLIC zos_vfs_open_internal
zos_vfs_open:
        push bc
        push de
        call zos_sys_remap_bc_page_2
        call zos_vfs_open_internal
        pop de
        pop bc
        ret
zos_vfs_open_internal:
        ; Check if NULL given as a parameter
        ld a, b
        or c
        ; Error have to be negated in such cases
        ld a, -ERR_INVALID_PARAMETER
        ret z
        ; TODO: Call check_buffer to make sure the string is not overlapping two pages
        ; Check that we have room in the dev table, save the flags in D first.
        ld d, h
        call zos_vfs_find_entry
        ; The empty entry to fill is in HL now
        or a
        jp nz, _zos_vfs_open_ret_error
        ; Check if the given path points to a driver or a file
        ld a, (bc)
        cp VFS_DRIVER_INDICATOR
        jp z, _zos_vfs_open_driver
        ; Save the empty entry address because we are going to need HL now
        push hl
        ; We need to allocate at least CONFIG_KERNEL_PATH_MAX and point it from DE.
        ; Allocate on the stack 256 bytes.
        ASSERT(CONFIG_KERNEL_PATH_MAX <= 256)
        ALLOC_STACK_256()       ; Alters HL
        ; Flags are in D, they will get overwritten by this next call
        push de
        ; HL contains the destination address, put it in DE instead
        ex de, hl
        call zos_get_full_path
        ; No matter what the return value is, BC won't be used from now on
        ; Use it to restore the flags (in B)
        pop bc
        ; Check if an error occurred
        or a
        jp nz, _zos_vfs_open_deallocate_stack_error
        ; Retrieve the current disk from the path and save it C (B has the flags already)
        ld a, (de)
        ld c, a
        ; Make DE point to the path after X:
        inc de
        inc de
        ; We can now pass the path to the disk API.
        ; Parameters:
        ;       B - Flags, can be O_RDWR, O_RDONLY, etc...
        ;       C - Disk letter
        ;       HL - Absolute path to the file (without X:)
        ; This call saves none of the register A, BC, DE and HL.
        ex de, hl
        call zos_disk_open_file
        ; Restore the stack pointer, A and HL cannot be used, they contain the return values
        ; but DE and BC can be used, so let's use DE to store the returned value.
        ex de, hl
        FREE_STACK_256()
        ; Pop the empty entry address from the stack too
        pop hl
        ; Check if an error occurred
        or a
        jp nz, _zos_vfs_open_ret_error
_zos_vfs_open_save_entry:
        ; Else, we have to save the returned context in our array
        ld (hl), e
        inc hl
        ld (hl), d
        ; Load and return the index of the current entry
        ld a, (_dev_table_empty_entry)
        ret
_zos_vfs_open_deallocate_stack_error:
        ; An error occurred, de-allocate the stack and return the error
        FREE_STACK_256()        ; Alters HL only, register A unmodified
        ; Pop HL (empty entry address) from the stack
_zos_vfs_open_pop_ret_error:
        pop hl
_zos_vfs_open_ret_error:
        ; Negate the error
        neg
        ret
        ; A driver has been requested to be opened
_zos_vfs_open_driver:
        ; Open a driver, the length of the driver name must be 4
        ; HL - The address of the empty dev entry
        ; BC - Driver name (including #)
        ; D - Flags
        inc bc
        push hl
        ; The length will be check by zos_driver_find_by_name, no need to do it here
        ; Put the driver name in HL instead of BC. Flags in B.
        ld h, b
        ld l, c
        ld b, d
        call zos_driver_find_by_name
        ; If the driver exists, A is 0, else A is positive
        or a
        ; Set the correct return value for A (instead of Failure), it won't modify the flags
        ld a, ERR_NO_SUCH_ENTRY
        jp nz, _zos_vfs_open_pop_ret_error
        ; Success, DE contains the driver address, HL contains the name and top of stack contains
        ; the address of the empty dev entry.
        ; Before saving the driver as opened, we have to execute its "open" routine, which MUST succeed!
        ; Parameters:
        ;       BC - Name of the opened driver
        ;       H - Flags to pass to it
        ; After this, we will still need DE (driver address).
        push de
        ; Prepare the name, put the name in BC (instead of HL)
        push bc ; Save the open flags parameter (in register B)
        ld b, h
        ld c, l
        ; Driver is in DE, get the open function address in HL
        GET_DRIVER_OPEN_FROM_DE()
        ; Set the opened dev number in D
        ld a, (_dev_table_empty_entry)
        ld d, a
        ; Retrieve the opening flags (A) from the stack
        pop af
        CALL_HL()
        pop de  ; pop driver address from the stack
        pop hl  ; pop the address of the empty dev from the stack
        ; Check the return value
        or a
        ; On success, save the driver (DE) inside the empty spot (HL)
        jp z, _zos_vfs_open_save_entry
        ; Error, negate and return (faster than jp/jr)
        neg
        ret


        ; Read the given dev number
        ; Parameters:
        ;       H  - Number of the dev to read from.
        ;       DE - Buffer to store the bytes read from the dev, the buffer must NOT cross page boundary.
        ;       BC - Size of the buffer passed, maximum size is a page size.
        ; Returns:
        ;       A  - 0 on success, error value else
        ;       BC - Number of bytes filled in DE.
        ; Alters:
        ;       A, BC
        PUBLIC zos_vfs_read
        PUBLIC zos_vfs_read_internal
zos_vfs_read:
        push de
        call zos_sys_remap_de_page_2
        call zos_vfs_read_internal
        pop de
        ret
        ; Alters:
        ;   A, BC, DE, HL
zos_vfs_read_internal:
        call zos_vfs_get_entry
        ret nz
        ; Check if the buffer and the size are valid, in other words, check that the
        ; size is less or equal to a page size and BC+size doesn't cross page boundary
        call zos_check_buffer_size
        or a
        ret nz
        ; Check if the opened dev is a file/directory
        call zos_disk_is_opn_filedir
        ; HL, DE and BC are valid, tail-call to zos_disk_read
        jp z, zos_disk_read
        ; We have a driver here, we will call its `read` function directly with the right
        ; parameters.
        ; Note: All drivers' `read` function take a 32-bit offset as a parameter on the
        ;       stack. For non-block drivers (non-filesystem), this parameter
        ;       doesn't make sense. It will always be 0 and must be popped by the driver
        ; First thing to do it retrieve the drivers' read function.
        ; Retrieve driver (HL) read function address, in HL.
        GET_DRIVER_READ()
        ld a, DRIVER_OP_NO_OFFSET
        ; Tail-call to driver's `read` routine
        jp (hl)

        ; Write to the given dev number.
        ; Parameters:
        ;       H  - Number of the dev to write to.
        ;       DE - Buffer to write to. The buffer must NOT cross page boundary.
        ;       BC - Size of the buffer passed. Maximum size is a page size.
        ; Returns:
        ;       A  - 0 on success, error value else
        ;       BC - Number of bytes written
        ; Alters:
        ;       A, HL, BC
        PUBLIC zos_vfs_write
zos_vfs_write:
        push de
        call zos_sys_remap_de_page_2
        call zos_vfs_write_internal
        pop de
        ret
zos_vfs_write_internal:
        ; We use the same flow as the one for the read function
        call zos_vfs_get_entry
        ret nz
        call zos_check_buffer_size
        or a
        ret nz
        ; Check if the opened dev is a file or a driver
        call zos_disk_is_opn_filedir
        ; Tail-call to zos_disk_write as the stack is clean
        jp z, zos_disk_write
        ; We have a driver here, we will call its `write` function directly with the right
        ; parameters.
        ; Retrieve driver (HL) `write` function address, in HL.
        GET_DRIVER_WRITE()
        ; HL now contains driver's `write` routine address.
        ld a, DRIVER_OP_NO_OFFSET
        ; Tail-call to driver's `read` routine
        jp (hl)

        ; Close the given dev number
        ; This should be done as soon as a dev is not required anymore, else, this could
        ; prevent any other `open` to succeed.
        ; Note: when a program terminates, all its opened devs are closed and STDIN/STDOUT
        ; are reset.
        ; Parameters:
        ;       H - Number of the dev to close
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       A, HL
        PUBLIC zos_vfs_close
zos_vfs_close:
        ; Save the dev number, we will pass it to the close function
        ; in case it is a driver
        ld a, h
        ld (_dev_table_empty_entry), a
        push de
        ; Flags set by zos_vfs_get_entry_addr, no need for 'or a'
        call zos_vfs_get_entry_addr
        jp nz, _zos_vfs_popde_ret
        ; Check if the opened dev is a file/dir or a driver
        call zos_disk_is_opn_filedir
        push de
        push bc
        jr z, _zos_vfs_close_isfile
        ; Retrieve driver (HL) close function address, in HL.
        GET_DRIVER_CLOSE()
        ; HL now contains the address of driver's close function. Call it
        ; with the dev number as a parameter
        ld a, (_dev_table_empty_entry)
        CALL_HL()
_zos_vfs_close_clean_entry:
        pop bc
        ; Clean the entry in _dev_table to 0, the top of the stack contains
        ; the address + 1.
        pop hl
        ld (hl), 0
        dec hl
        ld (hl), 0
        ; Restore DE before returning
_zos_vfs_popde_ret:
        pop de
        ret
_zos_vfs_close_isfile:
        call zos_disk_close
        jp _zos_vfs_close_clean_entry

        ; Return the stats of an opened file.
        ; The returned structure is defined in `vfs_h.asm` file.
        ; Each field of the structure is name file_*_t.
        ; Parameters:
        ;       H - Dev number
        ;       DE - File info structure, this memory pointed must be big
        ;            enough to store the file information
        ; Returns:
        ;       A - 0 on success, error else
        PUBLIC zos_vfs_dstat
        PUBLIC zos_vfs_dstat_internal
zos_vfs_dstat:
        ; Check DE parameter
        ld a, d
        or e
        jp z, _zos_vfs_invalid_parameter
        ; Parameter is valid, remap if necessary, and stat
        push de
        push bc
        call zos_sys_remap_de_page_2
        call zos_vfs_dstat_internal
        pop bc
        pop de
        ret
zos_vfs_dstat_internal:
        call zos_vfs_get_entry
        ret nz
        ; HL contains the opened dev address, DE the structure address
        ; Now, `stat` operation is only valid for files/directories, not drivers,
        ; so we have to check if the opened address is a driver.
        call zos_disk_is_opn_filedir
        ret nz
        ; Call the `disk` component for getting the file stats if success
        jp zos_disk_stat


        ; Returns the stats of a file.
        ; Same as the function above, but with a file path instead of an opened dev.
        ; Parameters:
        ;       BC - Path to the file
        ;       DE - File info structure, the memory pointed must be big
        ;            enough to store the file information (>= STAT_STRUCT_SIZE)
        ; Returns:
        ;       A - 0 on success, error else
        PUBLIC zos_vfs_stat
zos_vfs_stat:
        ; Open the file in BC, alters HL only. Set flags to O_RDONLY.
        ; Even if in practice we don't need any flag.
        ld h, O_RDONLY
        call zos_vfs_open
        ; Return value in A, negate A and return if error
        or a
        jp m, _zos_vfs_neg_ret
        ; File dev in H, save it on the stack
        ld h, a
        push hl
        ; Open may have moved MMU pages around (if BC was in the last virt page)
        ; So we must restore the second and third page first
        call zos_sys_remap_user_pages
        call zos_vfs_dstat
        pop hl
        ; No matter what the return value is, we have to save it to return it
        push af
        ; Close the opened dev in H
        call zos_vfs_close
        pop af
        ret

        ; Performs an IO request to an opened driver.
        ; The behavior of this syscall is driver-dependent.
        ; Parameters:
        ;       H - Dev number, must refer to an opened driver (not a file)
        ;       C - Command number. This is driver-dependent, check the
        ;           driver documentation for more info.
        ;       DE - 16-bit parameter. This is also driver dependent.
        ;            This can be used as a 16-bit value or as an address.
        ;            Similarly to the buffers in `read` and `write` routines,
        ;            If this is an address, it must not cross a page boundary.
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ;       DE - Driver dependent
        PUBLIC zos_vfs_ioctl
zos_vfs_ioctl:
        push bc
        ld b, h
        ; Get the entry address in HL
        call zos_vfs_get_entry
        ; Return directly if an error occurred
        jr nz, _zos_vfs_ioctl_ret
        ; If the entry is an opened file/directory, return an error too
        call zos_disk_is_opn_filedir
        jr z, _zos_vfs_ioctl_pop_ret
        ; HL points to a driver, get the IOCTL routine address
        GET_DRIVER_IOCTL()
        ; HL points to the IOCTL routine, prepare the parameters.
        ; C has not been modified, B contains the dev number
        CALL_HL()
        pop bc
        ret
_zos_vfs_ioctl_pop_ret:
        ld a, ERR_INVALID_PARAMETER
_zos_vfs_ioctl_ret:
        pop bc
        ret

        ; Move the cursor of an opened file or an opened driver.
        ; In case of a driver, the implementation is driver-dependent.
        ; In case of a file, the cursor never moves further than
        ; the file size. If the given whence is SEEK_SET, and the
        ; given offset is bigger than the file, the cursor will
        ; be set to the end of the file.
        ; Similarly, if the whence is SEEK_END and the given offset
        ; is positive, the cursor won't move further than the end of
        ; the file.
        ; Parameters:
        ;       H - Dev number, must refer to an opened driver (not a file)
        ;       BCDE - 32-bit offset, signed if whence is SEEK_CUR/SEEK_END.
        ;              Unsigned if SEEK_SET.
        ;       A - Whence. Can be SEEK_CUR, SEEK_END, SEEK_SET.
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else.
        ;       BCDE - Unsigned 32-bit offset. Resulting file offset.
        PUBLIC zos_vfs_seek
zos_vfs_seek:
        ; check if the whence is valid
        cp SEEK_END + 1
        jp nc, _zos_vfs_invalid_parameter
        ; Save the whence on the stack as we will need it later
        ld l, a
        push hl
        call zos_vfs_get_entry
        jr nz, _zos_vfs_seek_pophl_ret
        ; Check if the opened dev is a file/directory or a driver
        call zos_disk_is_opn_filedir
        jr z, _zos_vfs_seek_isfiledir
        ; HL points to a driver, get its `seek` function.
        GET_DRIVER_SEEK()
        ; HL now contains address of `seek` routine. The top of the stack contains
        ; the "dev" number and the whence.
        ; Exchange the contain on the stack with the address in HL (seek) and jump to
        ; that routine thanks to ret (tail-call)
        ; We have to get the original HL from the stack too as it contains
        ; the "dev" number.
        ex (sp), hl
        ld a, l
        ret
_zos_vfs_seek_isfiledir:
        ; Before getting the whence from stack, make sure it's a file, not a directory
        call zos_disk_is_opnfile
        jr nz, _zos_vfs_seek_pophl_ret
        ; Get the whence back from the stack (L)
        ex (sp), hl
        ld a, l
        pop hl
        jp zos_disk_seek
_zos_vfs_seek_pophl_ret:
        pop hl
        ret


        ; Create a directory at the specified location.
        ; If one of the directories in the given path doesn't exist, this will fail.
        ; For example, if mkdir("A:/D/E/F") is requested where D exists but E doesn't, this syscall
        ; will fail adn return an error.
        ; Parameters:
        ;       DE - Path of the directory to create. Must NOT cross boundaries.
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       A, HL
        PUBLIC zos_vfs_mkdir
zos_vfs_mkdir:
        ld hl, zos_disk_mkdir
        jp zos_call_disk_with_realpath


        ; Change the current working directory path.
        ; Parameters:
        ;       DE - Path to the new working directory
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       A, HL
        PUBLIC zos_vfs_chdir
zos_vfs_chdir:
        push de
        push bc
        ; Remap the user's buffer if necessary.
        call zos_sys_remap_de_page_2
        call _zos_vfs_chdir_internal
        pop bc
        pop de
        ret
_zos_vfs_chdir_internal:
        ; Check if the pointer is NULL
        ld a, d
        or e
        jp z, _zos_vfs_invalid_parameter
        ; Check if the string length is NULL
        ld a, (de)
        or a
        jp z, _zos_vfs_invalid_parameter
        ; Get the real path out of the given path. Path must be in BC,
        ; Result will be in DE.
        ld b, d
        ld c, e
        ; Allocate 256 bytes on the stack, make HL point to it
        ALLOC_STACK_256()
        ex de, hl
        call zos_get_full_path
        ; DE contains the full real path now, A the error code
        or a
        jr nz, zos_vfs_chdir_deallocate_return
        ; We have to check whether the directory exists or not, so let's open it
        ;       C - Disk letter
        ;       HL - Absolute path to the file (without X:/)
        ex de, hl
        ; Disk letter in C
        ld c, (hl)
        ; Save HL (not saved by opendir) and make it point to the / after X:
        push hl
        inc hl
        inc hl
        call zos_disk_opendir
        or a
        jr nz, zos_vfs_chdir_pop_deallocate_return
        ; Success, which means that the directory exists, we can close it directly
        call zos_disk_close
        ; Check for error again (unlikely)
        or a
        jr nz, zos_vfs_chdir_pop_deallocate_return
        ; Pop the original path and copy it to the current dir path
        pop hl
        ld de, _vfs_current_dir
        ; If we reached this point, the lengths have been checked, no need to check them
        ; again. Before copying, make the drive letter (first letter) upper case.
        ld a, (hl)
        call to_upper
        ld (hl), a
        call strcpy
        ; HL was unmodified, it still points to the allocated buffer on the stack
        ; We have to add a '/' at the end of the current path pointed by DE, if
        ; there isn't one already.
        xor a   ; Look for NULL-byte
        ld bc, CONFIG_KERNEL_PATH_MAX
        ex de, hl   ; Buffer allocated on the stack in DE
        cpir
        ; HL should now point to byte after the \0, move the \0 there
        ld (hl), a
        dec hl  ; Points to \0
        dec hl  ; Points to the last char
        ; Check if there is already a '/'
        ld a, '/'
        cp (hl)
        jr z, _zos_vfs_chdir_no_append_slash
        inc hl
        ld (hl), a
_zos_vfs_chdir_no_append_slash:
        ex de, hl
        ; Return value in A, which is 0
        xor a
        jp zos_vfs_chdir_deallocate_return
        ; Fall-through
zos_vfs_chdir_pop_deallocate_return:
        pop hl
zos_vfs_chdir_deallocate_return:
        ; Alters HL only, register A unmodified
        FREE_STACK_256()
        ret

        ; Get the current working directory
        ; Parameters:
        ;       DE - Buffer to store the current path to. This buffer must be of at least
        ;            CONFIG_KERNEL_PATH_MAX bytes.
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       A
        PUBLIC zos_vfs_curdir
zos_vfs_curdir:
        push de
        push bc
        ; Remap the user buffer if necessary
        call zos_sys_remap_de_page_2
        ; Copy the current dir to the buffer
        ld hl, _vfs_current_dir
        ld bc, CONFIG_KERNEL_PATH_MAX
        call strncpy
        pop bc
        pop de
        ; Return success
        xor a
        ret


        ; Open a directory given a path.
        ; The path can be relative, absolute to the disk or absolute to the
        ; system, just like open for files.
        ; Parameters:
        ;       DE - Path to the directory, it can be:
        ;            * Relative to the current directory ("../dir", "dir1")
        ;            * Absolute to the disk ("/dir1/dir2")
        ;            * Absolute to the system ("A:/dir1")
        ; Returns:
        ;       A - Number for the newly opened dev on success, negated error value else.
        ; Alters:
        ;       A (could also alter HL)
        PUBLIC zos_vfs_opendir
zos_vfs_opendir:
        push de
        push bc
        call zos_sys_remap_de_page_2
        call zos_vfs_opendir_internal
        pop bc
        pop de
        ret
zos_vfs_opendir_internal:
        ; Check if NULL given
        ld a, d
        or e
        ; Error have to be negated in such cases
        ld a, -ERR_INVALID_PARAMETER
        ret z
        ; TODO: Check that the string is not overlapping two pages
        ; Check that we have room in the dev table
        call zos_vfs_find_entry
        ; The empty entry to fill is in HL now
        or a
        jp nz, _zos_vfs_opendir_ret_error
        ; Check if the given path points to a driver or a file
        ld a, (de)
        cp VFS_DRIVER_INDICATOR
        ; TODO: List all the drivers
        ld a, -ERR_INVALID_PATH
        ret z
        ; As required by zos_get_full_path, put the user's path in BC
        ld b, d
        ld c, e
        ; Save the empty entry address because we are going to need HL now
        push hl
        ; We need to allocate at least CONFIG_KERNEL_PATH_MAX and point it from DE.
        ; Allocate this memory from the stack.
        ; Allocate on the stack 256 bytes
        ASSERT(CONFIG_KERNEL_PATH_MAX <= 256)
        ALLOC_STACK_256()       ; Alters HL
        ; HL contains the destination address, put it in DE instead
        ex de, hl
        call zos_get_full_path
        ; Check if an error occurred
        or a
        jp nz, _zos_vfs_opendir_deallocate_stack_error
        ; Retrieve the current disk from the path and save it C
        ld a, (de)
        ld c, a
        ; Make DE point to the path after X:
        inc de
        inc de
        ; We can now pass the path to the disk API
        ;       C - Disk letter
        ;       HL - Absolute path to the file (without X:/)
        ; We also have DE: Pointer to _vfs_current_dir + 3, it will be erased, that's ok,
        ; we don't need it
        ; It doesn't save any registers, save them here
        ex de, hl
        call zos_disk_opendir
        ; Restore the stack pointer, A and HL cannot be used, they contain the return values
        ; but DE and BC can be used, so let's use DE to store the returned value.
        ex de, hl
        FREE_STACK_256()
        ; Pop the empty entry address from the stack too
        pop hl
        ; Check if an error occurred
        or a
        jp nz, _zos_vfs_opendir_ret_error
        ; Else, we have to save the returned context in our array
        ld (hl), e
        inc hl
        ld (hl), d
        ; Load and return the index of the current entry
        ld a, (_dev_table_empty_entry)
        ret
_zos_vfs_opendir_deallocate_stack_error:
        ; An error occurred, deallocate the stack and return the error
        FREE_STACK_256()        ; Alters HL only, register A unmodified
        ; Pop HL (empty entry address) from the stack
        pop hl
_zos_vfs_opendir_ret_error:
_zos_vfs_neg_ret:
        ; Negate the error
        neg
        ret

        ; Read the next entry from the given opened directory
        ; Parameters:
        ;       H  - Number of the dev to write to.
        ;       DE - Buffer to store the entry data, the buffer must NOT cross page boundary.
        ;            It must be at least the size of an opendir entry size.
        ; Returns:
        ;       A  - ERR_SUCCESS on success,
        ;            ERR_NO_MORE_ENTRIES if all the entries have been browsed already,
        ;            error value else
        ; Alters:
        ;       A
        PUBLIC zos_vfs_readdir
zos_vfs_readdir:
        push de
        push bc
        call zos_sys_remap_de_page_2
        call _zos_vfs_readdir_internal
        pop bc
        pop de
        ret
_zos_vfs_readdir_internal:
        ; Get the opened dev address out of the H dev descriptor
        call zos_vfs_get_entry
        ret nz
        ; Check if the buffer and the size are valid, in other words, check that the
        ; size is less or equal to a page size and BC+size doesn't cross page boundary
        ld bc, DISKS_DIR_ENTRY_SIZE
        call zos_check_buffer_size
        or a
        ret nz
        ; Check if the opened dev is a dir or not
        call zos_disk_is_opndir
        ret nz
        jp zos_disk_readdir


        ; Remove a file or a(n empty) directory.
        ; Parameters:
        ;       DE - Path to the file or directory to remove
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       A, HL
        PUBLIC zos_vfs_rm
zos_vfs_rm:
        ld hl, zos_disk_rm
        jp zos_call_disk_with_realpath


        ; Mount a new disk, given a driver, a letter and a file system.
        ; The letter assigned to the disk must not be in use.
        ; Parameters:
        ;       H - Dev number. It must be an opened driver, not a file. The dev can be closed after
        ;           mounting, this will not affect the mounted disk.
        ;       D - ASCII letter to assign to the disk (upper or lower)
        ;       E - File system, taken from `vfs_h.asm`
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        PUBLIC zos_vfs_mount
zos_vfs_mount:
        call zos_vfs_get_entry
        ret nz
        ; Check if the entry is a file/directory or a driver
        DISKS_IS_OPN_FILEDIR(hl)
        ld a, ERR_INVALID_PARAMETER
        ret z
        ; The dev is a driver, we can try to mount it directly
        ld a, d ; Letter to mount it on in A register
        jp zos_disks_mount


        ; Duplicate on dev number to another dev number.
        ; This can be handy to override the standard input or output
        ; Note: New dev number MUST be empty/closed before calling this
        ; function, else, an error will be returned
        ; Parameters:
        ;       H - Old dev number
        ;       E - New dev number
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        PUBLIC zos_vfs_dup
zos_vfs_dup:
        ; Check that the "old" dev is a valid entry
        call zos_vfs_get_entry
        ret nz
        ; Check that the "new" dev entry is empty
        ld a, e
        cp CONFIG_KERNEL_MAX_OPENED_DEVICES
        jp nc, _zos_vfs_invalid_parameter
        push hl
        ; We need to multiple A by two as each entry is 2 bytes long
        add a
        ld hl, _dev_table
        ADD_HL_A()
        ld a, (hl)
        inc hl
        or (hl)
        ; If A is not zero, then the entry is not free
        jp nz, _zos_vfs_invalid_parameter_pophl
        ; We have to pop the "old" dev's content in DE without altering
        ; user program's DE.
        ex de, hl
        ex (sp), hl
        ex de, hl
        ; Copy the "old" dev value to it.
        ld (hl), d
        dec hl
        ld (hl), e
        pop de
        ; Both "new" and "old" devs can be used now
        ; Return success, A is already 0.
        ret

        ;======================================================================;
        ;================= P R I V A T E   R O U T I N E S ====================;
        ;======================================================================;

        ; Routine that implements both mkdir and rm syscalls.
        ; Interestingly, these two syscalls do exactly the same:
        ;       1) Remap the user buffer to an accessible page
        ;       2) Check the user's buffer (not NULL and not empty)
        ;       3) Get the realpath out of it
        ;       4) Call the disk layer
        ;       5) Return
        ; The only thing that changes is the routine to call in the disk layer.
        ; As such, we will take it as a parameter.
        ; Parameters:
        ;       HL - Routine to call in the disk layer (must have the same signature)
        ;       DE - User's buffer
        ; Alters:
        ;       A, HL
zos_call_disk_with_realpath:
        ; Create a "jp $dest" instruction in the work buffer, we will call it once
        ; we have to jump to the disk routine. This could be optimized with self-modifying
        ; code but this is running from ROM.
        ld a , 0xc3     ; JP instruction
        ld (_vfs_work_buffer), a
        ld (_vfs_work_buffer + 1), hl
        push de
        push bc
        ; Remap the user's buffer if necessary.
        call zos_sys_remap_de_page_2
        call _zos_call_disk_realpath
        pop bc
        pop de
        ret
_zos_call_disk_realpath:
        ; Check if the pointer is NULL
        ld a, d
        or e
        jp z, _zos_vfs_invalid_parameter
        ; Check if the string length is NULL
        ld a, (de)
        or a
        jp z, _zos_vfs_invalid_parameter
        ; Get the real path out of the given path. Path must be in BC,
        ; Result will be in DE.
        ld b, d
        ld c, e
        ; Allocate 256 bytes on the stack, make HL point to it
        ALLOC_STACK_256()
        ex de, hl
        call zos_get_full_path
        ; DE contains the full real path now, A the error code
        or a
        jp nz, zos_vfs_mkdir_deallocate_return
        ; Put the full-path back in HL, as required by the disk layer
        ex de, hl
        ; Get the driver letter from the path
        ld c, (hl)
        ; Make HL point to the / after X:
        inc hl
        inc hl
        ; Success, we can proceed to call the disk layer, we can't tail-call because
        ; we still need to deallocate the memory from the stack.
        call _vfs_work_buffer
        ; Fall-through
zos_vfs_mkdir_deallocate_return:
        ; Alters HL only, register A unmodified
        FREE_STACK_256()
        ret


        ; Get the real full path out of a path given in BC (by a user).
        ; The path can be relative, absolute or absolute to the system.
        ; The resulted path will be stored in DE.
        ; Parameters:
        ;       BC - Path (string) to the file/directory.
        ;            (must not be NULL)
        ;       DE - Pointer to store the real path into. Must be at least of
        ;            size CONFIG_KERNEL_PATH_MAX.
        ;            (must not be NULL)
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else (string length 0)
        ; Alters:
        ;       A, HL
zos_get_full_path:
        ; Check if the given path points to a driver or a file
        ld a, (bc)
        ; Check if the string is empty (A == 0)
        or a
        jp z, _zos_get_full_path_invalid
        ; Check if the first char is '/', in that case, it's an absolute path to the current disk
        cp '/'
        jp z, _zos_get_full_path_absolute_disk
        ; Check if the driver letter was given. It's the case when the second and third
        ; chars are ':/'
        ld l, a         ; Store the potential disk letter in L
        inc bc          ; Point to the second character
        ld a, (bc)
        cp ':'
        jp nz, _zos_get_full_path_rel
        inc bc
        ld a, (bc)
        cp '/'
        jp nz, _zos_get_full_path_rel_dec
        ; The path given is an absolute system path, including disk letter
 _zos_get_full_path_absolute:
        ; BC - Address of the path, pointing to the /, right after which starts after X:
        ; L  - Disk letter
        ; Copy the X: to the destination
        ld a, l
        ld (de), a
        inc de
        ld a, ':'
        ld (de), a
        inc de
        ; Destination is ready to receive the real path!
        ; Setup the source path in HL
        ld h, b
        ld l, c
        call zos_realpath
        ; Restore back DE to what it was when entering this routine
        dec de
        dec de
        ret
        ; ---- end of full_path_absolute route ---- ;
_zos_get_full_path_absolute_disk:
        ; The path given is absolute to the current disk, get the latter and jump
        ; to the previous label (_zos_get_full_path_absolute) as the code is fairly
        ; similar.
        ; BC - Address of the path, which starts at the first /
        ld a, (_vfs_current_dir)
        ; Setup the current disk letter in L just like what _zos_get_full_path_absolute
        ; is expecting.
        ld l, a
        jr _zos_get_full_path_absolute
        ; ---- end of full_path_absolute_disk route ---- ;
        ; In both cases below, BC is the address of the filename, so relative to the current path.
 _zos_get_full_path_rel_dec:
        dec bc
 _zos_get_full_path_rel:
        dec bc
        ; Start by copying the disk letter and the ':' as this won't change
        ld hl, _vfs_current_dir
        ldi
        ldi
        ; Do not modify BC
        inc bc
        inc bc
        ; Copy the path given by the caller into HL. The buffer to copy from
        ; must be in DE. But both BC and DE will be altered, save them.
        push bc
        push de
        ld d, b
        ld e, c
        ld hl, _vfs_current_dir + 2 ; skip the X:, we point to the / now
        ; Concatenate the new path to the current path.
        ld bc, 2 * CONFIG_KERNEL_PATH_MAX - 2
        ; Concatenate DE into HL, with a max size of BC (including \0)
        call strncat
        ; DE now contains the position of the NULL-byte in the former HL string
        ; Check if it was a success (path too long else)
        or a
        jp nz, _zos_get_full_path_strncat_error
        ; Restore the destination from the stack, but keep the current value of DE
        ; too. Store the current value of DE in BC as realpath doesn't alter BC.
        ld b, d
        ld c, e
        pop de  ; Caller's destination buffer + 2
        ; Calculate the realpath in DE out of the concatenation in HL.
        call zos_realpath
        ; Restore the NULL-byte that was in HL before concatenation
        ld h, b
        ld l, c
        ld (hl), 0
        pop bc
        ; Restore caller's original pointer
        dec de
        dec de
        ; Return value is in A, we can return now
        ret
_zos_get_full_path_strncat_error:
        ld a, ERR_PATH_TOO_LONG
        pop de
        pop bc
        ret
_zos_get_full_path_invalid:
        ld a, ERR_INVALID_NAME
        ret

        ; Check the consistency of the passed flags for open routine.
        ; For example, it is inconsistent to pass both
        ; O_RDWR and O_WRONLY flag, or both O_TRUNC and O_APPEND
        ; Parameters:
        ;       H - Flags
        ; Returns:
        ;       A - ERR_SUCCESS on success or error code else
zos_vfs_check_opn_flags:
        ld a, h
        ; Check that we don't have both O_RDWR and O_WRONLY
        and O_WRONLY | O_RDWR
        cp O_WRONLY | O_RDWR
        jr z, _zos_vfs_invalid_flags
        ; Check that O_TRUNC is not given with O_APPEND
        ld a, h
        and O_TRUNC | O_APPEND
        cp O_TRUNC | O_APPEND
        jr z, _zos_vfs_invalid_flags
        xor a
        ret
_zos_vfs_invalid_flags:
        ld a, ERR_BAD_MODE
        ret

        ; Check that a buffer address and its size are valid.
        ; They are valid if the size is less or equal to an MMU page size, and if
        ; the buffer doesn't cross the page-boundary
        ; Parameters:
        ;       DE - Buffer address
        ;       BC - Buffer size
        ; Returns:
        ;       A - ERR_SUCCESS is buffer and size valid, ERR_INVALID_PARAMETER else
        ; Alters:
        ;       A
zos_check_buffer_size:
        push hl
        xor a
        ld hl, MMU_VIRT_PAGES_SIZE
        sbc hl, bc
        jr c, zos_check_buffer_size_invalidparam
        push de
        ; BC is less than a page size, get the page number of DE
        MMU_GET_PAGE_INDEX_FROM_VIRT_ADDRESS(D, E)
        ; Page index of DE in A, calculate page index for the last buffer address:
        ; DE+BC-1
        ld h, d
        ld l, e
        add hl, bc
        dec hl
        ld d, a ; Save the page index in D
        MMU_GET_PAGE_INDEX_FROM_VIRT_ADDRESS(H, L)
        ; Compare D and A, they must be equal
        sub d
        pop de
        jr nz, zos_check_buffer_size_invalidparam
        ;A is already 0, we can return
        pop hl
        ret
zos_check_buffer_size_invalidparam:
        pop hl
        ld a, ERR_INVALID_PARAMETER
        ret

        ; Find an empty entry in the _dev_table
        ; Parameters:
        ;       None
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ;       HL - Address of the empty entry
        ; Alters:
        ;       A
zos_vfs_find_entry:
        push bc
        ld hl, _dev_table
        ld b, CONFIG_KERNEL_MAX_OPENED_DEVICES
        ld c, 0 ; Index of the entry found
_zos_vfs_find_entry_loop:
        ld a, (hl)
        inc hl
        or (hl)
        inc hl
        jp z, _zos_vfs_find_entry_found
        inc c
        djnz _zos_vfs_find_entry_loop
        ; Not found
        ld a, ERR_CANNOT_REGISTER_MORE
        pop bc
        ret
_zos_vfs_find_entry_found:
        ; Save the index in the work buffer
        ld a, c
        ld (_dev_table_empty_entry), a
        ; Return ERR_SUCCESS
        xor a
        ; Make HL point to the empty entry
        dec hl
        dec hl
        pop bc
        ret

        ; Get the entry of index H
        ; Parameters:
        ;       H - Index of the opened dev to retrieve
        ; Returns:
        ;       HL - Opened dev address
        ;       A - ERR_SUCCESS if success, error else
        ;       Z flag - Success
        ;       NZ flag - Error else
        ; Alters:
        ;       A, HL
zos_vfs_get_entry:
        ld a, h
        cp CONFIG_KERNEL_MAX_OPENED_DEVICES
        jr nc, _zos_vfs_get_entry_invalid_parameter
        ; HL = [HL + 2*A]
        ld hl, _dev_table
        rlca
        ADD_HL_A()
        ld a, (hl)
        inc hl
        ld h, (hl)
        ld l, a
        ; Success if HL is not 0. A already contains L.
        or h
        jr z, _zos_vfs_get_entry_invalid_parameter
        xor a
        ret
_zos_vfs_get_entry_invalid_parameter:
        ld a, ERR_INVALID_PARAMETER
        or a
        ret

        ; Same as above but also returns the address of the dev in the table in DE
zos_vfs_get_entry_addr:
        ld a, h
        cp CONFIG_KERNEL_MAX_OPENED_DEVICES
        jr nc, _zos_vfs_get_entry_invalid_parameter
        ; DE = [HL + 2*A]
        ld hl, _dev_table
        rlca
        ADD_HL_A()
        ld e, (hl)
        inc hl
        ld d, (hl)
        ex de, hl
        ; Success if HL is not 0
        ld a, h
        or l
        jr z, _zos_vfs_get_entry_invalid_parameter
        xor a
        ret


        ; Normalize the absolute NULL-terminated path given in HL while
        ; copying it to DE. This means that all the ., .., // will be removed
        ; from the path. At most CONFIG_KERNEL_PATH_MAX bytes will be written.
        ; The source path must not contain the disk letter.
        ; For example, HL cannot be:
        ;       C:/mydir/.//myfile.txt
        ; It should be:
        ;       /mydir/.//myfile.txt
        ; In that case, DE will be:
        ;       /mydir/myfile.txt
        ; Parameters:
        ;       HL - Source path
        ;       DE - Destination path
        ; Returns:
        ;       A - ERR_SUCCESS is success, error code else
        ; Alters:
        ;       A, HL
zos_realpath:
        push de
        push bc
        ; C will be our flags
        ; Bit 7: DE path at root
        ; Bit 4: valid char seen
        ; Bit 3: '...' seen
        ; Bit 2: '..' seen
        ; Bit 1: '.' seen
        ; Bit 0: '/' seen
        ; B is the destination path length
        ; FIXME: Maximum path length is 255
        ld c, 0x80
        ld b, 0
_zos_realpath_loop:
        ld a, (hl)
        or a    ; Check if end of string
        jp z, _zos_realpath_end_str
        cp '/'
        jp z, _zos_realpath_slash
        ; Not a slash, clear the flag
        res 0, c
        cp '.'
        jp z, _zos_realpath_dot
        ; Other characters, should be valid (printable)
        ; Check if any '.' or '..' is pending
        bit 1, c
        call nz, _zos_realpath_print_dot
        bit 2, c
        call nz, _zos_realpath_print_double_dot
        ld (de), a
        inc de
        inc hl
        inc b
        ; Clear the . and .. flag, set the valid char one
        ld a, c
        and 0x80
        or 0x10
        ld c, a
        jp _zos_realpath_loop
_zos_realpath_slash:
        inc hl
        ; In most cases, the flags won't be set, so optimize a bit here
        ld a, c
        and 0x07        ; Only the first 3 bits are interesting
        jp z, _zos_realpath_slash_write
        ; Reset the valid char seen flag
        res 4, c
        ; If we've seen a slash already, skip this part, else, set the slash-flag
        rrca    ; Bit 0 in CY
        jp c, _zos_realpath_loop
        ; Add the 'slash' flag
        set 0, c
        ; If we encountered a single '.', we should NOT modify the output, as
        ; './' means current folder
        res 1, c
        rrca    ; Bit 1 in CY
        jp c, _zos_realpath_loop
        ; We have encountered a '..', if we are at root, error, else, we have to
        ; look for the previous '/'
_zos_realpath_slash_at_end:
        bit 7, c
        jp nz, _zos_realpath_error_path
        res 2, c
        ; Look for the previous '/' in the destination
        ; For example, if HL is /mydir/../
        ; Destination would be /mydir/, and DE pointing after the last slash
        ; We have to look for the one before the last one.
        dec de
        dec de
        dec b
        push bc
        ld c, b
        ld b, 0
        ex de, hl
        ld a, '/'
        cpdr
        ld a, c
        pop bc
        ld b, a
        ex de, hl
        ; Make DE point back at the next empty char
        inc de
        inc de
        inc b
        ; If the resulted size is 0 (A), then we have to set the flag
        or a
        jp nz, _zos_realpath_loop
        set 7, c
        jp _zos_realpath_loop
_zos_realpath_slash_write:
        ; Add the 'slash' flag, and remove the other flags
        ld c, 1
        ; If B is 0, then we are still at the beginning of the path, still
        ; at the root, do not clean that flag
        ld a, b
        or a
        jp nz, _zos_realpath_slash_write_noset
        set 7, c
_zos_realpath_slash_write_noset:
        ; Add a slash to DE
        ld a, '/'
        ld (de), a
        inc de
        inc b
        ; Go back to the loop
        jp _zos_realpath_loop
_zos_realpath_dot:
        ; We've just came accross a dot.
        ; If we've already seen a triple dot, then this dot is part of a file name
        bit 3, c
        jr nz, _zos_realpath_valid_dot
        ; If we have seen regular characters before, the dot is valid
        bit 4, c
        jr nz, _zos_realpath_valid_dot
        ; If we've seen a .. before, then, this dot makes the file name '...'
        ; this is not a special sequence, so we have to write these to DE.
        bit 2, c
        jr nz, _zos_realpath_tripledot
        ; Update the flags and continue the loop. Do not write anything to the
        ; destination (yet). If we saw a dot before, the flags become:
        ; xxxxx_x01x => xxxxx_x10x
        ; If we haven't, it becomes:
        ; xxxxx_x00x => xxxxx_x01x
        ; Thus, simply perform c += 2
        inc c
        inc c
        inc hl
        jp _zos_realpath_loop
_zos_realpath_tripledot:
        ld (de), a
        inc de
        ld (de), a
        inc de
        ld (de), a
        inc de
        inc b
        inc b
        inc b
        ; Set the valid flag and clean the double dot one
        res 2, c
        set 3, c
_zos_realpath_valid_dot:
        ld (de), a
        inc de
        inc b
        inc hl
        jp _zos_realpath_loop
_zos_realpath_end_str:
        ; If we have seen a .. right before the NULL-byte, we have to
        ; act as if a final / was present.
        ; HL won't be incremented in _zos_realpath_slash_at_end, so it will
        ; still point to the NULL-byte, ending the next recursion.
        bit 2, c
        jr nz, _zos_realpath_slash_at_end
        xor a
        ld (de), a
        pop bc
        pop de
        ret
_zos_realpath_error_path:
        ; When .. is passed at the root
        ld a, 1
        pop bc
        pop de
        ret
_zos_realpath_print_double_dot:
        call _zos_realpath_print_dot
_zos_realpath_print_dot:
        ex de, hl
        ld (hl), '.'
        ex de, hl
        inc de
        inc b
        ret

        SECTION KERNEL_BSS
        ; Each of these entries points to either a driver (when opened a device) or an abstract
        ; structure returned by a disk (when opening a file)
_dev_default_stdout: DEFS 2
_dev_default_stdin: DEFS 2
_dev_table_empty_entry: DEFS 1 ; Only used to temporarily store the index of an empty entry
        ; Each entry takes 2 bytes as these are memory addresses
_dev_table: DEFS CONFIG_KERNEL_MAX_OPENED_DEVICES * 2
        ; As the following will also be used as a temporary buffer to calculate the realpath
        ; of file/directories (in zos_get_full_path), it must be able to handle 2 paths
        ; concatenated +1 for the potential NULL character added by the string library.
_vfs_current_dir: DEFS CONFIG_KERNEL_PATH_MAX * 2 + 1
        ; Work buffer usable by any (virtual) file system. It shall only be used by one
        ; FS implementation at a time, thus, it shall be used as a temporary buffer in
        ; the routines.
        PUBLIC _vfs_work_buffer
_vfs_work_buffer: DEFS VFS_WORK_BUFFER_SIZE
