; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    INCLUDE "osconfig.asm"
    INCLUDE "vfs_h.asm"
    INCLUDE "errors_h.asm"
    INCLUDE "drivers_h.asm"
    INCLUDE "disks_h.asm"
    INCLUDE "utils_h.asm"
    INCLUDE "strutils_h.asm"
    INCLUDE "fs/zealfs_h.asm"

    ; The maximum amount of pages a storage can have is 256 (64KB), so the bitmap size is 256/32
    DEFC FS_BITMAP_SIZE = 32
    DEFC FS_NAME_LENGTH = 16
    DEFC FS_PAGE_SIZE  = 256
    DEFC FS_OCCUPIED_BIT = 7
    DEFC FS_ISDIR_BIT = 0
    DEFC FS_OCCUPIED_MASK = 1 << FS_OCCUPIED_BIT
    DEFC FS_ISDIR_MASK = 1 << FS_ISDIR_BIT

    DEFC RESERVED_SIZE = 28

    ; ZealFS partition header. This is the first data in the store:
    DEFVARS 0 {
        zealfs_magic_t       DS.B 1 ; Must be 'Z' ascii code
        zealfs_version_t     DS.B 1 ; FS version
        zealfs_bitmap_size_t DS.B 1 ; Number of 256-byte pages in the image. Without counting the first page
                                    ; which contains the header
        zealfs_free_pages_t  DS.B 1 ; Number of free pages
        zealfs_pages_bitmap  DS.B FS_BITMAP_SIZE ; Bitmap for the free pages. A used page is marked as 1, else 0
        zealfs_reserved_t    DS.B RESERVED_SIZE ; Current number of entries in the root directory
        zealfs_root_entries  DS.B 1 ; The ZealFileEntry entries start from here
    }

    DEFC ZEALFS_HEADER_SIZE = zealfs_reserved_t
    DEFC ZEALFS_ROOT_DIR_OFFSET = zealfs_root_entries
    ASSERT(ZEALFS_ROOT_DIR_OFFSET == 64)

    ; ZealFileEntry structure. Entry for a single file or directory.
    DEFVARS 0 {
        zealfs_entry_flags  DS.B 1                  ; flags for the file entry
        zealfs_entry_name   DS.B FS_NAME_LENGTH     ; entry name, including the extension
        zealfs_entry_start  DS.B 1                  ; start page index
        zealfs_entry_size   DS.W 1                  ; size in bytes of the file
        zealfs_entry_date   DS.B DATE_STRUCT_SIZE   ; zos date format
        zealfs_entry_rsvd   DS.B 4                  ; Reserved
        zealfs_entry_end    DS.B 0
    }

    DEFC ZEALFS_ENTRY_SIZE = zealfs_entry_end
    DEFC ZEALFS_ENTRY_RSVD_SIZE = 4
    ASSERT(ZEALFS_ENTRY_SIZE == 32)

    DEFC ROOT_MAX_ENTRIES = ((FS_PAGE_SIZE - ZEALFS_ROOT_DIR_OFFSET) / ZEALFS_ENTRY_SIZE)
    DEFC DIR_MAX_ENTRIES  = (FS_PAGE_SIZE / ZEALFS_ENTRY_SIZE)
    ; First context to pass is in fact the offset of zealfs_root_entries
    DEFC FS_ROOT_CONTEXT  = zealfs_root_entries

    ; These macros points to code that will be loaded and executed within the buffer
    DEFC RAM_EXE_CODE  = _vfs_work_buffer
    DEFC RAM_EXE_READ  = RAM_EXE_CODE
    DEFC RAM_EXE_WRITE = RAM_EXE_READ + 8
    ; This 3-byte operation buffer will contain either JP RAM_EXE_READ or JP RAM_EXE_WRITE.
    ; It will be populated and used by the algorithm that will perform reads and writes from and to files.
    DEFC RAM_EXE_OPER  = RAM_EXE_WRITE + 8
    ; Same here, this will contain a JP instruction that will be used as a callback when the
    ; next disk page of a file is 0 (used during reads and writes)
    DEFC RAM_EXE_PAGE_0 =  RAM_EXE_OPER + 3

    ; Use this word to save which entry of the last directory was free. This will be filled by
    ; _zos_zealfs_check_next_name. Must be cleaned by the caller.
    DEFC RAM_FREE_ENTRY = RAM_EXE_PAGE_0 + 3  ; Reserve 3 bytes for the previous RAM code
    DEFC RAM_BUFFER     = RAM_FREE_ENTRY + 2 ; Reserve 2 byte for the previous label

    ; Make sure we can still store at least a header in the buffer
    ASSERT(24 + ZEALFS_HEADER_SIZE <= VFS_WORK_BUFFER_SIZE)

    ; Used to create self-modifying code in RAM
    DEFC XOR_A    = 0xaf
    DEFC LD_L_A   = 0x6f
    DEFC LD_H_A   = 0x67
    DEFC PUSH_HL  = 0xe5
    DEFC LD_HL    = 0x21
    DEFC JP_NNNN  = 0xc3
    DEFC ARITH_OP = 0xcb
    DEFC RET_OP   = 0xc9

    EXTERN _vfs_work_buffer
    EXTERN zos_date_getdate_kernel

    SECTION KERNEL_TEXT

zos_zealfs_init:
    ret

    ; Like the routine below, browse the absolute path given in HL until the last name is reached.
    ; It will check that all the names on the path corresponds to folders that actually exist on
    ; the disk.
    ; This routine will load the driver's READ function address in the global buffer before
    ; executing the routine below (RAM_EXE_READ)
    ; Parameters and return values are therefore the same
zos_zealfs_load_and_check_next_name:
    push hl
    call zos_zealfs_prepare_driver_read
    pop hl
    ; Fall-through

    ; Browse the absolute path given in HL and check whether they exist in the filesystem.
    ; All the parameters are not NULL.
    ; Parameters:
    ;   HL - Name of the entry to check (WITHOUT the first /)
    ;   RAM_EXE_READ - Loaded with driver's read function (see zos_zealfs_prepare_driver_read)
    ; Returns:
    ;   HL - Entry following the one checked (if B is not 1)
    ;   DE - Offset of the entry in the disk if exists, offset of the last entry in the last
    ;        directory in the path else. (Thus D contains the disk page of that directory)
    ;   B / Z flag - 0 if we have reached the last entry/end of the string
    ;   A  - 0 on success, ERR_NO_SUCH_ENTRY if the entry to check is not found,
    ;        other error code else (in that case B shall not be 0, Z flag must not be set)
    ; Alters:
    ;   A, HL, BC, DE
_zos_zealfs_check_next_name:
    ; First slash in path MUST BE SKIPPED BY CALLER
    ; Iterate over the path, checking each directory existence
    ld c, 1                 ; Marks root directory
    ld de, FS_ROOT_CONTEXT  ; First context to pass
_zos_zealfs_check_name_next_dir:
    ; Clear the empty flag first
    xor a
    ld (RAM_FREE_ENTRY), a
    ld (RAM_FREE_ENTRY + 1), a
    call _zos_zealfs_check_next_name_nested
    ; Restore the '/' that was potentially replaced with a \0
    dec hl
    ld (hl), '/'
    inc hl
    ld c, 0
    ; If B is 1, we have reached the end of the string
    dec b
    ret z
    ; Check for errors else
    or a
    ret nz
    jp _zos_zealfs_check_name_next_dir
    ;   C  - 1 if root of the disk, 0 else
    ;   HL - Name of the entry to check
    ;   DE - Context returned by this function (FS_ROOT_CONTEXT at first)
    ; Returns:
    ;   HL - Entry following the one checked (if B is not 1)
    ;   DE - Context passed to this function again
    ;   B  - 1 if we have reached the last entry/end of the string
_zos_zealfs_check_next_name_nested:
    push hl
    ; Look for the next '/' or '\0' in the string, maximum length is FS_NAME_LENGTH
    ld b, FS_NAME_LENGTH + 1
_zos_zealfs_next_char:
    ld a, (hl)
    or a
    jr z, _zos_zealfs_check_name_found_null
    ; Check / character
    cp '/'
    jr z, _zos_zealfs_check_name_found
    inc hl
    djnz _zos_zealfs_next_char
    ; The entry name is longer than FS_NAME_LENGTH, no need to continue, it's an error
    ld a, ERR_INVALID_NAME
    ; B is 0, we can return safely after cleaning the stack
    pop hl
    ret
    ; Reach this label when we detect a / in the name
_zos_zealfs_check_name_found:
    ; Replace the slash with a NULL-byte
    ld (hl), 0
    inc hl ; Point to the character after it
    ; If the next char is also a NULL-byte, it means that the string is ending with /,
    ; this can be the case with paths that point to a directory, treat it as the end of string
    ld a, (hl)
    or a
    jr z, _zos_zealfs_check_name_found_null
    ld a, '/'   ; not necessary but keep it symmetric with the other case
    ; Exchange with the original string which is on the top of the stack
    ; So that the "next" entry to check is on the top of the stack
    ex (sp), hl
    jp _zos_zealfs_check_name_start_search
_zos_zealfs_check_name_found_null:
    ; Reach here if we have reached the end of the string, store the original name in HL and
    ; on the stack
    pop hl
    push hl
_zos_zealfs_check_name_start_search:
    ; Here, we have the following register organization:
    ;   - A is 0 if we reached the end of the string, else, it is '/'
    ;   - C contains 1 if we are at the root, 0 else
    ;   - HL points to the name to check
    ;   - DE contains the context, which is the offset to the next entry to read
    ;   - [SP] address of the next entry
    ; We will optimize a bit and ignore the header data, look at the entries directly.
    ; Check how many bytes we need to read, by default, we will browse max dir entries
    ld b, DIR_MAX_ENTRIES
    dec c
    jr nz, _zos_zealfs_check_name_not_root
    ; Root directory
    ld b, ROOT_MAX_ENTRIES
_zos_zealfs_check_name_not_root:
    ; C can be re-used here, store A inside, as such, we can put BC on the stack
    ld c, a
_zos_zealfs_check_name_driver_read_loop:
    push bc ; Store the current flags
    push de ; Save the offset
    push hl ; Store the file name
    ; Read the flags, filename and start page of the file entry
    ASSERT(zealfs_entry_flags == 0)
    ASSERT(zealfs_entry_name == 1)
    ; Switch the offset from DE to HL
    ex de, hl
    ; Destination buffer in DE
    ld de, RAM_BUFFER
    ; Read until zealfs_entry_size (included)
    ld bc, zealfs_entry_size + 2 ; 16-bit
    call RAM_EXE_READ
    ; In all cases we will need to pop the name out of the stack
    pop hl
    ; Check if an error ocurred
    or a
    jr nz, _zos_zealfs_check_name_error
    ; No error, we can check the flags!
    ld a, (RAM_BUFFER + zealfs_entry_flags)
    bit FS_OCCUPIED_BIT, a
    jr z, _zos_zealfs_check_name_next_offset
    ld de, RAM_BUFFER  + zealfs_entry_name
    ld bc, FS_NAME_LENGTH
    call strncmp
    or a
    jr z, _zos_zealfs_check_name_entry_found
_zos_zealfs_check_name_next_offset:
    ; The entry is not the correct one or empty, we need to get the offset back
    ; and increment it to check the next entry
    pop de
    ; Increment the offset by the size of an entry
    ex de, hl
    ; Before incrementing, save the current offset in the FREE_ENTRY if and only if
    ; we found an empty entry (i.e. Z flag is set)
    jp nz, _zos_zealfs_no_set
    ld (RAM_FREE_ENTRY), hl
_zos_zealfs_no_set:
    ld bc, ZEALFS_ENTRY_SIZE
    add hl, bc
    ex de, hl
    ; Get back the flags and check if we need to continue the loop
    pop bc
    djnz _zos_zealfs_check_name_driver_read_loop
    ; No more entries to check in the directory anymore...error.
    ; B is 0 already, but it must be set to 1 (reached end of str) if C is 0.
    ld a, c
    or c
    jp nz, _zos_zealfs_no_add
    inc b
_zos_zealfs_no_add:
    ld a, ERR_NO_SUCH_ENTRY
    pop hl
    ret
_zos_zealfs_check_name_entry_found:
    pop de
    pop bc
    ; We won't need HL anymore, pop it out of the stack
    pop hl
    ; The entry has been found, we have to check if the flags are compatible,
    ; in other words, if we are not at the end of the path (C != 0), the entry must be a directory
    ; i.e. if C != 0, then flags & FS_ISDIR_MASK == 1
    ld a, c
    or a
    jr z, _zos_zealfs_check_name_entry_found_no_check
    ld a, (RAM_BUFFER + zealfs_entry_flags)
    and FS_ISDIR_MASK
    ; If the result is 0, then we have a problem, we are trying to open a file as a dir.
    ld a, ERR_NOT_A_DIR
    ret z
_zos_zealfs_check_name_entry_found_no_check:
    ; Here we have to prepare the return values:
    ; If we have reached the end of the path, we have to return the current offset
    ; If we are simply traversing a directory, we have to calculate its page offset and return it
    ld a, c
    or a
    ld b, 1 ; Prepare B return value
    ; If A is 0, we reached the end of the path, we can return current A and DE.
    ret z
    ; We have to calculate the new page offset.
    ld a, (RAM_BUFFER + zealfs_entry_start)
    ld d, a
    xor a   ; ERR_SUCCESS
    ld b, a ; Not end of string
    ld e, a
    ret
_zos_zealfs_check_name_error:
    ; Clean the stack and return
    pop de
    pop bc
    pop hl
    ret

    ; The address to return in HL is on the top of the stack
    ; HL contains the NULL-terminated file name string to check

    ; Open a file from a disk that has a ZealFS filesystem
    ; Parameters:
    ;   B - Flags, can be O_RDWR, O_RDONLY, O_WRONLY, O_CREAT, O_APPEND, etc...
    ;   HL - Absolute path, without the disk letter (without X:), guaranteed not NULL by caller, must not
    ;        be altered (can be modified but must be restored)
    ;   DE - Driver address, guaranteed not NULL by the caller.
    ; Returns:
    ;   A - ERR_SUCCESS on success, error code else
    ;   HL - Opened-file structure address, passed through all the other calls, until closed
    ; Alters:
    ;   A, BC, DE, HL
    PUBLIC zos_zealfs_open
zos_zealfs_open:
    ; Treat / as a special case
    inc hl
    ld a, (hl)
    or a
    jp z, _zos_zealfs_opendir_root
    ; Not empty path, we can continue
    push de
    push bc
    ; Check that the whole path exists, except maybe the last name (file/folder)
    call zos_zealfs_load_and_check_next_name
    pop bc
    ; If the Z flag is not set, an error occurred and A was set
    jr nz, _zos_zealfs_error
    ; Do not pop DE right now, it contains a context
    ; If A has no error, the name exists, check that it is a file, and not a dir
    or a
    jr z, _zos_zealfs_check_flags
    ; ERR_NO_SUCH_ENTRY can be valid if O_CREAT was passed, if the error is something
    ; else, it's a real error, clean the stack and return
    cp ERR_NO_SUCH_ENTRY
    jr nz, _zos_zealfs_error
    ; Check that the O_CREAT flag was given, if that's not the case, it's an error
    ld a, b
    and O_CREAT
    jr z, _zos_zealfs_error_no_such_entry
    ; O_CREAT has been provided, we should create the file first.
    ; Get the driver address out of the stack, but keep it on the stack still.
    ; Ignore the context currently in DE.
    pop de
    push de
    ; We will still the flags later on
    push bc
    ld b, 0
    ; Parameters:
    ;   HL - Name of the entry
    ;   DE - Disk driver address
    ;   B - 1 for a directory, 0 for a regular file
    call zos_zealfs_new_entry
    ; The new context becomes the former free entry
    ld de, (RAM_FREE_ENTRY)
    pop bc
    ; Check for errors
    or a
    jr nz, _zos_zealfs_error
_zos_zealfs_check_flags:
    ; Allow directories to be opened, however, directory must not be accessed with
    ; `read` nor `write`.
    ; TODO: Call the driver's open function!
    ; We arrive here with the parameters:
    ;   HL - Name of the file to open (NULL-terminated)
    ;   DE - Context of the file
    ;   B - Flags to open the file with
    ;   [SP] - Driver address
    ; -----------------------------------
    ; Check if we are trying to open a directory
    ld a, (RAM_BUFFER + zealfs_entry_flags)
    rrca
    jp c, zos_zeal_open_with_dir
    ; Check if the flags include O_TRUNC
    ld a, b
    ; Check if O_TRUNC was passed, if that was the case, the size has to be shrunk to 0
    and O_TRUNC
    jr z, _zos_zealfs_no_trunc
    ; O_TRUNC was passed, the simplest solution is to set the size to 0
    ld hl, 0
    jp _zos_zealfs_open_load_hl
_zos_zealfs_no_trunc:
    ld hl, (RAM_BUFFER + zealfs_entry_size)
_zos_zealfs_open_load_hl:
    ld a, b
    rlca
    rlca
    rlca
    rlca
    or FS_ZEALFS    ; Put the flags in the upper nibble and FS in the lower one
    ; Driver address in BC
    pop bc
    ; Save the context on the stack
    push de
    ; HL has been set already, set DE to 0 now
    ld de, 0
    call zos_disk_allocate_opnfile
    or a
    jr nz, _zos_zealfs_error
    ; Save the context in the structure private field (4 bytes)
    ; The context is in fact the offset on the disk of the file entry.
    ex de, hl
    pop bc
    ld (hl), c
    inc hl
    ld (hl), b
    inc hl
    ; Let's store the start page in the next byte
    ld a, (RAM_BUFFER + zealfs_entry_start)
    ld (hl), a
    inc hl
    ; We still have one free byte we can use, store the flags
    ld a, (RAM_BUFFER + zealfs_entry_flags)
    ld (hl), a
    ; Put back the structure to return in HL
    ex de, hl
    ; Mark A as success
    xor a
    ret
_zos_zealfs_not_file_pop_error:
    pop bc
_zos_zealfs_not_file_error:
    ld a, ERR_NOT_A_FILE
    ret
_zos_zealfs_error_no_such_entry:
    ld a, ERR_NO_SUCH_ENTRY
_zos_zealfs_error:
    pop bc
    ret


    ; Read bytes of an opened file on a ZealFS disk.
    ; At most BC bytes must be read in the buffer pointed by DE.
    ; Upon completion, the actual number of bytes filled in DE must be
    ; returned in BC register. It must be less or equal to the initial
    ; value of BC.
    ; Note: _vfs_work_buffer can be used at our will here
    ; Parameters:
    ;   HL - Address of the opened file. Guaranteed by the caller to be a
    ;        valid opened file. It embeds the offset to read from the file,
    ;        the driver address and the user field (filled above).
    ;        READ-ONLY, MUST NOT BE MODIFIED.
    ;   DE - Buffer to fill with the bytes read. Guaranteed to not be cross page boundaries.
    ;   BC - Size of the buffer passed, maximum size is a page size guaranteed.
    ;        It is also guaranteed to not overflow the file's total size.
    ; Returns:
    ;   A  - 0 on success, error value else
    ;   BC - Number of bytes filled in DE.
    ; Alters:
    ;   A, BC, DE, HL
    PUBLIC zos_zealfs_read
zos_zealfs_read:
    ; Specify we need a read operation
    ld a, 1
    jp zos_zealfs_browse_file


    ; Perform a write on an opened file, which is located on a ZealFS disk.
    ; Parameters:
    ;   HL - Address of the opened file. Guaranteed by the caller to be a
    ;        valid opened file. It embeds the offset to write to the file,
    ;        the driver address and the user field.
    ;        READ-ONLY, MUST NOT BE MODIFIED.
    ;   DE - Buffer containing the bytes to write to the opened file, the buffer is guaranteed to
    ;        NOT cross page boundary.
    ;   BC - Size of the buffer passed, maximum size is a page size
    ; Returns:
    ;   A  - ERR_SUCCESS on success, error code else
    ;   BC - Number of bytes written in the file.
    ; Alters:
    ;   A, BC, DE, HL
    PUBLIC zos_zealfs_write
zos_zealfs_write:
    xor a
    jp zos_zealfs_browse_file


    ; Get the stats of a file from a disk that has a ZealFS filesystem
    ; This includes the date, the size and the name. More info about the stat structure
    ; in `vfs_h.asm` file.
    ; Parameters:
    ;   BC - Driver address, guaranteed not NULL by the caller.
    ;   HL - Opened file structure address:
    ;           * Pointing to `opn_file_usr_t` for files
    ;           * Pointing to `opn_file_size_t` for directories
    ;   DE - Address of the STAT_STRUCT to fill:
    ;           * Pointing to `file_date_t` for files
    ;           * Pointing to `file_size_t` for directories
    ; Returns:
    ;   A - ERR_SUCCESS on success, error code else
    ; Alters:
    ;   A, BC, DE, HL (Can alter any of the fields)
    PUBLIC zos_zealfs_stat
zos_zealfs_stat:
    ; Check if we are trying to stat a directory
    call zos_disk_stat_is_dir
    jr z, _zos_stat_file
_debug_me:
    ; Check the opened file structure for the current directory address:
    ; if the page index is 0, stat was called on the root `/`, handle it.
    inc hl
    inc hl
    ld a, (hl)
    or a
    jp z, zos_disk_stat_fill_root
    ; Make HL point to the offset on disk field (skip page index and iterator)
    inc hl
    inc hl
    ; Stat structure is pointing to size, set it to 0x100, and make it point to the date
    xor a
    ld (de), a
    inc de
    inc a
    ld (de), a
    inc de
    dec a
    ld (de), a
    inc de
    ld (de), a
    inc de
_zos_stat_file:
    ; Start by setting up the read function for the driver. Driver address must
    ; be in HL
    push de
    push hl
    ld d, b
    ld e, c
    call zos_zealfs_prepare_driver_read
    pop hl
    ; Keep the user buffer to fill on the stack
    ; Retrieve the offset on disk of the file from the user field
    ld a, (hl)
    inc hl
    ld h, (hl)
    ld l, a
    ; Offset to read is now in HL. We will read in a temporary buffer since the
    ; organization of the file header in ZealFS is different than the file stats
    ; structure.
    ld de, RAM_BUFFER
    ; Let's save some time and ignore the reserved bytes
    ld bc, ZEALFS_ENTRY_SIZE - ZEALFS_ENTRY_RSVD_SIZE
    call RAM_EXE_READ
    ; Before checking the return value, retrieve the user buffer from the stack
    pop de
    or a
    ret nz
    ASSERT(file_date_t == 4)
    ; We can optimize if we know that date structure follows the size
    ld hl, RAM_BUFFER + zealfs_entry_date
    ld bc, DATE_STRUCT_SIZE
    ldir
    ; User buffer (stat structure) points to the name now
    ld hl, RAM_BUFFER + zealfs_entry_name
    ASSERT(STAT_STRUCT_NAME_LEN == FS_NAME_LENGTH)
    ld bc, FS_NAME_LENGTH
    ldir
    ; Success, we can return
    xor a
    ret

    ; Close an opened file. On ZealFS this doesn't do anything special apart from
    ; calling the driver's close routine.
    ; Note: _vfs_work_buffer can be used at our will here
    ; Parameters:
    ;       HL - (RW) Address of the user field in the opened file structure
    ;       DE - Driver address
    ; Returns:
    ;       A  - 0 on success, error value else
    ; Alters:
    ;       A, BC, DE, HL
    PUBLIC zos_zealfs_close
zos_zealfs_close:
    ; If the opened file was opened with WRITE flags, the size may have been updated,
    ; thus, we need to write the new file size on the disk. Prepare the write routine.
    call zos_zealfs_prepare_driver_write_safe
    ; Keep HL on the stack, we are going to need it to get the info about the file.
    push hl
    GET_DRIVER_CLOSE_FROM_DE()
    ; Put the close routine address on the stack and get the opened file structure
    ex (sp), hl
    ; Check if the file was opened with write flag
    ld d, h
    ld e, l
    DISKS_FILE_IS_WRITE(opn_file_usr_t)
    ; If the Z flag is set, we should "return". ret here will jump to driver's close routine
    ; as it is on the stack
    ret z
    ; We have to update the file size on the disk. Get the file entry offset.
    ex de, hl
    ld e, (hl)
    inc hl
    ld d, (hl)
    DISKS_FILE_GET_SIZE(opn_file_usr_t + 1)
    ; HL points to the size field, exchange it with DE
    ex de, hl
    ; Make HL point to the size field in the disk file entry
    ld bc, zealfs_entry_size
    add hl, bc
    ; Perform a write on the disk (16-bit size)
    ld bc, 2
    call RAM_EXE_WRITE
    ; Store close routine address in HL
    pop hl
    ; Check error
    or a
    ret nz
    ; Jump to close routine
    jp (hl)


    ; Remove a file or an empty directory on the disk.
    ; Parameters:
    ;   HL - Absolute path of the file/dir to remove, without the disk letter (without X:),
    ;        guaranteed not NULL by caller.
    ;   DE - Driver address, guaranteed not NULL by the caller.
    ; Returns:
    ;   A - ERR_SUCCESS on success, error code else
    ; Alters:
    ;   A
    PUBLIC zos_zealfs_rm
zos_zealfs_rm:
    ; Treat / as a special case
    inc hl
    ld a, (hl)
    or a
    jr z, _zos_zealfs_rm_invalid
    call zos_zealfs_prepare_driver_write_safe
    call zos_zealfs_load_and_check_next_name
    ; Check that we reached the end of the string (Z flag must be set)
    ret nz
    ; Check that A is a success too
    or a
    ret nz
    ; Prepare the free_page self-modifying code that contains:
    ; res bit, (hl)
    ; ret
    ld a, ARITH_OP
    ld (RAM_EXE_PAGE_0), a
    ld a, RET_OP
    ld (RAM_EXE_PAGE_0 + 2), a
    ; The file was found, DE contains the offset of the file/directory on disk
    ; Test if the entry is a directory or a file
    ld a, (RAM_BUFFER)
    and FS_ISDIR_MASK
    jp nz, _zos_zealfs_rm_isdir
    ; The entry is a file, we have to free each page of the file.
    ; Start by marking the file entry as free, put its offset in HL.
    ex de, hl
    call _zos_zealfs_rm_mark_as_free
    or a
    ret nz
    ld a, (RAM_BUFFER + zealfs_entry_start)
    ld h, a
    ; Free the file page in H, keep it to read the next page
_zos_zealfs_rm_file_loop:
    ld l, 0
    push hl
    call zos_zealfs_free_page
    pop hl
    ; Read the next page
    ld de, RAM_BUFFER
    ld bc, 1
    call RAM_EXE_READ
    ; Check for error
    or a
    ret nz
    ; Get the "next" page of the current one
    ld a, (RAM_BUFFER)
    ld h, a
    or a
    ; If the "next" page is not free, continue the loop
    jp nz, _zos_zealfs_rm_file_loop
    ; End of the linked-lis tof pages, success
    xor a
    ret
_zos_zealfs_rm_isdir:
    push de
    ; The entry is a directory, check that it is empty, we have to iterate over
    ; all entries it contains. Put the start offset of the directory in HL.
    ld a, (RAM_BUFFER + zealfs_entry_start)
    ld h, a
    ld l, 0
_zos_zealfs_rm_isdir_loop:
    push hl
    ld de, RAM_BUFFER
    ld bc, 1
    call RAM_EXE_READ
    pop hl
    ; Check if there was an error while reading from the disk
    or a
    ret nz
    ; Check that the current entry is empty
    ld a, (RAM_BUFFER)
    and FS_OCCUPIED_MASK
    jp nz, _zos_zealfs_rm_isdir_notempty
    ; Current entry is empty, increment offset and continue
    ; Update the next entry offset (HL += ZEALFS_ENTRY_SIZE)
    ld a, ZEALFS_ENTRY_SIZE
    add l
    ld l, a
    ; On carry, the page containing the dir page has been overflowed, the dir is empty
    jp nc, _zos_zealfs_rm_isdir_loop
_zos_zealfs_rm_is_empty:
    ; Directory to remove is empty, we can mark it as free. The entry offset is on the stack
    ; The page to free is in H.
    ex (sp), hl
    call _zos_zealfs_rm_mark_as_free
    ; We have to free the page in H
    pop hl
    or a
    ret nz
    jp zos_zealfs_free_page
_zos_zealfs_rm_isdir_notempty:
    ; The directory is not empty, we can return right now
    ld a, ERR_DIR_NOT_EMPTY
    pop de
    ret
_zos_zealfs_rm_invalid:
    ld a, ERR_INVALID_PATH
    ret
_zos_zealfs_rm_mark_as_free:
    ; Set the flags at offset HL to 0
    ld bc, 1
    ld de, RAM_BUFFER
    xor a
    ld (de), a
    jp RAM_EXE_WRITE


    ;============= D I R E C T O R I E S   R O U T I N E S ================;


    ; Routine that pops the driver address from the stack and continues allocating
    ; a directory. This branch is used when `open` was invoked with a directory
    ; and not a file.
zos_zeal_open_with_dir:
    pop bc
    jr _zos_zealfs_opendir_allocate


    ; Open a directory from a ZealFS-formatted disk.
    ; The opened dir structure to return can be allocated thanks to `zos_disk_allocate_opndir`.
    ; Parameters: (Guaranteed not NULL by caller)
    ;       HL - Absolute path, without the disk letter (without X:)
    ;       DE - Disk driver address
    ; Returns:
    ;       A - ERR_SUCCESS on success, error code else
    ;       HL - Opened-dir structure address, passed through all the other calls, until closed
    ; Alters:
    ;       A, BC, DE, HL
    PUBLIC zos_zealfs_opendir
zos_zealfs_opendir:
    ; Treat / as a special case
    inc hl
    ld a, (hl)
    or a
    jr z, _zos_zealfs_opendir_root
    push de
    ; Check that the whole path exists, except maybe the last name (file/folder)
    call zos_zealfs_load_and_check_next_name
    pop bc  ; Driver address in BC
    ; If the Z flag is not set, an error occurred and A was set
    ret nz
    ; Do not pop DE right now, it contains a context
    ; A must also be - here as the entry (directory) must exist
    or a
    ret nz
    ; Check that the entry is a directory and not a file!
    ld a, (RAM_BUFFER + zealfs_entry_flags)
    ; We can optimize a bit when ISDIR is bit 0
    ASSERT(FS_ISDIR_BIT == 0)
    rrca
    ld a, ERR_NOT_A_DIR
    ret nc
_zos_zealfs_opendir_allocate:
    ; We arrive here with the parameters:
    ;   DE - Address of the directory on the disk
    ;   BC - Disk driver address
    ; We have to allocate a directory descriptor
    ld a, FS_ZEALFS
    push de
    push bc ; Save disk address
    call zos_disk_allocate_opndir
    pop bc
    or a
    ; Pop and return on error
    jr nz, _zos_zealfs_opendir_error_pop
    ; HL contains the address of the newly allocated opened dir entry
    ; DE points to the address of our private field, fill it with:
    ;   * Driver address
    ;   * Page index of the directory content - 1 byte
    ;   * Next entry index. The index will be updated after each call to readdir - 1 byte
    ;   * Address of directory entry on the disk (dir infos) - 2 bytes
    ex de, hl
    ; Save driver address
    ld (hl), c
    inc hl
    ld (hl), b
    inc hl
    ; Save page index + next entry index
    ld a, (RAM_BUFFER + zealfs_entry_start)
    ld (hl), a
    inc hl
    ld (hl), 0
    inc hl
    ; Address of directory entry
    pop bc
    ld (hl), c
    inc hl
    ld (hl), b
    ; Put back the original structure in HL and return success
    ex de, hl
    xor a
    ret
_zos_zealfs_opendir_root:
    ; Driver address is in DE, store it in BC instead
    ld b, d
    ld c, e
    push bc
    ld a, FS_ZEALFS
    call zos_disk_allocate_opndir
    pop bc
    or a
    ret nz
    ; HL contains the address of the newly allocated opened dir entry
    ; DE points to the address of our private field, fill it with:
    ;   * Driver address
    ;   * Page index of the directory content - 1 byte
    ;   * Next entry index. The index will be updated after each call to readdir - 1 byte
    ;   * Address of directory entry on the disk (dir infos) - 2 bytes
    ex de, hl
    ; Save driver address
    ld (hl), c
    inc hl
    ld (hl), b
    inc hl
    ; Save page index + next entry index
    xor a
    ld (hl), a
    inc hl
    ld (hl), FS_ROOT_CONTEXT & 0xff
    inc hl
    ; Address of directory entry, set it to 0
    ld (hl), a
    inc hl
    ld (hl), a
    ; Put back the original structure in HL and return success
    ex de, hl
    ; A is already 0
    ret
_zos_zealfs_no_more_entries_pop:
    ld a, ERR_NO_MORE_ENTRIES
_zos_zealfs_opendir_error_pop:
    pop de
    ret

    ; Read the next entry from the opened directory and store it in the user's buffer.
    ; The given buffer is guaranteed to be big enough to store DISKS_DIR_ENTRY_SIZE bytes.
    ; Note: _vfs_work_buffer can be used at our will here
    ; Parameters:
    ;       HL - Address of the user field in the opened directory structure. This is the same address
    ;            as the one given when `opendir` was called.
    ;       DE - Buffer to fill with the next entry data. Guaranteed to not be cross page boundaries.
    ;            Guaranteed to be at least DISKS_DIR_ENTRY_SIZE bytes.
    ; Returns:
    ;       A - ERR_SUCCESS on success,
    ;           ERR_NO_MORE_ENTRIES if the end of directory has been reached,
    ;           error code else
    ; Alters:
    ;       A, BC, DE, HL (can alter any)
    PUBLIC zos_zealfs_readdir
zos_zealfs_readdir:
    ; Get the driver address (DE) and prepare the read function
    push de
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    push hl
    call zos_zealfs_prepare_driver_read
    pop hl
    ; Load directory content page index on disk
    ld b, (hl)
    inc hl
    ; Load the next entry index
    ld c, (hl)
    ; If entry index is 0xFF, we have no more entries
    inc c
    ; Pop and return on error
    jp z, _zos_zealfs_no_more_entries_pop
    ; Restore the index
    dec c
    ; Look for the next user entry.
    ; Iterate until the offset (BC), jumps to the next page. In other words,
    ; until B gets incremented.
    pop de  ; Get the user buffer back
    push hl ; Save HL to update it before returning
    ; Put the offset in HL
    ld h, b
    ld l, c
zos_zealfs_readdir_next:
    ; Reading the next entry in the directory, save the current offset (HL)
    push hl
    ; IMPORTANT: The dir_entry structure has the exact same fields and size as the
    ; one in ZealFS directory's entry. As such, we can use the user buffer to read
    ; data from disk directly. This will save time. Save user buffer address.
    push de
    ld bc, DISKS_DIR_ENTRY_SIZE
    call RAM_EXE_READ
    pop de
    pop hl
    ; Check if there was an error while reading from the disk
    or a
    jp nz, _zos_zealfs_opendir_error_pop
    ; Update the next entry offset (HL += ZEALFS_ENTRY_SIZE)
    ld a, ZEALFS_ENTRY_SIZE
    add l
    ld l, a
    ; If there is carry, we jumped to the next page, so no more entries afterwards.
    ; This can be done because the number of the entries are a multiple of a page size.
    jp nc, zos_zealfs_readdir_not_last
    ld l, 0xFF
zos_zealfs_readdir_not_last:
    ; HL contains the next entry which may be valid or invalid
    ; Check if the flag marks an empty entry or a populated one
    ld a, (de)
    bit 7, a
    jp nz, zos_zealfs_readdir_end
    ; Entry is empty, continue the loop if L is not 0xFF
    ld a, l
    inc a
    jp nz, zos_zealfs_readdir_next
    ; Entry is empty, end of dir data, we have to save this state and return an error
    pop de
    dec a   ; Make A = 0xFF
    ld (de), a
    ld a, ERR_NO_MORE_ENTRIES
    ret
zos_zealfs_readdir_end:
    ; An entry has been found! The name has already been populated, modify the flags
    ; on ZealFS 1 means directory, on ZealOS it means file. Invert it.
    xor 0x81    ; also clears the top bit
    ld (de), a
    ; Update the opened dir entry structure with the offset reached (HL)
    pop de
    ld a, l
    ld (de), a
    ; Success
    xor a
    ret


    ; Create a directory on a ZealFS-formatted disk.
    ; The opened dir structure to return can be allocated thanks to `zos_disk_allocate_opndir`.
    ; Parameters: (Guaranteed not NULL by caller)
    ;       HL - Absolute path, without the disk letter (without X:)
    ;       DE - Disk driver address
    ; Returns:
    ;       A - ERR_SUCCESS on success, error code else
    ; Alters:
    ;       A, BC, DE, HL
    PUBLIC zos_zealfs_mkdir
    DEFC RAM_BITMAP = RAM_BUFFER + zealfs_pages_bitmap - zealfs_bitmap_size_t
zos_zealfs_mkdir:
    ; Treat / as a special case
    inc hl
    ld a, (hl)
    or a
    jr z, _zos_zealfs_mkdir_already_exists
    ; The algorithm here is similar to opendir as we need to search for the path
    push de
    call zos_zealfs_load_and_check_next_name
    pop de
    ret nz
    ; A must not be 0 here as the directory must NOT exist
    or a
    jr z, _zos_zealfs_mkdir_already_exists
    ; This routine will allocate a new page and write it the last known FREE_ENTRY,
    ; update the disk header, including the bitmap, and return the new page index.
    ; This routine will also setup the driver's write routine in the RAM_EXE_WRITE
    ; buffer.
    ; Parameters:
    ;   HL - Name of the entry
    ;   DE - Driver address
    ;   B - 1 for a directory, 0 for a regular file
    ; Returns:
    ;   A - ERR_SUCCESS on success, error code else
    ;   B - Index of the newly allocated page
    ld b, 1
    call zos_zealfs_new_entry
    or a
    ret nz
    ; We just created a directory, we must empty its content, use HL as the disk
    ; offset. Iterate over all the DIR_MAX_ENTRIES entries of the directory.
    ; Set the first byte of the buffer to 0, it'll used to clean the directories
    ; entries.
    ; Note: _zos_zealfs_new_entry already set the first byte to 0, we can continue to
    ; the next entry directly to save time.
    ld (RAM_BUFFER), a
    ld h, b
    ld l, ZEALFS_ENTRY_SIZE
    ld b, DIR_MAX_ENTRIES - 1
_zos_zealfs_empty_dir:
    push bc
    push hl
    ld de, RAM_BUFFER
    ; A should be 0 here
    ld bc, 1
    call RAM_EXE_WRITE
    ; Calculate the next offset to clean
    pop hl
    ld bc, ZEALFS_ENTRY_SIZE
    add hl, bc
    pop bc
    ; Check for errors from the disk driver
    or a
    ret nz
    djnz _zos_zealfs_empty_dir
    ; Success, A is already 0
    ret
_zos_zealfs_mkdir_already_exists:
    ld a, ERR_ALREADY_EXIST
    ret


    ;======================================================================;
    ;================= P R I V A T E   R O U T I N E S ====================;
    ;======================================================================;

    ; Browse an opened file while reading or writing to it. The algorithm is almost exactly the same,
    ; apart form the driver's routine that will be used for each loop iteration.
    ; This routine will prepare the proper callbacks for each loop iteration.
    ; Parameters:
    ;   A - 1 to perform a read operation, any other value for write
    ;   HL - Address of the opened file. It embeds the offset to read from the file,
    ;        the driver address and the user field.
    ;   DE - User buffer used to contains bytes to write or to store byte read from a file.
    ;   BC - Size of the buffer passed, maximum size is a page size guaranteed.
    ; Returns:
    ;   A  - 0 on success, error value else
    ;   BC - Number of bytes processed from/to DE
    ; Alters:
    ;   A, BC, DE, HL
zos_zealfs_browse_file:
    ; Prepare the callbacks according to the given parameter
    push hl
    dec a
    jr z, zos_zealfs_browse_read
    ; Write is requested, set the NULL page callback and the RAM_EXE_WRITE as the default operation
    ld hl, _zos_zealfs_browse_allocate
    ld (RAM_EXE_PAGE_0 + 1), hl
    ld hl, RAM_EXE_WRITE
    jp zos_zealfs_browse_start
zos_zealfs_browse_read:
    ld hl, _zos_zealfs_browse_error_pop
    ld (RAM_EXE_PAGE_0 + 1), hl
    ld hl, RAM_EXE_READ
zos_zealfs_browse_start:
    ld a, JP_NNNN
    ld (RAM_EXE_OPER), a
    ld (RAM_EXE_PAGE_0), a
    ld (RAM_EXE_OPER + 1), hl
    pop hl
    ; Return success if BC is 0
    ld a, b
    or c
    ret z
    ; Seek the file in order to get the physical address of the current offset.
    ; This routine will also fill the driver's read and write routines in RAM (RAM_EXE_*)
    push de
    push bc
    call zos_zealfs_seek
    ; DE contains the resulted offset on disk
    ; Pop the user buffer size and address
    pop bc
    pop hl
    ; Check for errors before continuing
    or a
    ret nz
    ; Organize the stack so that we have:
    ; [SP + 4] : User buffer size
    ; [SP + 2] : User buffer address
    ; [SP + 0] : Remaining size to process
    push bc ; Buffer size
    push hl
    ; We now have to process bytes until BC is 0, however, we can process at most 255 bytes
    ; per page. The current page is in D.
_zos_zealfs_browse_content_loop:
    ; BC contains the remaining size to read/write
    ; E is the offset in the file
    ; D is the current page
    ; If B is not 0, we can process at most 255 bytes
    push bc
    ; Calculate in advance A = 255 - offset
    ld a, 255
    sub e
    ; Check if B is 0
    inc b
    dec b
    jr nz, _zos_zealfs_browse_a_bytes
    ; Read the minimum between C and A bytes
    cp c
    ; On carry, C is bigger than A
    jp c, _zos_zealfs_browse_a_bytes
    ld a, c ; faster than a jump
_zos_zealfs_browse_a_bytes:
    ld c, a
_zos_zealfs_browse_c_bytes:
    ; We have to process C bytes starting at offset E, in user buffer
    ; Registers are:
    ;   D - Current page
    ;   E - Offset to process
    ;   (So DE is the address to start reading/writing from/to)
    ;   C - Bytes count to read/write
    ;   [SP] - Remaining size to read/write
    ;   [SP + 2] - User buffer address
    ; Put the destination buffer in HL
    pop hl
    ex (sp), hl
    ; [SP] - Remaining size to read/write
    ex de, hl
    ; Skip the first byte (next page) of page, we can use inc l instead of inc hl
    ; because L is not 0xFF for sure
    inc l
    ld b, 0
    ; Save the user buffer address and offset on the stack
    push hl
    push de
    call RAM_EXE_OPER
    ; Get the offset in DE and destination buffer in HL
    pop hl
    pop de
    or a
    jr nz, _zos_zealfs_browse_error
    ; Calculate the next buffer address
    add hl, bc
    ; Put it back at the bottom of the stack
    ex (sp), hl
    ; HL contains the remaining size, subtract what we just processed
    ; The carry should be 0 here since the previous add is safe
    sbc hl, bc
    jr z, _zos_zealfs_browse_content_loop_end
    ; HL contains the remaining size (!= 0)
    ; DE contains the offset we just read/write from
    ; BC contains the bytes count we just read/write
    ; We have to calculate the offset and/or next page index
    ex de, hl
    dec l
    add hl, bc
    ; We won't need BC anymore, put the remaining size to process in BC
    ld b, d
    ld c, e
    ; Store the current page in D, as required at the beginning of the loop
    ld d, h
    ld e, l
    ; If L is not 0xFF, we can continue the loop without reading the next page
    ld a, l
    inc a
    jr nz, _zos_zealfs_browse_content_loop
    ; We need to read the next page, and set the offset to 0
    push bc
    ; H already contains the current page, set the offset (L) to 0
    ld l, 0
    ld de, RAM_BUFFER
    ld bc, 1
    push hl
    call RAM_EXE_READ
    pop hl
    or a    ; Check the flags for potential error
    jr nz, _zos_zealfs_browse_error_pop
    ; Get the next page index
    ld a, (RAM_BUFFER)
    ; If the next page is empty, we have to jump to our callback
    or a
    jp z, RAM_EXE_PAGE_0
    ; Store it in D, and set the offset to 0
    ld d, a
    ld e, b     ; B is 0
    pop bc
    jp _zos_zealfs_browse_content_loop
_zos_zealfs_browse_content_loop_end:
    xor a   ; Success
    ; Pop the end of the buffer address from the stack
_zos_zealfs_browse_error:
    pop de
    pop bc
    ret
_zos_zealfs_browse_error_pop:
    pop bc
    jr _zos_zealfs_browse_error


    ; Jump to the following sub-routine when we have to go to the next page but it is 0
    ; in the current page. This only happens during writes, so we have to allocate a new
    ; page and return to the loop that browse content.
    ; Entry:
    ;   H - Currently page number
    ; Exit:
    ;   D - New page index
    ;   E - 0
    ;   BC - Popped out of the stack
    ; Returns to: _zos_zealfs_browse_content_loop
_zos_zealfs_browse_allocate:
    push hl
    ; Start by allocating a page, this routine will update the bitmap and disk header
    call zos_zealfs_new_page
    pop hl
    or a
    jr nz, _zos_zealfs_browse_error_pop
    ; Write the new page index (D) as the first byte of the current page (H)
    ld bc, 1
    ; B is 0
    ld l, b
    ld a, d
    ld de, RAM_BUFFER
    ld (de), a
    call RAM_EXE_WRITE
    ; Now write 0 as the first byte of the new page we allocated (used to be in D, now in RAM_BUFFER)
    ; This will mark the end of the file.
    ld de, RAM_BUFFER
    ld bc, 1
    ld a, (de)
    ld h, a
    xor a
    ld l, a
    push hl
    ; Set 0 in the RAM_BUFFER
    ld (de), a
    call RAM_EXE_WRITE
    pop hl
    ex de, hl
    ; As explained in the routine description
    pop bc
    jp _zos_zealfs_browse_content_loop


    ; Seek into an opened file. This is useful when an offset has been provided and we
    ; have to look for the page that contains the bytes pointed by it.
    ; Parameters:
    ;       HL - Address of the opened file. It embeds the offset to read from the
    ;            file, the driver address and the user field.
    ; Returns:
    ;       A - 0 on success, error value else
    ;       DE - Address in disk of the current file offset.
    ;       (D - Page index/number)
    ;       (E - Offset in the page)
    ; Alters:
    ;   A, BC, DE, HL
zos_zealfs_seek:
    ; Get the driver out of the opened file structure
    ; TODO: Use an abstraction?
    inc hl
    inc hl
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ; We are going to need DE (driver address) to get the read and write function, the resulted
    ; function address will be in HL so save it first.
    push hl
    ; Take advantage of the fact that HL is saved to check if the opened dev is a file
    ; or a directory. HL is pointing to opn_file_size_t. Make it point to the last
    ; byte of the opn_file_usr_t field.
    ld bc, opn_file_usr_t + 3 - opn_file_size_t
    add hl, bc
    bit FS_ISDIR_BIT, (hl)
    jr nz, _zos_zealfs_seek_not_file_error
    ; Prepare both read and write routines
    push de
    call zos_zealfs_prepare_driver_read
    pop de
    call zos_zealfs_prepare_driver_write
    ; Make HL point to the offset in the file, ignore the size
    pop hl
    ld bc, 4
    add hl, bc
    ; HL points to the offset now, which is guaranteed to be 16-bit, because of the
    ; limitation of the filesystem
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ; Skip highest 16-bit of the offset and the first 16 bits of the user field.
    add hl, bc
    ; Load the start page of the file, we can re-use HL afterwards
    ld l, (hl)
    ; DE contains the file offset. We have to skip pages until we find the first byte
    ; to process. Files are organized as linked-lists of 256-byte pages (each page can hold
    ; 255 bytes of data, 1 byte for the next page pointer).
    ; We have to enter the loop if DE is equal to or greater than 0x00FF
    ; Calculate Q = offset / 255 <=> Q = (DE + 1 + D) >> 8
    ; And modulus M = Q + E
    ld c, e
    ld a, d
    inc de
    add e
    ld e, a
    adc d
    sub e
    ; Quotient in A, save it in B
    ld b, a
    ; Calculate Mod in C
    add c
    ld c, a
    ; Load the start page in A and enter the loop only if B is not 0!
    ld a, l
    dec b
    inc b
    jr z, _zos_zealfs_seek_loop_end
_zos_zealfs_seek_loop:
    push bc
    ; A contains the current page index, read the first byte of page 0xRaRa00 where Ra is
    ; register A. The byte read is the next page index.
    ld de, RAM_BUFFER
    ld bc, 1
    ; HL = 0xRaRa00
    ld h, a
    ld l, b  ; l = b = 0
    call RAM_EXE_READ
    or a
    jr nz, _zos_zealfs_seek_pop_ret
    ; Load the next page index in A
    ld a, (RAM_BUFFER)
    or a
    jr z, _zos_zealfs_seek_corrupted
    pop bc
    djnz _zos_zealfs_seek_loop
_zos_zealfs_seek_loop_end:
    ; A contain the current page index in the filesystem
    ; C contains the offset in the current page
    ld d, a
    ld e, c
    ; Return success
    xor a
    ret
_zos_zealfs_seek_not_file_error:
    ld a, ERR_NOT_A_FILE
_zos_zealfs_seek_pop_ret: ; we don't care in which registers we pop the stack
    pop hl
    ret
_zos_zealfs_seek_corrupted:
    ld a, ERR_ENTRY_CORRUPTED
    ret


    ; Allocate a new page and update the disk header and bitmap accordingly
    ; Parameters:
    ;   [RAM_EXE_READ]  - Must be populate already with driver's read routine
    ;   [RAM_EXE_WRITE] - Must be populate already with driver's read routine
    ; Returns:
    ;   D - Index of the new page
zos_zealfs_new_page:
    ; Read the page_count, free_pages and pages bitmap from the header
    ld hl, zealfs_bitmap_size_t
    ld bc, zealfs_reserved_t - zealfs_bitmap_size_t
    ld de, RAM_BUFFER
    call RAM_EXE_READ   ; Read from the disk
    or a
    ret nz
    ; Retrieve the size of the bitmap and update the count
    ld hl, RAM_BUFFER
    ld b, (hl)  ; Bitmap size in B
    inc hl
    dec (hl)    ; Decrement free pages count
    inc hl
    ; HL now points to the bitmap array
    call allocate_page
    ld d, a ; Store the page allocated from the bitmap in D
    or a
    ld a, ERR_NO_MORE_MEMORY
    ret z
    ; Update the bitmap on the disk
    push de
    ld hl, zealfs_bitmap_size_t
    ld bc, zealfs_reserved_t - zealfs_bitmap_size_t
    ld de, RAM_BUFFER
    call RAM_EXE_WRITE
    pop de
    ret


    ; Free a page and update the disk header and bitmap accordingly
    ; Parameters:
    ;   H - Index of the page to free
    ;   [RAM_EXE_READ]  - Must be populate already with driver's read routine
    ;   [RAM_EXE_WRITE] - Must be populate already with driver's read routine
    ; Returns:
    ;   A - success or error code
    ; Alters:
    ;   A, BC, DE, HL
zos_zealfs_free_page:
    push hl
    ; Read the header, starting at the bitmap size field, up to the end of the bitmap.
    ld hl, zealfs_bitmap_size_t
    ld bc, zealfs_reserved_t - zealfs_bitmap_size_t
    ld de, RAM_BUFFER
    call RAM_EXE_READ   ; Read from the disk
    or a
    pop hl
    ret nz
    ld a, h
    ; Retrieve the size of the bitmap and update the count
    ld hl, RAM_BUFFER
    ld b, (hl)  ; Bitmap size in B
    inc hl
    inc (hl)    ; Increment free pages count
    inc hl
    ; HL now points to the bitmap array, free the page
    call free_page
    ; Update the bitmap on the disk
    ld hl, zealfs_bitmap_size_t
    ld bc, zealfs_reserved_t - zealfs_bitmap_size_t
    ld de, RAM_BUFFER
    jp RAM_EXE_WRITE


    ; Create a new entry at the last known FREE_ENTRY location.
    ; This routine allocated a new page, update the entry, the disk header, the bitmap
    ; and returns the new page allocated.
    ; In case of a directory, the size will be set to a page size (256). In case of a
    ; file, it will be set to 0.
    ; Parameters:
    ;   HL - Name of the entry
    ;   DE - Disk driver address
    ;   B - 1 for a directory, 0 for a regular file
    ;   [RAM_EXE_READ] - Must be preloaded with the driver's read routine address.
    ; Returns:
    ;   A - ERR_SUCCESS on success, error code else
    ;   B - Index of the newly allocated page
    ; Alters:
    ;   A, BC, DE, HL
zos_zealfs_new_entry:
    ; Prepare the write routine from the driver to the buffer
    push hl
    call zos_zealfs_prepare_driver_write
    pop hl
    ; We won't need the driver address anymore, re-use it
    ; Check if a free entry was found or not
    ld de, (RAM_FREE_ENTRY)
    ld a, d
    or e
    jr z, _zos_zealfs_new_entry_full
    push hl
    push bc
    ; Start by getting the page_count, free_pages and pages bitmap from the header
    call zos_zealfs_new_page
    or a
    jr nz, _zos_zealfs_pop_all_ret
    ; The header (w/ bitmap) has been updated, now, create a new file entry in the RAM_BUFFER
    ; that will be used to flash the free entry found.
    ; Clean up the structure first
    call _zealfs_clear_buffer
    ; Populate the flags first, we will need BC for this (we have to pop af first...)
    pop bc
    pop hl
    ld c, d ; Save start_page in C
    ld a, b
    or 0x80
    ; Fill the RAM_BUFFER with the new entry
    ld de, RAM_BUFFER
    ld (de), a
    inc de
    ; Populate the name now, copy from HL to structure
    push bc
    ld bc, FS_NAME_LENGTH
    call strncpy
    ; HL can be re-used, use it instead of DE to point to the RAM buffer
    ex de, hl
    add hl, bc  ; Skip the name[] array in the buffer
    pop bc  ; Get the start_start from register C
    ld (hl), c
    inc hl
    ; B is still 0 (files) or 1 (directories). The size is in little-endian.
    ; In both cases, the lowest byte is 0.
    ld (hl), 0
    inc hl
    ; We can write B directly now, so that the size is:
    ;   0x000 for files
    ;   0x100 for directories
    ld (hl), b
    inc hl
    ; HL points to the date now, get the current date if a clock is available
    ex de, hl
    call zos_date_getdate_kernel
    ; Do not check the return code, in the worst case, the structure is clean already
    ; Write back this structure to disk
    ld hl, (RAM_FREE_ENTRY)
    ld bc, ZEALFS_ENTRY_SIZE
    ld de, RAM_BUFFER
    call RAM_EXE_WRITE
    or a
    ret nz
    ld hl, RAM_BUFFER + zealfs_entry_start
    ld h, (hl)
    ld l, 0
    push hl
    ; In both cases (file or directory), the first byte of the new allocated page must
    ; be set to 0, do it here.
    ld de, zealfs_entry_size ; This value is already 0
    ld bc, 1
    call RAM_EXE_WRITE
    pop hl
    ld b, h ; Return new page index
    ret
_zos_zealfs_new_entry_full:
    ld a, ERR_CANNOT_REGISTER_MORE
    ret
_zos_zealfs_pop_af_all_ret:
    pop bc
_zos_zealfs_pop_all_ret:
    pop bc
    pop hl
    ret

    ; Clear ZEALFS_ENTRY_SIZE bytes starting at RAM_BUFFER.
    ; Parameters:
    ;   -
    ; Returns:
    ;   -
_zealfs_clear_buffer:
    push hl
    push de
    push bc
    ld hl, RAM_BUFFER
    ld d, h
    ld e, l
    ld (hl), 0
    inc de
    ld bc, ZEALFS_ENTRY_SIZE - 1
    ldir
    pop bc
    pop de
    pop hl
    ret

    ; This routine gets the `read` function of a driver and stores it in the RAM_EXE_READ buffer.
    ; It will in fact store a small routine that does:
    ;       xor a   ; Set A to "FS" mode, i.e., has offset on stack
    ;       push hl
    ;       ld h, a
    ;       ld l, a ; Set HL to 0
    ;       push hl
    ;       jp driver_read_function
    ; As such, HL is the 16-bit offset to read from the driver, can this routine can be called
    ; with `call RAM_EXE_READ`, no need to manually push the return address on the stack.
    ; Parameters:
    ;   DE - Driver address
    ; Returns:
    ;   HL - Address of read function
    ; Alters:
    ;   A, DE, HL
zos_zealfs_prepare_driver_read:
    ld hl, PUSH_HL << 8 | XOR_A
    ld (RAM_EXE_READ + 0), hl
    ld hl, LD_L_A << 8 | LD_H_A
    ld (RAM_EXE_READ + 2), hl
    ld hl, JP_NNNN << 8 | PUSH_HL
    ld (RAM_EXE_READ + 4), hl
    ; Retrieve driver (DE) read function address, in HL.
    GET_DRIVER_READ_FROM_DE()
    ld (RAM_EXE_READ + 6), hl
    ret


    ; Same as above, but with write routine
zos_zealfs_prepare_driver_write:
    ld hl, PUSH_HL << 8 | XOR_A
    ld (RAM_EXE_WRITE + 0), hl
    ld hl, LD_L_A << 8 | LD_H_A
    ld (RAM_EXE_WRITE + 2), hl
    ld hl, JP_NNNN << 8 | PUSH_HL
    ld (RAM_EXE_WRITE + 4), hl
    ; Retrieve driver (DE) read function address, in HL.
    GET_DRIVER_WRITE_FROM_DE()
    ld (RAM_EXE_WRITE + 6), hl
    ret

    ; Same as above but safe
zos_zealfs_prepare_driver_write_safe:
    push hl
    push de
    call zos_zealfs_prepare_driver_write
    pop de
    pop hl
    ret

    ; Allocate a page in the bitmap. The bitmap will be altered as the free page (bit 0)
    ; will be marked as allocated (bit 1)
    ; Parameters:
    ;   HL - Address of the bitmap
    ;   B  - Size of the bitmap in bytes
    ; Returns:
    ;   A - Index of the page allocated on success, 0 on error
    ; Alters:
    ;   A, BC, HL
allocate_page:
    ; Given a bitmap byte, all 8 pages are allocated if it is equal to 0xff
    ld a, 0xff
    ld c, b
_allocate_page_loop:
    cp (hl)
    jr nz, _allocate_page_loop_found
    inc hl
    djnz _allocate_page_loop
    ; Bitmap is full, return 0
    xor a
    ret
    ; Jump here if we have found a free page (bit 0) in the bitmap
_allocate_page_loop_found:
    ; Calculate the offset in B: B = (FS_BITMAP_SIZE - B) * 8
    ld a, c
    sub b
    ; Guaranteed that upper bits are 0, use rlca
    rlca
    rlca
    rlca
    ld b, a
    ; Now increment B until we find the bit 0, also, keep tracking the index
    ; of that bit 0 (in C) because we will need to modify the bitmap
    ld a, (hl)
    ld c, 1
_allocate_page_bit_loop:
    rrca
    jr nc, _allocate_page_bit_found
    inc b
    sla c
    jp _allocate_page_bit_loop
_allocate_page_bit_found:
    ; B contains the value to return, we need to update the bitmap now with C bitmask
    ld a, (hl)
    or c
    ld (hl), a
    ; Prepare the return value in A
    ld a, b
    ret


    ; Routine that frees a previously allocated page in the bitmap
    ; Parameters:
    ;   HL - Address of the bitmap (must be as big as FS_BITMAP_SIZE)
    ;   A  - Index of the page allocated to free
    ; Returns:
    ;   None
    ; Alters:
    ;   A, BC, DE, HL
free_page:
    ; Store page/8 in C
    ; By rotating by 3 to the right, we get:
    ; A = NNNN_NLLL => A = LLLN_NNNN
    ; Only keep the Ns at the moment
    rrca
    rrca
    rrca
    ld b, a
    and 0x1f
    ; HL += A
    add l
    ld l, a
    adc h
    sub l
    ld h, a
    ; Now, we need to set (HL) bit A to 0. Let's use sel-modifying code
    ; to simplify this. We have to generate res A, (hl) instruction.
    ; Re-use RAM_EXE_PAGE_0 (prepared by the called) part which is 3-bytes big.
    ; A = 0x86 + bit*8, so A needs to be 00LL_L000, rotate twice is enough
    ld a, b
    rrca
    rrca
    and 0b00111000
    add 0x86
    ld (RAM_EXE_PAGE_0 + 1), a
    jp RAM_EXE_PAGE_0
