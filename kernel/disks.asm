        INCLUDE "errors_h.asm"
        INCLUDE "disks_h.asm"
        INCLUDE "utils_h.asm"

        ; Requred external routines
        EXTERN to_upper

        SECTION KERNEL_TEXT

        PUBLIC zos_disks_init
zos_disks_init:
        ; Set the default disk to A
        ld a, DISK_DEFAULT_LETTER
        ld (_disks_default), a
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
        ld d, a
        ; Let's say that the pointer is invalid if the upper byte is 0
        ld a, h
        or a
        jp z, _zos_disks_invalid_param
        ; Check the letter now
        ld a, d
        call to_upper
        jp c, _zos_disks_invalid_param
        ; Convert A to the _disk array index
        sub 'A'
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
        xor a   ; Optimization for ERR_SUCCESS
        ex de, hl
        ret
_zos_disks_mount_already_mounted:
        ex de, hl
        ld a, ERR_ALREADY_MOUNTED
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
        ;       A - ERR_SUCCESS is success, error code else
        ;       HL - Pointer to the driver
        ; Alters:
        ;       A, DE, HL
        PUBLIC zos_disks_get_driver
zos_disks_get_driver:
        call to_upper
        jp c, _zos_disks_invalid_param
        ; A is a correct upper letter for sure now
        sub 'A'
        ; A *= 2 because _disks entry are 16-bit long
        add a
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
        xor a        ; Optimization for ERR_SUCCESS
        ret

        SECTION KERNEL_BSS
        ; Letter of the default disk 
_disks_default: DEFS 1
_disks: DEFS DISKS_MAX_COUNT * 2
_disks_fs: DEFS DISKS_MAX_COUNT