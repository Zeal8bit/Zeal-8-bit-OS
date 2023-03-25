; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "osconfig.asm"
        INCLUDE "errors_h.asm"
        INCLUDE "disks_h.asm"
        INCLUDE "utils_h.asm"
        INCLUDE "vfs_h.asm"
        INCLUDE "strutils_h.asm"
        INCLUDE "fs/rawtable_h.asm"
        INCLUDE "fs/zealfs_h.asm"

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
        ;       HL - Pointer to the driver structure. Guaranteed valid by the caller.
        ; Returns:
        ;       A - ERR_SUCCESS on success
        ;           ERR_ALREADY_MOUNTED if the letter has already on disk mounted on
        ;           ERR_INVALID_PARAMETER if the pointer or the letter passed is wrong
        ; Alters:
        ;       A
        PUBLIC zos_disks_mount
zos_disks_mount:
        push bc
        push de
        ld b, a
        ld c, e
        ; Check the letter now
        ld a, b
        call to_upper
        jr c, _zos_disks_mount_invalid_param
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
        jr nz, _zos_disks_mount_already_mounted
        ; Cell is empty, fill it with the new drive
        ld (hl), d
        dec hl
        ld (hl), e
        ; Also fill the filesystem
        ld a, b
        ld hl, _disks_fs
        ADD_HL_A()
        ld (hl), c
        xor a   ; Optimization for ERR_SUCCESS
_zos_disks_mount_ex_pop_ret:
        ex de, hl
_zos_disks_mount_pop_ret:
        pop de
        pop bc
        ret
_zos_disks_mount_invalid_param:
        ld a, ERR_INVALID_PARAMETER
        jr _zos_disks_mount_pop_ret
_zos_disks_mount_already_mounted:
        ld a, ERR_ALREADY_MOUNTED
        jr _zos_disks_mount_ex_pop_ret

        ; Unmount the disk of the given letter. It is not possible to unmount the
        ; default disk. It shall must be changed.
        ; Parameters:
        ;       A  - Letter of the disk to unmount
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
        jp z, _zos_disks_invalid_param
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
_zos_disks_invalid_param_pop_hl:
        pop hl
_zos_disks_invalid_param:
        ld a, ERR_INVALID_PARAMETER
        ret

        ; Returns the driver of the disk letter passed in A.
        ; Parameters:
        ;       A - Letter of the disk to get the driver of
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ;       C - Filesystem number
        ;       DE - Driver structure address
        ; Alters:
        ;       A, C, DE
        PUBLIC zos_disks_get_driver_and_fs
zos_disks_get_driver_and_fs:
        call to_upper
        jr c, _zos_disks_invalid_param
        push hl
        ; A is a correct upper letter for sure now
        sub 'A'
        ; Save the index of the disk, before multiplying it by 2
        ld c, a
        ; A *= 2 because _disks entry are 16-bit long
        add a
        ld hl, _disks
        ADD_HL_A()
        ld e, (hl)
        inc hl
        ld d, (hl)
        ; DE contains the content of _disks[A], check if it's NULL
        ld a, e
        or d
        jr z, _zos_disks_invalid_param_pop_hl
        ; Get the filesystem number thanks to E
        ld a, c
        ld hl, _disks_fs
        ADD_HL_A()
        ; Put the FS number in C and exit with success
        ld c, (hl)
        xor a           ; Optimization for ERR_SUCCESS
        pop hl
        ret

        ; Open a file on a disk with the given flags
        ; Parameters:
        ;       B - Flags, can be O_RDWR, O_RDONLY, O_WRONLY, O_NONBLOCK, O_CREAT, O_APPEND, etc...
        ;       C - Disk letter (lower/upper are both accepted)
        ;       HL - Absolute path to the file (without X:)
        ; Returns:
        ;       HL - Newly opened descriptor
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       A, BC, DE, HL
        PUBLIC zos_disk_open_file
zos_disk_open_file:
        ; Get the driver of the given disk letter
        ld a, c
        call zos_disks_get_driver_and_fs
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
        ; We have a very few file systems, no need for a lookup table AT THE MOMENT
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
        ;       HL - Address of the opened file/directory
        ;       DE - Buffer to store the bytes read from the dev, the buffer must NOT cross page boundary
        ;       BC - Size of the buffer passed, maximum size is a page size
        ; Returns:
        ;       A  - 0 on success, error value else
        ;       BC - Number of bytes filled in DE.
        ; Alters:
        ;       A, BC, DE, HL
        EXTERN zos_disk_read
zos_disk_read:
        ; Check that we are not reading a directory
        call zos_disk_is_opnfile
        ret nz
        ; Load the filesystem from the opened file address
        inc hl
        ld a, (hl)
        dec hl
        ; We have to check if the file has been opened in READ mode (at least)
        ; As the flags are in the upper nibble, we have to add 4 to the bit
        bit O_WRONLY_BIT + 4, a
        ; If z flag is set, then the file is not write only, we can read it
        jr nz, _zos_disk_bad_mode
        ; Only keep the filesystem number now
        DISKS_OPN_FILE_GET_FS()
        push hl
        push af
        ; Save the parameters to pass to the filesystem
        push de
        push bc
        ; We have to check if the size given will reach the end of the file or not
        ; For example, if the file size is 1000 bytes, the offset is 50 bytes,
        ; and the size to read (BC) is 1500 bytes, we have to adjust BC to 950 bytes.
        ; Make HL point to the size
        ld a, opn_file_size_t
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
        jr nc, _zos_disk_read_add_min_is_bc_no_pop
        ; If we have a carry, HL was smaller than BC, set BC to HL former value
        add hl, bc
        ld b, h
        ld c, l
        jr _zos_disk_read_add_min_is_bc_no_pop
_zos_disk_read_add_min_is_bc:
        pop bc
_zos_disk_read_add_min_is_bc_no_pop:
        pop de
        ; Before using A, test if BC is 0, if that's the case we can return successfully
        ; right now without calling any underlying fs, nor updating the file offset.
        ld a, b
        or c
        jr z, _zos_disk_read_early_success
        pop af
        pop hl
        push hl ; Save HL on the stack again
        ; TODO: Optimize with a table?
        cp FS_RAWTABLE
        jr z, _zos_disk_read_rawtable
        cp FS_ZEALFS
        jp z, _zos_disk_read_zealfs
        cp FS_FAT16
        jp z, _zos_disk_read_fat16
        ; The filesystem has not been found, memory corruption?
        pop hl
        ld a, ERR_INVALID_FILESYSTEM
        ret
_zos_disk_read_zealfs:
        call zos_fs_zealfs_read
        jp _zos_disk_read_epilogue
_zos_disk_read_fat16:
        call zos_fs_fat16_read
        jp _zos_disk_read_epilogue
_zos_disk_read_rawtable:
        call zos_fs_rawtable_read
_zos_disk_read_epilogue:
        ; Get the original HL, the one pointing to the opened file
        pop hl
        ; Check the return value
        or a
        ; If there was an error, return directly
        ret nz
        ; Else, we have to update the offset field in the opened file.
        ; The fastest way is to use de and then add hl, de
        ; Using ADD_HL_A() takes more clock cycles, pushing/popping
        ; HL when it was already calculated takes the same amount of
        ; clock cycles.
        ld de, opn_file_off_t
        add hl, de
        ; Now add BC to the offset in the file. BC must not be altered because
        ; we need to return it. It can be a tail-call as our stack is clean,
        ; we have nothing more to do.
        jp zos_disk_add_offset_bc
_zos_disk_read_early_success:
        ; Clean the stack, we can pop the values in any register
        pop hl
        pop hl
        ; A is already 0
        ret
_zos_disk_bad_mode:
        ld a, ERR_BAD_MODE
        ret


        ; Write bytes to an opened file.
        ; Parameters:
        ;       HL - Address of the opened file/directory
        ;       DE - Buffer containing the bytes to write to the dev. The buffer is guaranteed
        ;            to not cross page boundary.
        ;       BC - Size of the buffer passed, maximum size is a page size.
        ; Returns:
        ;       A  - 0 on success, error value else
        ;       BC - Number of bytes written from DE.
        ; Alters:
        ;       A, BC, DE, HL
        DEFC O_WRITE_MASK = (O_WRONLY | O_RDWR)
        PUBLIC zos_disk_write
zos_disk_write:
        ; Check that we are not reading a directory
        call zos_disk_is_opnfile
        ret nz
        ; Load the filesystem from the opened file address
        inc hl
        ld a, (hl)
        ; We have to check if the file has been opened in WRITE mode (at least)
        ; As the flags are in the upper nibble, we have to shift the value 4 times to the left
        and O_WRITE_MASK << 4
        jr z, _zos_disk_bad_mode
        ; Write flag was provided, this is a valid operation.
        ; Check if the file was opened with `O_APPEND` flag. If this is the case,
        ; We need to set the cursor to the end of the file before calling the
        ; filesystem.
        ld a, (hl)
        and O_APPEND << 4
        ; If the result is 0, the flag was not provided, no need to modify the cursor beforehand
        jr z, _zos_disk_write_no_append
        ; Set the cursor to the file size as O_APPEND was provided
        ; HL points to the fs field, make it point to size field, and DE to the
        ; offset field.
        push hl
        push de
        inc hl
        inc hl
        inc hl
        ; HL points to the size field
        ld d, h
        ld e, l
        REPT opn_file_off_t - opn_file_size_t
        inc de
        ENDR
        ; Save BC as it is going to get modified
        push bc
        ; Copy [HL] inside [DE] 4 times, as off_t is 4-byte long
        REPT opn_file_off_t - opn_file_size_t
        ldi
        ENDR
        pop bc
        pop de
        pop hl
_zos_disk_write_no_append:
        ; Load the filesystem out of the opened file structure
        ld a, (hl)
        DISKS_OPN_FILE_GET_FS()
        ; Before calling the FS function, decrement HL to make it point
        ; to the beginning of the structure
        dec hl
        push hl
        cp FS_RAWTABLE
        jr z, _zos_disk_write_rawtable
        cp FS_ZEALFS
        jp z, _zos_disk_write_zealfs
        cp FS_FAT16
        jp z, _zos_disk_write_fat16
        ; The filesystem has not been found, memory corruption?
        pop hl
        ld a, ERR_INVALID_FILESYSTEM
        ret
_zos_disk_write_rawtable:
        call zos_fs_rawtable_write
        jp _zos_disk_write_epilogue
_zos_disk_write_zealfs:
        call zos_fs_zealfs_write
        jp _zos_disk_write_epilogue
_zos_disk_write_fat16:
        call zos_fs_fat16_write
_zos_disk_write_epilogue:
        pop hl
        ; Check if an error occurred, stack is clean, we can ret at any time
        or a
        ret nz
        ; Write was a success, we have the number of bytes written in BC
        ; Check if it's 0, this is a small optimization
        ld a, b
        or c
        ret z   ; A is 0, it's a success, BC is also 0
        ; Else, we will have to add BC to the offset. Make HL point to the offset.
        ld de, opn_file_off_t - opn_file_magic_t
        add hl, de
        ; Save the address of HL in DE as we will need it later to get the
        ; address of size field
        ld d, h
        ld e, l
        ; Perform (UINT32) [HL] += (UINT16) BC
        call zos_disk_add_offset_bc
        ; Now, we have to set the size to the offset value if the offset is bigger
        ; than the size.
        ; DE points to opn_file_size_t + 4 (== opn_file_off_t), make it point to the
        ; highest byte while making HL point to the highest byte of the offset.
        ld h, d
        ld l, e
        dec de
        inc hl
        inc hl
        inc hl
        ; Compare the offset (HL) to the size (DE)
        ld a, (de)
        cp (hl)
        jr c, _zos_disk_write_set_size_4
        ; If the result is not 0, it means the size is bigger, we can return
        ret nz
        ; Do the same for the 3rd byte
        dec hl
        dec de
        ld a, (de)
        cp (hl)
        jr c, _zos_disk_write_set_size_3
        ret nz
        ; 2nd byte
        dec hl
        dec de
        ld a, (de)
        cp (hl)
        jr c, _zos_disk_write_set_size_2
        ret nz
        ; Last byte
        dec hl
        dec de
        ld a, (de)
        cp (hl)
        jr c, _zos_disk_write_set_size_1
        ; Size is bigger than offset, we can return with a success
        xor a
        ret
_zos_disk_write_set_size_4:
        ; Jump here if the offset is bigger than the size
        ; All 4 bytes must be copied, from HL to DE.
        ldd
        inc bc
_zos_disk_write_set_size_3:
        ldd
        inc bc
_zos_disk_write_set_size_2:
        ldd
        inc bc
_zos_disk_write_set_size_1:
        ldd
        inc bc
        xor a
        ret


        ; Perform the same operation on the offset, it will return ERR_SUCCESS
        ; in all cases, we can do a tail-call here
        ex de, hl
        ld de, opn_file_off_t - opn_file_size_t
        add hl, de
        jp zos_disk_add_offset_bc


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
        ;       HL - Address of the opened file. Guaranteed by the caller to be a
        ;            non-free opened file (check zos_disk_is_opnfile)
        ;       BCDE - 32-bit offset, signed if whence is SEEK_CUR/SEEK_END.
        ;              Unsigned if SEEK_SET.
        ;       A - Whence. Guaranteed to be SEEK_CUR, SEEK_END, SEEK_SET.
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else.
        ;       BCDE - Unsigned 32-bit offset. Resulting file offset.
        PUBLIC zos_disk_seek
zos_disk_seek:
        ; Make HL point to the size field
        REPT opn_file_size_t
        inc hl
        ENDR
        cp SEEK_SET
        jr z, _zos_disk_seek_set
        ; Whence is SEEK_CUR or SEEK_END
        ; In both cases, we are going to dereference HL into BCDE,
        ; but in the case of SEEK_CUR, we need to perform HL+=4 beforehand,
        ; to make it point to the offset field
        cp SEEK_END
        jr z, _zos_disk_seek_end
        ; Whence is SEEK_CUR. Several things to check here:
        ; - BCDE + file offset must not overflow if BCDE positive
        ; - file offset - BCDE must not be less than 0 (underflow)
        ; Make Hl point to the offset field
        push hl
        REPT opn_file_off_t - opn_file_size_t
        inc hl
        ENDR
        bit 7, b
        jr z, _zos_disk_seek_cur_positive
        ; BCDE is negative, check if -BCDE is greater than [HL]
        call zos_disk_bcde_gt_addr
        or a    ; A is > 0 if -BCDE is greater, 0 else
        jp nz, _zos_disk_seek_set_beginning_pophl
        ; Else, [HL] + BCDE will not trigger any issue, we can continue
        call zos_disk_addr_add_bcde
        pop hl
        jr _zos_disk_seek_set
_zos_disk_seek_cur_positive:
        ; If BCDE is positive, perform BCDE = [HL] + BCDE directly
        call zos_disk_addr_add_bcde
        pop hl
        ; If there was an overflow, then, set it to the end of the file
        jr c, _zos_disk_seek_set_end
        ; Else, the offset is correct, we can calculate it normally,
        ; just as if it was a SEEK_SET request.
        jr _zos_disk_seek_set
_zos_disk_seek_end:
        ; Before calculating the new offset, we have to make some checks:
        ; - Offset must not be a positive value. If it is, then set the cursor
        ;   to the end (file size)
        bit 7, b
        jr z, _zos_disk_seek_set_end
        ; - The opposite of offset must not be bigger than the file size
        call zos_disk_bcde_gt_addr
        or a    ; A is > 0 if -BCDE is greater, 0 else
        jp nz, _zos_disk_seek_set_beginning
        ; Let's calculate [HL] + BCDE, result in BCDE
        push hl ; HL is still pointing to the size field
        call zos_disk_addr_add_bcde
        pop hl
        ; The offset calculated is correct else, we can fall-through
_zos_disk_seek_set:
        ; Entering this branch, HL must point to the size field
        ; Make HL point to the offset field (to get highest byte of size)
        REPT opn_file_off_t - opn_file_size_t
        inc hl
        ENDR
        ; BCDE is now interpreted as an unsigned 32-bit offset.
        ; Compare it to the size of the file. We have to keep the minimum.
        REPTI reg, b, c, d, e
        dec hl
        ld a, (hl)
        cp reg
        jr c, _zos_disk_seek_set_size_min_##reg
        jp nz, _zos_disk_seek_set_offset_min_##reg
        ENDR
        ; If we reach this point (no jump), then both are equal,
        ; which can also be interpreted as "given offset is the minimum".
        ; Thus, we can set the given offset inside the file's offset and
        ; return it directly. Make HL point to the offset field.
_zos_disk_seek_set_offset_min_e:
        inc hl
_zos_disk_seek_set_offset_min_d:
        inc hl
_zos_disk_seek_set_offset_min_c:
        inc hl
_zos_disk_seek_set_offset_min_b:
        inc hl
_zos_disk_seek_set_offset:
        ; Save the new offset inside the structure.
        ; HL points to the offset field entering this branch.
        ; BCDE contains the 32-bit offset to return.
        REPTI reg, e, d, c, b
        ld (hl), reg
        inc hl
        ENDR
        ; Success!
        xor a
        ret
        ; The following code could be simplified by:
        ; REPTI reg, b, c, d, e
        ; _zos_disk_seek_set_size_min_##reg:
        ;     ld reg, (hl)
        ;     IF reg != e
        ;     dec hl
        ;     ENDIF
        ;     ENDR
        ; But the assembler doesn't like it, so let's do it by hand.
        ; The idea is that we assign all the untested/remaining bytes inside
        ; BCDE, as this will be the return value.
        ; Before returning, we jump to _zos_disk_seek_set_offset_min_e as
        ; it will assign that value inside the opened file's offset field.
_zos_disk_seek_set_size_min_b:
        ld b, (hl)
        dec hl
_zos_disk_seek_set_size_min_c:
        ld c, (hl)
        dec hl
_zos_disk_seek_set_size_min_d:
        ld d, (hl)
        dec hl
_zos_disk_seek_set_size_min_e:
        ld e, (hl)
        jp _zos_disk_seek_set_offset_min_e
        ; Set the cursor to the end of the file, i.e. the file size
        ; HL points to the size field entering this branch.
        ; BCDE will contain the file size.
_zos_disk_seek_set_end:
        REPTI reg, e, d, c, b
        ld reg, (hl)
        inc hl
        ENDR
        ; Set the BCDE offset inside the file structure, Hl points to the
        ; offset field.
        jr _zos_disk_seek_set_offset
_zos_disk_seek_set_beginning_pophl:
        pop hl
        ; Set the cursor to the beginning of the file, 0.
        ; HL points to the size field entering this branch
        ; BCDE will contain 0.
_zos_disk_seek_set_beginning:
        ; Make HL point to the offset field
        ld de, opn_file_off_t - opn_file_size_t
        add hl, de
        ; D is 0 (the offset is smaller than 256)
        ld (hl), d
        inc hl
        ld (hl), d
        inc hl
        ld (hl), d
        inc hl
        ld (hl), d
        ld e, d
        ld b, d
        ld c, d
        ; Return success
        xor a
        ret

        ; Routine testing whether -BCDE is greater than the 32-bit value
        ; pointed by HL.
        ; Parameters:
        ;       HL - Address of a 32-bit value
        ;       BCDE - Negative 32-bit value offset
        ; Returns:
        ;       A - 1 if greater, 0 else
        ; Alters:
        ;       A
zos_disk_bcde_gt_addr:
        push hl
        push bc
        push de
        ; Calculate -BCDE, which is equivalent to ~BCDE + 1
        REPTI reg, b, c, d, e
        ld a, reg
        cpl
        ld reg, a
        ENDR    ; 44 T-states
        inc de
        ld a, d
        or e
        jr nz, _zos_disk_bcde_inverted
        inc bc  ; 44+30 = 74 cycles
_zos_disk_bcde_inverted:
        inc hl
        inc hl
        inc hl
        ; HL points to the higher byte
        REPTI reg, b, c, d, e
        ld a, (hl)
        cp reg
        jp c, _zos_disk_bcde_is_gt
        ld a, 0 ; Prepare return value just in case
        jp nz, _zos_disk_addr_is_gt
        dec hl
        ENDR
_zos_disk_bcde_is_gt:
        ld a, 1
_zos_disk_addr_is_gt:
        pop de
        pop bc
        pop hl
        ret

        ; Routine performing an add between the 32-bit value pointed by
        ; HL and the 32-bit value in BCDE.
        ; Parameters:
        ;       HL - Address of a 32-bit value
        ;       BCDE - 32-bit value to add
        ; Returns:
        ;       BCDE - Sum of both
        ;       Flag C - Set if underflow/overflow
        ; Alters:
        ;       HL, BCDE
zos_disk_addr_add_bcde:
        ld a, (hl)
        inc hl
        add e
        ld e, a
        ld a, (hl)
        inc hl
        adc d
        ld d, a
        ld a, (hl)
        inc hl
        adc c
        ld c, a
        ld a, (hl)
        adc b
        ld b, a
        ret

        ; Close an opened file or directory.
        ; The caller must check that the given entry is a valid opened entry.
        ; Parameters:
        ;       HL - Address of the opened file/directory. Guaranteed by the caller to be a
        ;            non-free opened file or directory.
        ; Returns:
        ;       A  - 0 on success, error value else
        ; Alters:
        ;       A, BC, DE
        PUBLIC zos_disk_close
zos_disk_close:
        ; Check if it's a directory
        ld a, (hl)
        and DISKS_OPN_ENTITY_MARKER
        cp DISKS_OPN_DIR_MAGIC_FREE
        jr z, _zos_disk_close_dir
        ; Check if it's a file, if not, corrupted data?
        cp DISKS_OPN_FILE_MAGIC_FREE
        jp nz, zos_disk_invalid_filedev
        ; Load the filesystem from the opened file address
        push hl
        inc hl
        ld a, (hl)
        ; Only keep the filesystem number now
        DISKS_OPN_FILE_GET_FS()
        ; Get the driver out of the opened file
        inc hl
        ld e, (hl)
        inc hl
        ld d, (hl)
        ; Point to the user field. HL is pointing to the size field - 1.
        ld bc, opn_file_usr_t - opn_file_size_t + 1
        add hl, bc
        ; Call the filesystem now
        ; FIXME: Use a vector table?
        cp FS_RAWTABLE
        jp z, _zos_disk_close_rawtable
        cp FS_ZEALFS
        jp z, _zos_disk_close_zealfs
        cp FS_FAT16
        jp z, _zos_disk_close_fat16
        ; The filesystem has not been found, memory corruption?
        pop hl
        ld a, ERR_INVALID_FILESYSTEM
        ret
_zos_disk_close_rawtable:
        call zos_fs_rawtable_close
        jr _zos_disk_close_epilogue
_zos_disk_close_zealfs:
        call zos_fs_zealfs_close
        jr _zos_disk_close_epilogue
_zos_disk_close_fat16:
        call zos_fs_fat16_close
_zos_disk_close_epilogue:
        pop hl
        ; Decrement reference counter in all cases
        dec (hl)
        ret
_zos_disk_close_dir:
        ; Decrement the reference count.
        ; If there was a single reference, 0xB1, becomes 0xB0 here
        dec (hl)
        xor a
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
        ;       HL - Address of an empty opened file structure
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
        ld b, CONFIG_KERNEL_MAX_OPENED_FILES
        ld de, DISKS_OPN_FILE_STRUCT_SIZE
        ld hl, _disk_file_slot
_zos_disks_allocate_loop:
        ; Check if structure's first field reference count is 0
        ld a, (hl)
        and DISKS_OPN_ENTITY_REF
        jr z, _zos_disks_allocate_found
        add hl, de      ; Go to the next structure
        djnz _zos_disks_allocate_loop
        ; Could not find any empty entry, send an error
        pop af
        pop bc
        pop hl
        pop de
        ld a, ERR_CANNOT_REGISTER_MORE
        ld hl, 0
        ret
_zos_disks_allocate_found:
        ; a free structure has been found, mark it as allocated now (reference count + 1)
        ld (hl), DISKS_OPN_FILE_MAGIC_FREE + 1
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
        ; Save file system number and flags
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


        ; Routine checking if the opened dev address passed is an opened file.
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
        and DISKS_OPN_ENTITY_MARKER
        sub DISKS_OPN_FILE_MAGIC_FREE
        ; If zero, return directly, small optimization for ERR_SUCCESS
        ret z
zos_disk_invalid_filedev:
        ; Error, not an opened file, Z flag is not set
        ld a, ERR_INVALID_FILEDEV
        ret

        ; Routine checking that the opened dev is a file OR a directory.
        PUBLIC zos_disk_is_opn_filedir
zos_disk_is_opn_filedir:
        ld a, (hl)
        and DISKS_OPN_FILE_MAGIC_FREE & DISKS_OPN_DIR_MAGIC_FREE
        sub DISKS_OPN_FILE_MAGIC_FREE & DISKS_OPN_DIR_MAGIC_FREE
        ret z
        jr zos_disk_invalid_filedev

        ; Open a directory on a disk
        ; Parameters:
        ;       C - Disk letter (lower/upper are both accepted)
        ;       HL - Absolute path to the file (without X:/)
        ; Returns:
        ;       HL - Newly opened descriptor
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       A, BC, DE, HL
        PUBLIC zos_disk_opendir
zos_disk_opendir:
        ; Get the driver of the given disk letter
        ld a, c
        call zos_disks_get_driver_and_fs
        ; DE contains the potential driver, A must be a success here
        or a
        ret nz
        ; Put the filesystem number in A
        ld a, c
        ; We have a very few filesystems, no need for a lookup table AT THE MOMENT
        cp FS_RAWTABLE
        jp z, zos_fs_rawtable_opendir
        cp FS_ZEALFS
        jp z, zos_fs_zealfs_opendir
        cp FS_FAT16
        jp z, zos_fs_fat16_opendir
        ; The filesystem has not been found, memory corruption?
        ld a, ERR_INVALID_FILESYSTEM
        ret


        ; Create a directory on a disk.
        ; The filesystem must check if the path already exists (file or dir)
        ; Parameters:
        ;       C - Disk letter (lower/upper are both accepted)
        ;       HL - Absolute path of the new directory (without X:/)
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       A, BC, DE, HL
        PUBLIC zos_disk_mkdir
zos_disk_mkdir:
        ; Get the driver of the given disk letter
        ld a, c
        call zos_disks_get_driver_and_fs
        ; DE contains the potential driver, A must be a success here
        or a
        ret nz
        ; Put the filesystem number in A
        ld a, c
        ; We have a very few filesystems, no need for a lookup table AT THE MOMENT
        cp FS_RAWTABLE
        jp z, zos_fs_rawtable_mkdir
        cp FS_ZEALFS
        jp z, zos_fs_zealfs_mkdir
        cp FS_FAT16
        jp z, zos_fs_fat16_mkdir
        ; The filesystem has not been found, memory corruption?
        ld a, ERR_INVALID_FILESYSTEM
        ret


        ; Routine checking if the opened dev address passed is an opened directory.
        ; To do so, the first byte will be dereferenced and compared to the "magic" value.
        ; Parameters:
        ;       HL - Address of the opened "dev". Must not be NULL.
        ; Returns:
        ;       A - ERR_SUCCESS if it's a directory, ERR_INVALID_FILEDEV else
        ;       Z flag - Set if A is ERR_SUCCESS
        ; Alters:
        ;       A
        PUBLIC zos_disk_is_opndir
zos_disk_is_opndir:
        ld a, (hl)
        and DISKS_OPN_ENTITY_MARKER
        sub DISKS_OPN_DIR_MAGIC_FREE
        ret z
        ld a, ERR_INVALID_FILEDEV
        ret


        ; Routine returning the address of an empty opened-dir structure
        ; This will be used by the file systems `opendir` routines.
        ; The first field will be marked as `USED` in this routine.
        ; Parameters:
        ;       A  - Filesystem number
        ;       BC - Driver address
        ; Returns:
        ;       A  - ERR_SUCCESS if success, error code else
        ;       HL - Address of an empty opened directory structure
        ;       DE - Address of the user field in that same structure.
        ;            (Which is 12 bytes long, usable by the filesystem)
        ; Alters:
        ;       A, BC, DE, HL
        PUBLIC zos_disk_allocate_opndir
zos_disk_allocate_opndir:
        ; Save the driver address and the filesystem in C
        push bc
        ld c, a
        ld b, CONFIG_KERNEL_MAX_OPENED_FILES
        ld de, DISKS_OPN_DIR_STRUCT_SIZE
        ld hl, _disk_file_slot
_zos_disks_allocatedir_loop:
        ; Check if structure's first field reference count is 0
        ld a, (hl)
        and DISKS_OPN_ENTITY_REF
        jr z, _zos_disks_allocatedir_found
        add hl, de      ; Go to the next structure
        djnz _zos_disks_allocatedir_loop
        ; Could not find any empty entry, send an error
        pop bc
        ld a, ERR_CANNOT_REGISTER_MORE
        ld hl, 0
        ret
_zos_disks_allocatedir_found:
        ; Restore the file system and the driver address
        ld a, c
        pop bc
        ; A free structure has been found, mark it as allocated now
        push hl
        ld (hl), DISKS_OPN_DIR_MAGIC_FREE + 1
        ; Let's save the filesystem (A) and the driver address (BC) first
        inc hl
        ld (hl), a
        inc hl
        ; Save driver address
        ld (hl), c
        inc hl
        ld (hl), b
        inc hl
        push hl ; Address to return in DE after clearing the fields
        ; Clear the structure
        xor a
        ld (hl), a
        ld d, h
        ld e, l
        inc de
        ld bc, DISKS_OPN_DIR_STRUCT_SIZE - 4 - 1
        ldir
        ; Pop the address of the field right after the driver field
        pop de
        pop hl
        xor a           ; Optimization for ERR_SUCCESS
        ret


        ; Read the next entry from the opened directory.
        ; Parameters:
        ;       HL - Opened directory entry (allocated by zos_disk_allocate_opndir previously)
        ;            Guaranteed to be an opened dir by the caller.
        ;       DE - User buffer to fill. Guaranteed to be at least DISKS_DIR_ENTRY_SIZE big,
        ;            not crossing boundaries, and already mapped to an accessible address.
        ; Returns:
        ;       A - ERR_SUCCESS on success,
        ;           ERR_NO_MORE_ENTRIES if the end of directory has been reached,
        ;           error code else
        ;       [DE] - Next entry data, check dir_entry_t for the structure of this buffer
        PUBLIC zos_disk_readdir
zos_disk_readdir:
        ; Load the filesystem from the opened file address
        inc hl
        ld a, (hl)
        ; Only keep the filesystem number now
        DISKS_OPN_FILE_GET_FS()
        ; Point to the user field directly, no need to extract the driver
        inc hl
        inc hl
        inc hl
        cp FS_RAWTABLE
        jp z, zos_fs_rawtable_readdir
        cp FS_ZEALFS
        jp z, zos_fs_zealfs_readdir
        cp FS_FAT16
        jp z, zos_fs_fat16_readdir
        ; The filesystem has not been found, memory corruption?
        ld a, ERR_INVALID_FILESYSTEM
        ret


        ; Remove a file or a(n empty) directory from a disk
        ; Parameters:
        ;       C - Disk letter (lower/upper are both accepted)
        ;       HL - Absolute path of the file/directory to remove (without X:/)
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       A, BC, DE, HL
        PUBLIC zos_disk_rm
zos_disk_rm:
        ; Get the driver of the given disk letter
        ld a, c
        call zos_disks_get_driver_and_fs
        ; DE contains the potential driver, A must be a success here
        or a
        ret nz
        ; Put the filesystem number in A
        ld a, c
        cp FS_RAWTABLE
        jp z, zos_fs_rawtable_rm
        cp FS_ZEALFS
        jp z, zos_fs_zealfs_rm
        cp FS_FAT16
        jp z, zos_fs_fat16_rm
        ; The filesystem has not been found, memory corruption?
        ld a, ERR_INVALID_FILESYSTEM
        ret


        ;======================================================================;
        ;================= P R I V A T E   R O U T I N E S ====================;
        ;======================================================================;


        ; Private stub used when a file system is disabled from the menuconfig
zos_fs_fat16_open:
zos_fs_fat16_stat:
zos_fs_fat16_read:
zos_fs_fat16_close:
zos_fs_fat16_write:
zos_fs_fat16_opendir:
zos_fs_fat16_readdir:
zos_fs_fat16_mkdir:
zos_fs_fat16_rm:
zos_disk_fs_not_supported:
        ld a, ERR_NOT_SUPPORTED
        ret

        ; Perform a addition of an unsigned 32-bit value pointed by HL with the
        ; unsigned 16-bit value in BC.
        ; Parameters:
        ;       HL - Address of an unsigned 32-bit value (little-endian)
        ;       BC - Unsigned 16-bit value
        ; Returns:
        ;       [HL] - Sum of (uint32*) [HL] and (uint16) BC
        ;       A - ERR_SUCCESS in all cases
        ; Alters:
        ;       A, HL
zos_disk_add_offset_bc:
        ld a, (hl)
        add c
        ld (hl), a
        inc hl
        ; Second byte
        ld a, (hl)
        adc b
        ld (hl), a
        ; Third and fourth byte, can be optimized: if there is no carry,
        ; no need to continue, we can return directly
        ld a, 0 ; DO NOT use xor a here as we don't want to alter the flags
        ret nc
        ; There is a carry, propagate it. We can use inc (hl) but it doesn't set the
        ; carry flag, it sets the zero flag. In fact, if we have an overflow (carry),
        ; the result will be 0 because we only added 1 (increment)
        inc hl
        inc (hl)
        ; If no overflow, we can return
        ret nz
        ; Propagate the overflow to the last byte
        inc hl
        inc (hl)
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