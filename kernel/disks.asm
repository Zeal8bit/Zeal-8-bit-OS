        INCLUDE "osconfig.asm"
        INCLUDE "errors_h.asm"
        INCLUDE "disks_h.asm"
        INCLUDE "utils_h.asm"
        INCLUDE "vfs_h.asm"

        ; Requred external routines
        EXTERN to_upper
        EXTERN zos_fs_rawtable_open
        EXTERN zos_fs_rawtable_stat
        EXTERN zos_fs_rawtable_read

        SECTION KERNEL_TEXT

        PUBLIC zos_disks_init
zos_disks_init:
        ; Set the default disk to A
        ld a, DISK_DEFAULT_LETTER
        ld (_disks_default), a
        ; Empty opened files
        ld a, DISKS_OPN_FILE_MAGIC_FREE
        ld b, CONFIG_KERNEL_MAX_OPENED_FILES
        ld de, DISKS_OPN_FILE_STRUCT_SIZE
        ld hl, _disk_file_slot
_zos_disks_init_opened_files:
        ld (hl), a      ; Mark the first field to EMPTY
        add hl, de      ; Go to the next structure
        djnz _zos_disks_init_opened_files
        ret

        ; Mount a disk (driver) to the given letter
        ; Parameters:
        ;       A  - Letter to mount the disk on
        ;       E  - File system (taken from vfs_h.asm)
        ;       HL - Pointer to the driver structure
        ; Returns:
        ;       A - ERR_SUCCESS on success
        ;           ERR_ALREADY_MOUNTED if the letter has already on disk mounted on
        ;           ERR_INVALID_PARAMETER if the pointer or the letter passed is wrong
        ; Alters:
        ;       A, DE
        PUBLIC zos_disks_mount
zos_disks_mount:
        push bc
        ld b, a
        ld c, e
        ; Let's say that the pointer is invalid if the upper byte is 0
        ld a, h
        or a
        jp z, _zos_disks_mount_invalid_param
        ; Check the letter now
        ld a, b
        call to_upper
        jp c, _zos_disks_mount_invalid_param
        ; Convert A to the _disk array index
        sub 'A'
        ld b, a
        add a
        ; Calculate the offset
        ex de, hl
        ld hl, _disks
        ADD_HL_A()
        inc hl
        ; Check upper byte for an already-registered driver
        ld a, (hl)
        or a
        jp nz, _zos_disks_mount_already_mounted
        ; Cell is empty, fill it with the new drive
        ld (hl), d
        dec hl
        ld (hl), e
        ; Also fill the filesystem
        ld a, b
        ld hl, _disks_fs
        ADD_HL_A()
        ld (hl), c
        pop bc
        xor a   ; Optimization for ERR_SUCCESS
        ex de, hl
        ret
_zos_disks_mount_already_mounted:
        pop bc
        ex de, hl
        ld a, ERR_ALREADY_MOUNTED
        ret
_zos_disks_mount_invalid_param:
        pop bc
        ld a, ERR_INVALID_PARAMETER
        ret

        ; Unmount the disk of the given letter. It is not possible to unmount the
        ; default disk. It shall must be changed.
        ; Parameters:
        ;       A  - Letter to mount the disk on
        ; Returns:
        ;       A - ERR_SUCCESS on success
        ;           ERR_INVALID_PARAMETER if the letter passed is wrong or
        ;           points to an invalid disk
        ;           ERR_ALREADY_MOUNTED is the disk to unmount is the default one
        ; Alters:
        ;       A, HL
        PUBLIC zos_disks_unmount
zos_disks_unmount:
        ; TODO: empty the VFS for any opened file on the drive to unmount!
        ld hl, _disks_default
        cp (hl)
        jp z, _zos_disks_mount_already_mounted
        ; Check if the letter is correct now
        call to_upper
        jp c, _zos_disks_invalid_param
        ; Calculate the index out of A letter
        sub 'A'
        add a
        ; Unmount the drive
        ld hl, _disks
        ADD_HL_A()
        xor a
        ld (hl), a
        inc hl
        ld (hl), a
        ; Optimization of ERR_SUCCESS, A is already 0 
        ret

        PUBLIC zos_disks_get_default
zos_disks_get_default:
        ld a, (_disks_default)
        ret

        ; Set the default disk to the one passed as a parameter
        ; Parameters:
        ;       A - Letter of the new default disk
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       A
        PUBLIC zos_disks_set_default
zos_disks_set_default:
        ; to_upper will convert the letter in A to its upper counterpart
        ; if the char is not a lower case one, then carry flag will be set
        ; (it won't be modified)
        call to_upper
        jp c, _zos_disks_invalid_param
        ld (_disks_default), a
        xor a           ; Optimization for ERR_SUCCESS
        ret
_zos_disks_invalid_param:
        ld a, ERR_INVALID_PARAMETER
        ret

        ; Returns the driver of the disk letter passed in A.
        ; Prameters:
        ;       A - Letter of the disk to get the driver of
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ;       C - Filesystem number
        ;       DE - Driver structure address
        ; Alters:
        ;       A, C, DE, HL
zos_disks_get_driver_and_fs:
        call to_upper
        jp c, _zos_disks_invalid_param
        ; A is a correct upper letter for sure now
        sub 'A'
        ; A *= 2 because _disks entry are 16-bit long
        add a
        ld c, a
        ld hl, _disks
        ADD_HL_A()
        ld e, (hl)
        inc hl
        ld d, (hl)
        ex de, hl
        ; HL contains the content of _disks[A], check if it's NULL
        ld a, h
        or l
        jp z, _zos_disks_invalid_param
        ; Get the filesystem number thanks to E
        ld a, c
        ex de, hl       ; Store the driver address in DE
        ld hl, _disks_fs
        ADD_HL_A()
        ; Put the FS number in C and exit with success
        ld c, (hl)
        xor a           ; Optimization for ERR_SUCCESS
        ret

        ; Open a file on a disk with the given flags
        ; Parameters:
        ;       B - Flags, can be O_RDWR, O_RDONLY, O_WRONLY, O_NONBLOCK, O_CREAT, O_APPEND, etc...
        ;       C - Disk letter (lower/upper are both accepted)
        ;       HL - Absolute path to the file (without X:/)
        ; Returns:
        ;       HL - Newly opened descriptor
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       A, BC, DE, HL
        PUBLIC zos_disk_open_file
zos_disk_open_file:
        push hl
        ; Get the driver of the given disk letter
        ld a, c
        call zos_disks_get_driver_and_fs
        ; Pop won't modify the flags
        pop hl
        ; DE contains the potential driver, A must be a success here
        or a
        ret nz
        ; Put the absolute path back in HL
        ; Put the filesystem number in A
        ld a, c
        ; We have a very few filesystems, no need for a lookup table AT THE MOMENT
        cp FS_RAWTABLE
        jp z, zos_fs_rawtable_open
        cp FS_ZEALFS
        jp z, zos_fs_zealfs_open
        cp FS_FAT16
        jp z, zos_fs_fat16_open
        ; The filesystem has not been found, memory corruption?
        ld a, ERR_INVALID_FILESYSTEM
        ret
        ; TODO: Remove the stubs
        ; STUBS FOR COMPILING
zos_fs_zealfs_open:
zos_fs_fat16_open:
zos_fs_zealfs_stat:
zos_fs_fat16_stat:
zos_fs_zealfs_read:
zos_fs_fat16_read:
        ld a, ERR_NOT_IMPLEMENTED
        ret

        ; Get the stats of a given opened file. The structure passed in DE will be
        ; filled in accordingly. The definition of that structure must follow
        ; its description, which is in `vfs_h.asm`.
        ; Parameters:
        ;       HL - Opened file address. MUST be valid (caller-checked).
        ;       DE - Address of the structure to fill
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       A, BC, DE, HL
        PUBLIC zos_disk_stat
zos_disk_stat:
        ; Load the filesystem from the opened file address
        inc hl
        ld a, (hl)
        ; Retrieve the driver address from the structure and save it
        inc hl
        ld c, (hl)
        inc hl
        ld b, (hl)
        inc hl
        push bc
        ; Retrieve the size and save it inside the structure.
        ; DE already points to the structure's size field
        ; HL also points to size field 
        ld bc, file_date_t - file_size_t
        ldir
        ; Make HL point to the user field now
        REPT opn_file_usr_t - opn_file_off_t
        inc hl
        ENDR
        ; Pop the driver address from the stack
        pop bc
        ; We have a very few filesystems, no need for a lookup table AT THE MOMENT
        cp FS_RAWTABLE
        jp z, zos_fs_rawtable_stat
        cp FS_ZEALFS
        jp z, zos_fs_zealfs_stat
        cp FS_FAT16
        jp z, zos_fs_fat16_stat
        ; The filesystem has not been found, memory corruption?
        ld a, ERR_INVALID_FILESYSTEM
        ret

        ; Read bytes from an opened file.
        ; Parameters:
        ;       HL - Address of the opened file. Guaranteed by the caller to be a
        ;            non-free opened file (check zos_disk_is_opnfile)
        ;       DE - Buffer to store the bytes read from the dev, the buffer must NOT cross page boundary
        ;       BC - Size of the buffer passed, maximum size is a page size
        ;
        ; Returns:
        ;       A  - 0 on success, error value else
        ;       BC - Number of bytes remaning to read. 0 means the buffer has been filled.
        ; Alters:
        ;       A, BC, DE, HL
        EXTERN zos_disk_read
zos_disk_read:
        ; Load the filesystem from the opened file address
        inc hl
        ld a, (hl)
        ; We have to check if the file has been opened in READ mode (at least)
        ; As the flags are in the upper nibble, we have to add 4 to the bit
        bit O_WRONLY_BIT + 4, a
        ; If z flag is set, then the file is not write only, we can read it
        jr nz, _zos_disk_read_not_readable
        ; Only keep the filesystem number now
        DISKS_OPN_FILE_GET_FS()
        push hl
        push af
        ; Save the paramters to pass to the filesystem
        push de
        push bc
        ; We have to check if the size given will reach the end of the file or not
        ; For example, if the file size is 1000 bytes, the offset is 50 bytes,
        ; and the size to read (BC) is 1500 bytes, we have to adjust BC to 950 bytes.
        ; Make HL point to the size
        ld a, opn_file_size_t - 1 ; HL has already been incremented
        ADD_HL_A()
        ; We have to perform the 32-bit operation: size-offset, while saving the result
        ; in BC. 16-bit are enough for the simple reason that if the result is bigger than
        ; 0xFFFF, then BC is the minimum, so we don't need to adjust it.
        ld d, h
        ld e, l
        ; Make HL point to the offset
        REPT opn_file_off_t - opn_file_size_t
        inc hl
        ENDR
        ; Start the subtraction. HL points to the offset, DE points to the size
        ld a, (de)
        sub (hl)
        ld c, a
        inc de
        inc hl
        ; -- Second byte --
        ld a, (de)
        sbc (hl)        ; inc 16-bit doesn't update the flags (carry)
        ld b, a
        inc de
        inc hl
        ; -- Third byte --
        ld a, (de)
        sbc (hl)
        jp nz, _zos_disk_read_add_min_is_bc
        inc de
        inc hl
        ; -- Fourth byte --
        ld a, (de)
        sbc (hl)
        jp nz, _zos_disk_read_add_min_is_bc
        ; If we reach here, BC contains the difference between size and offset
        ; Compare it to the size given by the user 
        ld h, b
        ld l, c
        pop bc
        xor a   ; clear flags
        sbc hl, bc
        ; If we have no carry, it means that HL >= BC, so BC is the minimum
        jr nc, _zos_disk_read_add_min_is_bc
        ; If we have a carry, HL was smaller than BC, set BC to HL former value
        add hl, bc
        ld b, h
        ld c, l
        jr _zos_disk_read_add_min_is_bc
_zos_disk_read_add_min_is_bc_pop:
        pop bc  
_zos_disk_read_add_min_is_bc:
        pop de
        pop af
        pop hl
        cp FS_RAWTABLE
        jp z, zos_fs_rawtable_read
        cp FS_ZEALFS
        jp z, zos_fs_zealfs_read
        cp FS_FAT16
        jp z, zos_fs_fat16_read
        ; The filesystem has not been found, memory corruption?
        ld a, ERR_INVALID_FILESYSTEM
        ret
_zos_disk_read_not_readable:
        ld a, ERR_BAD_MODE
        ret

        ; Function returning the address of an empty opened-file structure
        ; This will be used by the filesystems `open` routines.
        ; The first field will be marked as `USED` in this routine.
        ; Parameters:
        ;       A    - Filesystem number and opened flags (O_RDONLY, etc...)
        ;       BC   - Driver address
        ;       DEHL - 32-bit file size
        ; Returns:
        ;       A - ERR_SUCCESS if success, error code else
        ;       HL - Address of an empty opened filed structure
        ;       DE - Address of the user field in that same structure
        ; Alters:
        ;       A, BC, DE, HL
        PUBLIC zos_disk_allocate_opnfile
zos_disk_allocate_opnfile:
        push de
        ; Put the size's lowest bytes on the top of the higher bytes
        push hl
        ; Save the driver address
        push bc
        push af ; Save the filesystem
        ld a, DISKS_OPN_FILE_MAGIC_FREE
        ld b, CONFIG_KERNEL_MAX_OPENED_FILES
        ld de, DISKS_OPN_FILE_STRUCT_SIZE
        ld hl, _disk_file_slot
_zos_disks_allocate_loop:
        cp (hl)         ; Compare A with structure's first field
        jr z, _zos_disks_allocate_found
        add hl, de      ; Go to the next structure
        djnz _zos_disks_allocate_loop
        ; Could not find any emptry entry, send an error
        pop af
        pop bc
        pop hl
        pop de
        ld a, ERR_CANNOT_REGISTER_MORE
        ld hl, 0
        ret
_zos_disks_allocate_found:
        ; a free structure has been found, mark it as allocated now
        ld (hl), DISKS_OPN_FILE_MAGIC_USED
        ; we need to retrieve the 32-bit size from the stack in registers
        ; because we need to save HL address on the top of the stack
        ; Restore the file system and the driver address
        pop af
        pop bc
        ; 32-bit size is still on the top of the stack
        ; Let's save the filesystem (A) and the driver address (BC) first then
        ; Save HL (original address) in DE
        ld d, h
        ld e, l
        inc hl
        ; Save file system number
        ld (hl), a
        inc hl
        ; Save driver address
        ld (hl), c
        inc hl
        ld (hl), b
        inc hl
        ; HL is pointing to the size, pop it from the stack and save it
        pop bc
        ld (hl), c
        inc hl
        ld (hl), b
        inc hl
        pop bc
        ld (hl), c
        inc hl
        ld (hl), b     
        inc hl
        ; Save the original address
        push de
        ; Pointing to the offset, we need to clear it
        xor a
        ld (hl), a
        ld d, h
        ld e, l
        inc de
        ld bc, opn_file_end_t - opn_file_off_t - 1
        ldir
        ; Decrement DE until we reach the address of user field
        REPT opn_file_end_t - opn_file_usr_t
        dec de
        ENDR
        ; Finished copying, we can pop the original addresses and return them
        pop hl
        xor a           ; Optimization for ERR_SUCCESS
        ret


        ; Function checking if the opened dev address passed is an opened file (or a driver).
        ; To do so, the first byte will be dereferenced and compared to the "magic" value.
        ; Parameters:
        ;       HL - Address of the opened "dev". Must not be NULL.
        ; Returns:
        ;       A - ERR_SUCCESS if it's actually a file, error code else
        ; Alters:
        ;       A
        PUBLIC zos_disk_is_opnfile
zos_disk_is_opnfile:
        ld a, (hl)
        ; A now contains the first byte pointed by the opened "dev".
        ; If this value is DISKS_OPN_FILE_MAGIC_USED, then we're good!
        ; If it's something else, even DISKS_OPN_FILE_MAGIC_FREE, it's not good
        sub DISKS_OPN_FILE_MAGIC_USED
        ; If zero, return directly, small optimization for ERR_SUCCESS
        ret z
        ; Error, not an opened file
        ld a, ERR_INVALID_FILEDEV
        ret

        SECTION KERNEL_BSS
        ; Letter of the default disk 
_disks_default: DEFS 1
_disks: DEFS DISKS_MAX_COUNT * 2
_disks_fs: DEFS DISKS_MAX_COUNT
        ; Structure containing the opened file structure.
        ; Check disk_h.asm file for more info about this
        ; structure.
_disk_file_slot: DEFS CONFIG_KERNEL_MAX_OPENED_FILES * DISKS_OPN_FILE_STRUCT_SIZE