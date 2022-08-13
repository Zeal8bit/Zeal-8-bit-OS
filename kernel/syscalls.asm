        INCLUDE "errors_h.asm"
        INCLUDE "vfs_h.asm"

        SECTION SYSCALL_ROUTINES
zos_sys_msleep:
zos_sys_settime:
zos_sys_gettime:
zos_sys_map:
zos_sys_exit:
zos_sys_exec:
        ret

        SECTION SYSCALL_TABLE
        PUBLIC zos_syscalls_table
        ALIGN 0x100
zos_syscalls_table:
        ; Each jump instruction must take 4 bytes because of the way the caller (zos_syscall)
        ; calculates the offset
	jp zos_vfs_read
        DEFB 0
	jp zos_vfs_write
        DEFB 0
	jp zos_vfs_open
        DEFB 0
	jp zos_vfs_close
        DEFB 0
	jp zos_vfs_dstat
        DEFB 0
	jp zos_vfs_stat
        DEFB 0
	jp zos_vfs_seek
        DEFB 0
	jp zos_vfs_ioctl
        DEFB 0
	jp zos_vfs_mkdir
        DEFB 0
	jp zos_vfs_getdir
        DEFB 0
	jp zos_vfs_chdir
        DEFB 0
	jp zos_vfs_rddir
        DEFB 0
	jp zos_vfs_rm
        DEFB 0
	jp zos_vfs_mount
        DEFB 0
	jp zos_sys_exit
        DEFB 0
	jp zos_sys_exec
        DEFB 0
	jp zos_vfs_dup
        DEFB 0
	jp zos_sys_msleep
        DEFB 0
	jp zos_sys_settime
        DEFB 0
	jp zos_sys_gettime
        DEFB 0
	jp zos_sys_map
        DEFB 0
