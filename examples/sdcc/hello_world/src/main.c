/* SPDX-FileCopyrightText: 2026 Zeal 8-bit Computer <contact@zeal8bit.com>
 *
 * SPDX-License-Identifier: CC0-1.0
 */

#include <stdio.h>

/**
 * Minimal example: print a message using the standard library.
 *
 * The Zeal 8-bit OS SDCC support provides a full libc, including stdio, so a
 * simple printf is enough to write to the standard output.
 */
int main(void) {
    printf("Hello World!\n");
    return 0;
}
