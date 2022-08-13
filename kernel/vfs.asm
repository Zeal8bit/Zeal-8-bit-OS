        INCLUDE "osconfig.asm"
        INCLUDE "vfs_h.asm"
        INCLUDE "errors_h.asm"
        INCLUDE "disks_h.asm"

        SECTION KERNEL_TEXT

        PUBLIC zos_vfs_init
zos_vfs_init:
        ld hl, _vfs_current_dir
        ld (hl), DISK_DEFAULT_LETTER
        inc hl
        ld (hl), ':'
        inc hl
        ld (hl), '/'
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
        ; Drivers name shall not exceed 4 characters and must be preceeded by #
        ; (5 characters in total)
        ; Names not starting with # will be considered as files.
        ; Parameters:
        ;       DE - Name: driver or file
        ;       H - Flags, can be O_RDWR, O_RDONLY, O_WRONLY, O_NONBLOCK, O_CREAT, O_APPEND, etc...
        ;           It is possible to OR them.
        ; Returns:
        ;       A - Number for the newly opened dev on success, negated error value else.
        ; Alters:
        ;       A, HL
        PUBLIC zos_vfs_open
zos_vfs_open:


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

        ; Read the given dev number
        ; Parameters:
        ;       H  - Number of the dev to write to
        ;       DE - Buffer to store the bytes read from the dev, the buffer must NOT cross page boundary
        ;       BC - Size of the buffer passed, maximum size is 16K
        ; Returns:
        ;       A  - 0 on success, error value else
        ;       BC - Number of bytes remaning to read. 0 means the buffer has been filled.
        ;       A, BC
        PUBLIC zos_vfs_read
zos_vfs_read:        


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
zos_vfs_close:

        ; Return the stats of an opened file.
        ; Structure returned looks like:
        ;  char name[8];
        ;  char ext[3];
        ;  uint32 size_bytes;
        ;  timestamp date; 
        ; Timestamp is like:
        ;  uint16 year;
        ;  uint8 month;
        ;  uint8 day;   (Optional)
        ;  uint8 date;
        ;  uint8 hour;
        ;  uint8 minutes;
        ;  uint8 seconds;
        ; Total = 8 bytes
        ; Where all the values are in BCD format
        ; Parameters:
        ;       H - Dev number
        ;       DE - File info stucture, this memory pointed must be big
        ;            enough to store the file information
        ; Returns:
        ;       A - 0 on success, error else
        ; Alters:
        ;       TBD
        PUBLIC zos_vfs_dstat
zos_vfs_dstat:

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
        ret

        SECTION KERNEL_BSS
        ; Each of these entries points to either a driver (when opened a device) or an abstract
        ; structure returned by a disk (when opening a file)
_dev_default_stdout: DEFS 2
_dev_default_stdin: DEFS 2
_dev_table: DEFS CONFIG_KERNEL_MAX_OPENED_DEVICES * 2
_vfs_current_dir: DEFS CONFIG_KERNEL_PATH_MAX