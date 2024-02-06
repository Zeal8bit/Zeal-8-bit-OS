/* SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
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
 * @brief Kernel configuration structure
 */
typedef struct {
    zos_target_t c_target; // Machine number the OS is running on, 0 means UNKNOWN
    uint8_t  c_mmu;        // 0 if the MMU-less kernel is running, 1 else
    char     c_def_disk;   // Upper case letter for the default disk
    uint8_t  c_max_driver; // Maximum number of driver loadable in the kernel
    uint8_t  c_max_dev;    // Maximum number of opened devices in the kernel
    uint8_t  c_max_files;  // Maximum number of opened files in the kernel
    uint16_t c_max_path;   // Maximum path length
    void*    c_prog_addr;  // Virtual address where user programs are loaded
    void*    c_custom;     // Custom area, target-specific, can be NULL
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
 * @brief Get a read-only pointer to the kernel configuration.
 *
 * @returns A pointer to the kernel configuration. It is guaranteed that the
 *          structure won't be spread across two 256-byte pages. In other words,
 *          it is possible to browse the structure by performing 8-bit arithmetic.
 */
static inline const zos_config_t* kernel_config(void) {
    return *((zos_config_t**) 0x0004);
}