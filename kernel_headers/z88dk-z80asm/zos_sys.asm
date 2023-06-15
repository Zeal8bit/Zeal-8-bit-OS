; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    INCLUDE "zos_err.asm"

    IFNDEF ZOS_SYS_HEADER
    DEFINE ZOS_SYS_HEADER

    ; @brief Opened device value for the standard output
    DEFC DEV_STDOUT = 0

    ; @brief Opened device value for the standard input
    DEFC DEV_STDIN = 1

    ; @brief Maximum length for a file/directory name
    DEFC FILENAME_LEN_MAX = 16

    ; @brief Maximum length for a path
    DEFC PATH_MAX = 128

    ; @note In the syscalls below, any pointer, buffer or structure address
    ; provided with an explicit or implicit (sizeof structure) size must NOT
    ; cross virtual page boundary, and must not be bigger than a virtual page
    ; size.
    ; For example, if we have two virtual pages located at 0x4000 and 0x8000
    ; respectively, a buffer starting a 0x7F00 cannot be used with a size of
    ; more than 256 bytes in the function below. Indeed, if the size is bigger,
    ; the end of buffer would cross the second page, which starts at 0x8000. In
    ; such cases, two or more calls to the desired syscall must be performed.

    ; @brief Flags used to defined the modes to use when opening a file
    ; Note on the behavior:
    ;  - O_RDONLY: Can only read
    ;  - O_WRONLY: Can only write
    ;  - O_RDWR: Can both read and write, sharing the same cursor, writing will
    ;  -         overwrite existing data.
    ;  - O_APPEND: Needs writing. Before each write, the cursor will be
    ;  -           moved to the end of the file, as if seek was called.
    ;  -           So, if used with O_RDWR, reading after a write will read 0.
    ;  - O_TRUNC: No matter if O_RDWR or O_WRONLY, the size is first set to
    ;  -          0 before any other operation occurs.
    DEFC O_WRONLY_BIT = 0
    DEFC O_RDONLY = 0 << O_WRONLY_BIT
    DEFC O_WRONLY = 1 << O_WRONLY_BIT
    DEFC O_RDWR   = 2
    DEFC O_TRUNC  = 1 << 2
    DEFC O_APPEND = 2 << 2
    DEFC O_CREAT  = 4 << 2
    ; Only makes sense for drivers, not files
    DEFC O_NONBLOCK = 1 << 5

    ; @brief Directory entry size, in bytes.
    ; Its content would be represented like this in C:
    ; struct {
    ;     uint8_t d_flags;
    ;     char    d_name[FILENAME_LEN_MAX];
    ; }
    DEFC ZOS_DIR_ENTRY_SIZE = 1 + FILENAME_LEN_MAX

    ; @brief Date structure size, in bytes.
    ; Its content would be represented like this in C:
    ; struct {
    ;     uint16_t d_year;
    ;     uint8_t  d_month;
    ;     uint8_t  d_day;
    ;     uint8_t  d_date; // Range [1,7] (Sunday, Monday, Tuesday...)
    ;     uint8_t  d_hours;
    ;     uint8_t  d_minutes;
    ;     uint8_t  d_seconds;
    ; }
    ; All the fields above are in BSD format.
    DEFC ZOS_DATE_SIZE = 17

    ; @brief Stat file size, in bytes.
    ; Its content would be represented like this in C:
    ; struct {
    ;     uint32_t   s_size; // in bytes
    ;     zos_date_t s_date;
    ;     char       s_name[FILENAME_LEN_MAX];
    ; }
    DEFC ZOS_STAT_SIZE = 1 + ZOS_DATE_SIZE + FILENAME_LEN_MAX

    ; @brief Whence values. Check `seek` syscall for more info
    DEFC SEEK_SET = 0
    DEFC SEEK_CUR = 1
    DEFC SEEK_END = 2

    ; @brief Filesystems supported on Zeal 8-bit OS
    DEFC FS_RAWTABLE = 0


    ; @brief Macro to abstract the syscall instruction
    MACRO SYSCALL
        rst 0x8
    ENDM


    ; @brief Read from an opened device.
    ;        Can be invoked with READ().
    ;
    ; Parameters:
    ;   H  - Device to read from. This value must point to an opened device.
    ;        Refer to `open()` for more info.
    ;   DE - Buffer to store the bytes read from the opened device.
    ;   BC - Size of the buffer passed, maximum size is a page size.
    ; Returns:
    ;   A  - ERR_SUCCESS on success, error value else
    ;   BC - Number of bytes filled in DE.
    MACRO  READ  _
        ld l, 0
        SYSCALL
    ENDM


    ; @brief Helper for the READ syscall when the opened dev value is known
    ;        at assembly it.
    ;        Can be invoked with S_READ1(dev).
    ; Refer to READ() syscall for more info about the parameters and the returned values.
    MACRO S_READ1 dev
        ld h, dev
        READ()
    ENDM

    ; @brief Helper for the READ syscall when the opened dev and the buffer are known
    ;        at assembly it.
    ;        Can be invoked with S_READ2(dev, buf).
    ; Refer to READ() syscall for more info about the parameters and the returned values.
    MACRO S_READ2 dev, buf
        ld h, dev
        ld de, buf
        READ()
    ENDM

    ; @brief Helper for the READ syscall when the opened dev, the buffer and the size
    ;        are known at assembly it.
    ;        Can be invoked with S_READ3(dev, buf, size).
    ; Refer to READ() syscall for more info about the parameters and the returned values.
    MACRO S_READ3 dev, buf, len
        ld h, dev
        ld de, buf
        ld bc, len
        READ()
    ENDM


    ; @brief Write to an opened device.
    ;        Can be invoked with WRITE().
    ;
    ; Parameters:
    ;   H  - Number of the dev to write to.
    ;   DE - Buffer to write to. The buffer must NOT cross page boundary.
    ;   BC - Size of the buffer passed. Maximum size is a page size.
    ; Returns:
    ;   A  - ERR_SUCCESS on success, error value else
    ;   BC - Number of bytes written
    MACRO  WRITE  _
        ld l, 1
        SYSCALL
    ENDM


    ; @brief Helper for the WRITE syscall when the opened dev value is known
    ;        at assembly it.
    ;        Can be invoked with S_WRITE1(dev).
    ; Refer to WRITE() syscall for more info about the parameters and the returned values.
    MACRO S_WRITE1 dev
        ld h, dev
        WRITE()
    ENDM

    ; @brief Helper for the WRITE syscall when the opened dev and the buffer are known
    ;        at assembly it.
    ;        Can be invoked with S_WRITE2(dev, buf).
    ; Refer to WRITE() syscall for more info about the parameters and the returned values.
    MACRO S_WRITE2 dev, str
        ld h, dev
        ld de, str
        WRITE()
    ENDM

    ; @brief Helper for the WRITE syscall when the opened dev, the buffer and the size
    ;        are known at assembly it.
    ;        Can be invoked with S_WRITE3(dev, buf, size).
    ; Refer to WRITE() syscall for more info about the parameters and the returned values.
    MACRO S_WRITE3 dev, str, len
        ld h, dev
        ld de, str
        ld bc, len
        WRITE()
    ENDM


    ; @brief Open the given file or driver.
    ;        Drivers name shall not exceed 4 characters and must be preceded by # (5 characters in total)
    ;        Names not starting with # will be considered as files.
    ;        Path to the file to open, the path can be:
    ;          - Relative to the current directory: file.txt
    ;          - Absolute to the current disk: /path/to/file.txt
    ;          - Absolute to the system: C:/path/to/file.txt
    ;        Can be invoked with OPEN().
    ;
    ; Parameters:
    ;   BC - Name: driver or file.
    ;   H - Flags, can be O_RDWR, O_RDONLY, O_WRONLY, O_NONBLOCK, O_CREAT, O_APPEND, etc...
    ;       It is possible to OR them.
    ; Returns:
    ;   A - Number of the newly opened dev on success, negated error value else.
    MACRO  OPEN  _
        ld l, 2
        SYSCALL
    ENDM


    ; @brief Close an opened device. It is necessary to keep the least minimum
    ;        of devices/files opened as the limit is set by the kernel and may be
    ;        different between implementations.
    ;        Can be invoked with CLOSE().
    ;
    ; Parameters:
    ;   H - Number of the dev to close
    ; Returns:
    ;   A - ERR_SUCCESS on success, error code else
    MACRO  CLOSE  _
        ld l, 3
        SYSCALL
    ENDM


    ; @brief Return the stats of an opened file.
    ;        The returned structure is defined above, check ZOS_STAT_SIZE description.
    ;        Can be invoked with DSTAT().
    ;
    ; Parameters:
    ;   H - Opened dev to get the stat of.
    ;   DE - Address of the stat structure to fill on success.
    ;        The memory pointed must be big enough to store the file information.
    ; Returns:
    ;   A - ERR_SUCCESS on success, error else
    MACRO  DSTAT  _
        ld l, 4
        SYSCALL
    ENDM


    ; @brief Return the stats of a file.
    ;        The returned structure is defined above, check ZOS_STAT_SIZE description.
    ;        Can be invoked with STAT().
    ;
    ; Parameters:
    ;   BC - Path to the file.
    ;   DE - Address of the stat structure to fill on success.
    ;        The memory pointed must be big enough to store the file information.
    ; Returns:
    ;   A - ERR_SUCCESS on success, error else
    MACRO  STAT  _
        ld l, 5
        SYSCALL
    ENDM


    ; @brief Move the cursor of an opened file or an opened driver.
    ;        In case of a driver, the implementation is driver-dependent. In case of
    ;        a file, the cursor never moves further than the file size.
    ;        If the given whence is SEEK_SET, and the given offset is bigger than the file,
    ;        the cursor will be set to the end of the file.
    ;        Similarly, if the whence is SEEK_END and the given offset is positive,
    ;        the cursor won't move further than the end of the file.
    ;        Can be invoked with SEEK().
    ;
    ; Parameters:
    ;   H - Opened dev to reposition the cursor from, must refer to an opened driver.
    ;   BCDE - 32-bit offset, signed if whence is SEEK_CUR/SEEK_END.
    ;          Unsigned if SEEK_SET.
    ;   A - Whence. When set to SEEK_SET, `offset` parameter is the new value of
    ;       cursor in the file.
    ;       When set to SEEK_CUR, `offset` represents a signed value to add to the
    ;       current position in the file.
    ;       When set to SEEK_END, `offset` represents a signed value to add to the
    ;       last valid position in the file.
    ; Returns:
    ;   A - ERR_SUCCESS on success, error code else.
    ;   BCDE - Unsigned 32-bit offset. Resulting file offset.
    MACRO  SEEK  _
        ld l, 6
        SYSCALL
    ENDM


    ; @brief Perform an input/output operation on an opened driver.
    ;        The command and parameter are specific to the device drivers of destination.
    ;        Make sure to check the documentation of the driver buffer calling this function.
    ;        Can be invoked with IOCTL().
    ;
    ; Parameters:
    ;   H - Dev number, must refer to an opened driver, not a file.
    ;   C - Command number. This is driver-dependent, check the driver documentation for more info.
    ;   DE - 16-bit parameter. This is also driver dependent. This can be used as a 16-bit value or
    ;        as an address. Similarly to the buffers in `read` and `write` routines, if this is an
    ;        address, it must not cross a page boundary.
    ; Returns:
    ;   A - ERR_SUCCESS on success, error code else
    MACRO  IOCTL  _
        ld l, 7
        SYSCALL
    ENDM


    ; @brief Create a directory at the specified location.
    ;        If one of the directories in the given path doesn't exist, this will fail.
    ;        For example, if mkdir("A:/D/E/F") is requested where D exists but E doesn't, this syscall
    ;        will fail and return an error.
    ;        Can be invoked with MKDIR().
    ;
    ; Parameters:
    ;   DE - Path of the directory to create, including the NULL-terminator. Must NOT cross boundaries.
    ; Returns:
    ;   A - ERR_SUCCESS on success, error code else.
    MACRO  MKDIR  _
        ld l, 8
        SYSCALL
    ENDM


    ; @brief Change the current working directory path.
    ;        Can be invoked with CHDIR().
    ;
    ; Parameters:
    ;   DE - Path to the new working directory. The string must be NULL-terminated.
    ; Returns:
    ;   A - ERR_SUCCESS on success, error code else.
    MACRO  CHDIR  _
        ld l, 9
        SYSCALL
    ENDM


    ; @brief Get the current working directory.
    ;        Can be invoked with CURDIR().
    ;
    ; Parameters:
    ;   DE - Buffer to store the current path to. The buffer must be big enough
    ;        to store a least PATH_MAX bytes.
    ; Returns:
    ;   A - ERR_SUCCESS on success, error code else
    MACRO  CURDIR  _
        ld l, 10
        SYSCALL
    ENDM


    ; @brief Open a directory given a path.
    ;        The path can be relative, absolute to the disk or absolute to the
    ;        system, just like open for files.
    ;        Can be invoked with OPENDIR().
    ;
    ; Parameters:
    ;   DE - Path to the directory to open, the string must be NULL-terminated.
    ;        Like for all the above paths, it can be:
    ;        * Relative to the current directory ("../dir", "dir1")
    ;        * Absolute to the disk ("/dir1/dir2")
    ;        * Absolute to the system ("A:/dir1")
    ; Returns:
    ;   A - Number for the newly opened dev on success, negated error value else.
    MACRO  OPENDIR  _
        ld l, 11
        SYSCALL
    ENDM


    ; @brief Read the next entry from the given opened directory.
    ;        Can be invoked with READDIR().
    ;
    ; Parameters:
    ;   H  - Number of the dev to write to. If the given dev is not a directory,
    ;        an error will be returned.
    ;   DE - Buffer to store the entry data, the buffer must NOT cross page boundary.
    ;        It must be big enough to hold at least ZOS_DIR_ENTRY_SIZE bytes.
    ; Returns:
    ;   A  - ERR_SUCCESS on success,
    ;        ERR_NO_MORE_ENTRIES if all the entries have been browsed already,
    ;        error value else.
    MACRO  READDIR  _
        ld l, 12
        SYSCALL
    ENDM


    ; @brief Remove a file or an empty directory.
    ;        Can be invoked with RM().
    ;
    ; Parameters:
    ;   DE - Path to the file or directory to remove. Like the path above, it must be
    ;        NULL-terminated, can be a relative, relative to the disk, or absolute path.
    ; Returns:
    ;   A - ERR_SUCCESS on success, error code else.
    MACRO  RM  _
        ld l, 13
        SYSCALL
    ENDM


    ; @brief Mount a new disk, given a driver, a letter and a file system.
    ;        The letter assigned to the disk must not be in use.
    ;        Can be invoked with MOUNT().
    ;
    ; Parameters:
    ;   H - Opened dev number. It must be an opened driver, not a file. The dev can be closed
    ;       after mounting, this will not affect the mounted disk.
    ;   D - ASCII letter to assign to the disk (upper or lower)
    ;   E - File system, check the FS_* macro defined at the top of this file.
    ; Returns:
    ;   A - ERR_SUCCESS on success, error code else
    MACRO  MOUNT  _
        ld l, 14
        SYSCALL
    ENDM


    ; @brief Exit the program and give back the hand to the kernel.
    ;        Can be invoked with EXIT().
    ;
    ; Parameters:
    ;   C - Returned code (unused yet)
    ; Returns:
    ;   None
    MACRO  EXIT  _
        ld l, 15
        SYSCALL
    ENDM


    ; @brief Load and execute a program from a file name given as a parameter.
    ;        The program will cover the current program.
    ;        Can be invoked with EXEC().
    ;
    ; Parameters:
    ;   BC - File to load and execute. The string must be NULL-terminated and must not cross boundaries.
    ;   DE - String argument to give to the program to execute, must be NULL-terminated. Can be NULL.
    ; Returns:
    ;   A - On success, the new program is executed. ERR_FAILURE on failure.
    MACRO  EXEC  _
        ld l, 16
        SYSCALL
    ENDM


    ; @brief Duplicate the given opened dev to a new index. This will only
    ;        duplicate the "pointer" to the actual implementation. For example,
    ;        duplicate the dev of an opened file and performing a seek on the it
    ;        will affect both the old and the new dev.
    ;        This can be handy to override the standard input or output.
    ;        Can be invoked with DUP().
    ;
    ; Parameters:
    ;   H - Dev number to duplicate.
    ;   E - New number for the opened dev.
    ; Returns:
    ;   A - ERR_SUCCESS on success, error code else
    MACRO  DUP  _
        ld l, 17
        SYSCALL
    ENDM


    ; @brief Sleep for a specified duration.
    ;        Can be invoked with MSLEEP().
    ;
    ; Parameters:
    ;   DE - 16-bit duration (maximum 65 seconds).
    ; Returns:
    ;   A - ERR_SUCCESS on success, error code else.
    MACRO  MSLEEP  _
        ld l, 18
        SYSCALL
    ENDM


    ; @brief Routine to manually set/reset the time counter, in milliseconds.
    ;        Can be invoked SETTIME().
    ;
    ; Parameters:
    ;   H - ID of the clock (unused for now)
    ;   DE - 16-bit counter value, in milliseconds.
    ; Returns:
    ;   A - ERR_SUCCESS on success, ERR_NOT_IMPLEMENTED if target doesn't implement
    ;       this feature error code else.
    MACRO  SETTIME  _
        ld l, 19
        SYSCALL
    ENDM


    ; @brief Get the time counter, in milliseconds.
    ;        The granularity is dependent on the implementation/hardware, for example,
    ;        it could be 1ms, 2ms, 16ms, etc.
    ;        You should be aware of this when calling this syscall.
    ;        Can be invoked with GETTIME().
    ;
    ; Parameters:
    ;   H - Id of the clock (for future use, unused for now)
    ; Returns:
    ;   A - ERR_SUCCESS on success, ERR_NOT_IMPLEMENTED if target doesn't implement
    ;       this feature, error code else.
    ;   DE - 16-bit counter value, in milliseconds.
    MACRO  GETTIME  _
        ld l, 20
        SYSCALL
    ENDM


    ; @brief Set the system date, on targets where RTC is available.
    ;        Can be invoked with SETDATE().
    ;
    ; Parameters:
    ;   DE - Address of the date structure, as defined at the top of this file.
    ;        The buffer must NOT cross page boundary.
    ; Returns:
    ;   A - ERR_SUCCESS on success, ERR_NOT_IMPLEMENTED if target doesn't implement
    ;       this feature, error code else
    MACRO  SETDATE  _
        ld l, 21
        SYSCALL
    ENDM


    ; @brief Get the system date, on targets where RTC is available.
    ;        Can be invoked with GETDATE().
    ;
    ; Parameters:
    ;   DE - Buffer to store the date structure in, the buffer must NOT cross page boundary.
    ;        It must be big enough to hold at least ZOS_DATE_SIZE bytes.
    ; Returns:
    ;   A - ERR_SUCCESS on success, ERR_NOT_IMPLEMENTED if target doesn't implement
    ;       this feature, error code else
    MACRO  GETDATE  _
        ld l, 22
        SYSCALL
    ENDM


    ; @brief Map a physical address/region to a virtual address/region.
    ;        Can be invoked with MAP().
    ;
    ; Parameters:
    ;   DE - Destination address in virtual memory. This will be rounded down to the target closest
    ;        page bound. For example, passing 0x5000 here, would in fact trigger a remap of the
    ;        page starting at 0x4000 on a target that has 16KB virtual pages.
    ;   HBC - Upper 24-bits of the physical address to map. If the target does not support
    ;         the physical address given, an error will be returned.
    ;         Similarly to the virtual address, the value may be rounded down to the closest page bound.
    ; Returns:
    ;   ERR_SUCCESS on success, error code else.
    MACRO  MAP  _
        ld l, 23
        SYSCALL
    ENDM

    ENDIF ; ZOS_SYS_HEADER