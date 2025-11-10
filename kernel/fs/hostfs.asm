; SPDX-FileCopyrightText: 2024 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    INCLUDE "osconfig.asm"
    INCLUDE "vfs_h.asm"
    INCLUDE "errors_h.asm"
    INCLUDE "drivers_h.asm"
    INCLUDE "disks_h.asm"
    INCLUDE "utils_h.asm"
    INCLUDE "strutils_h.asm"
    INCLUDE "fs/hostfs_h.asm"

    SECTION KERNEL_TEXT


wait_for_completion:
    in a, (IO_STATUS)
    ; A is 0xFF if the host is busy
    inc a
    jr z, wait_for_completion
    ; Restore A value, which contains the error code
    dec a
    ret


    ; Open a file from a disk that has a RAWTABLE filesystem
    ; Parameters:
    ;       B - Flags, can be O_RDWR, O_RDONLY, O_WRONLY, O_NONBLOCK, O_CREAT, O_APPEND, etc...
    ;       HL - Absolute path, without the disk letter (without X:), guaranteed not NULL by caller.
    ;       DE - Driver address, guaranteed not NULL by the caller.
    ; Returns:
    ;       A - ERR_SUCCESS on success, error code else
    ;       HL - Opened-file structure address, passed through all the other calls, until closed
    ; Alters:
    ;       A, BC, DE, HL
    PUBLIC zos_fs_hostfs_open
zos_fs_hostfs_open:
    ; Give the parameters to the host
    ld a, b
    out (IO_ARG0_REG), a
    ld a, l
    out (IO_ARG1_REG), a
    ld a, h
    out (IO_ARG2_REG), a
    ; Start the operation
    ld a, OP_OPEN
    out (IO_OPERATION), a
    call wait_for_completion
    ret nz
    ; Check if we have to allocate a file or a directory
    in a, (IO_ARG5_REG)
    or a
    jr z, _open_file
    ; Open a directory, put driver address in BC
    ld b, d
    ld c, e
    ld a, FS_HOSTFS
    call zos_disk_allocate_opndir
    or a
    ret nz ; check for errors
    jr open_end
_open_file:
    ; Allocate the file descriptor in which we store an abstract context
    ld a, b
    and 0xf
    rlca
    rlca
    rlca
    rlca
    or FS_HOSTFS
    push af
    ; Driver address in BC
    ld b, d
    ld c, e
    ; File size in DEHL (returned by the host)
    in a, (IO_ARG0_REG)
    ld l, a
    in a, (IO_ARG1_REG)
    ld h, a
    in a, (IO_ARG2_REG)
    ld e, a
    in a, (IO_ARG3_REG)
    ld d, a
    pop af
    call zos_disk_allocate_opnfile
    or a
    ret nz  ; If error, return directly
open_end:
    ; Fill the user field with the abstract value got from the host
    in a, (IO_ARG4_REG)
    ld (de), a
    ; Success
    xor a
    ret


    ; Get the stats of a file from disk.
    ; This includes the date, the size and the name. More info about the stat structure
    ; in `vfs_h.asm` file.
    ; Parameters:
    ;       BC - Driver address, guaranteed not NULL by the caller.
    ;       HL - Opened file structure address, pointing to the user field.
    ;       DE - Address of the STAT_STRUCT to fill.
    ; Returns:
    ;       A - ERR_SUCCESS on success, error code else
    ; Alters:
    ;       A, BC, DE, HL (Can alter any of the fields)
    PUBLIC zos_fs_hostfs_stat
zos_fs_hostfs_stat:
    ld a, e
    out (IO_ARG0_REG), a
    ld a, d
    out (IO_ARG1_REG), a
    ld a, (hl)
    out (IO_ARG2_REG), a
    ; Start the operation
    ld a, OP_STAT
    out (IO_OPERATION), a
    jp wait_for_completion


    ; Read bytes of an opened file.
    ; At most BC bytes must be read in the buffer pointed by DE.
    ; Upon completion, the actual number of bytes filled in DE must be
    ; returned in BC register. It must be less or equal to the initial
    ; value of BC.
    ; Parameters:
    ;       HL - Address of the opened file. Guaranteed by the caller to be a
    ;            valid opened file. It embeds the offset to read from the file,
    ;            the driver address and the user field (filled above).
    ;            READ-ONLY, MUST NOT BE MODIFIED.
    ;       DE - Buffer to fill with the read bytes. Guaranteed to not be cross page boundaries.
    ;       BC - Size of the buffer passed, maximum size is a page size guaranteed.
    ;            It is also guaranteed to not overflow the file's total size.
    ; Returns:
    ;       A  - 0 on success, error value else
    ;       BC - Number of bytes filled in DE.
    ; Alters:
    ;       A, BC, DE, HL
    PUBLIC zos_fs_hostfs_read
zos_fs_hostfs_read:
    ld a, OP_READ
    push af
    ; Fall-through
_zos_fs_hostfs_read_write:
    ld a, l
    out (IO_ARG0_REG), a
    ld a, h
    out (IO_ARG1_REG), a
    ld a, e
    out (IO_ARG2_REG), a
    ld a, d
    out (IO_ARG3_REG), a
    ld a, c
    out (IO_ARG4_REG), a
    ld a, b
    out (IO_ARG5_REG), a
    ; Start the operation
    pop af
    out (IO_OPERATION), a
    call wait_for_completion
    ret nz
    in a, (IO_ARG4_REG)
    ld c, a
    in a, (IO_ARG5_REG)
    ld b, a
    xor a
    ret


    ; Perform a write on an opened file, which is located on a
    ; disk that is using a rawtable filesystem.
    ; Parameters:
    ;       HL - Address of the opened file. Guaranteed by the caller to be a
    ;            valid opened file. It embeds the offset to write to the file,
    ;            the driver address and the user field.
    ;            READ-ONLY, MUST NOT BE MODIFIED.
    ;       DE - Buffer containing the bytes to write to the opened file, the buffer is gauranteed to
    ;            NOT cross page boundary.
    ;       BC - Size of the buffer passed, maximum size is a page size
    ; Returns:
    ;       A  - ERR_SUCCESS on success, error code else
    ;       BC - Number of bytes in DE.
    ; Alters:
    ;       A, BC, DE, HL
    PUBLIC zos_fs_hostfs_write
zos_fs_hostfs_write:
    ld a, OP_WRITE
    push af
    jr _zos_fs_hostfs_read_write


    ; Close an opened file, which is located on a disk that is
    ; using the rawtable filesystem.
    ; Note: _vfs_work_buffer can be used at our will here
    ; Parameters:
    ;       HL - (RW) Address of the user field in the opened file structure
    ;       DE - Driver address
    ; Returns:
    ;       A  - 0 on success, error value else
    ; Alters:
    ;       A, BC, DE, HL
    PUBLIC zos_fs_hostfs_close
zos_fs_hostfs_close:
    ; Get the abstract value from the user field
    ld a, (hl)
    out (IO_ARG0_REG), a
    ; Start the operation
    ld a, OP_CLOSE
    out (IO_OPERATION), a
    jp wait_for_completion


    ; ====================== Directories related ====================== ;

    ; Open a directory from a disk that has a RAWTABLE filesystem.
    ; Note: Currently, RAWTABLE only supports a single directory,
    ;       the root one: '/'.
    ; Parameters:
    ;       HL - Absolute path, without the disk letter (without X:), guaranteed not NULL by caller.
    ;       DE - Driver address, guaranteed not NULL by the caller.
    ; Returns:
    ;       A - ERR_SUCCESS on success, error code else
    ;       HL - Opened-dir structure address, passed through all the other calls, until closed
    ; Alters:
    ;       A, BC, DE, HL
    PUBLIC zos_fs_hostfs_opendir
zos_fs_hostfs_opendir:
    ; Give the parameters to the host, keep it similar to `open`, so start at ARG1
    ld a, l
    out (IO_ARG1_REG), a
    ld a, h
    out (IO_ARG2_REG), a
    ; Start the operation
    ld a, OP_OPENDIR
    out (IO_OPERATION), a
    call wait_for_completion
    ret nz
    ; Allocate the file descriptor in which we store an abstract context
    ; We arrive here with the parameters:
    ;   DE - Address of the directory on the disk
    ;   BC - Disk driver address
    ; We have to allocate a directory descriptor
    ld a, FS_HOSTFS
    ; Driver address in BC
    ld b, d
    ld c, e
    call zos_disk_allocate_opndir
    ; File size in DEHL (returned by the host)
    or a
    ret nz
    ; Fill the user field with the abstract value got from the host
    in a, (IO_ARG4_REG)
    ld (de), a
    ; Success
    xor a
    ret


    ; Read the next entry from the opened directory and store it in the user's buffer.
    ; The given buffer is guaranteed to be big enough to store DISKS_DIR_ENTRY_SIZE bytes.
    ; Note: _vfs_work_buffer can be used at our will here
    ; Parameters:
    ;       HL - Address of the user field in the opened directory structure. This is the same address
    ;            as the one given when opendir was called.
    ;       DE - Buffer to fill with the next entry data. Guaranteed to not be cross page boundaries.
    ;            Guaranteed to be at least DISKS_DIR_ENTRY_SIZE bytes.
    ; Returns:
    ;       A - ERR_SUCCESS on success,
    ;           ERR_NO_MORE_ENTRIES if the end of directory has been reached,
    ;           error code else
    ; Alters:
    ;       A, BC, DE, HL (can alter any)
    PUBLIC zos_fs_hostfs_readdir
zos_fs_hostfs_readdir:
    ; Provide the structure to fill to the host
    ld a, e
    out (IO_ARG0_REG), a
    ld a, d
    out (IO_ARG1_REG), a
    ; Get the abstract value from the user field
    ld a, (hl)
    out (IO_ARG2_REG), a
    ; Start the operation
    ld a, OP_READDIR
    out (IO_OPERATION), a
    jp wait_for_completion


    ; Create a directory on a disk
    ; Parameters:
    ;       HL - Absolute path of the new directory to create, without the
    ;            disk letter (without X:/), guaranteed not NULL by caller.
    ;       DE - Driver address, guaranteed not NULL by the caller.
    ; Returns:
    ;       A - ERR_SUCCESS on success, error code else
    ; Alters:
    ;       A
    PUBLIC zos_fs_hostfs_mkdir
zos_fs_hostfs_mkdir:
    ; Give the parameters to the host, keep it similar to `open`, so start at ARG1
    ld a, l
    out (IO_ARG1_REG), a
    ld a, h
    out (IO_ARG2_REG), a
    ; Start the operation
    ld a, OP_MKDIR
    out (IO_OPERATION), a
    jp wait_for_completion


    ; Remove a file or a(n empty) directory on the disk
    ; Parameters:
    ;       HL - Absolute path of the file/dir to remove, without the
    ;            disk letter (without X:), guaranteed not NULL by caller.
    ;       DE - Driver address, guaranteed not NULL by the caller.
    ; Returns:
    ;       A - ERR_SUCCESS on success, error code else
    ; Alters:
    ;       A
    PUBLIC zos_fs_hostfs_rm
zos_fs_hostfs_rm:
    ; Give the parameters to the host, keep it similar to `open`, so start at ARG1
    ld a, l
    out (IO_ARG1_REG), a
    ld a, h
    out (IO_ARG2_REG), a
    ; Start the operation
    ld a, OP_RM
    out (IO_OPERATION), a
    jp wait_for_completion