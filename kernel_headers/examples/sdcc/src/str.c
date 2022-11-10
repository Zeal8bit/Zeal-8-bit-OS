/* SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
 *
 * SPDX-License-Identifier: CC0-1.0
 */
#include <stdint.h>
#include <zos_vfs.h>

/* Function calculating the length of a string. It would have been much faster
 * to implement it in assembly or even using SDCC's one. But let's keep it
 * for the sake of the demonstration. */
static uint16_t strlen(const char* str)
{
    uint16_t len = 0;
    while(*str++) len++;
    return len;
}

/* Print the string given as a parameter to the standard output. */
zos_err_t print_string(const char* s)
{
    uint16_t len = strlen(s);
    return write(DEV_STDOUT, s, &len);
}