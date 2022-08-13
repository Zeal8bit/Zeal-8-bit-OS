        INCLUDE "osconfig.asm"
        INCLUDE "mmu_h.asm"
        INCLUDE "vfs_h.asm"
        INCLUDE "errors_h.asm"
        INCLUDE "disks_h.asm"
        INCLUDE "drivers_h.asm"
        INCLUDE "utils_h.asm"

        EXTERN zos_driver_find_by_name
        EXTERN zos_disk_open_file
        EXTERN zos_disk_read
        EXTERN zos_disk_stat
        EXTERN zos_disk_is_opnfile
        EXTERN strncat

        SECTION KERNEL_TEXT

        DEFC VFS_DRIVER_INDICATOR = '#'

        PUBLIC zos_vfs_init
zos_vfs_init:
        ld hl, _vfs_current_dir
        ld (hl), DISK_DEFAULT_LETTER
        inc hl
        ld (hl), ':'
        inc hl
        ld (hl), '/'
        ret

        ; Routine saving the current working directory. It will have no effect if a backup
        ; is already there.
        ; This must be called from the first execvp (from a terminal/console).
        ; Parameter:
        ;       None
        ; Returns:
        ;       None
        ; Alters:
        ;       A, BC, DE, HL
zos_vfs_backup_dir:
        ld a, (_vfs_current_dir_backup)
        ret nz
        ld hl, _vfs_current_dir
        ld de, _vfs_current_dir_backup
        ld bc, CONFIG_KERNEL_PATH_MAX
        ldir
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
        ; Copy back the "current" dir
        ld hl, _vfs_current_dir_backup
        ld de, _vfs_current_dir
        ld bc, CONFIG_KERNEL_PATH_MAX
        ldir
        ; Clean the backup
        xor a
        ld (_vfs_current_dir_backup), a
        ; Close all the opened devs, even stdout and stdin
        ld b, CONFIG_KERNEL_MAX_OPENED_DEVICES
_zos_vfs_clean_close:
        ld a, b
        dec a
        ld h, b
        call zos_vfs_close
        ld b, h
        djnz _zos_vfs_clean_close
        ; Fall-throught

        PUBLIC zos_vfs_restore_std
zos_vfs_restore_std:
        ; Populate the stdout and stdin entries
        ; TODO: Re-open them if closed by the program that just exited?
        ld hl, (_dev_default_stdout)
        ld (_dev_table), hl
        ld hl, (_dev_default_stdin)
        ld (_dev_table + 2), hl
        ret

        ; Routine to set the default stdout of the system
        ; This is where the logs will go by defaults
        ; Parameters:
        ;       HL - Pointer to the driver
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
        xor a   ; Optimization for A = ERR_SUCCESS
        ret        

        ; Routine to set the default stdin of the system
        ; Parameters:
        ;       HL - Pointer to the driver
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
        xor a   ; Optimization for A = ERR_SUCCESS
        ret

_zos_vfs_invalid_parameter:
        ld a, ERR_INVALID_PARAMETER
        ret


        ; Routines used to interact with the drivers

        ; Open the given file or driver
        ; Drivers name shall not exceed 4 characters and must be preceeded by VFS_DRIVER_INDICATOR (#)
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
        ;       HL when called from zos_vfs_open_syscall  (popped from the stack)
        PUBLIC zos_vfs_open
        PUBLIC zos_vfs_open_syscall
zos_vfs_open:
        push hl
zos_vfs_open_syscall:   ; Syscalls already pushed HL on the stack
        push de
        push bc
        ; Check if BC is NULL
        ld a, b
        or c
        jp z, _zos_vfs_open_ret_invalid
        ; Check that we have room in the dev table. HL will be altered, save H (flags in D)
        ld d, h
        call zos_vfs_find_entry
        ; A is 0 on success
        or a
        jp nz, _zos_vfs_open_ret_err
        ; Check if the given path points to a driver or a file
        ld a, (bc)
        ; Check if the string is empty (A == 0)
        or a
        jp z, _zos_vfs_open_ret_invalid
        cp VFS_DRIVER_INDICATOR
        jp z, _zos_vfs_open_drv
        ; Open a file here
        ; Check if the first char is '/', in that case, it's an absolute path to the current disk
        cp '/'
        inc bc  ; doesn't update flags, so, safe
        jp z, _zos_vfs_open_absolute_disk
        ; Check if the driver letter was passed. It's the case when the second and third
        ; chars are ':/'
        ld e, a         ; Store the disk letter in E
        ld a, (bc)
        cp ':'
        jp nz, _zos_vfs_open_file
        inc bc
        ld a, (bc)
        cp '/'
        jp nz, _zos_vfs_open_file_dec
        ; The path given is an absolute system path, including disk letter
        ; Make BC point to the first directory name and not ('/')
        inc bc
_zos_vfs_open_absolute:
        ; BC - Address of the path, which starts after X:/
        ; DE - Flags | Disk letter
        ; HL - Address of the empty dev.
        ; Before calling the disk API, we have to prepare the arguments:
        ; BC - Flags | Disk letter
        ; HL - Absolute path to the file (without X:/)
        ; Exchange BC with DE, then HL with DE
        ; ex bc, de
        ld a, d
        ld d, b
        ld b, a
        ld a, e
        ld e, c
        ld c, a
        ; DE now contains the full path, BC contains Flags | Disk letter
        ex de, hl
        ; It doesn't save any register
        push de
        call zos_disk_open_file
        pop de
        or a
        jp nz, _zos_vfs_open_ret_err
        ; It was a success, store the newly obtained descriptor (HL) in the free entry (DE)
        ex de, hl
        jp _zos_vfs_open_save_de_and_exit
        ;=================================;
        ; Open a file relative to the current path
        ; For example:
        ;       myfile.txt
_zos_vfs_open_file_dec:
        dec bc
_zos_vfs_open_file:
        dec bc
        ; In both cases (above), at this point, BC is the address of the filename.
        ; D - Contains the flags
        ; HL - Address of the empty dev.
        ; TODO: Normalize the path by getting the realpath. Currently, we are going to ignore
        ; the fact that paths can contain .., . or multiple /, the path MUST be correct.
        ; In practice, we should check that the last char is not / 
        ; Here we have to retrieve the current disk, from _vfs_current_dir
        push hl
        ld a, (_vfs_current_dir)
        ld e, a
        ; Load the filename in HL
        ld hl, _vfs_current_dir + 3 ; skip the X:/
        ; Get the length of the current dir. We will concatenate to it the new filename.
        push de
        ld d, b
        ld e, c
        ld bc, CONFIG_KERNEL_PATH_MAX
        ; Concatenate DE into HL, with a max size of BC (including \0)
        call strncat
        ; Here, store DE (flags + disk letter) in BC as DE contains the former NULL byte address of HL
        pop bc
        ; Check if A is 0 (success)
        or a
        ; Load the error code in case
        ld a, ERR_PATH_TOO_LONG
        jp nz, _zos_vfs_open_ret_pophl
        ; We can now pass the path to the disk API
        ; B: Flags
        ; C: Disk letter
        ; HL: Absolute path to the file (without X:/)
        ; DE: Former address of HL's NULL-byte
        ; It doesn't save any registers, save them here
        push de
        call zos_disk_open_file
        pop de
        ; Returns status in A (0 if success) and dev descriptor in HL,
        ; we have to save it in case of success.
        ; In any case, restore HL's former NULL-byte
        ex de, hl
        ld (hl), 0
        ; Check zos_disk_open_file return value
        or a
        jp nz, _zos_vfs_open_ret_pophl
        ; Return was a success, we can save the dev descriptor from DE (the free entry address is on the stack)
        pop hl
_zos_vfs_open_save_de_and_exit:
        ld (hl), e
        inc hl
        ld (hl), d
        ; We have to return the index of the newly opened dev, we can calculate it
        ; from HL. We need to perform A = (HL - 1 - _dev_table) / 2.
        ld bc, _dev_table
        scf
        sbc hl, bc
        ; HL is now an 8-bit value, because we have at most 128 entries
        ld a, l
        ; Divide by 2 with rra as carry is 0 (because of sbc)
        rra
        jp _zos_vfs_open_ret
        ; Open a file with an absolute path of the current disk 
        ; For example: /mydir/myfile.txt
        ; BC is pointing at the char of index 1 already (after /)
_zos_vfs_open_absolute_disk:
        ; Open the file as an absolute path, but load the current disk first
        ; Disk letter must be put in E. We cannot use HL here.
        ld a, (_vfs_current_dir)
        ld e, a
        jp _zos_vfs_open_absolute
        
        ; Open a driver, the length of the driver name must be 4
        ; HL - The address of the empty dev entry
        ; BC - Driver name (including #)
        ; D - Flags
_zos_vfs_open_drv:
        inc bc
        push hl
        ; The length will be check by zos_driver_find_by_name, no need to do it here
        ; Put the driver name in HL instead of BC. Flags in B.
        ld h, b
        ld l, c
        ld b, d
        call zos_driver_find_by_name
        ; Check that it was a success
        or a
        jp nz, _zos_vfs_open_ret_pophl
        ; Success, DE contains the driver address, HL contains the name and top of stack contains
        ; the address of the empty dev entry.
        ; Before saving the driver as opened, we have to execute its "open" routine, which MUST succeed!
        ; Parameters:
        ;       BC - name
        ;       H - flags
        ; After this, we will still need DE (driver address).
        push de
        ; Prepare the name, exchange B and H
        ld a, b
        push af ; Save the flags
        ld b, h
        ; ld c, l // C hasn't been modified
        GET_DRIVER_OPEN()
        pop af  ; Retrieve the opening flags (A) from the stack
        CALL_HL()
        pop de
        ; Check the return value
        or a
        jp nz, _zos_vfs_open_ret_pophl
        ; Success! We can now save the driver inside the empty spot.
        pop hl
        jp _zos_vfs_open_save_de_and_exit
_zos_vfs_open_ret_pophl:
        pop hl
_zos_vfs_open_ret_err:
        ; Error value here, negate it before returning
        neg
_zos_vfs_open_ret:
        pop bc
        pop de
        ; All "syscall" accessible functions, we must pop hl before returning
        pop hl
        ret
_zos_vfs_open_ret_invalid:
        ld a, ERR_INVALID_NAME
        jr _zos_vfs_open_ret_err


        ; Read the given dev number
        ; Parameters:
        ;       H  - Number of the dev to write to
        ;       DE - Buffer to store the bytes read from the dev, the buffer must NOT cross page boundary
        ;       BC - Size of the buffer passed, maximum size is a page size
        ; Returns:
        ;       A  - 0 on success, error value else
        ;       BC - Number of bytes remaning to read. 0 means the buffer has been filled.
        ; Alters:
        ;       A, BC
        PUBLIC zos_vfs_read
        PUBLIC zos_vfs_read_syscall
zos_vfs_read:
        push hl
zos_vfs_read_syscall:
        push de
        call zof_vfs_get_entry
        pop de
        or a
        jp nz, _zos_vfs_pop_ret
        ; Check if the buffer and the size are valid, in other words, check that the
        ; size is less or equal to a page size and BC+size doesn't cross page boundary 
        call zos_check_buffer_size
        or a
        jp nz, _zos_vfs_pop_ret
        ; Check if the opened dev is a file or a driver
        call zos_disk_is_opnfile
        or a
        jr z, _zos_vfs_read_isfile
        ; We have a driver here, we will call its `read` function directly with the right
        ; parameters.
        ; Note: All drivers' `read` function take a 32-bit offset as a parameter on the
        ;       stack. For non-block drivers (non-filesystem), this parameter
        ;       doesn't make sense. It will always be 0 and must be popped by the driver
        ; First thing to do it retreive the drivers' read function, to do this,
        ; we need both DE and HL
        push de
        ex de, hl 
        ; Retrieve driver (DE) read function address, in HL.
        GET_DRIVER_READ()
        pop de
        ; HL now contains read address
        ; We have to save DE as it must not be altered,
        ; at the same time, we also have to put a 32-bit offset (= 0)
        ; Use the work buffer to do this, it can then be used freely
        ; by the drivers. That buffer is used as a "dynamic" memory that
        ; is considered as active during a whole syscall.
        ; Which means that after a syscall, `read` for example, it can
        ; be re-used by any other syscall. It's not permanent, it's a
        ; temporary buffer.
        ; Encode jp driver_read_function inside the work buffer
        ld a, 0xc3      ; jp instruction
        ld (_vfs_work_buffer), a
        ld (_vfs_work_buffer + 1), hl
        push de
        ld hl, zos_vfs_read_driver_return
        push hl ; Return address
        ld hl, 0
        push hl
        push hl ; 32-bit offset parameter (0)
        ; Jump to that read function
        jp _vfs_work_buffer
zos_vfs_read_driver_return:
        ; Restore DE and HL before returning
        pop de
        pop hl
        ret
_zos_vfs_read_isfile:
        push de
        call zos_disk_read
        pop de
        pop hl
        ret


        ; Write to the given dev number
        ; Parameters:
        ;       H  - Number of the dev to write to
        ;       DE - Buffer to write to the dev
        ;       BC - Size of the buffer passed. The maximum size is 32K.
        ;            If the size is less than or equal to 16KB, cross page boundary buffer is NOT allowed
        ;            If the size is more than 16KB, the buffer can only cross 2 virtual pages, not more.
        ; Returns:
        ;       A  - 0 on success, error value else
        ;       BC - Number of bytes remaining to be written. 0 means everything has been written.
        ; Alters:
        ;       A, HL, BC
        PUBLIC zos_vfs_write
zos_vfs_write:     

        ; Close the given dev number
        ; This should be done as soon as a dev is not required anymore, else, this could
        ; prevent any other `open` to succeed.
        ; Note: when a program terminates, all its opened devs are closed and STDIN/STDOUT
        ; are reset.
        ; Parameters:
        ;       A - Number of the dev to close
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        PUBLIC zos_vfs_close
        PUBLIC zos_vfs_close_syscall
zos_vfs_close:
        push hl
zos_vfs_close_syscall:
        pop hl
        ret

        ; Return the stats of an opened file.
        ; The returned structure is defined in `vfs_h.asm` file.
        ; Each field of the structure is name file_*_t.
        ; Parameters:
        ;       H - Dev number
        ;       DE - File info stucture, this memory pointed must be big
        ;            enough to store the file information
        ; Returns:
        ;       A - 0 on success, error else
        ; Alters:
        ;       TBD
        PUBLIC zos_vfs_dstat
        PUBLIC zos_vfs_dstat_syscall
zos_vfs_dstat:
        push hl
zos_vfs_dstat_syscall:
        ; Check DE parameter
        ld a, d
        or e
        jp z, _zos_vfs_invalid_parameter
        push de
        call zof_vfs_get_entry
        pop de
        or a
        jr nz, _zos_vfs_dstat_pop_ret
        ; HL contains the opened dev address, DE the structure address
        ; Now, `stat` operation is only valid for files, not drivers, so we
        ; have to check if the opened address is a file or not, fortunately,
        ; `disk` component can do that.
        call zos_disk_is_opnfile
        or a
        jp nz, _zos_vfs_dstat_pop_ret
        ; Call the `disk` component for getting the file stats if success
        push bc
        push de
        call zos_disk_stat
        pop de
        pop bc
_zos_vfs_dstat_pop_ret:
_zos_vfs_pop_ret:
        pop hl
        ret

        ; Returns the stats of a file.
        ; Same as the function above, but with a file path instead of an opened dev.
        ; Parameters:
        ;       BC - Path to the file
        ;       DE - File info stucture, this memory pointed must be big
        ;            enough to store the file information (>= STAT_STRUCT_SIZE)
        ; Returns:
        ;       A - 0 on success, error else
        ; Alters:
        ;       TBD
        PUBLIC zos_vfs_stat
zos_vfs_stat:

        PUBLIC zos_vfs_seek
zos_vfs_seek:

        PUBLIC zos_vfs_ioctl
zos_vfs_ioctl:

        PUBLIC zos_vfs_mkdir
zos_vfs_mkdir:

        PUBLIC zos_vfs_getdir
zos_vfs_getdir:

        PUBLIC zos_vfs_chdir
zos_vfs_chdir:

        PUBLIC zos_vfs_rddir
zos_vfs_rddir:

        PUBLIC zos_vfs_rm
zos_vfs_rm:

        PUBLIC zos_vfs_mount
zos_vfs_mount:

        ; Duplicate on dev number to another dev number
        ; This can be handy to override the standard input or output
        ; Note: New dev number MUST be empty/closed before calling this
        ; function, else, an error will be returned
        ; Parameters:
        ;       A - Old dev number
        ;       E - New dev number
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ;
        PUBLIC zos_vfs_dup
zos_vfs_dup:
        ld a, ERR_NOT_IMPLEMENTED
        ret

        ;======================================================================;
        ;================= P R I V A T E   R O U T I N E S ====================;
        ;======================================================================;

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
        jr z, zos_check_buffer_size_invalidparam
        push de
        ; BC is less than a page size, get the page number of DE
        MMU_GET_PAGE_INDEX_FROM_VIRT_ADDRESS()
        ; Page index of DE in A, calculate page index for the last buffer address:
        ; DE+BC-1
        ld h, d
        ld l, e
        adc hl, bc
        dec hl
        ld d, a ; Save the page index in D
        ; Echange HL and DE as MMU_GET_PAGE_INDEX_FROM_VIRT_ADDRESS needs the address in DE
        ex de, hl
        MMU_GET_PAGE_INDEX_FROM_VIRT_ADDRESS()
        ex de, hl
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
_zos_vfs_find_entry_loop:
        ld a, (hl)
        inc hl
        or (hl)
        inc hl
        jp z, _zos_vfs_find_entry_found
        djnz _zos_vfs_find_entry_loop
        ; Not found
        ld a, ERR_CANNOT_REGISTER_MORE
_zos_vfs_find_entry_found:
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
        ; Alters:
        ;       A, DE, HL
zof_vfs_get_entry:
        ld a, h
        cp CONFIG_KERNEL_MAX_OPENED_DEVICES
        jp nc, _zos_vfs_invalid_parameter
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
        jp z, _zos_vfs_invalid_parameter
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
        ; TODO: implement realpath
        IF 0
zos_realpath:
        push de
        push bc
        ; Check if the size of HL is smaller than CONFIG_KERNEL_PATH_MAX
        call strlen
        push hl
        ld hl, CONFIG_KERNEL_PATH_MAX
        xor a
        sbc hl, bc
        pop hl
        ; If carry, BC is too big!
        jp c, _zos_realpath_too_big
        ; C will be our flags
        ; Bit 7: DE path at root
        ; Bit 1: '..' seen
        ; Bit 1: '.' seen
        ; Bit 0: '/' seen
        ld c, 0x80
_zos_realpath_loop:
        ld a, (hl)
        or a    ; Check if end of string
        jp z, _zos_realpath_end_str
        cp '/'
        jp z, _zos_realpath_slash
        cp '.'
        jp z, _zos_realpath_dot
        ; Other characters, should be valid (printable)
        ld (de), a
        inc de
        ; We should reset C to 0 now
        xor a
        ld c, a
        jp _zos_realpath_loop
        ; End of the string, write NULL character
        xor a
        jp _zos_realpath_end_str
_zos_realpath_slash:
        ; Loop until we find another char than slash or NULL
        ld a, (hl)
        or a
        ; We have found a NULL byte while looking for a non-slash
        jp z, _zos_realpath_single_slash_end
        cp '/'
        jp nz, _zos_realpath_slash_cont
        ; go to next char
        inc hl
        jp z, _zos_realpath_slash
_zos_realpath_slash_cont:
        ; We have found another char than '/', go back to the normal flow, after
        ; copying the slash
        ld (de), a
        inc de
_zos_realpath_single_slash_end:
        ; Here, B is at least 1, so we can write / and NULL
        ld a, '/'
        ld (de), a
        inc de
        xor a
        jp _zos_realpath_end_str
_zos_realpath_dot:

_zos_realpath_end_str:
        xor a
        ld (de), a
        pop bc
        pop de
        ret
_zos_realpath_too_big:
        ld a, ERR_PATH_TOO_LONG
        pop bc
        pop de
        ret
        ENDIF

        SECTION KERNEL_BSS
        ; Each of these entries points to either a driver (when opened a device) or an abstract
        ; structure returned by a disk (when opening a file)
_dev_default_stdout: DEFS 2
_dev_default_stdin: DEFS 2
_dev_table: DEFS CONFIG_KERNEL_MAX_OPENED_DEVICES * 2
_vfs_current_dir_backup: DEFS CONFIG_KERNEL_PATH_MAX + 1   ; Used before executing a program
_vfs_current_dir: DEFS CONFIG_KERNEL_PATH_MAX + 1          ; Restored once a program exits
        ; Work buffer usable by any (virtual) file system. It shall only be used by one
        ; FS implementation at a time, thus, it shall be used as a temporary buffer in
        ; the routines.
        PUBLIC _vfs_work_buffer
_vfs_work_buffer: DEFS VFS_WORK_BUFFER_SIZE
