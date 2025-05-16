; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        IFNDEF DISKS_H
        DEFINE DISKS_H

        ; Required for O_* flags
        INCLUDE "vfs_h.asm"

        ; Default disk letter on boot up
        DEFC DISK_DEFAULT_LETTER = 'A'

        ; Maximum number of disks at a time
        DEFC DISKS_MAX_COUNT = 26

        ; Public routines, the signatures can be found in the implementation file
        EXTERN zos_disks_init
        EXTERN zos_disks_get_default
        EXTERN zos_disk_open_file
        EXTERN zos_disk_read
        EXTERN zos_disk_write
        EXTERN zos_disk_seek
        EXTERN zos_disk_stat
        EXTERN zos_disk_close
        EXTERN zos_disk_is_opnfile
        EXTERN zos_disk_is_opndir
        EXTERN zos_disk_is_opn_filedir
        EXTERN zos_disks_mount
        EXTERN zos_disk_opendir
        EXTERN zos_disk_allocate_opndir
        EXTERN zos_disk_allocate_opnfile
        EXTERN zos_disk_readdir
        EXTERN zos_disk_mkdir
        EXTERN zos_disk_rm
        EXTERN zos_disks_get_driver_and_fs

        ; Public routine but meant to be used by the file systems
        EXTERN zos_disk_stat_is_dir

        ; Structure of an opened file (and directory)
        ; The first field, the magic will also be used to determine
        ; whether an opened "dev" is a file or not.
        ; Driver's structure start with 4 characters, which represents the name.
        ; These char are ASCII. Thus, if in the following structure, the magic
        ; is an invalid ASCII char (e.g. 0xA0), it will be quiet easy to determine
        ; whether a pointer to a "dev" is a file or not.
        DEFVARS 0 {
                opn_file_magic_t   DS.B 1 ; 0xA0 if entry free, 0xAn where n is reference count else
                opn_file_fs_t      DS.B 1 ; Filesystem number (lowest nibble) and flags (highest nibble)
                opn_file_driver_t  DS.B 2 ; Driver address
                opn_file_size_t    DS.B 4 ; Little-endian
                opn_file_off_t     DS.B 4 ; Offset in the file
                opn_file_usr_t     DS.B 4 ; 4 bytes for the FS, can be used at it wants
                opn_file_end_t     DS.B 1
        }

        ; Mask to get the opened entity type (file or DIR)
        DEFC DISKS_OPN_ENTITY_MARKER = 0xF0
        ; Mask to get the number of opened references
        DEFC DISKS_OPN_ENTITY_REF    = 0x0F

        DEFC DISKS_OPN_FILE_MAGIC_FREE = 0xA0
        DEFC DISKS_OPN_FILE_FS_MASK = 0x0F
        DEFC DISKS_OPN_FILE_FLAGS_MASK = 0xF0
        DEFC DISKS_OPN_FILE_STRUCT_SIZE = opn_file_end_t - opn_file_magic_t

        ; The structure above will also be used for directories, not all the
        ; fields will be used thought.
        DEFC DISKS_OPN_DIR_MAGIC_FREE  = 0xB0
        DEFC DISKS_OPN_DIR_FS_MASK     = DISKS_OPN_FILE_FS_MASK
        DEFC DISKS_OPN_DIR_STRUCT_SIZE = DISKS_OPN_FILE_STRUCT_SIZE

        DEFC opn_dir_end_t = opn_file_end_t
        DEFC opn_dir_usr_t = opn_file_usr_t

        ; Directory entry structure, needs to be allocated by the user program and passed to
        ; the readdir function
        DEFVARS 0 {
                dir_entry_flags   DS.B 1  ; Is the entry a file ? A dir ?
                dir_entry_name_t  DS.B 16 ; File name NULL-terminated, including the extension
                dir_entry_end_t
        }

        ; Size of the directory entry structure
        DEFC DISKS_DIR_ENTRY_SIZE = dir_entry_end_t
        DEFC DISKS_DIR_ENTRY_IS_FILE = 1
        DEFC DISKS_DIR_ENTRY_IS_DIR  = 0


        ; Macro to test whether the flags from an opened file address, pointing to a opn_file_* field,
        ; was opened in WRITE or not.
        ; Prerequisite:
        ;   HL - Address of the opened file structure
        ; Parameter:
        ;   name of the field HL is pointing to
        ; Returns:
        ;   A/Z flag - 0 if not opened in write, positive value else
        ; Alters:
        ;   A, BC, HL
        DEFC WR_FLAGS = O_WRONLY | O_RDWR
        MACRO DISKS_FILE_IS_WRITE field
            ld bc, opn_file_fs_t - field
            add hl, bc
            ld a, (hl)
            and WR_FLAGS << 4
        ENDM


        ; Macro to get the address of the size of an opened file.
        ; The opened file can point to any opn_file_* field.
        ; Prerequisite:
        ;   HL - Address of the opened file structure
        ; Parameter:
        ;   name of the field HL is pointing to
        ; Returns:
        ;   HL - Address of the size field
        ; Alters:
        ;   A, BC, HL
        MACRO DISKS_FILE_GET_SIZE field
            ld bc, opn_file_size_t - (field)
            add hl, bc
        ENDM

        ; Macro to test whether the given address points to an opened file/directory or not
        ; The result is put in A and flags: 0 (z) if true, other value (nz) else
        MACRO DISKS_IS_OPN_FILEDIR _
                ld a, (_)
                and DISKS_OPN_FILE_MAGIC_FREE & DISKS_OPN_DIR_MAGIC_FREE
                sub DISKS_OPN_FILE_MAGIC_FREE & DISKS_OPN_DIR_MAGIC_FREE
        ENDM

        ; Extract filesystem number from the read opn_file_fs_t in A
        ; A high-nibble contains the flags, low-nibble contains the fs
        ; Only keep the filesystem
        MACRO DISKS_OPN_FILE_GET_FS _
                and DISKS_OPN_FILE_FS_MASK
        ENDM

        ENDIF ; DISKS_H