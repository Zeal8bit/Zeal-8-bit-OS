        IFNDEF VFS_H
        DEFINE VFS_H

        ; Filesystem list, useful when mounting a disk
        DEFGROUP {
                FS_RAWTABLE,    ; Check fs/rawtab.asm for more info
                FS_ZEALFS,
                FS_FAT16,
        }

        ; Standard index in the opened devs table 
        DEFC STANDARD_OUTPUT = 0
        DEFC STANDARD_INPUT = 1

        ; Flags for opening devices/files
        DEFC O_RDONLY = 0
        DEFC O_WRONLY = 1
        DEFC O_RDWR   = 2
        DEFC O_APPEND = 1 << 2
        DEFC O_CREAT  = 0 << 2
        DEFC O_NONBLOCK = 1 << 3

        ; File stats structure, filled by zos_vfs_dstat and zos_vfs_stat
        DEFVARS 0 {
                file_size_t     DS.B 4 ; Little-endian
                file_date_t     DS.B 8
                file_name_t     DS.B 8
                file_ext_t      DS.B 3
                file_end_t      DS.B 1
        }

        DEFC STAT_STRUCT_SIZE = file_end_t

        ; Date structure contained in file stats;
        ; TODO: move this to date/time component
        DEFVARS 0 {
                date_year_t     DS.B 2
                date_month_t    DS.B 1
                date_day_t      DS.B 1
                date_date_t     DS.B 1
                date_hours_t    DS.B 1
                date_minutes_t  DS.B 1
                date_seconds_t  DS.B 1
                date_end_t      DS.B 1
        }

        DEFC DATE_STRUCT_SIZE = date_end_t

        ; Public routines
        EXTERN zos_vfs_init
        EXTERN zos_vfs_read
        EXTERN zos_vfs_write
        EXTERN zos_vfs_open
        EXTERN zos_vfs_close
        EXTERN zos_vfs_dstat
        EXTERN zos_vfs_stat
        EXTERN zos_vfs_seek
        EXTERN zos_vfs_ioctl
        EXTERN zos_vfs_mkdir
        EXTERN zos_vfs_getdir
        EXTERN zos_vfs_chdir
        EXTERN zos_vfs_rddir
        EXTERN zos_vfs_rm
        EXTERN zos_vfs_mount
        EXTERN zos_vfs_dup

        ENDIF