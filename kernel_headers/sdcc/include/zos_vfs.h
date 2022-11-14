/* SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#pragma once

#include <stdint.h>
#include "zos_errors.h"
#include "zos_time.h"

/**
 * Define the calling convention for all the routines
 */
#if __SDCC_VERSION_MAJOR >= 4 && __SDCC_VERSION_MINOR >= 2
    #define CALL_CONV __sdcccall(1)
#else
    #error "Unsupported calling convention. Please upgrade your SDCC version."
#endif


/**
 * @brief Opened device value for the standard output
 */
#define DEV_STDOUT 0

/**
 * @brief Opened device value for the standard input
 */
#define DEV_STDIN 1

/**
 * @brief Maximum length for a file/directory name
 */
#define FILENAME_LEN_MAX 16

/**
 * @brief Maximum length for a path
 */
#define PATH_MAX 128

/**
 * @brief Flags used to defined the modes to use when opening a file
 * Note on the behavior:
 *  - O_RDONLY: Can only read
 *  - O_WRONLY: Can only write
 *  - O_RDWR: Can both read and write, sharing the same cursor, writing will
 *  -         overwrite existing data.
 *  - O_APPEND: Needs writing. Before each write, the cursor will be
 *  -           moved to the end of the file, as if seek was called.
 *  -           So, if used with O_RDWR, reading after a write will read 0.
 *  - O_TRUNC: No matter if O_RDWR or O_WRONLY, the size is first set to
 *  -          0 before any other operation occurs.
 */
#define O_WRONLY_BIT 0
#define O_RDONLY     0 << O_WRONLY_BIT
#define O_WRONLY     1 << O_WRONLY_BIT
#define O_RDWR       2
#define O_TRUNC      1 << 2
#define O_APPEND     2 << 2
#define O_CREAT      3 << 2
#define O_NONBLOCK   1 << 4 /*  Only makes sense for drivers, not files */


/**
 * @brief Macros testing if a d_flags marks a file or a directory
 */
#define D_ISFILE(flags) (((flags) & 1) == 1)
#define D_ISDIR(flags)  (((flags) & 1) == 0)

/**
 * @brief Type for opened devices
 */
typedef int8_t zos_dev_t;


/**
 * @brief Structure representing a directory entry.
 */
typedef struct {
    uint8_t d_flags; // Is the entry a file ? A dir ?
    char    d_name[FILENAME_LEN_MAX]; // File name NULL-terminated, including the extension
} zos_dir_entry_t;


/**
 * @brief Structure representing a stat for a file.
 *
 * @note The size is expressed in bytes
 */
typedef struct {
    uint32_t   s_size; // in bytes
    zos_date_t s_date;
    char       s_name[FILENAME_LEN_MAX];
} zos_stat_t;


/**
 * @brief Structure representing a whence. Check `seek` function for more info.
 */
typedef enum {
    SEEK_SET = 0,
    SEEK_CUR,
    SEEK_END
} zos_whence_t;


/**
 * @brief Enumeration regrouping all the filesystems supported on Zeal 8-bit OS
 */
typedef enum {
    FS_RAWTABLE = 0, // Only filesystem implemented for the moment
} zos_fs_t;

/**
 * @note In the functions below, any pointer, buffer or structure address
 * provided with an explicit or implicit (sizeof structure) size must NOT
 * cross virtual page boundary, and must not be bigger than a virtual page
 * size.
 * For example, if we have two virtual pages located at 0x4000 and 0x8000
 * respectively, a buffer starting a 0x7F00 cannot be used with a size of
 * more than 256 bytes in the function below. Indeed, if the size is bigger,
 * the end of buffer would cross the second page, which starts at 0x8000. In
 * such cases, two or more calls to the desired syscall/function must be
 * performed.
 */

/**
 * @brief Read from an opened device
 *
 * @param dev Device to read from. This value must point to an opened device.
 *            Refer to `open()` for more info.
 * @param buf Buffer to store the bytes read from the opened device.
 * @param size Pointer to the size of the given buffer `buf`. Upon return, the
 *             value pointed will be replaced by the number of bytes read.
 *
 * @returns ERR_SUCCESS on success, error code else.
 */
zos_err_t read(zos_dev_t dev, void* buf, uint16_t* size) CALL_CONV;


/**
 * @brief Write to an opened device
 *
 * @param dev Device to write to. This value must point to an opened device.
 *            Refer to `open()` for more info.
 * @param buf Buffer containing the bytes to write to the opened device.
 * @param size Pointer to the size of the given buffer `buf`. Upon return, the
 *             value pointed will be replaced by the number of bytes written.
 *
 * @returns ERR_SUCCESS on success, error code else.
 */
zos_err_t write(zos_dev_t dev, const void* buf, uint16_t* size) CALL_CONV;


/**
 * @brief Open a device, it can be a driver or file.
 *
 * @param name Path to the file to open, the path can be:
 *               - Relative to the current directory: file.txt
 *               - Absolute to the current disk: /path/to/file.txt
 *               - Absolute to the system: C:/path/to/file.txt
 *             If a driver needs to be opened, prefix the name with #.
 *             For example, to open the GPIO driver, provide #GPIO as `name`.
 * @param flags Flags to open the file or driver with. Flags can be ORed.
 *
 * @returns Open device number on success, negated error value else.
 *          For example, if ERR_FAILURE error occurred, -ERR_FAILURE will be
 *          returned.
 */
zos_dev_t open(const char* name, uint8_t flags) CALL_CONV;


/**
 * @brief Close an opened device. It is necessary to keep the least minimum
 *        of devices/files opened as the limit is set by the kernel and may be
 *        different between implementations.
 *
 * @param dev Device to close.
 *
 * @returns ERR_SUCCESS on success, error code else.
 */
zos_err_t close(zos_dev_t dev) CALL_CONV;


/**
 * @brief Get info about the given opened file. If the given dev doesn't point
 *        to a file, an error will be returned.
 *
 * @param dev Opened dev to get the stat of.
 * @param stat Pointer to the stat structure to fill on success.
 *
 * @returns ERR_SUCCESS on success, error code else.
 */
zos_err_t dstat(zos_dev_t dev, zos_stat_t* stat) CALL_CONV;


/**
 * @brief Get info about the given file path. Like `open` function, the given
 *        path can be relative, absolute to the disk or absolute to the system.
 *
 * @param path Path to the file.
 * @param stat Pointer to the stat structure to fill on success.
 *
 * @returns ERR_SUCCESS on success, error code else.
 */
zos_err_t stat(const char* path, zos_stat_t* stat) CALL_CONV;


/**
 * @brief Reposition the cursor in the opened file or driver.
 *        In the case of a driver, the implementation is driver dependent.
 *        In case of a file, the cursor never moves further than the file size.
 *        If the given whence is SEEK_SET, and the given offset is bigger than
 *        the file size, the cursor will be set to the end of the file.
 *        Similarly, if the whence is SEEK_END and the given offset is positive,
 *        the cursor won't move further than the end of the file.
 *
 * @param dev Opened dev to reposition the cursor from.
 * @param offset Pointer to the 32-bit offset defining the cursor offset or
 *               absolute value depending on the parameter `whence`.
 * @param whence When set to SEEK_SET, `offset` parameter is the new value of
 *               cursor in the file.
 *               When set to SEEK_CUR, `offset` represents a signed value
 *               to add to the current position in the file.
 *               When set to SEEK_END, `offset` represents a signed value
 *               to add to the last valid position in the file.
 *
 * @returns ERR_SUCCESS on success, error code else. On success, `offset`
 *          pointer will contain the new position of the cursor in the file.
 */
zos_err_t seek(zos_dev_t dev, int32_t* offset, zos_whence_t whence) CALL_CONV;


/**
 * @brief Perform an input/output operation on an opened driver.
 *        The command and parameter are specific to the device drivers of
 *        destination. Make sure to check the documentation of the driver
 *        buffer calling this function.
 *
 * @param dev Opened driver to perform the I/O on.
 * @param cmd Command to give to the driver
 * @param arg Parameter to give to the driver, it can be a pointer to fill or to
 *            read by the driver.
 *
 * @returns ERR_SUCCESS on success, error code else.
 */
zos_err_t ioctl(zos_dev_t dev, uint8_t cmd, void* arg) CALL_CONV;


/**
 * @brief Create a directory with the given path/name.
 *        If one of the directories in the given path doesn't exist, this will fail.
 *        For example, if mkdir("A:/D/E/F") is requested where D exists but E doesn't,
 *        this function will fail and return an error.
 *
 * @param path Path to the directory to create, including the name and the
 *             NULL-terminator. Like for all the above paths, it can be a relative
 *             one or an absolute one.
 *             The pointer must NOT cross boundaries.
 *
 * @returns ERR_SUCCESS on success, error code else.
 */
zos_err_t mkdir(const char* path) CALL_CONV;


/**
 * @brief Change the current working directory.
 *
 * @param path Path to the new working directory. The string must be
 *             NULL-terminated.
 *
 * @returns ERR_SUCCESS on success, error code else.
 */
zos_err_t chdir(const char* path) CALL_CONV;


/**
 * @brief Get the current working directory.
 *
 * @param path Buffer to fill with the current working directory path. The
 *             buffer must be big enough to store PATH_MAX bytes.
 *
 * @returns ERR_SUCCESS on success, error code else.
 */
zos_err_t curdir(char* path) CALL_CONV;


/**
 * @brief Open a directory.
 *
 * @param path Path to the directory to open. The string must be NULL-terminated.
 *             Like for all the above paths, it can be a relative one or an
 *             absolute one.
 *
 * @returns Opened device number on success, negated error value else.
 *          For example, if ERR_FAILURE error occurred, -ERR_FAILURE will be
 *          returned.
 */
zos_dev_t opendir(const char* buf) CALL_CONV;


/**
 * @brief Read the next entry from the opened directory.
 *
 * @param dev Opened dev of the directory. If the given dev is not a directory,
 *            an error will be returned.
 * @param dst Pointer to the directory entry structure to fill.
 *
 * @returns ERR_SUCCESS on success, error code else.
 */
zos_err_t readdir(zos_dev_t dev, zos_dir_entry_t* dst) CALL_CONV;


/**
 * @brief Remove a file or an empty directory.
 *
 * @param path Path to the file or directory to remove.
 *
 * @returns ERR_SUCCESS on success, error code else.
 */
zos_err_t rm(const char* path) CALL_CONV;


/**
 * @brief Mount the opened driver as a disk.
 *        The letter assigned to the disk must not be in use.
 *
 * @param dev Driver's opened dev number that will act as a disk. The dev can be
 *            closed after mounting, this will not affect the mounted disk.
 * @param letter Letter to assign to the new disk (A-Z), not sensitive to case.
 * @param fs File system of the new disk to mount.
 *
 * @returns ERR_SUCCESS on success, error code else.
 */
zos_err_t mount(zos_dev_t dev, char letter, zos_fs_t fs) CALL_CONV;


/**
 * @brief Duplicate the given opened dev to a new index. This will only
 *        duplicate the "pointer" to the actual implementation. For example,
 *        duplicate the dev of an opened file and performing a seek on the it
 *        will affect both the old and the new dev.
 *        This can be handy to override the standard input or output.
 *
 * @note new dev number MUST be empty/closed before calling this function, else,
 *       an error will be returned.
 *
 * @param dev Dev number to duplicate.
 * @param ndev New number for the opened dev.
 *
 * @returns ERR_SUCCESS on success, error code else.
 */
zos_err_t dup(zos_dev_t dev, zos_dev_t ndev) CALL_CONV;


/**
 * @brief Map a physical address/region to a virtual address/region.
 *
 * @param vaddr Destination address in virtual memory. This will be rounded down
 *              to the target closest page bound.
 *              For example, passing 0x5000 here, would in fact trigger a
 *              remap of the page starting at 0x4000 on a target that has 16KB
 *              virtual pages.
 * @param paddr 32-bit physical address to map. If the target does not support
 *              the physical address given, an error will be returned.
 *              Similarly to the virtual address, the value may be rounded down
 *              to the closest page bound.
 *
 * @returns ERR_SUCCESS on success, error code else.
 */
zos_err_t map(void* vaddr, uint32_t paddr) CALL_CONV;
