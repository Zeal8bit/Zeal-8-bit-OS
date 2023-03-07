/* SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
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
 * @brief Exit the program and give back the hand to the kernel.
 *
 * @returns No return
 */
void exit(void) CALL_CONV;


/**
 * @brief Load and execute a program from a file name given as a parameter.
 *        The program will cover the current program, replacing it completely.
 *
 * @param name Name of the executable to execute
 * @param argv Arguments to give to the program to execute. Currently, only
 *             the first one will be passed to the kernel. Can be NULL.
 *
 * @returns No return on success, the new program is executed.
 *          Returns error code on failure.
 */
zos_err_t exec(const char* name, char* argv[]) CALL_CONV;


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
