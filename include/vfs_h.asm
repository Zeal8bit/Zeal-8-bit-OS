        IFNDEF VFS_H
        DEFINE VFS_H

        ; Filesystem list, useful when mounting a disk
        ; We can have at most 16 filesystems at the moment
        DEFGROUP {
                FS_RAWTABLE,    ; Check fs/rawtable.asm for more info
                FS_ZEALFS,
                FS_FAT16,
                FS_END,
        }

        ; Standard index in the opened devs table 
        DEFC STANDARD_OUTPUT = 0
        DEFC STANDARD_INPUT = 1

        ; Whences for seek routine
        DEFGROUP {
                SEEK_SET,
                SEEK_CUR,
                SEEK_END,       ; Last valid entry
        }

        ; Define the bit index for the WRONLY flag.
        DEFC O_WRONLY_BIT = 0

        ; Flags for opening devices/files
        ; Note on the behavior:
        ;     O_RDONLY: Can only read
        ;     O_WRONLY: Can only write
        ;     O_RDWR: Can both read and write, sharing the same cursor, writing will
        ;             overwrite existing data.
        ;     O_APPEND: Needs writing. Before each write, the cursor will be
        ;               moved to the end of the file, as if lseek was called.
        ;               So, if used with O_RDWR, reading after a write will read 0.
        ;     O_TRUNC: No matter if O_RDWR or O_WRONLY, the size is first set to
        ;              0 before any other operation occurs.
        DEFC O_RDONLY = 0 << O_WRONLY_BIT
        DEFC O_WRONLY = 1 << O_WRONLY_BIT
        DEFC O_RDWR   = 2
        DEFC O_TRUNC  = 1 << 2
        DEFC O_APPEND = 2 << 2
        DEFC O_CREAT  = 3 << 2
        ; Only makes sense for drivers, not files
        DEFC O_NONBLOCK = 1 << 4

        ; File stats structure, filled by zos_vfs_dstat and zos_vfs_stat
        DEFVARS 0 {
                file_size_t     DS.B 4 ; Little-endian
                file_date_t     DS.B 8
                file_name_t     DS.B 16 ; Includes the extension
                file_end_t      DS.B 1
        }

        DEFC STAT_STRUCT_SIZE = file_end_t

        ; Date structure contained in file stats.
        ; All the values are in BCD format!
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
        
        ; Misc
        DEFC VFS_WORK_BUFFER_SIZE = 64

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


        EXTERN zos_vfs_init_syscall
        EXTERN zos_vfs_read_syscall
        EXTERN zos_vfs_write_syscall
        EXTERN zos_vfs_open_syscall
        EXTERN zos_vfs_close_syscall
        EXTERN zos_vfs_dstat_syscall
        EXTERN zos_vfs_stat_syscall
        EXTERN zos_vfs_seek_syscall
        EXTERN zos_vfs_ioctl_syscall
        EXTERN zos_vfs_mkdir_syscall
        EXTERN zos_vfs_getdir_syscall
        EXTERN zos_vfs_chdir_syscall
        EXTERN zos_vfs_rddir_syscall
        EXTERN zos_vfs_rm_syscall
        EXTERN zos_vfs_mount_syscall
        EXTERN zos_vfs_dup_syscall

        ENDIF