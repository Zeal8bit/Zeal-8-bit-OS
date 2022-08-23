; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        ; RAWTABLE file system describes a very simple way of storing read-only data.
        ; It is not really a file system, it is more an organized way of storing
        ; raw data. (Isn't that the definition of a file system though?)
        ; It consists in a header, starting at offset 0 containing information about
        ; the number of files and the files themselves. No directory supported (yet?).
        INCLUDE "osconfig.asm"
        INCLUDE "vfs_h.asm"
        INCLUDE "errors_h.asm"
        INCLUDE "drivers_h.asm"
        INCLUDE "disks_h.asm"
        INCLUDE "utils_h.asm"

        ; The rawtable structure is as follow:
        DEFVARS 0 {
                rawtable_count_t   DS.W 1   ; Max 2047 entries at most, more than enough
                ; The following is repeated for each file that we have
                rawtable_name_t    DS.B 16  ; 16 char max for the name, including extension
                rawtable_size_t    DS.B 4   ; 32-bit file size
                rawtable_offset_t  DS.B 4   ; 32-bit offset in the device itself
                rawtable_date_t    DS.B DATE_STRUCT_SIZE ; Same as file_date_t, check vfs_h.asm
                rawtable_end_t     DS.B 1   ; End of entry
                ; Total of 32 bytes per entry
        }

        DEFC RAWTABLE_NAME_MAX_LEN = rawtable_size_t - rawtable_name_t
        DEFC RAWTABLE_ENTRY_SIZE = rawtable_end_t - rawtable_name_t
        ; Offset of rawtable_size_t in the header entry
        DEFC RAWTABLE_SIZE_OFFSET = rawtable_size_t - rawtable_name_t
        ASSERT(RAWTABLE_ENTRY_SIZE == 32)

        DEFC JP_INSTR_OPCODE = 0xC3

        EXTERN _vfs_work_buffer
        EXTERN strchrnul

        DEFC RAM_DRIVER_ADDR = _vfs_work_buffer 
        DEFC RAM_EXE_CODE = RAM_DRIVER_ADDR + 2 ; Reserve 2 bytes for the address
        DEFC RAM_BUFFER   = RAM_EXE_CODE + 3    ; Reserve 3 bytes for the jp code

        SECTION KERNEL_TEXT

        ; Open a file from a disk that has a RAWTABLE filesystem
        ; Parameters:
        ;       B - Flags, can be O_RDWR, O_RDONLY, O_WRONLY, O_NONBLOCK, O_CREAT, O_APPEND, etc...
        ;       HL - Absolute path, without the disk letter (without X:/), guaranteed not NULL by caller.
        ;       DE - Driver address, guaranteed not NULL by the caller.
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ;       HL - Opened-file structure address, passed through all the other calls, until closed
        ; Alters:
        ;       A, BC, DE, HL
        PUBLIC zos_fs_rawtable_open
zos_fs_rawtable_open:
        ; We are guaranteed by the caller that the path/name is not empty nor NULL.
        ; Check if flags are valid as rawtables are read-only
        ld a, b
        cp O_RDONLY
        ld a, ERR_READ_ONLY
        jp nz, _zos_fs_rawtable_open_readonly
        ; Check if it is a valid name for rawtable FS, in other words, check if it contains /
        ld a, '/'
        push hl
        call strchrnul
        ; BC is not used anymore, put the name address inside
        pop bc
        ; If A is not zero, then we found a / in the name, let's say we didn't find the file
        or a
        jp nz, _zos_fs_rawtable_open_invalid_name
        ; Calculate the name length thanks to BC and HL
        ; Here, carry flag and A are both 0
        sbc hl, bc
        ; HL contains the string length, check that it's smaller than RAWTABLE_NAME_MAX_LEN
        or h
        ; Name too long, file not found
        jp nz, _zos_fs_rawtable_open_invalid_name
        or l
        ; A contains the string length INCLUDING \0, check that it's <= RAWTABLE_NAME_MAX_LEN
        cp RAWTABLE_NAME_MAX_LEN + 2
        jp nc, _zos_fs_rawtable_open_invalid_name
        ; BC - name address
        ; L  - name length
        ; DE - driver address
        ; The remaining things to do:
        ;       - Call driver's open function
        ;       - Call driver's read function
        ;       - Look for the file in the table
        ;       - Return if not found
        ;       - Create a descriptor else
        ; Driver's functions can alter any register
        ; Length is not needed anymore
        push bc
        push de
        ; Save the driver address in RAM
        ld (RAM_DRIVER_ADDR), de
        ; Put driver's open function in HL
        GET_DRIVER_OPEN()
        ; Put the flags in A
        ld a, O_RDONLY
        ; Open function in HL
        CALL_HL()
        pop de
        pop bc
        ; Check return value
        or a
        ret nz   ; If error occured in `open`, return 
        ; Save driver address?
        ; push de
        ; Retrieve driver (DE) read function address, in HL.
        ; Push + pop + call_hl() takes 10 + 11 + 11 + 4 = 36 T-states.
        ; If we generate a call read_function instruction, we will generate:
        ; jp read_function in RAM, called with call ram_loc. This will take:
        ; 17 + 10 T-states = 27 T-states, without counting the init (copying 3 bytes
        ; to RAM)
        ; Here, we need to implement a call read_function in RAM. This will take more
        ; time than push + pop everytime BUT this needs to be done a single time.
        ; Use a function for this.
        call zos_fs_rawtable_get_and_store_driver_read
        ; ================== Start reading ================== ; 
        ; Read the header of the partition, to do so, read the first 34 bytes
        ; Buffer in DE, size in BC, 32-bit offset on the stack, higher bytes first
        ; +-----------+
        ; | Ret. addr |
        ; +-----------+
        ; |  0xAABB   |
        ; +-----------+
        ; |  0x1122   |  <== SP
        ; +-----------+
        ; This represents the offset 0x1122AABB
        push bc ; Save filename address
        ; Before pushing the 0 offset, push the return address
        ld hl, _rawtable_code_ret
        push hl
        ; Set offset to 0
        ld hl, 0
        push hl
        push hl
        ; The callee MUST pop the offset from the stack!
        ; Set Buffer to work buffer and a size of 34 bytes to start with
        ld de, RAM_BUFFER
        ld bc, RAWTABLE_ENTRY_SIZE + 2 ; 2 for the entries count
        jp RAM_EXE_CODE
_rawtable_code_ret:
        pop bc
        ; Check for an error from the driver
        or a
        ret nz  ; Stack is clean, we can return directly
        ; Data have been copied to RAM_BUFFER, retrieve the entries count
        ld hl, (RAM_BUFFER)
        ; If there is no file in the disk, return
        ld a, h
        or l
        jp z, _zos_fs_rawtable_open_invalid_name
        ; Save the entries counts (HL)
        push hl
        ; We have at least a file, check the first entry, make HL point to the first name
        ld hl, RAM_BUFFER + 2
        ; HL - String 1
        ; BC - String 2
        ;  E - Size
        ld e, RAWTABLE_NAME_MAX_LEN
        call _zos_fs_rawtable_fast_strncmp
        ; Pop entries count in case we need to return now
        pop de
        ; Zero flag is set if the strings are equal
        jp z, _zos_fs_rawtable_open_entry_found
        ; Set the offset to 2 (skip the entries count)
        ld hl, 0x2
_zos_fs_rawtable_open_loop:
        ; DE contains the number of entries, decrement and check if 0
        dec de
        ld a, d
        or e
        ; Not found, return
        jp z, _zos_fs_rawtable_open_invalid_name
        ; Increment the offset by RAWTABLE_ENTRY_SIZE
        ld a, RAWTABLE_ENTRY_SIZE
        ADD_HL_A()
        ; Prepare arguments:
        ; DE - Buffer to save data in
        ; BC - Size
        push de
        push hl
        push bc
        ; Load the parameters. Before putting the offset on the stack,
        ; we must push the return address. Thus, we won't be able to 
        ; use `call` later on, we will have to use jp.
        ld de, _rawtable_code_ret2
        push de
        ; Load other parameters
        ld de, RAM_BUFFER
        ld bc, RAWTABLE_ENTRY_SIZE
        ; Offset in HL
        push hl
        ; Push 0, offset is a 32-bit value
        ld hl, 0
        push hl
        jp RAM_EXE_CODE
_rawtable_code_ret2:
        pop bc  ; Pop filename
        ; Check for an error from the driver
        or a
        jp nz, _zos_fs_rawtable_open_err_2pop
        ; Entries count and offset not popped yet
        ; Compare filename with current file
        ld hl, RAM_BUFFER
        ; HL - String 1
        ; BC - String 2
        ;  E - Size
        ld e, RAWTABLE_NAME_MAX_LEN
        call _zos_fs_rawtable_fast_strncmp
        ; Pop entries count and offset, in case we have to return
        pop hl
        pop de
        jp z, _zos_fs_rawtable_open_entry_found
        jp _zos_fs_rawtable_open_loop
_zos_fs_rawtable_open_invalid_name:
        ld a, ERR_NO_SUCH_ENTRY
        ret
_zos_fs_rawtable_open_readonly:
        ld a, ERR_READ_ONLY
        ret
_zos_fs_rawtable_open_err_2pop:
        ; Clean stack and return
        pop hl
        pop hl
        ret
_zos_fs_rawtable_open_entry_found:
        ; The entry has been found!
        ; HL contains the offset of file header in the ROMDISK. All the other
        ; info are in the buffer. Allocate a file descriptor, in which we will store them.
        ; Put the file size in DEHL and the filesystem in C
        push hl
        ; Put the opened flags inside the highest nibble
        ; Rawtables only accept read-only files
        ld a, O_RDONLY << 4 | FS_RAWTABLE
        ; RAM_BUFFER contains the entry data, retreive them
        ld bc, (RAM_DRIVER_ADDR)
        ld hl, (RAM_BUFFER + RAWTABLE_SIZE_OFFSET)
        ld de, (RAM_BUFFER + RAWTABLE_SIZE_OFFSET + 2)
        call zos_disk_allocate_opnfile
        or a
        ; Clean the stack in case we have to return
        pop bc
        ret nz  ; If error, return directly
        ; HL contains the stucture address,
        ; DE points to the private data we can use at our will. We have 4 bytes. 
        ; BC contains the offset of the header, store it in our private field
        ex de, hl
        ld (hl), c
        inc hl
        ld (hl), b
        ex de, hl
        ; DE is not necessary anymore, A is 0 already, HL points to the newly allocated
        ; opened-file structure, we can safely exit!
        ret


        ; Get the stats of a file from a disk that has a RAWTABLE filesystem
        ; This includes the date, the size and the name. More info about the stat structure
        ; in `vfs_h.asm` file.
        ; Parameters:
        ;       BC - Driver address, guaranteed not NULL by the caller.
        ;       HL - Opened file structure address, pointing to the user field.
        ;       DE - Address of the date structure to fill, followed by the name:
        ;            { uint8_t date[8]; char name[16]; }
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       A, BC, DE, HL (Can alter any of the fields)
        PUBLIC zos_fs_rawtable_stat
zos_fs_rawtable_stat:
        ; We will only need the read function out of the driver, so get it,
        ; then we will be able to re-use two registers freely.
        ; The driver address must be in DE, the result will be in HL, save them
        push de
        push hl
        ld d, b
        ld e, c
        ; Just like the open function, we have to create a jump instruction
        ; to that function, check the routine above for more details.
        call zos_fs_rawtable_get_and_store_driver_read
        ; Driver's read function is set up, we can read the file header out of the
        ; ROMDISK. We saved the offset of that header in the opened file private/user field
        ; So we need to read that field to ge tthe offset.
        pop hl
        ld e, (hl)
        inc hl
        ld d, (hl)
        ; DE is our offset, we need to push it on the stack, as a 32-bit value.
        ; However, just liek `open` function, we have to put the return address
        ; first, because the driver will pop the size directly from the stack.
        ld hl, _zos_fs_rawtable_stat_return
        push hl
        push de
        ; Push upper 16-bit, which are 0
        ld hl, 0
        push hl
        ; Prepare the arguments for open:
        ld de, RAM_BUFFER
        ld bc, RAWTABLE_ENTRY_SIZE
        jp RAM_EXE_CODE
_zos_fs_rawtable_stat_return:
        ; Pop the structure field to fill out of the stack
        pop de
        ; The stack is clean now, check the return value, should be 0 (ERR_SUCCESS)
        or a
        ret nz
        ; Success, the RAM_BUFFER contains our data, we can copy them inside
        ; the stat structure (DE) which already points to date field (8 bytes)
        ; The structure of ROMDISK date and struct date is the same, we can
        ; thus use a raw copy!
        ld hl, RAM_BUFFER + rawtable_date_t
        ld bc, file_name_t - file_date_t
        ldir
        ; DE points to the name field, make HL points to it too
        ld hl, RAM_BUFFER + rawtable_name_t
        ld bc, file_end_t - file_name_t
        ldir
        ; Success, we can exit safely
        xor a   ; Optimizaiton for ERR_SUCCESS
        ret

        ; Read bytes of an opened file, which is located on a disk that is
        ; using the rawtable filesystem.
        ; At most BC bytes must be read in the buffer pointed by DE.
        ; Upon completion, the actual number of bytes filled in DE must be
        ; returned in BC register. It must be less or equal to the initial
        ; value of BC. 
        ; Note: _vfs_work_buffer can be used at our will here
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
        PUBLIC zos_fs_rawtable_read
zos_fs_rawtable_read:
        ; We first need to retrieve the driver's address and then the read address
        push de
        push bc
        ; Let's optimize the access to the opened file structure, ideally, we need
        ; an abstraction, but for performance reason, we will directly access the fields.
        ; FIXME: Use a (good) abstraction to access the fields?
        inc hl
        inc hl
        ; Dereference HL into DE to get the driver address
        ld e, (hl)
        inc hl
        ld d, (hl)
        inc hl
        ; Get the read function out of the driver pointed by DE, the resulted 
        ; function address will be in HL. Save it beforehand.
        push hl
        call zos_fs_rawtable_get_and_store_driver_read
        ; Make HL point to the offset in the file
        ; FIXME: Use an abstraction?
        pop hl
        inc hl
        inc hl
        inc hl
        inc hl
        ; What we have to do now is to add the offset of the file in the disk
        ; with the offset in the file, both are 32 bits.
        ; For example, if the opened file is at offset 0x100 in the romdisk,
        ; and we have to read the offset 0x50 of the file, then we have to read
        ; offset 0x150 out of the rom disk.
        ; Retrieve the user field out of the opened file structure
        ; FIXME: Use an abstraction?
        push hl
        inc hl
        inc hl
        inc hl
        inc hl
        ld e, (hl)
        inc hl
        ld d, (hl)
        ; DE contains the offset of the file's header in the romdisk...
        ; So we have to perform a read to retrieve the info that interests us:
        ; the offset of the file in the disk
        ld a, rawtable_offset_t - rawtable_name_t
        ADD_DE_A()
        ; DE points to the file header's offset field, which is 32-bit long
        ld bc, 4
        ; For the save reasons as explained above, we need to manually push
        ; the return address
        ld hl, _zos_fs_rawtable_read_header_ret
        push hl
        ; Push the offset
        push de
        ; B is zero, use it to make HL be 0
        ld h, b
        ld l, b
        push hl
        ; Almost ready, set the temporary destination buffer
        ld de, RAM_BUFFER
        jp RAM_EXE_CODE
_zos_fs_rawtable_read_header_ret:
        or a
        jp nz, _zos_fs_rawtable_read_header_err
        ; RAM_BUFFER contains the offset of the file in the romdisk!
        ; Pop out the address of the offset we need to read
        pop hl
        ld de, RAM_BUFFER
        ; Perform the 32-bit addition
        ld a, (de)
        add (hl)
        ld (de), a
        inc hl
        inc de
        REPT 2  ; For the 2 other bytes, optimize the last one by omitting inc
        ld a, (de)
        adc (hl)
        ld (de), a
        inc hl
        inc de
        ENDR
        ld a, (de)
        adc (hl)
        ld (de), a
        ; We don't need HL value anymore, we can reuse it.
        ; Prepare the parameters for the final call to read
        pop bc
        pop de
        ; We don't need to push the return address, because we
        ; don't have to check anything upon return, so this will
        ; be a tail-call
        ld hl, (RAM_BUFFER)
        push hl
        ld hl, (RAM_BUFFER + 2)
        push hl
        jp RAM_EXE_CODE
        ; No return.
_zos_fs_rawtable_read_header_err:
        ; Error encountered while reading the file header
        pop hl
        pop bc
        pop de
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
        PUBLIC zos_fs_rawtable_write
zos_fs_rawtable_write:
        ; Rawtable is a read-only filesystem
        ld a, ERR_NOT_IMPLEMENTED
        ret

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
        PUBLIC zos_fs_rawtable_close
zos_fs_rawtable_close:
        ; Nothing special for rawtable FS, closing a file won't require any
        ; flush or any particular behavior. Calling the driver's close
        ; function will be enough.
        ; Retrieve driver (DE) close function address, in HL.
        GET_DRIVER_CLOSE()
        jp (hl)


        ; ====================== Directories related ====================== ;

        ; Open a directory from a disk that has a RAWTABLE filesystem.
        ; Note: Currently, RAWTABLE only supports a single directory,
        ;       the root one: '/'.
        ; Parameters:
        ;       HL - Absolute path, without the disk letter (without X:/), guaranteed not NULL by caller.
        ;       DE - Driver address, guaranteed not NULL by the caller.
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ;       HL - Opened-dir structure address, passed through all the other calls, until closed
        ; Alters:
        ;       A, BC, DE, HL
        PUBLIC zos_fs_rawtable_opendir
zos_fs_rawtable_opendir:
        ; Check that the path is either \0
        ld a, (hl)
        or a
        jp z, _zos_fs_rawtable_path_valid
        ; Either / followed by \0 
        sub '/'
        inc hl
        or (hl)
        jp nz, _zos_fs_rawtable_open_invalid_name
_zos_fs_rawtable_path_valid:
        ; Path is correct, request an empty opened-dir structure
        ; Parameters:
        ;       A  - Filesystem number
        ;       BC - Driver address
        ld a, FS_RAWTABLE
        ld b, d
        ld c, e
        push de ; Driver address on the stack
        call zos_disk_allocate_opndir
        ; Put the user field address in BC, to re-use DE. HL will need to be
        ; returned as it contains the opendir entry address.
        ld b, d
        ld c, e
        ; Pop the stack value now, as we are going to return if an error
        ; occured
        pop de
        or a
        ret nz
        ; Get driver's read function, it'll be store in the temporary buffer
        ; but let's store it in our user field too
        push hl
        call zos_fs_rawtable_get_and_store_driver_read
        ; Driver's read in HL, save it to the user field (BC)
        ; So the fields that are opened to us are 12 bytes long, let's
        ; organize them as:
        ;       read_function - 2 bytes
        ;       entries_count - 2 bytes
        ;       current_entry - 2 bytes
        ld d, b
        ld e, c
        ex de, hl
        ld (hl), e
        inc hl
        ld (hl), d
        inc hl
        ; Read function address has been saved in our structure
        ; HL points to the rest of the user field, we are going to place
        ; the number of entries of the directory (filesystem)
        ; So we need to perform a read of 2 bytes.
        ; Driver's read parameters:
        ;       [SP] - 32-bit offset
        ;       DE - Destination buffer (currently HL in our flow)
        ;       BC - Size to read
        ex de, hl
        ld hl, _zos_fs_rawtable_opendir_ret
        push hl
        ; Offset of 0
        ld hl, 0
        push hl
        push hl
        ; BC = sizeof(rawtable_count_t) 
        ld bc, 2
        jp RAM_EXE_CODE
_zos_fs_rawtable_opendir_ret:
        ; No matter the return value, pop hl and return now
        pop hl
        ret


        ; Read the next entry from the opened directory and store it in the user's buffer.
        ; The given buffer is guarenteed to be big enough to store DISKS_DIR_ENTRY_SIZE bytes.
        ; Note: _vfs_work_buffer can be used at our will here
        ; Parameters:
        ;       HL - Address of the user field in the opened directory structure. This is the same address
        ;            as the one given when opendir was called.
        ;       DE - Buffer to fill with the next entry data. Guaranteed to not be cross page boundaries.
        ;            Garenteed to be at least DISKS_DIR_ENTRY_SIZE bytes.
        ; Returns:
        ;       A - ERR_SUCCESS on success,
        ;           ERR_NO_MORE_ENTRIES if the end of directory has been reached,
        ;           error code else
        ; Alters:
        ;       A, BC, DE, HL (can alter any)
        PUBLIC zos_fs_rawtable_readdir
zos_fs_rawtable_readdir:
        ; Get the driver's read function in the opened dir struct, adn set it in the exec buffer
        ld a, JP_INSTR_OPCODE
        ld (RAM_EXE_CODE), a
        ld a, (hl)
        ld (RAM_EXE_CODE + 1), a
        inc hl
        ld a, (hl)
        ld (RAM_EXE_CODE + 2), a
        inc hl
        ; Continue by getting the entries count
        push de
        ld e, (hl)
        inc hl
        ld d, (hl)
        inc hl
        ; Same for the current entries
        ld c, (hl)
        inc hl
        ld b, (hl)
        dec hl  ; Keep pointing at the current_entry address
        ; Check if we still have entries to browse
        xor a
        ex de, hl
        sbc hl, bc
        jp z, _zos_fs_rawtable_no_more_entries
        ; Put the current_entry field address in HL as DE will pop the buffer address from the stack
        ex de, hl
        ; DE shall contain the destination buffer, which is on the stack,
        pop de
        ; Set the flag to DISKS_DIR_ENTRY_IS_FILE as we don't have dirs in rawtables
        ld a, DISKS_DIR_ENTRY_IS_FILE
        ld (de), a
        inc de  ; Point to the name
        push hl ; Push the current entry index field address
        ; Entry count is in BC, to calculate the index to read from the driver, we have to calculate
        ; BC * RAWTABLE_ENTRY_SIZE + 2 (because there is the entry count at the beginning)
        push bc
        ; Save the return address of read function beforehand
        ld hl, _zos_fs_rawtable_readdir_ret
        push hl
        ; Calculate the offset
        ld h, b
        ld l, c
        ASSERT(RAWTABLE_ENTRY_SIZE == 32)
        add hl, hl      ; x2
        add hl, hl      ; x4
        add hl, hl      ; x8
        add hl, hl      ; x16
        add hl, hl      ; x32
        inc hl
        inc hl
        push hl
        ld hl, 0        ; 32-bit offset
        push hl
        ; Let's directly read the filename
        ; Subtract 1 as we already wrote a byte above (is_dir flag) 
        ld bc, DISKS_DIR_ENTRY_SIZE - 1
        jp RAM_EXE_CODE
_zos_fs_rawtable_readdir_ret:
        pop bc
        pop hl
        ; If there was an error, we can return immediately
        or a
        ret nz
        ; It was a success, update the current_entry in the structure
        inc bc  ; Cannot overflow, we know it's not equal to entry_count for sure
        ld (hl), c
        inc hl
        ld (hl), b
        ret
_zos_fs_rawtable_no_more_entries:
        pop de
        ld a, ERR_NO_MORE_ENTRIES
        ret


        ;======================================================================;
        ;================= P R I V A T E   R O U T I N E S ====================;
        ;======================================================================;

        ; Routine to get the read function out of a driver and store it in
        ; the RAM_EXE_CODE memory.
        ; Parameters:
        ;       DE - Driver address
        ; Returns:
        ;       HL - Address of read function
        ; Alters:
        ;       A, DE, HL
zos_fs_rawtable_get_and_store_driver_read:
        ; Retrieve driver (DE) read function address, in HL.
        GET_DRIVER_READ()
        ld a, JP_INSTR_OPCODE
        ld (RAM_EXE_CODE), a
        ld (RAM_EXE_CODE + 1), hl
        ret

        ; Compare strings in HL and BC, at most E bytes will be read.
        ; Alters:
        ;       A, HL, DE
_zos_fs_rawtable_fast_strncmp:
        push bc
        dec hl
        dec bc
        inc e
_fast_strncmp_compare:
        inc hl
        inc bc
        dec e
        jr z, _fast_strncmp_end
        ld a, (bc)
        sub (hl)
        jr nz, _fast_strncmp_end
        ; Check if both strings have reached the end
        ; If this is the case, or (hl) will reset in zero flag to be set
        ; In that case, no need to continue, we can return, with flag Z set
        or (hl) 
        jr nz, _fast_strncmp_compare
_fast_strncmp_end:
        pop bc
        ret