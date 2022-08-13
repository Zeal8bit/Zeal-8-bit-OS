        IFNDEF DISKS_H
        DEFINE DISKS_H

        ; Default disk letter on bootup
        DEFC DISK_DEFAULT_LETTER = 'A'

        ; Maximum number of disks at a time
        DEFC DISKS_MAX_COUNT = 26

        ; Public routines
        EXTERN zos_disks_init
        EXTERN zos_disk_open_file
        EXTERN zos_disk_read
        EXTERN zos_disk_write
        EXTERN zos_disk_seek
        EXTERN zos_disk_stat
        EXTERN zos_disk_close
        EXTERN zos_disk_is_opnfile
        EXTERN zos_disks_mount

        ; Structure of an opened file
        ; The first field, the magic will also be used to determine
        ; whether an opened "dev" is a file or not.
        ; Driver's structure start with 4 characters, which represents the name.
        ; These char are ASCII. Thus, if in the following structure, the magic
        ; is an invalid ASCII char (e.g. 0xA0), it will be quiet easy to determine
        ; whether a pointer to a "dev" is a file or not. 
        DEFVARS 0 {
                opn_file_magic_t   DS.B 1 ; 0xA0 if entry free, 0xAF else
                opn_file_fs_t      DS.B 1 ; Filesystem number (lowest nibble) and flags (highest nibble)
                opn_file_driver_t  DS.B 2 ; Driver address
                opn_file_size_t    DS.B 4 ; Little-endian
                opn_file_off_t     DS.B 4 ; Offset in the file
                opn_file_usr_t     DS.B 4 ; 4 bytes for the FS, can be used at it wants
                opn_file_end_t     DS.B 1 
        }

        DEFC DISKS_OPN_FILE_MAGIC_FREE = 0xA0
        DEFC DISKS_OPN_FILE_MAGIC_USED = 0xAF
        DEFC DISKS_OPN_FILE_FS_MASK = 0x0F
        DEFC DISKS_OPN_FILE_FLAGS_MASK = 0xF0
        DEFC DISKS_OPN_FILE_STRUCT_SIZE = opn_file_end_t - opn_file_magic_t

        ; Extract filesystem number from the read opn_file_fs_t in A
        ; A high-nibble contains the flags, low-nibble contains the fs
        ; Only keep the filesystem
        MACRO DISKS_OPN_FILE_GET_FS _
            and DISKS_OPN_FILE_FS_MASK
        ENDM

        ENDIF ; DISKS_H