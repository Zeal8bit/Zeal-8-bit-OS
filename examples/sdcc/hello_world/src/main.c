/* SPDX-FileCopyrightText: 2026 Zeal 8-bit Computer <contact@zeal8bit.com>
 *
 * SPDX-License-Identifier: CC0-1.0
 */

#include <stdio.h>

/* Zeal 8-bit OS provides a full libc for SDCC, so a simple printf() is enough
 * to write on the standard output. */
int main(void) {
    printf("Hello World!\n");
    return 0;
}
