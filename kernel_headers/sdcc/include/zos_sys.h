/* SPDX-FileCopyrightText: 2023-2025 Zeal 8-bit Computer <contact@zeal8bit.com>
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#pragma once

#include <stdint.h>
#include "zos_errors.h"


/**
 * Define the calling convention for all the routines
 */
#if __SDCC_VERSION_MAJOR >= 4 && __SDCC_VERSION_MINOR >= 2
    #define CALL_CONV __sdcccall(1)
#else
    #error "Unsupported calling convention. Please upgrade your SDCC version."
#endif

/**
 * @brief Enumeration for all the supported machines.
 *        Check the configuration structure below to retrieve the current target.
 */
typedef enum {
    TARGET_UNKNOWN  = 0,
    TARGET_ZEAL8BIT = 1,
    TARGET_TRS80    = 2,
    TARGET_AGON     = 3,
    TARGET_COUNT
} zos_target_t;


/**
 * @brief Structure of available file systems names
 */
typedef struct {
    char    fs_name[4];
    uint8_t fs_padding[20];
} zos_fs_t;

_Static_assert(sizeof(zos_fs_t) == 24, "File system structure must be 24 bytes big");

/**
 * @brief Kernel configuration structure
 */
typedef struct {
    zos_target_t c_target; // Machine number the OS is running on, 0 means UNKNOWN
    uint8_t      c_mmu;        // 0 if the MMU-less kernel is running, 1 else
    char         c_def_disk;   // Upper case letter for the default disk
    uint8_t      c_max_driver; // Maximum number of driver loadable in the kernel
    uint8_t      c_max_dev;    // Maximum number of opened devices in the kernel
    uint8_t      c_max_files;  // Maximum number of opened files in the kernel
    uint16_t     c_max_path;   // Maximum path length
    void*        c_prog_addr;  // Virtual address where user programs are loaded
    void*        c_custom;     // Custom area, target-specific, can be NULL
    uint8_t      c_fs_count;   // Number of file systems entries in the array
    zos_fs_t*    c_fs;         // Supported file systems array
} zos_config_t;

/**
 * @brief Enumeration of all the modes for `exec` syscall
 */
typedef enum zos_exec_mode_t {
    EXEC_OVERRIDE_PROGRAM = 0,
    EXEC_PRESERVE_PROGRAM = 1
} zos_exec_mode_t;

/**
 * @brief Exit the program and give back the hand to the kernel. If the caller
 *        program invoked `exec()` with `EXEC_PRESERVE_PROGRAM` as the mode,
 *        it will be reloaded from RAM after exiting the current program.
 *
 * @param retval Return code to pass to caller program
 *
 * @returns No return
 */
void exit(uint8_t retval) CALL_CONV;


/**
 * @brief Load and execute a program from a file name given as a parameter.
 *        The current program, invoking this syscall, can either be preserved in memory
 *        until the sub-program finishes executing, or, it can be covered/overridden.
 *        In the first case, upon return, when not NULL, retval is filled with the return value
 *        of the sub-program.
 *        The depth of sub-programs is defined and limited in the kernel. As such, it is not
 *        guaranteed that it will always be possible to execute a sub-program while keeping
 *        the current one in memory. It depends on the target and kernel configuration.
 *        Can be invoked with EXEC().
 *
 * @param mode Mode marking whether the current program shall be preserved in RAM
 *             or overwritten by sub-program to execute.
 * @param name Name of the binary to execute
 * @param argv Arguments to give to the program to execute. Currently, only
 *             the first one will be passed to the kernel. Can be NULL.
 * @param retval Pointer to store the return value of the sub-program when exec() succeeded.
 *               Can be NULL.
 *
 * @returns No return on success, the new program is executed.
 *          Returns error code on failure.
 */
zos_err_t exec(zos_exec_mode_t mode, const char* name, const char* argv[], uint8_t* retval) CALL_CONV;


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
zos_err_t map(const void* vaddr, uint32_t paddr) CALL_CONV;


/**
 * @brief Allocate a RAM page of 16KB.
 *
 * This function is responsible for allocating a memory page, it will not be mapped
 * in the virtual address space directly, use `map` or `pmap` for that.
 *
 * @param page_index[out] Pointer to the page_index to be filled with the newly allocated
 *                        page index. This index shall be given to `pfree` upon release.
 *                        Must not be NULL.
 *
 * @returns ERR_SUCCESS on success,
 *          ERR_INVALID_PARAMETER if parameter is NULL
 *          ERR_NO_MORE_MEMORY if no free RAM page is available
 */
zos_err_t palloc(uint8_t* page_index) CALL_CONV;


/**
 * @brief Free a previously allocated RAM page.
 *
 * The current program can only free pages taht it previously allocated with `palloc`.
 * It CANNOT free pages allocated by other programs.
 *
 * @param page_index Index of the page to free. The physical address associated to this
 *                   page shall not be used afterwards.
 *
 * @returns ERR_SUCCESS on success,
 *          ERR_INVALID_PARAMETER if the page was not allocated by the current program
 */
zos_err_t pfree(uint8_t page_index) CALL_CONV;


/**
 * @brief Map a given page index to the virtual address.
 *
 * @note This is NOT a syscall but a helper!
 *
 * @param page_index Index of memory page to map, returned by `palloc`.
 * @param vaddr Destination address in virtual memory. This will be rounded down
 *              to the target closest page bound.
 *              For example, passing 0x5000 here, would in fact trigger a
 *              remap of the page starting at 0x4000 on a target that has 16KB
 *              virtual pages.
 *
 * @returns ERR_SUCCESS on success, error code else.
 */
zos_err_t pmap(uint8_t page_index, const void* vaddr) CALL_CONV;


/**
 * @brief Get a read-only pointer to the kernel configuration.
 *
 * @returns A pointer to the kernel configuration. It is guaranteed that the
 *          structure won't be spread across two 256-byte pages. In other words,
 *          it is possible to browse the structure by performing 8-bit arithmetic.
 */
static inline const zos_config_t* kernel_config(void)
{
    return *((zos_config_t**) 0x0004);
}


/**
 * @brief Search for a file system index given a name
 *
 * @param name File system name to look for, valid values are:
 *              - RAWT (Rawtable)
 *              - ZFS (ZealFS, version depends on the kernel)
 *              - HOST (HostFS)
 * @param fs_index Pointer to the index to return
 */
zos_err_t zos_search_fs(const char* name, uint8_t* fs_index);