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
    INCLUDE "utils_h.asm"

    ; The maximum amount of pages a storage can have is 256 (64KB), so the bitmap size is 256/32
    DEFC FS_NAME_LENGTH   = 16
    DEFC FS_OCCUPIED_BIT  = 7
    DEFC FS_ISDIR_BIT     = 0
    DEFC FS_OCCUPIED_MASK = 1 << FS_OCCUPIED_BIT
    DEFC FS_ISDIR_MASK    = 1 << FS_ISDIR_BIT

    DEFC RESERVED_SIZE = 28

    ; ZealFS partition header. This is the first data in the store:
    DEFVARS 0 {
        zealfs_magic_t       DS.B 1 ; Must be 'Z' ascii code
        zealfs_version_t     DS.B 1 ; FS version
        zealfs_bitmap_size_t DS.B 2 ; Number of bytes composing the bitmap
        zealfs_free_pages_t  DS.B 2 ; Number of free pages, at most 65535
        zealfs_page_size_t   DS.B 1 ; Size of the pages on the disk:
                                    ; 0 - 256
                                    ; 1 - 512
                                    ; 2 - 1024
                                    ; 3 - 2048
                                    ; 4 - 4096
                                    ; 5 - 8192
                                    ; 6 - 16384
                                    ; 7 - 32768
                                    ; 8 - 65536
        zealfs_pages_bitmap  DS.B 0 ; Bitmap for the free pages, this needs to be calculated dynamically
                                    ; A used page is marked as 1, else 0
        ; The root entries come after the bitmap, it needs to be calculated dynamically
    }

    ; Number of bytes the `zealfs_entry_size` field takes
    DEFC FS_SIZE_WIDTH = 4

    ; ZealFileEntry structure. Entry for a single file or directory.
    DEFVARS 0 {
        zealfs_entry_flags  DS.B 1                  ; flags for the file entry
        zealfs_entry_name   DS.B FS_NAME_LENGTH     ; entry name, including the extension
        zealfs_entry_start  DS.B 2                  ; 16-bit start page index
        zealfs_entry_size   DS.B FS_SIZE_WIDTH      ; size in bytes of the file
        zealfs_entry_date   DS.B DATE_STRUCT_SIZE   ; zos date format
        zealfs_entry_rsvd   DS.B 1                  ; Reserved
        zealfs_entry_end    DS.B 0
    }

    DEFC ZEALFS_ENTRY_SIZE = zealfs_entry_end
    DEFC ZEALFS_ENTRY_RSVD_SIZE = 1
    ASSERT(ZEALFS_ENTRY_SIZE == 32)


    #define RAM_EXE_WRITE   write_trampoline
    #define RAM_EXE_READ    read_trampoline

    ; These macros points to code that will be loaded and executed within the buffer
    DEFC RAM_EXE_CODE  = _vfs_work_buffer

    ; 2-byte parameter containing the parameter to pass to the driver's underlyign function (read or write)
    DEFC DRIVER_DE_PARAM = RAM_EXE_CODE
    ; 32-bit variable containing the browse context (when looking for a file)
    DEFC RAM_CUR_CONTEXT = DRIVER_DE_PARAM + 2
    ; Name of the file or directory the algorithm is looking for
    DEFC RAM_CUR_NAME    = RAM_CUR_CONTEXT + 4
    ; Current page number while browsing the disk
    DEFC RAM_CUR_PAGE    = RAM_CUR_NAME + 2

    ; This 3-byte operation buffer will contain either JP RAM_EXE_READ or JP RAM_EXE_WRITE.
    ; It will be populated and used by the algorithm that will perform reads and writes from and to files.
    DEFC RAM_EXE_OPER = RAM_CUR_PAGE + 2
    ; Same here, this will contain a JP instruction that will be used as a callback when the
    ; next disk page of a file is 0 (used during reads and writes)
    DEFC RAM_EXE_PAGE_0 = RAM_EXE_OPER + 3

    ; Use this word to save which entry of the last directory was free. This will be filled by
    ; _zos_zealfs_check_next_name. Must be cleaned by the caller.
    DEFC RAM_FREE_ENTRY    = RAM_EXE_PAGE_0 + 3     ; Reserve 3 bytes for the previous RAM code
    DEFC RAM_LAST_DIR_PAGE = RAM_FREE_ENTRY + 4

    ; Define a static space in memory that is able to contain the first bytes of the FS header,
    ; excluding the magic and the version, this will save us some bytes
    DEFC RAM_FS_HEADER = RAM_LAST_DIR_PAGE + 2  ; Reserve 2 bytes

    ; Remaining buffer
    DEFC RAM_BUFFER = RAM_FS_HEADER + 6 ; Reserve 6 bytes for RAM_FS_HEADER
    DEFC RAM_BUFFER_SIZE = VFS_WORK_BUFFER_SIZE - 30


    ; Used to create self-modifying code in RAM
    DEFC XOR_A    = 0xaf
    DEFC PUSH_HL  = 0xe5
    DEFC PUSH_DE  = 0xd5
    DEFC JP_NNNN  = 0xc3
    DEFC ARITH_OP = 0xcb
    DEFC RET_OP   = 0xc9

    EXTERN _vfs_work_buffer
    EXTERN zos_date_getdate_kernel

    SECTION KERNEL_TEXT

    ; Get the size of the filesystem header
    ; NOTE: Arithmetic tested and working
    ; Parameters:
    ;   [RAM_FS_HEADER] - Filled with FS header
    ; Returns:
    ;   HL - Header size in bytes
    ; Alters:
    ;   A, HL
_zos_zealfs_header_size:
    ; The RAM_FS_HEADER data already contains the `zealfs_bitmap_size_t` field, no offset to add
    ld hl, (RAM_FS_HEADER)
    ; Add the size of the header itself to the result while aligning up the result to the next
    ; ZEALFS_ENTRY_SIZE boundary:
    ; size = align_up(bitmap_size + header_size, ZEALFS_ENTRY_SIZE)
    ld a, zealfs_pages_bitmap + ZEALFS_ENTRY_SIZE
    add l
    ld l, a
    adc h
    sub l
    ld h, a
    ; Make the assumption that ZEALFS_ENTRY_SIZE is < 256
    ; size = size & ~(ZEALFS_ENTRY_SIZE - 1)
    ld a, ~(ZEALFS_ENTRY_SIZE - 1)
    and l
    ld l, a
    ret


    ; Get the size of a page, in bytes
    ; Parameters:
    ;   [RAM_FS_HEADER] - Filled with FS header
    ; Returns:
    ;   HL - Header size in bytes (0 means 65536)
    ; Alters:
    ;   A, HL
_zos_zealfs_page_size:
    ld a, (RAM_FS_HEADER + zealfs_page_size_t - zealfs_bitmap_size_t)
    ; The minimum page size is 256 bytes
    ld hl, 256
    or a
    ret z
    ; Put the H value in A so that we can rotate faster
    ld l, a
    ld a, h
    ; Shift A register L times, carry must be 0 (to have an 9-bit rotation)
_zos_zealfs_page_size_loop:
    rla
    dec l
    jr nz, _zos_zealfs_page_size_loop
    ; L is 0, no need to set it again
    ld h, a
    ret

    ; Same as above, but returns the upper bytes in BC
    ; Parameters:
    ;   [RAM_FS_HEADER] - Filled with FS header
    ; Returns:
    ;   BC - Header size in bytes / 256
    ; Alters:
    ;   A, BC, HL
_zos_zealfs_page_size_upper:
    call _zos_zealfs_page_size
    ld c, h
    ; Check if the result is 0 (64K)
    ld b, 0
    inc c
    dec c
    ret nz
    inc b
    ret


    ; Get the offset (address on the disk) of the root directories entries.
    ; The address is always < 64KB, since the maximum page size is 64KB.
    ; Parameters:
    ;   [RAM_FS_HEADER] - Filled with FS header
    ; Returns:
    ;   HL - Address of the root directory entries
    ; Alters:
    ;   A, HL
    DEFC _zos_zealfs_rootdir_entries = _zos_zealfs_header_size


    ; Get the maximum number of entries in the root directory
    ; Parameters:
    ;   [RAM_FS_HEADER] - Filled with FS header
    ; Returns:
    ;   HL - Maximum number of entries in the root directory
_zos_zealfs_rootdir_max_entries:
    push de
    ; Size of the header in bytes, divide it by ZEALFS_ENTRY_SIZE
    call _zos_zealfs_header_size
    ; Shift HL right 5 times
    ld a, l
    srl h
    rra
    srl h
    rra
    srl h
    rra
    srl h
    rra
    srl h
    rra
    ld l, a
    ; Store the result in DE (number of entries taken by the header)
    ex de, hl
    call _zos_zealfs_reg_dir_max_entries
    ; Set carry to 0
    or a
    sbc hl, de
    pop de
    ret


    ; Get the maximum number of entries in any non-root directory
    ; Parameters:
    ;   [RAM_FS_HEADER] - Filled with FS header
    ; Returns:
    ;   HL - Maximum number of entries
    ; Alters:
    ;   HL
_zos_zealfs_reg_dir_max_entries:
    ; We could calculate the formula: (_zos_zealfs_page_size() - _zos_zealfs_header_size()) / ZEALFS_ENTRY_SIZE
    ; But we can optimize by reading page size S from the header and calculate (256 / 32) << S.
    ld a, (RAM_FS_HEADER + zealfs_page_size_t - zealfs_bitmap_size_t)
    ld hl, 8
    or a
    ret z
    ; Shift HL register A times
_zos_zealfs_dir_max_entries_loop:
    add hl, hl
    dec a
    jp nz, _zos_zealfs_dir_max_entries_loop
    ret


    ; Get the maximum number of entries in a directory
    ; Parameters:
    ;   C - 1 if root directory, 0 else
    ; Returns:
    ;   HL - Number of entries per directory
_zos_zealfs_get_dir_max_entries:
    dec c
    jr z, _zos_zealfs_rootdir_max_entries
    jr _zos_zealfs_reg_dir_max_entries


    ; Convert a disk page into a physical address
    ; Parameters:
    ;   DE - Page number to convert
    ; Returns:
    ;   DEHL - Physical address
    ; Alters:
    ;   A, DE, HL
_zos_zealfs_phys_from_page:
    ; Calculate the 32-bit physical address of the page
    ld a, (RAM_FS_HEADER + zealfs_page_size_t - zealfs_bitmap_size_t) ; Page size
    ex de, hl
    or a
    jr z, _zos_zealfs_phys_from_page_ret
    ; Register L will always be 0 since we need to multiply by 256 at the end
    ld e, a ; Use E as a counter
    xor a
_zos_zealfs_phys_from_page_loop:
    add hl, hl
    rla
    dec e
    jr nz, _zos_zealfs_phys_from_page_loop
_zos_zealfs_phys_from_page_ret:
    ; Multiply the result by 256
    ld d, a
    ld e, h
    ld h, l
    ld l, 0
    ret

    ; Like the routine below, browse the absolute path given in HL until the last name is reached.
    ; It will check that all the names on the path corresponds to folders that actually exist on
    ; the disk.
    ; This routine will load the driver's READ function address in the global buffer before
    ; executing the routine below (RAM_EXE_READ)
zos_zealfs_load_and_check_next_name:
    push hl
    call zos_zealfs_prepare_driver_read
    call zos_zealfs_prepare_header
    pop hl
    ; Fall-through

    ; Browse the absolute path given in HL and check whether they exist in the filesystem.
    ; All the parameters are not NULL.
    ; Parameters:
    ;   HL - Name of the entry to check (WITHOUT the first /)
    ;   RAM_EXE_READ - Loaded with driver's read function (see zos_zealfs_prepare_driver_read)
    ; Returns:
    ;   HL - Entry following the one checked (if B is not 1)
    ;   [RAM_CUR_CONTEXT] - Offset of the entry in the disk if exists, offset of the last entry in the last
    ;        directory in the path else.
    ;   B / Z flag - 0 if we have reached the last entry/end of the string
    ;   A  - 0 on success, ERR_NO_SUCH_ENTRY if the entry to check is not found,
    ;        other error code else (in that case B shall not be 0, Z flag must not be set)
    ; Alters:
    ;   A, HL, BC, DE
_zos_zealfs_check_next_name:
    ; First slash in path MUST BE SKIPPED BY CALLER
    ; Iterate over the path, checking each directory existence
    ld c, 1                 ; Marks root directory
    ; The first context to pass to the function is the offset of the root directory,
    ; must not alter HL since it contains the path to check
    ex de, hl
    call _zos_zealfs_rootdir_entries
    ; The root directory's entries are always in the first 64KB of the disk, the upper bits
    ; therefore 0.
    ld (RAM_CUR_CONTEXT), hl
    ld hl, 0
    ld (RAM_CUR_CONTEXT + 2), hl
    ; Always start at page 0, which contains the root directory
    ld (RAM_CUR_PAGE), hl
    ex de, hl
_zos_zealfs_check_name_next_dir:
    ; Clear the empty entry address first (32-bit value)
    ld de, 0
    ld (RAM_FREE_ENTRY), de
    ld (RAM_FREE_ENTRY + 2), de
    call _zos_zealfs_check_next_name_nested
    ; Restore the '/' that was potentially replaced with a \0
    dec hl
    ld (hl), '/'
    inc hl
    ; In all case, we won't check the root directory anymore
    ld c, 0
    ; If B is 0, we have reached the end of the string
    inc b
    dec b
    ret z
    ; Check for errors else
    or a
    ret nz
    ; We are entering a sub-directory, we have to update RAM_CUR_PAGE, DE contains the new entry's page
    ld (RAM_CUR_PAGE), de
    jp _zos_zealfs_check_name_next_dir

    ; Look for the next entry in the absolute path received by the routine `_zos_zealfs_check_next_name`
    ;   C  - 1 if root of the disk, 0 else
    ;   HL - Name of the entry to check, ending with either '\0' or '/'
    ;   [RAM_CUR_CONTEXT] - Context returned by this function (Root directory entries at first)
    ; Returns:
    ;   B  - 0 if we have reached the last entry/end of the string
    ;   HL - Entry following the one checked (if B is not 1)
    ;   DE - Start page for the entry taht was found (when found)
    ;   [RAM_CUR_CONTEXT] - Context passed to this function again
    ;   [RAM_CUR_PAGE] - Last (valid) page of the last directory opened
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
    ; Replace the '/' with a NULL-byte
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
    ;   - C contains 1 if we are checking the root directory, 0 else
    ;   - HL points to the file/dir name to check, NULL-terminated
    ;   - [RAM_CUR_CONTEXT] contains the context, which is the offset to the next entry to read
    ;   - [SP] address of the next entry
    push af ; Keep in memory the 'end' flag
    ; In the loop below, we will keep DEHL pointing to the 32-bit offset to read
    ld (RAM_CUR_NAME), hl
    ; Check how many entries we need to read, `_zos_zealfs_get_dir_max_entries` returns the number
    ; of entries in HL
    ; In the code below, the destination buffer will always be RAM_BUFFER, optimize by saving it
    ; right now as the driver's read function parameter instead of setting it at each iteration
    ld hl, RAM_BUFFER
    ld (DRIVER_DE_PARAM), hl
    call _zos_zealfs_get_dir_max_entries
    ld b, h
    ld c, l
    ; BC contains the number of entries to browse
    ; Set the initial 32-bit offset to read in DEHL
    ld hl, (RAM_CUR_CONTEXT)
    ld de, (RAM_CUR_CONTEXT + 2)
_zos_zealfs_check_name_driver_read_loop:
    push bc ; Store the number of entries to browse
    ; Read the flags, filename and start page of the file entry
    ASSERT(zealfs_entry_flags == 0)
    ASSERT(zealfs_entry_name == 1)
    ; Read until zealfs_entry_size (included)
    ld bc, zealfs_entry_size + FS_SIZE_WIDTH
    ; Keep DEHL on the stack
    push de
    push hl
    ; Get the offset from the context variable, HL is the lowest 16-bit, DE the upper 16-bit
    call RAM_EXE_READ
    ; ; In all cases we will need to pop the name out of the stack
    ; pop hl
    ; Check if an error ocurred
    or a
    jr nz, _zos_zealfs_check_name_error
    ; No error, we can check the flags!
    ld a, (RAM_BUFFER + zealfs_entry_flags)
    bit FS_OCCUPIED_BIT, a
    jr z, _zos_zealfs_check_name_next_offset
    ; Retrieve the entry name we are looking for
    ld hl, (RAM_CUR_NAME)
    ld de, RAM_BUFFER  + zealfs_entry_name
    ld bc, FS_NAME_LENGTH
    call strncmp
    or a
    jr z, _zos_zealfs_check_name_entry_found
_zos_zealfs_check_name_next_offset:
    ; The entry found is empty or the name doesn't match, pop the 32-bit offset out of the stack
    pop hl
    pop de
    ; Before incrementing, save the current offset in the FREE_ENTRY if and only if
    ; we found an empty entry (i.e. Z flag is set)
    jr nz, _zos_zealfs_no_set
    ld (RAM_FREE_ENTRY), hl
    ld (RAM_FREE_ENTRY + 2), de
_zos_zealfs_no_set:
    ld bc, ZEALFS_ENTRY_SIZE
    add hl, bc
    ; No need to increment DE in case of an overflow because pages are at mode 64KB, a directory
    ; cannot be bigger than a single page, so overflowing would mean that we didn't find the
    ; entry in the current directory.
    ; Get back the number of entries remaining and check if we need to continue the loop
    pop bc
    dec bc
    ld a, b
    or c
    jr nz, _zos_zealfs_check_name_driver_read_loop
    ; No more entries to check in the current directory, check if it has any other page
    ld de, (RAM_CUR_PAGE)
    ; Parameter:
    ;   DE - Current page to get the next page of
    call zos_zealfs_get_fat_entry
    ; DE contains the next page, 0 if no more entries (no next page)
    ld a, d
    or e
    jr z, _zos_zealfs_check_name_no_more_entries
    ld (RAM_CUR_PAGE), de
    ; DE contains the next page to browse
    call _zos_zealfs_reg_dir_max_entries
    ; Move the maximum number of entries in BC instead of HL
    ld b, h
    ld c, l
    call _zos_zealfs_phys_from_page
    jp _zos_zealfs_check_name_driver_read_loop
_zos_zealfs_check_name_no_more_entries:
    pop af
    ; Get the original string address in HL
    pop hl
    ; If A is zero, we reached the end of the string, B should be set to 0 too
    ld b, a
    ld a, ERR_NO_SUCH_ENTRY
    ret
_zos_zealfs_check_name_entry_found:
    ; Pop the 32-bit offset out of the stack
    pop hl
    pop de
    ; Pop the remaining entries count (not needed anymore)
    pop bc
    ; Get the flags out of the stack, and store them in B
    pop af
    ld b, a
    ; The entry has been found, we have to check if the flags are compatible,
    ; in other words, if we are not at the end of the path (A != 0), the entry must be a directory
    ; i.e. if A != 0, then flags & FS_ISDIR_MASK == 1
    or a
    jr z, _zos_zealfs_check_name_entry_found_end_str
    ld a, (RAM_BUFFER + zealfs_entry_flags)
    and FS_ISDIR_MASK
    ; If the result is 0, then we have a problem, we are trying to open a file as a dir.
    ld a, ERR_NOT_A_DIR
    ret z
    ; We haven't reached the end of the path but the given entry is a directory, calculate its
    ; physical address from the page offset and set it in RAM_CUR_CONTEXT.
    ; We can re-use DEHL, we won't need them anymore
    ld de, (RAM_BUFFER + zealfs_entry_start)
    push de ; We need to return this value
    call _zos_zealfs_phys_from_page
    ; Store the physical address in static variable
    ; Fall-through
_zos_zealfs_check_name_entry_found_end_str:
    ; Last entry of the path found, set the current context into RAM_CUR_CONTEXT
    ld (RAM_CUR_CONTEXT), hl
    ld (RAM_CUR_CONTEXT + 2), de
    ; Get the entry's start page
    pop de
    ; B has already been set, return success
    xor a
    ; Retrieve the path/string address from the stack
    pop hl
    ret
_zos_zealfs_check_name_error:
    ; Pop the offset
    pop hl
    pop de
    ; Pop the remaining entries to browse
    pop bc
    ; Pop the string flags (end of string or not) and the original HL value
_zos_zealfs_poptwice_ret:
    pop bc
    pop hl
    ret


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
    pop de
    push de
    ; We will still need the flags later on
    push bc
    ld b, 0
    ; Parameters:
    ;   HL - Name of the entry
    ;   DE - Disk driver address
    ;   B - 1 for a directory, 0 for a regular file
    ; Returns:
    ;   [RAM_CUR_CONTEXT] - New entry's page 32-bit address
    ;   [RAM_FREE_ENTRY] - 32-bit physical address of the new entry
    call zos_zealfs_new_entry
    pop bc
    ; Check for errors
    or a
    jr nz, _zos_zealfs_error
    ; No error, make the free entry address the entry context
    ld hl, (RAM_FREE_ENTRY)
    ld (RAM_CUR_CONTEXT), hl
    ld hl, (RAM_FREE_ENTRY + 2)
    ld (RAM_CUR_CONTEXT + 2), hl
_zos_zealfs_check_flags:
    ; Allow directories to be opened, however, directory must not be accessed with
    ; `read` nor `write`.
    ; TODO: Call the driver's open function!
    ; We arrive here with the parameters:
    ;   HL - Name of the file to open (NULL-terminated), not needed anymore
    ;   DE - Unknown
    ;   B - Flags to open the file with
    ;   [SP] - Driver address
    ; -----------------------------------
    ; Check if we are trying to open a directory
    ld a, (RAM_BUFFER + zealfs_entry_flags)
    rrca
    jp c, zos_zeal_open_with_dir
    ; Opening a file, we can continue
    ; Check if the flags include O_TRUNC
    ld a, b
    ; Check if O_TRUNC was passed, if that was the case, the size has to be shrunk to 0
    and O_TRUNC
    jr z, _zos_zealfs_no_trunc
    ; O_TRUNC was passed, the simplest solution is to set the size to 0
    ld hl, 0
    ld d, h
    ld e, l
    jr _zos_zealfs_open_load_hl
_zos_zealfs_no_trunc:
    ld hl, (RAM_BUFFER + zealfs_entry_size)
    ld de, (RAM_BUFFER + zealfs_entry_size + 2)
_zos_zealfs_open_load_hl:
    ld a, b
    rlca
    rlca
    rlca
    rlca
    or FS_ZEALFS    ; Put the flags in the upper nibble and FS in the lower one
    ; Driver address in BC
    pop bc
    ; File size is already in DEHL
    call zos_disk_allocate_opnfile
    or a
    ret nz
    ; HL must not be altered since it needs to be returned but this routine
    ; DE points to the custom 4-byte we can fill, use it to store the ENTRY context (and not the content address)
    ex de, hl
    ld bc, (RAM_CUR_CONTEXT)
    ld (hl), c
    inc hl
    ld (hl), b
    inc hl
    ld bc, (RAM_CUR_CONTEXT + 2)
    ld (hl), c
    inc hl
    ld (hl), b
    ; Put back the structure to return in HL
    ex de, hl
    ; Mark A as success
    xor a
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


    ; Read the 32-bit value pointed by HL. Mainly used to get the offset on disk
    ; of a file from the user field in the opened dev structure.
    ; Parameters:
    ;   HL - Address of the 32-bit value
    ; Returns:
    ;   DEHL - 32-bit value
    ; Alters:
    ;   A, Hl, DE
_zos_helper_offset_from_user_field:
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld a, (hl)
    inc hl
    ld h, (hl)
    ld l, a
    ex de, hl
    ret

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
    ; Check the opened file structure for the current directory address:
    ; if the entry address is 0, stat was called on the root `/`, handle it.
    ld a, 8
    ADD_HL_A()
    ; HL now points to the opn_file_usr_t field
    push hl
    ld a, (hl)
    inc hl
    or (hl)
    inc hl
    or (hl)
    inc hl
    or (hl)
    pop hl
    jp z, zos_disk_stat_fill_root
    ; Stat structure is pointing to size, make it point to the date
    inc de
    inc de
    inc de
    inc de
_zos_stat_file:
    ; Start by setting up the read function for the driver. Driver address must
    ; be in HL
    push de
    push hl
    ld d, b
    ld e, c
    call zos_zealfs_prepare_driver_read
    ; Read in a temporary buffer since the organization of the file header in
    ; ZealFS is different than the file stats structure.
    ld hl, RAM_BUFFER
    ld (DRIVER_DE_PARAM), hl
    ; Keep the user buffer to fill on the stack
    ; Retrieve the offset on disk of the file from the user field (32-bit)
    pop hl
    call _zos_helper_offset_from_user_field
    ; Offset to read is now in DEHL.
    ; Let's save some time and ignore the reserved bytes
    ld bc, ZEALFS_ENTRY_SIZE - ZEALFS_ENTRY_RSVD_SIZE
    call RAM_EXE_READ
    ; Before checking the return value, retrieve the user buffer from the stack
    pop de
    or a
    ret nz
    ASSERT(file_date_t == 4)
    ; We can optimize since we know that date structure follows the size
    ld hl, RAM_BUFFER + zealfs_entry_date
    ld bc, DATE_STRUCT_SIZE
    ldir
    ; User buffer (stat structure) points to the name now
    ld hl, RAM_BUFFER + zealfs_entry_name
    ASSERT(STAT_STRUCT_NAME_LEN == FS_NAME_LENGTH)
    ld bc, FS_NAME_LENGTH
    ldir
    ; Check if we just read a directory, if yes, set the size to a page size
    ld a, (RAM_BUFFER + zealfs_entry_flags)
    and 1
    ; If A is 0, the entry was a file, we can return success (= 0)
    ret z
_debug_me:
    ; Make the stat structure point to the size
    ex de, hl
    ld bc, -STAT_STRUCT_SIZE
    add hl, bc
    ex de, hl
    ld hl, RAM_BUFFER + zealfs_entry_size
    REPT FS_SIZE_WIDTH
        ldi
    ENDR
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
    ; If the Z flag is set, the file was opened in read-only, we should "return",
    ; ret here will jump to driver's close routine as it is on the top of the stack
    ret z
    ; Get a pointer to the size field in the structure (DE points to the structure's user field)
    ld h, d
    ld l, e
    DISKS_FILE_GET_SIZE(opn_file_usr_t)
    ; HL points to the size, make this the parameter for driver's WRITE
    ld (DRIVER_DE_PARAM), hl
    ; Keep the user buffer to fill on the stack
    ; Retrieve the offset on disk of the file from the user field (32-bit)
    ex de, hl
    ; We have to update the file size on the disk. Get the file entry offset.
    call _zos_helper_offset_from_user_field
    ; And add the size field offset
    ld bc, zealfs_entry_size
    add hl, bc
    jr nc, _zos_zealfs_close_no_carry
    inc de
_zos_zealfs_close_no_carry:
    ; Perform a write on the disk
    ld bc, FS_SIZE_WIDTH
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
    jp z, _zos_zealfs_rm_invalid
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
    jr nz, _zos_zealfs_rm_isdir
    ; The entry is a file, we have to free each page of the file.
    ; Start by marking the file entry as free (in the directory).
    call _zos_zealfs_rm_mark_as_free
    or a
    ret nz
    ld de, (RAM_BUFFER + zealfs_entry_start)
    ld (RAM_BUFFER + zealfs_entry_rsvd), de
    ; The following routine already returns A = 0
    jp zos_zealfs_remove_page_list
_zos_zealfs_rm_isdir:
    ; The entry is a directory, check that it is empty, we have to iterate over
    ; all entries it contains. Put the start offset of the directory in HL.
    ld de, (RAM_BUFFER + zealfs_entry_start)
    ld (RAM_CUR_PAGE), de
_zos_zealfs_rm_isdir_current_page:
    ; DE should contain the current page (so is [RAM_CUR_PAGE])
    call _zos_zealfs_reg_dir_max_entries
    ld b, h
    ld c, l
    call _zos_zealfs_phys_from_page
_zos_zealfs_rm_isdir_loop:
    push de
    push hl
    push bc
    ; ASSUMPTION: DRIVER_DE_PARAM was set in zos_zealfs_load_and_check_next_name
    ; to RAM_BUFFER
    ld bc, 1
    call RAM_EXE_READ
    pop bc
    pop hl
    pop de
    ; Check if there was an error while reading from the disk
    or a
    ret nz
    ; Check that the current entry is empty
    ld a, (RAM_BUFFER)
    and FS_OCCUPIED_MASK
    jr nz, _zos_zealfs_rm_isdir_notempty
    ; Check if we still have to test any entry
    dec bc
    ld a, b
    or c
    jr z, _zos_zealfs_rm_page_empty
    ; We still have entries to check, perform DEHL += ZEALFS_ENTRY_SIZE
    ld a, ZEALFS_ENTRY_SIZE
    add l
    ld l, a
    jr nc, _zos_zealfs_rm_isdir_loop
    inc h
    jr nz, _zos_zealfs_rm_isdir_loop
    inc de
    jp _zos_zealfs_rm_isdir_loop

_zos_zealfs_rm_page_empty:
    ; Reached this point if the current page is empty, check if this page
    ; contains any other page in the FAT
    ; Start page still in the buffer (don't forget to update it!)
    ld de, (RAM_CUR_PAGE)
    call zos_zealfs_get_fat_entry
    ; If the next page is 0, no need to continue the loop, the directory is empty
    ld a, d
    or e
    jr z, _zos_zealfs_rm_is_empty
    ; There is a next page in the directory iterate over it
    ld (RAM_CUR_PAGE), de
    jr _zos_zealfs_rm_isdir_current_page
_zos_zealfs_rm_is_empty:
    ; Directory to remove is empty, we can mark it as free.
    call _zos_zealfs_rm_mark_as_free
    ; Get the first page of the directory
    ld de, (RAM_BUFFER + zealfs_entry_start)
    ; Tail-call, the stack is clean already
    jp zos_zealfs_remove_page_list
_zos_zealfs_rm_isdir_notempty:
    ; The directory is not empty, we can return right now
    ld a, ERR_DIR_NOT_EMPTY
    ret
_zos_zealfs_rm_invalid:
    ld a, ERR_INVALID_PATH
    ret
_zos_zealfs_rm_mark_as_free:
    ; ASSUMPTION: DRIVER_DE_PARAM was set in zos_zealfs_load_and_check_next_name
    ; to RAM_BUFFER
    ld bc, 1
    xor a
    ld (RAM_BUFFER), a
    ; Load the offset from RAM_CUR_CONTEXT
    ld hl, (RAM_CUR_CONTEXT)
    ld de, (RAM_CUR_CONTEXT + 2)
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
    ; A must also be 0 here as the entry (directory) must exist
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
    ; Allocate a directory descriptor, BC already contains the driver address
    ld a, FS_ZEALFS
    call zos_disk_allocate_opndir
    or a
    ; Pop and return on error
    jr nz, _zos_zealfs_opendir_error_pop
    ; HL contains the address of the newly allocated opened dir entry
    ; DE points to the address of our private field, we have 12 bytes, fill it with:
    ;   * Current page of the directory - 2 bytes
    ;   * Remaining entries to scan - 2 bytes
    ;   * Next entry index. The index will be updated after each call to readdir - 4 byte
    ;   * Address of directory entry on the disk (dir infos) - 4 bytes
    ex de, hl
    ; Get the physical address of the directory's CONTENT
    push de ; Value to return at the end of the routine
    ; Store the "current" page of the directory
    ld de, (RAM_BUFFER + zealfs_entry_start)
    ld (hl), e
    inc hl
    ld (hl), d
    inc hl
    ; Get the total amount of entries per directories (in DE)
    ex de, hl
    call _zos_zealfs_reg_dir_max_entries
    ex de, hl
    ld (hl), e
    inc hl
    ld (hl), d
    inc hl
    ; Get the physical address of the directory start page
    push hl
    ld de, (RAM_BUFFER + zealfs_entry_start)
    call _zos_zealfs_phys_from_page
    ; Result is in DEHL, put it in DEBC
    ld b, h
    ld c, l
    pop hl
    ld (hl), c
    inc hl
    ld (hl), b
    inc hl
    ld (hl), e
    inc hl
    ld (hl), d
    inc hl
    ; Save the physical address of the directory entry
    ld bc, (RAM_CUR_CONTEXT)
    ld (hl), c
    inc hl
    ld (hl), b
    inc hl
    ld bc, (RAM_CUR_CONTEXT + 2)
    ld (hl), c
    inc hl
    ld (hl), b
    ; Get the original pointer back
    pop hl
    xor a
    ret
_zos_zealfs_opendir_root:
    ; Driver address is in DE, store it in BC instead
    ld b, d
    ld c, e
    push bc
    call zos_zealfs_prepare_driver_read
    ld a, FS_ZEALFS
    call zos_disk_allocate_opndir
    pop bc
    or a
    ret nz
    ; HL contains the address of the newly allocated opened dir entry
    ; DE points to the address of our private field, we have 12 bytes, fill it with:
    ;   * Current page of the directory - 2 bytes
    ;   * Remaining entries to scan - 2 bytes
    ;   * Next entry index. The index will be updated after each call to readdir - 4 byte
    ;   * Address of directory entry on the disk (dir infos) - 4 bytes (0x000000)
    ex de, hl
    push de
    ; Current page starts at 0 for the root directory (A is 0 here)
    ld (hl), a
    inc hl
    ld (hl), a
    inc hl
    ; Since we haven't called `_zos_zealfs_opendir_root`, we need to prepare the header manually
    ; We only need to keep HL
    push hl
    call zos_zealfs_prepare_header
    pop de
    ; Save page index + next entry index
    call _zos_zealfs_rootdir_max_entries
    ex de, hl
    ld (hl), e
    inc hl
    ld (hl), d
    inc hl
    ; Get the root directory first entry address
    ex de, hl
    call _zos_zealfs_header_size
    ex de, hl
    ld (hl), e
    inc hl
    ld (hl), d
    ; The structure has already been cleared by `zos_disk_allocate_opndir`, no need to manually
    ; store 6 NULL bytes.
    xor a
    ; Put back the original structure in HL and return success
    pop hl
    ret
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
    ; IMPORTANT: The dir_entry structure has the exact same fields and size as the
    ; one in ZealFS directory's entry. As such, we can use the user buffer to read
    ; data from disk directly. This will save time.
    ld (DRIVER_DE_PARAM), de
    ; The driver address is in the field before the user one in the structure
    dec hl
    dec hl
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    push hl
    call zos_zealfs_prepare_driver_read
    pop hl
    ; Our custom field is organized as follows:
    ;   * Current page of the directory - 2 bytes
    ;   * Remaining entries to scan - 2 bytes
    ;   * Next entry index. The index will be updated after each call to readdir - 4 byte
    ;   * Address of directory entry on the disk (dir infos) - 4 bytes (0x000000)
    ; Load the current page in DE
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ; Load the remaining number of entries in BC
    ld c, (hl)
    inc hl
    ld b, (hl)
    ; If we don't have anymore entries, we can return directly
    ld a, b
    or c
    ld a, ERR_NO_MORE_ENTRIES
    ret z
    ; Save the current page address above the struct (to fill) address
    push de
    ; Save HL to update it before returning, it is pointing to the remaining entries count MSB
    push hl
    inc hl
    ; HL points to the next entry physical address, dereference it in DEHL
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld a, (hl)
    inc hl
    ld h, (hl)
    ld l, a
    ex de, hl
    ; Look for the next used entry, iterate until BC is 0.
zos_zealfs_readdir_next:
    ; Reading the next entry in the directory, save the current offset (HL)
    push de
    push hl
    push bc
    ld bc, DISKS_DIR_ENTRY_SIZE
    call RAM_EXE_READ
    pop bc
    pop hl
    ; Check if there was an error while reading from the disk
    or a
    jp nz, _zos_zealfs_readdir_error_pop
    ; In all cases (current entry is empty or not), we need to update the next entry address
    dec bc
    ld a, b
    or c
    ; Before restoring DE, put in A the flags of the entry read
    ld de, (DRIVER_DE_PARAM)
    ld a, (de)
    ; If there is no more entries in the current page, we need to check if the current directory
    ; has another page and save it for the potential next call
    jr z, zos_zealfs_readdir_next_page
    ; Else, we still have entries in the current page, update the next entry offset (HL += ZEALFS_ENTRY_SIZE)
    ld de, ZEALFS_ENTRY_SIZE
    add hl, de
    ; Restore DE right now as will need it in all cases
    pop de
    jp nc, zos_zealfs_readdir_no_carry
    inc de
zos_zealfs_readdir_no_carry:
    ; Check if the entry we read was empty or not, if A's bit 7 is not 0, an entry has been found!
    bit 7, a
    jp z, zos_zealfs_readdir_next
    ; -----------------------------
    ; An entry has been found! Update the opened dir entry structure with the offset reached (HL)
    ; and the remaining number of entries to scan.
    ex (sp), hl
    ; HL points to the remaining entries count MSB
    ld (hl), b
    dec hl
    ld (hl), c
    inc hl
    inc hl
    ; HL points to the entry address
    pop bc
    ld (hl), c
    inc hl
    ld (hl), b
    inc hl
    ld (hl), e
    inc hl
    ld (hl), d
    ; Remove the "current page" from the stack
    pop de
    ; The name has already been populated, modify the flags: on ZealFS 1 means directory, on Zeal 8-bit OS
    ; it means file. Invert it.
zos_zealfs_readdir_return_entry_hl:
    ld hl, (DRIVER_DE_PARAM)
    ld a, (hl)
    xor 0x81
    ld (hl), a
    ; Success
    xor a
    ret
zos_zealfs_readdir_next_page:
    ; The user buffer (DE) is in DRIVER_DE_PARAM, it will be overwritten by zos_zealfs_prepare_header
    ; So save it somewhere temporarily, it will be restored later
    ld (RAM_BUFFER + 2), de
    ; Here, all registers can be altered since we are fetching a new page.
    ; The top of the stack must be cleaned (high 16-bit of address)
    pop de
    ; Prepare the header:
    ; This may be redundant, but it is unlikely to be executed multiple times (except if the directory is big
    ; and with a lot of empty pages)
    call zos_zealfs_prepare_header
    ; Get the structure's user field (on the stack, keep it there)
    pop hl
    ; Get the current page in DE
    pop de
    ; DE contains the current page, HL won't be altered
    call zos_zealfs_get_fat_entry
    ; If the next page is 0, we don't have any more entries, set the size to 0
    ld a, d
    or e
    jr z, zos_zealfs_readdir_no_next_page
    ; Store the new current page on the stack AND in the structure
    push de
    push hl ; Restore original organization
    ; ---
    push hl
    ; Calculate the number of entries in the new page
    call _zos_zealfs_reg_dir_max_entries
    ; Store the returned entries (remaining entries in the new page)
    ld b, h
    ld c, l
    pop hl
    ld (hl), b
    dec hl
    ld (hl), c
    dec hl
    ; Store the new page
    ld (hl), d
    dec hl
    ld (hl), e
    ; Get the physical address of the next entry (page)
    ; DE already contains the new page to read
    call _zos_zealfs_phys_from_page
    ; Physical address will always be aligned on 256, so L is 0 for sure!
    ; BC contains the number of remaining entries, it shall not be altered
    ld a, h
    ; Get the dir structure again
    pop hl
    push hl
    ; The physical address is "DEA0"
    inc hl
    ld (hl), 0
    inc hl
    ld (hl), a
    inc hl
    ld (hl), e
    inc hl
    ld (hl), d
    ; Get the original user buffer back
    ld hl, (RAM_BUFFER + 2)
    ld (DRIVER_DE_PARAM), hl
    bit 7, (hl)
    ; Restore HL as the lowest 16-bit of the physical address
    ld h, a
    ld l, 0
    ; DEHL contains the physical address of the next entry to check, BC contains the remaining size
    ; to check. We need to continue the loop only if the entry we read was empty.
    jp z, zos_zealfs_readdir_next
    ; We have to return! The stack is not clean, it contains the original user field address and current page
    pop hl
    pop de
    jr zos_zealfs_readdir_return_entry_hl
zos_zealfs_readdir_no_next_page:
    ; Store 0 for the remaining entries count
    ld (hl), a
    dec hl
    ld (hl), a
    ; Check the current entry, the stack is clean
    ld hl, (RAM_BUFFER + 2)
    ld a, (hl)
    bit 7, a
    jr z, zos_zealfs_readdir_no_more_entries
    xor 0x81
    ld (hl), a
    xor a
    ret
zos_zealfs_readdir_no_more_entries:
    ; No more entries, we can return
    ld a, ERR_NO_MORE_ENTRIES
    ret
_zos_zealfs_readdir_error_pop:
    pop de
    pop de
    pop de
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
    ; This routine will allocate a new page and write it to the last known FREE_ENTRY,
    ; update the disk header, including the bitmap, and return the new page index.
    ; This routine will also setup the driver's write routine in the RAM_EXE_WRITE
    ; buffer.
    ; Parameters:
    ;   HL - Name of the entry
    ;   DE - Driver address
    ;   B - 1 for a directory, 0 for a regular file
    ; Returns:
    ;   A - ERR_SUCCESS on success, error code else
    ;   [RAM_CUR_CONTEXT] - 32-bit physical address of the new entry description
    ;   [RAM_FREE_ENTRY]  - 32-bit physical address of the new entry
    ld b, 1
    call zos_zealfs_new_entry
    or a
    ret nz
    ; We just created a directory, we must empty its content.
    ; Iterate over all the DIR_MAX_ENTRIES entries of the directory.
    ; Set the first byte of the buffer to 0, it will clean the directories entries.
    ld hl, (RAM_CUR_CONTEXT + 0)
    ld de, (RAM_CUR_CONTEXT + 2)
    ; Parameters:
    ;   DEHL - Physical address of the directory to clear?
zos_zealfs_clear_dir:
    push hl
    ; Store the flag 0 in the RAM_BUFFER and set it as the parameter for the next driver write
    ld hl, RAM_BUFFER
    ld (hl), 0
    ld (DRIVER_DE_PARAM), hl
    ; Get the number of entries to iterate over
    call _zos_zealfs_reg_dir_max_entries
    ; Store the page size in BC
    ld b, h
    ld c, l
    pop hl
    ; DEHL contains the index to clean
_zos_zealfs_empty_dir:
    push de
    push bc
    push hl
    ld bc, 1
    call RAM_EXE_WRITE
    ; Calculate the next offset to clean
    pop hl
    ld bc, ZEALFS_ENTRY_SIZE
    add hl, bc
    pop bc
    ; Only DE is on the stack at the moment, check if we have to update it
    pop de
    jp nc, _zos_zealfs_empty_dir_no_carry
    inc de
_zos_zealfs_empty_dir_no_carry:
    ; Check for errors from the disk driver
    or a
    ; The stack is clean already
    ret nz
    ; Check if we still have entries to clean
    dec bc
    ld a, b
    or c
    jr nz, _zos_zealfs_empty_dir
    ; Success, A is already 0, no need to set it
    ret
_zos_zealfs_mkdir_already_exists:
    ld a, ERR_ALREADY_EXIST
    ret


    ;======================================================================;
    ;================= P R I V A T E   R O U T I N E S ====================;
    ;======================================================================;


    ; Get the physical address of a page in the FAT
    ; Parameters:
    ;   DE - Page to get the address of
    ; Returns:
    ;   DEHL - Address on the disk for the given page
    ;   Z flag - Entries in the FAT are 8-bit big
    ;   NZ     - Entries in the FAT are 16-bit big
    ; Alters:
    ;   A, BC, DE, HL
zos_zealfs_get_page_addr_in_fat:
    ld b, d
    ld c, e
    ; Get the size of a single page on the disk
    call _zos_zealfs_page_size
    ; HL contains the size of a single page, since the FAT table is always page 1 and page 2 (except when page is 256 bytes)
    ; HL already points to the FAT address on the disk.
    ; Special cases for H = 1 (page size is 8-bit) and H = 0 (page size is 64K)
    ld d, l ; L is 0 for sure here
    ld a, h
    or a
    jr z, zos_zealfs_get_entry_addr_64K
    dec a
    jr z, zos_zealfs_get_entry_addr_256
    ; Pages are not 64K big, set A to 0xFF so that after inc, it becomes 0
    ld a, 0xff
zos_zealfs_get_entry_addr_64K:
    inc a
    ; A is either 0 or 1 here, it will contain the high byte of the address (E)
    ; Calculate AHL + BC * 2 = AHL + BC + BC
    add hl, bc
    ; Move the carry in A (optimization: D is 0 for sure)
    adc d
    add hl, bc
    ; A will contain the carries to add to E (which is 0 or 1)
    adc d
    ld e, a
    ; DEHL contains the address to read, make sure Z flag is NOT set
    ; A is 0, 1, 2 or 3, incrementing it will never be 0
    inc a
    ret
zos_zealfs_get_entry_addr_256:
    ; Set E to 0 since the disk cannot exceed 64KB
    ld e, l ; L is 0 here for sure
    ; Pages are 256 bytes big, so each entry in the FAT table are 1 byte
    ; B is 0, C is the page index (guaranteed)
    ld l, c
    ; DEHL (0x000001xx) points to the address on disk of the next page of the given page
    ; Z flag is still set!
    ret


    ; Get the next page of a given page from the FAT
    ; Parameters:
    ;   DE - Page to get the next page of
    ;   [RAM_EXE_READ]  - Must be populate already with driver's read routine
    ; Returns:
    ;   DE - Next page
    ; Alters:
    ;   A, DE
zos_zealfs_get_fat_entry:
    push hl
    push bc
    ; Save the former parameter
    ld hl, (DRIVER_DE_PARAM)
    push hl
    ld hl, RAM_BUFFER
    ld (DRIVER_DE_PARAM), hl
    call zos_zealfs_get_page_addr_in_fat
    push af
    ld bc, 2
    call RAM_EXE_READ
    ld de, (RAM_BUFFER)
    pop af
    ; Restore the former parameter
    pop hl
    ld (DRIVER_DE_PARAM), hl
    ; If Z flag is set, we have to set D to 0 before returning (pages are only 1 byte)
    pop bc
    pop hl
    ret nz
    ld d, 0
    ret


    ; Clear the FAT entry from a page
    ; Parameters:
    ;   DE - Page to clear
    ;   [RAM_EXE_WRITE]  - Must be populate already with driver's write routine
    ; Returns:
    ;   None
    ; Alters:
    ;   A, BC, DE, HL
zos_zealfs_clear_fat_entry:
    ld hl, 0
    ex de, hl
    ; Fall-through

    ; Set the next page of a given page from the FAT
    ; Parameters:
    ;   HL - Last page of current directory
    ;   DE - New allocated page
    ;   [RAM_EXE_WRITE]  - Must be populate already with driver's write routine
    ; Returns:
    ;   [DRIVER_DE_PARAM] - RAM_BUFFER
    ; Alters:
    ;   A, BC, DE, HL
zos_zealfs_set_fat_entry:
    ; Put the last page of directory in DE and new allocated page in HL
    ex de, hl
    ; Store the new page (to write), in the temporary buffer
    ld (RAM_BUFFER), hl
    ld hl, RAM_BUFFER
    ; Set this buffer as the parameter to the driver write function
    ld (DRIVER_DE_PARAM), hl
    call zos_zealfs_get_page_addr_in_fat
    ld bc, 1
    jr z, zos_zealfs_set_fat_entry_single_byte
    inc c
zos_zealfs_set_fat_entry_single_byte:
    jp RAM_EXE_WRITE


    ; Remove the a whole list of pages from a given starting page
    ; Parameter:
    ;   DE - Starting page
    ; Returns:
    ;   A - 0
    ; Alters:
    ;   A, BC, DE, HL
zos_zealfs_remove_page_list:
    ; Free the current page (in DE)
    push de
    call zos_zealfs_free_page
    pop de
    ; Get next entry of the current page
    call zos_zealfs_get_fat_entry
    ; Next page in DE, if the "next" page is not free, continue the loop
    ld a, d
    or e
    ret z
    ; Remove the entry from the FAT, this is optional, the most important is the bitmap
    ; call zos_zealfs_clear_fat_entry
    jr zos_zealfs_remove_page_list


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
    ld hl, _zos_zealfs_browse_read_error
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
    ; In most cases, we won't have any error
    or a
    jp z, _zos_zealfs_browse_continue
    ; Check if the entry is corrupted or if we got a real internal error
    cp ERR_ENTRY_CORRUPTED
    jp nz, _zos_zealfs_browse_seek_error
    ; It can happen that A is ERR_ENTRY_CORRUPTED if the file we are trying to write to has
    ; a size multiple of the page size. In this case, we have to allocate a new page and link
    ; it to the last page of the file, currently in DE
    ex de, hl
    call RAM_EXE_PAGE_0
    or a
    ; 0 means error in this case
    jp z, _zos_zealfs_seek_corrupted
    ; No error, the new page is in DE, set the offset to 0 as the page is new and empty
    ld bc, 0
    ; Fall-through
_zos_zealfs_browse_continue:
    ; Store the current page and the offset in RAM_CUR_CONTEXT
    ;   DE - Current page of the file
    ;   BC - Offset in that current page
    ; Calculate the physical address of that page
    ld (RAM_CUR_CONTEXT), de
    call _zos_zealfs_phys_from_page
    ; Add the offset to the physical page
    add hl, bc
    ; Carry should never occur here, store the physical address in RAM_BUFFER
    ld (RAM_BUFFER + 10), hl
    ld (RAM_BUFFER + 12), de
    ; Store the page size in RAM_BUFFER
    call _zos_zealfs_page_size
    ld (RAM_CUR_CONTEXT + 2), hl
    ; Calculate the remaining number of bytes in the current page
    or a
    sbc hl, bc
    ; HL contains the remaining bytes to read in the current page
    ; BC - Buffer size
    pop bc
    ; Store the user buffer as a parameter
    pop de
    ld (DRIVER_DE_PARAM), de
    ; Organize the stack so that we have:
    ; [SP + 4] : User buffer size
    ; [SP + 2] : User buffer address
    ; [SP + 0] : Remaining size to process
    push bc ; Buffer size
    push de
    ; HL contains the remaining bytes to read/write in the current page,
    ; BC contains the remaining bytes to read/write in the user buffer,
    ; Calculate the minimum and keep it in BC
    ; Carry should be 0 here
    push bc ; Remaining size to process
    call _zos_zealfs_browse_min
    ; We have to process BC bytes starting at physical address [RAM_BUFFER+10..RAM_BUFFER+13], in user buffer
    ld hl, (RAM_BUFFER + 10)
    ld de, (RAM_BUFFER + 12)
    push bc
_zos_zealfs_browse_loop:
    pop bc
    call RAM_EXE_OPER
    or a
    jr nz, _zos_zealfs_browse_content_loop_end
    ; Get the remaining size to process in HL
    pop hl
    ; Subtract what we just read/wrote
    sbc hl, bc
    ; Nothing more to process?
    jr z, _zos_zealfs_browse_process_end
    ; Get the user buffer address from the stack and make it advance to the stack byte to process
    ex de, hl
    pop hl
    add hl, bc
    push hl
    ld (DRIVER_DE_PARAM), hl
    ; Push the remaining bytes to read on the stack
    push de
    ld b, d
    ld c, e
    ; Get the page size from the context
    ld hl, (RAM_CUR_CONTEXT + 2)
    call _zos_zealfs_browse_min
    push bc
    ; The stack is ready, we need to get the next page of the file, HL will not be altered
    ; Needed by `zos_zealfs_get_fat_entry`
    ld de, (RAM_CUR_CONTEXT)
    ld h, d
    ld l, e
    call zos_zealfs_get_fat_entry
    ; If the page is 0, we have to call our callback
    ld a, d
    or e
    ; The callback can alter any register, it returns the new page in DE
    call z, RAM_EXE_PAGE_0
    ; Check A (in case we entered the routine above)
    or a
    jp z, _zos_zealfs_browse_corrupted
    ; Success, DE contains the new page
    ld (RAM_CUR_CONTEXT), de
    ; DE contains the new page, calculate the physical address
    call _zos_zealfs_phys_from_page
    jr _zos_zealfs_browse_loop
_zos_zealfs_browse_process_end:
    ; Pop the user buffer address
    pop de
    ; Pop the final size (user buffer size) in BC
    pop bc
    ; Success
    xor a
    ret
    ; Calculate the minimum between HL and BC, return the result in BC
_zos_zealfs_browse_min:
    or a
    sbc hl, bc
    ret nc
    add hl, bc
    ld b, h
    ld c, l
    ret
_zos_zealfs_browse_corrupted:
    ld a, ERR_ENTRY_CORRUPTED
_zos_zealfs_browse_content_loop_end:
    pop de
_zos_zealfs_browse_seek_error:
    pop de
    pop bc
    ret
_zos_zealfs_browse_read_error:
    xor a
    ret


    ; Jump to the following sub-routine when we have to go to the next page but it is 0
    ; in the current page. This only happens during writes, so we have to allocate a new
    ; page and return to the loop that browse content.
    ; Entry:
    ;   HL - Current page number
    ; Exit:
    ;   A - 1 in case of success, 0 else
    ;   DE - New page index
    ; Alters:
    ;   Any register
_zos_zealfs_browse_allocate:
    push hl
    ; Save the DRIVER_PARAM since it'll be overwritten
    ld hl, (DRIVER_DE_PARAM)
    ; Make former HL value back on top of the stack
    ex (sp), hl
    push hl
    ; Start by allocating a page, this routine will update the bitmap and disk header
    call zos_zealfs_new_page
    pop hl
    or a
    jr nz, _zos_zealfs_browse_allocate_error
    ; DE contains the new page index, save it to return it
    push de
    call zos_zealfs_set_fat_entry
    pop de
    ; HL can still be altered, use it to restore the DRIVER PARAM
    pop hl
    ld (DRIVER_DE_PARAM), hl
    ld a, 1
    ret
_zos_zealfs_browse_allocate_error:
    xor a
    ret


    ; Seek into an opened file. This is useful when an offset has been provided and we
    ; have to look for the page that contains the bytes pointed by it.
    ; Parameters:
    ;       HL - Address of the opened file. It embeds the offset to read from the
    ;            file, the driver address and the user field.
    ; Returns:
    ;       A - 0 on success, error value else
    ;       DE - Current page of the file or last valid page in case of error
    ;       BC - Offset in that current page
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
    ; Prepare the header as well
    call zos_zealfs_prepare_header
    ; Prepare the driver's functions parameters
    ld hl, RAM_BUFFER
    ld (DRIVER_DE_PARAM), hl
    ; Make HL point to the offset in the file, ignore the size
    pop hl
    ld bc, 4
    add hl, bc
    ld c, (hl)
    inc hl
    ld b, (hl)
    inc hl
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ; DEBC contains the file offset. HL points to the user field, which contains the physical
    ; address of the file ENTRY (not content) on the disk, we have to read it to get the start page.
    push bc
    push de
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld a, (hl)
    inc hl
    ld h, (hl)
    ld l, a
    ex de, hl
    ; 32-bit offset is now in DEHL, add the start page offset
    ld bc, zealfs_entry_start
    add hl, bc
    ; Carry can never occur since the entries are always aligned on the entry size (32 bytes)
    ; Read 2 bytes from that offset
    ld bc, 2
    call RAM_EXE_READ
    or a
    jr nz, _zos_zealfs_seek_read_error
    ; Get the page size from the header, this represents the number of right
    ; shift to perform to divide the address with the page size:
    ;   0 - 256
    ;   1 - 512
    ;   ...
    ;   8 - 65536
    ld a, (RAM_FS_HEADER + zealfs_page_size_t - zealfs_bitmap_size_t)
    ; Put the offset in DEHL
    pop de
    pop hl
    ; EHL will be the result, shift by 8 directly
    or a
    ; Shift in B
    ld b, a
    ; AC is the remainder
    ld c, l
    ld a, 0 ; do not alter the flags
    ld l, h
    ld h, e
    ld e, d
    jr z, _zos_zealfs_seek_no_shift
    push bc
_zos_zealfs_seek_shift:
    srl e
    rr h
    rr l
    ; Push it to the remainder
    rla
    djnz _zos_zealfs_seek_shift
    ; The bits in A are mirrored, bit 7 should be bit 0, bit 6 should be bit 1, etc...
    ; D is free to use
    pop bc
    ld d, a
    xor a
_zos_zealfs_seek_mirror:
    rrc d
    rla
    djnz _zos_zealfs_seek_mirror
_zos_zealfs_seek_no_shift:
    ; Remainder in BC instead of AC
    ld b, a
    ; Keep the remainder on the stack
    push bc
    ; We have to get the next page EHL times, put it in CHL
    ld c, e
    ; Get the start page in DE
    ld de, (RAM_BUFFER)
_zos_zealfs_seek_loop:
    push de
    ; Make sure the loop is not finished
    ld a, c
    or h
    or l
    jr z, _zos_zealfs_seek_loop_end
    call zos_zealfs_get_fat_entry
    ld a, d
    or e
    jr z, _zos_zealfs_seek_corrupted
    ; Pop from the stack without altering registers
    inc sp
    inc sp
    ; If HL is 0, we will need to decrement C
    ld a, h
    or l
    dec hl
    jr nz, _zos_zealfs_seek_loop
    ; HL was 0, decrement C
    dec c
    jp _zos_zealfs_seek_loop
_zos_zealfs_seek_loop_end:
    ; DE contains the page we seeked to. Get the offset in that page from the stack
    pop bc  ; former page
    pop bc
    ; Success
    xor a
    ret
_zos_zealfs_seek_not_file_error:
    ld a, ERR_NOT_A_FILE
    pop hl
    ret
_zos_zealfs_seek_corrupted:
    ; Previous valid page in DE
    pop de
    ; Remove the "remaining" bytes from the stack
    pop hl
    ld a, ERR_ENTRY_CORRUPTED
    ret
_zos_zealfs_seek_read_error:
    pop hl
    pop hl
    ret


    ; Allocate a new page and update the disk header and bitmap accordingly
    ; Parameters:
    ;   [RAM_FS_HEADER] - Must be already populated with FS header
    ;   [RAM_EXE_READ]  - Must be already populated with driver's read routine
    ;   [RAM_EXE_WRITE] - Must be already populated with driver's read routine
    ; Returns:
    ;   DE - Index of the new page
    ;   A - ERR_SUCCESS on success, error code else
    ; Alters:
    ;   A, BC, DE, HL
zos_zealfs_new_page:
    ld hl, (RAM_FS_HEADER + zealfs_free_pages_t - zealfs_bitmap_size_t)
    ld a, h
    or l
    jr z, _zos_zealfs_new_page_no_memory
    ; Prepare the parameter for the driver's READ
    ld hl, RAM_BUFFER
    ld (DRIVER_DE_PARAM), hl
    ; Retrieve the size of the bitmap in HL
    ld hl, (RAM_FS_HEADER + zealfs_bitmap_size_t - zealfs_bitmap_size_t)
    ld d, h
    ld e, l
    ; Store the total size of the bitmap in HL and the
    ; minimum between the bitmap size and RAM_BUFFER_SIZE
    ; in BC.
    ; Calculate the minimum between HL and RAM_BUFFER_SIZE
    ld bc, RAM_BUFFER_SIZE
    sbc hl, bc
    jr nc, _zos_zealfs_new_page_bc_ready
    ; The minimum was HL
    ld b, d
    ld c, e
_zos_zealfs_new_page_bc_ready:
    ; The minimum is in BC, restore HL
    ex de, hl
    ; Store the offset to read on top of the stack
    ld de, zealfs_pages_bitmap
    push de
    ; Store the remaining bytes to read on the stack
    push hl
    ; Read BC bytes from the bitmap, the offset is the bitmap start
    push bc
    ; Set the initial bitmap address in HL, and DE to 0 since bitmap will
    ; always be in the first 64KB, DE will always be 0
    ex de, hl
_zos_zealfs_new_page_loop:
    ld de, 0
    call RAM_EXE_READ
    ; Check for any error
    or a
    jr nz, _zos_zealfs_new_page_read_error
    ; Check for any free bit in the bitmap, the size should be in B, not BC
    ; the static buffer is smaller than 256, so we can simply move C to B.
    ld b, c
    ld hl, RAM_BUFFER
    call allocate_page
    or a
    jr nz, _zos_zealfs_new_page_found
    ; Page not found, all the bits are marked as taken, calculate the remaining
    ; size and read the next part of the bitmap
    pop bc  ; Size to read
    pop hl  ; Remaining size to read
    sbc hl, bc
    ex de, hl   ; Remaining size in DE
    pop hl  ; Put the former offset (bitmap) in HL
    ; If the remaining size if 0, the end of the bitmap has been
    jr z, _zos_zealfs_new_page_no_memory
    ; Calculate the next offset
    add hl, bc
    ; Organize the stack as before:
    ; - Offset
    ; - Remaining
    ; - Size
    push hl
    push de
    push bc
    jp _zos_zealfs_new_page_loop
_zos_zealfs_new_page_found:
    ; B - Bit index of the free page in the byte
    ; E - Byte index in the bitmap chunk
    ; The address of the byte that was modified is in HL, make it
    ; the parameter for the driver's WRITE function
    ld (DRIVER_DE_PARAM), hl
    ; Pop the size to read from the stack
    ld a, b
    pop bc
    ; Pop the remaining size to read
    pop bc
    ; Get the offset that was read but keep it on the stack too
    pop hl
    push hl
    ; Subtract the offset of bitmap from the header
    ld bc, -zealfs_pages_bitmap
    add hl, bc
    ; Add the index of the byte (in the current bitmap chunk) containing the free page
    ld b, 0
    ld c, e
    add hl, bc
    ; Multiply by 8 since we have 8 pages per byte
    add hl, hl
    add hl, hl
    add hl, hl
    ; Add the bit index in the free page's byte
    ld c, a
    add hl, bc
    ; Put the calculate page in DE
    ld c, e ; Byte index in C
    ex de, hl
    ; Get back the offset of the bitmap chunk we previously read
    pop hl
    ; Write it back to the disk...we need its physical address. Byte index
    ; already in BC
    add hl, bc
    ; Save DE, we will need it later, stack is clean already
    push de
    ld de, 0
    ld bc, 1
    call RAM_EXE_WRITE
    or a
    jr nz, _zos_zealfs_new_page_write_error
    ; Update the FAT table to let the new page not have any next page
    ld hl, RAM_BUFFER
    ld (DRIVER_DE_PARAM), hl
    ; Get the new page number, keep it on the stack
    pop de
    push de
    call zos_zealfs_clear_fat_entry
    ; Decrement the number of free pages count in the header
    ld bc, -1
    call _zos_zealfs_add_free_pages_count
    ; Get the allocated page back
    pop de
    ; Success
    xor a
    ret
_zos_zealfs_new_page_read_error:
    pop hl
    pop bc
_zos_zealfs_new_page_write_error:
    pop hl
    ret
_zos_zealfs_new_page_no_memory:
    ld a, ERR_NO_MORE_MEMORY
    ret

    ; Parameters:
    ;   BC - Number to add to the free pages count
_zos_zealfs_add_free_pages_count:
    ld hl, (RAM_FS_HEADER + zealfs_free_pages_t - zealfs_bitmap_size_t)
    add hl, bc
    ld (RAM_FS_HEADER + zealfs_free_pages_t - zealfs_bitmap_size_t), hl
    ld hl, RAM_FS_HEADER + zealfs_free_pages_t - zealfs_bitmap_size_t
    ld (DRIVER_DE_PARAM), hl
    ; Offset to update in DEHL
    ld bc, 2
    ; DE = 0
    ld d, b
    ld e, b
    ld hl, zealfs_free_pages_t
    jp RAM_EXE_WRITE


    ; Free a page and update the disk header and bitmap accordingly.
    ; Parameters:
    ;   DE - Index of the page to free
    ;   [RAM_FS_HEADER] - Must be already populated with FS header
    ;   [RAM_EXE_READ]  - Must be already populated with driver's read routine
    ;   [RAM_EXE_WRITE] - Must be already populated with driver's read routine
    ; Returns:
    ;   A - success or error code
    ; Alters:
    ;   A, BC, DE, HL
zos_zealfs_free_page:
    ld hl, RAM_BUFFER
    ld (DRIVER_DE_PARAM), hl
    ; Calculate the byte to update in the bitmap, divide DE by 8
    ld a, e
    srl d
    rr e
    srl d
    rr e
    srl d
    rr e
    ; The bit to update is A & 3, multiply it by 8 as required below
    and 3
    rlca
    rlca
    rlca
    push af
    ; Read the byte from the bitmap
    ld hl, zealfs_pages_bitmap
    add hl, de
    push hl ; Need it to write back
    ld de, 0
    ld bc, 1
    call RAM_EXE_READ   ; Read from the disk
    pop hl
    or a
    jr nz, _zos_zealfs_free_page_error
    pop af
    ; Now, we need to set (RAM_BUFFER) bit A to 0. Let's use self-modifying code
    ; to simplify this. We have to generate res b, A instruction.
    ; Re-use RAM_EXE_PAGE_0 (prepared by the caller) part which is 3-bytes big.
    ; A = 0b10bbb111
    add 0x87
    ld (RAM_EXE_PAGE_0 + 1), a
    ld a, (RAM_BUFFER)
    call RAM_EXE_PAGE_0
    ld (RAM_BUFFER), a
    ; Write the byte back
    ld de, 0
    ld bc, 1
    call RAM_EXE_WRITE
    ; Increment the free page count from the header
    ld bc, 1
    jp _zos_zealfs_add_free_pages_count
_zos_zealfs_free_page_error:
    pop bc
    ret


    ; Create a new entry at the last known FREE_ENTRY location.
    ; This routine allocates a new page, update the entry, the disk header, the bitmap
    ; and returns the new page allocated.
    ; In case of a directory, the size will be set to a page size (256). In case of a
    ; file, it will be set to 0.
    ; Parameters:
    ;   HL - Name of the entry
    ;   DE - Disk driver address
    ;   B - 1 for a directory, 0 for a regular file
    ;   [RAM_EXE_READ]   - Must be preloaded with the driver's read routine address.
    ;   [RAM_FS_HEADER]  - Filled with FS header
    ;   [RAM_FREE_ENTRY] - Last known free entry address (32-bit)
    ; Returns:
    ;   A - ERR_SUCCESS on success, error code else
    ;   [RAM_CUR_CONTEXT] - 32-bit physical address of the new allocated page
    ;   [RAM_FREE_ENTRY] - 32-bit physical address of the new entry
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
    ld de, (RAM_FREE_ENTRY + 2)
    or d
    or e
    jr z, _zos_zealfs_new_entry_full
_zos_zealfs_new_entry_resume:
    push hl
    push bc
    ; Allocate a page from the header
    call zos_zealfs_new_page
    or a
    jr nz, _zos_zealfs_pop_all_ret
    ; Index of the new page is in DE, calculate the new page address, do not alter DE
    push de
    call _zos_zealfs_phys_from_page
    ; Save DEHL (physical address) as the return value
    ld (RAM_CUR_CONTEXT), hl
    ld (RAM_CUR_CONTEXT + 2), de
    pop de
    ; The header (w/ bitmap) has been updated, now, create a new file entry in the RAM_BUFFER
    ; that will be used to flash the free entry found.
    ; Clean up the structure first
    call _zealfs_clear_buffer
    ; Populate the flags first, we will need BC for this (we have to pop first...)
    pop bc
    pop hl
    ; Start page is in DE, store it in the buffer directly
    ld (RAM_BUFFER + zealfs_entry_start), de
    ld a, b
    or 0x80
    ; Fill the RAM_BUFFER with the new entry
    ld de, RAM_BUFFER
    ld (de), a
    ; ( Take advantage of the fact that DE points to the buffer to set the driver WIRTE routine parameter
    ld (DRIVER_DE_PARAM), de ; )
    inc de
    ; Populate the name now, copy from HL to structure
    ld bc, FS_NAME_LENGTH
    call strncpy
    ; HL can be re-used, set the size to 0 for files, page size for directories
    xor a
    ld b, a ; BC = 0
    ld c, a
    ; Lowest byte and highest byte are both 0 is all cases
    ld (RAM_BUFFER + zealfs_entry_size), a
    ld (RAM_BUFFER + zealfs_entry_size + 3), a
    ; Check the flags to know whether we are creating a file or dir
    ld a, (RAM_BUFFER)
    and 1
    call nz, _zos_zealfs_page_size_upper
    ld (RAM_BUFFER + zealfs_entry_size + 1), bc
    ; Make DE points to the date and get the current date if a clock is available
    ld de, RAM_BUFFER + zealfs_entry_date
    call zos_date_getdate_kernel
    ; Do not check the return code, in the worst case, the structure is clean already
    ; Write back this new file entry to the disk, at the free entry offset
    ld hl, (RAM_FREE_ENTRY)
    ld de, (RAM_FREE_ENTRY + 2)
    ld bc, ZEALFS_ENTRY_SIZE
    ; Tail-call
    jp RAM_EXE_WRITE
_zos_zealfs_new_entry_full:
    ; Save the entry name and its flag
    push hl
    push bc
    ; Allocate a new page that will be the next page of the current directory
    call zos_zealfs_new_page
    ; Allocated page is in register pair DE
    or a
    jr nz, _zos_zealfs_new_entry_full_error
    ; Save the newly allocated page
    push de
    ; Link the new page to the last page of the current directory, by calling zos_zealfs_set_fat_entry
    ; Parameters:
    ;   HL - Last page of current directory
    ;   DE - New allocated page
    ld hl, (RAM_CUR_PAGE)
    ; DRIVER_DE_PARAM will be set by the routine
    call zos_zealfs_set_fat_entry
    pop de
    ; New page is in DE, calculate the physical address and store the result in RAM_FREE_ENTRY
    call _zos_zealfs_phys_from_page
    ; Physical address in DEHL
    ld (RAM_FREE_ENTRY), hl
    ld (RAM_FREE_ENTRY + 2), de
    ; New page allocate in the bitmap and FAT table! We need to clear the first bytes of every entry (except the
    ; first one since we are going to re-use it anyway)
    call zos_zealfs_clear_dir
    ; Restore the flags, used by the caller
    pop bc
    pop hl
    or a
    ; If there was no error, we can continue the execution of the routine
    jr z, _zos_zealfs_new_entry_resume
    ; Return the error else
    ret
_zos_zealfs_new_entry_full_error:
    ld a, ERR_CANNOT_REGISTER_MORE
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

    ; ZealFS function called to initialize the functions in RAM
zos_zealfs_init:
    ld hl, zos_zealfs_trampoline_start
    ; We will need to copy it twice
    ld de, read_trampoline
    ld bc, zos_zealfs_trampoline_end - zos_zealfs_trampoline_start
    push hl
    push bc
    ldir
    pop bc
    pop hl
    ldir
    ret


    ; Trampoline function that must be copied to RAM, it will be modified at runtime to
    ; jump to the driver's read or write routine.
    ; Parameters:
    ;   DEHL - 32-bit offset to read/write from the disk
    ;   [DRIVER_DE_PARAM] - Address of the buffer
    ;   BC - Length to read/write
zos_zealfs_trampoline_start:
    xor a
    push hl
    push de
    ld de, (DRIVER_DE_PARAM)
    jp 0x0000   ; Stub to be replaced at runtime
zos_zealfs_trampoline_end:


    ; This routine gets the `read` function of a driver and stores it in the read trampoline function
    ; After that, it can use `call RAM_EXE_READ` safely.
    ; Parameters:
    ;   DE - Driver address
    ; Returns:
    ;   HL - Address of read function
    ; Alters:
    ;   A, DE, HL
zos_zealfs_prepare_driver_read:
    ; Retrieve driver (DE) read function address, in HL.
    GET_DRIVER_READ_FROM_DE()
    ; The last 2 bytes of the trampoline are the the jump destination
    ld (read_trampoline_end - 2), hl
    ret

    ; Same as above, but with write routine
zos_zealfs_prepare_driver_write:
    ; Retrieve driver (DE) read function address, in HL.
    GET_DRIVER_WRITE_FROM_DE()
    ld (write_trampoline_end - 2), hl
    ret

    ; Same as above but safe, it preserves both HL and DE
zos_zealfs_prepare_driver_write_safe:
    push hl
    push de
    call zos_zealfs_prepare_driver_write
    pop de
    pop hl
    ret


    ; Populate the FS header by reading the first bytes
    ; Parameters:
    ;   RAM_EXE_READ - Should be ready to read from the driver
    ; Alters:
    ;   A, BC, DE, HL
zos_zealfs_prepare_header:
    ; Read 6 bytes from the disk
    ld bc, 6
    ; Destination is the RAM_FS_HEADER
    ld hl, RAM_FS_HEADER
    ld (DRIVER_DE_PARAM), hl
    ; Offset is `zealfs_bitmap_size_t`, we can skip the magic byte and version
    ld d, b ; DE = 0
    ld e, d
    ld hl, zealfs_bitmap_size_t
    jp RAM_EXE_READ


    ; Allocate a page in the bitmap. The bitmap will be altered as the free page (bit 0)
    ; will be marked as allocated (bit 1)
    ; Parameters:
    ;   HL - Address of the bitmap
    ;   B  - Size of the bitmap in bytes
    ; Returns:
    ;   A - 0 if no free page found, positive value else
    ;   B - Bit index of the free page (0-7)
    ;   E - Byte index in the bitmap containing the free page
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
    ; Calculate the offset, in bytes, of the byte that contains the free page
    ld a, c
    sub b
    ; Store the byte that contains the byte index in E
    ld e, a
    ; B will contain the bit index of the free page
    ld b, 0
    ; Keep track of the index of that bit 0 (in C) because we will need to modify the bitmap
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
    ; A is not 0 for sure
    ret


    SECTION KERNEL_BSS
    ; We need some space to store both the read and the write trampolines
read_trampoline:    DEFS zos_zealfs_trampoline_end - zos_zealfs_trampoline_start
read_trampoline_end:
write_trampoline:   DEFS zos_zealfs_trampoline_end - zos_zealfs_trampoline_start
write_trampoline_end: